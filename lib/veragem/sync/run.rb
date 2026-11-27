# frozen_string_literal: true

require "tmpdir"

module Veragem
  module Sync
    # One sync of a gem's harness: planned, shown, chosen, applied, then recorded.
    class Run
      # What each action, and a merge's outcome, means.
      MEANINGS = {
        add: "veragem added it", update: "veragem changed it, you did not", delete: "veragem removed it",
        merge: "veragem and you changed it", keep: "you changed it, veragem did not", removed: "you removed it",
        orphan: "veragem removed it, you changed it", adopted: "yours differs from veragem's",
        conflicted: "merged, its conflicts marked",
        lost: "merged without its base, which is lost: check it, from its first difference to its last"
      }.freeze
      private_constant :MEANINGS

      # @param dir [String] the gem's directory
      # @param record [Veragem::Record] its record, or the one --adopt starts from
      # @param options [Hash{Symbol => String, Boolean}] Sync.options'
      # @param input [#gets, #tty?] where --interactive's choice is typed
      # @param output [#puts, #print] where the plan is shown
      # @option options [Boolean] :dry_run show the plan, and change nothing
      # @option options [Boolean] :interactive ask which files change
      # @return [void]
      def initialize(dir, record, options, input:, output:)
        @dir = dir
        @record = record
        @options = options
        @input = input
        @output = output
      end

      # Syncs the harness, then writes the record, a file left to resolve or not.
      # @return [void]
      # @raise [Veragem::Error] a file is left to resolve, --interactive has no terminal, the harness
      #   has changes not committed, or git fails
      def call
        raise Error, "--interactive needs a terminal" if @options[:interactive] && !@input.tty?

        entries, own = harness
        rows = rows(entries, own)
        chosen = choose(rows.reject { it.action == :same })
        finish(rows, chosen, entries) unless @options[:dry_run]
      end

      private

      # this veragem's harness, each file by its path, and the paths of the gem's own
      def harness
        harness, own = Generator.entries(@record.project).partition(&:harness)
        [harness.to_h { [it.path, it] }, own.map(&:path)]
      end

      # a file this veragem takes as the gem's own is no longer the harness's: unrecorded, untouched
      def rows(entries, own)
        recorded = @record.files.except(*own)
        paths = recorded.keys | entries.keys
        check_clean(paths) unless @options[:dry_run]
        theirs = entries.transform_values { Git.id(@dir, it.path, it.bytes) }
        Plan.rows(recorded, ours(paths), theirs)
      end

      # an ignored file too, which no commit holds: every file sync writes or deletes is git's to restore
      def check_clean(paths)
        changed = Git.output(@dir, "--literal-pathspecs", "status", "--porcelain", "--ignored", "--", Record::FILE,
                             *paths)
        raise Error, "commit, stash or remove the harness's changes first:\n#{changed}" unless changed.empty?
      end

      def ours(paths) = Git.ids(@dir, paths.select { File.file?(File.join(@dir, it)) })

      # The rows chosen: asked, or those sync takes unasked; each shown
      def choose(shown)
        taken = shown.select { Plan::APPLIED.include?(it.action) }
        @output.puts "#{shown.empty? ? "Nothing to sync" : "Sync"} from veragem #{VERSION} (#{Sync.source})"
        return ask(shown, taken) if @options[:interactive] && !shown.empty?

        shown.each { @output.puts "  #{taken.include?(it) ? "sync" : "keep"} #{line(it)}" }
        taken
      end

      def ask(shown, taken)
        shown.each.with_index(1) { |row, n| @output.puts "#{taken.include?(row) ? "*" : " "}#{n}. #{line(row)}" }
        defaults = shown.each.with_index(1).filter_map { |row, n| n if taken.include?(row) }
        Selection.ask(@input, @output, shown.size, defaults).map { shown.fetch(it - 1) }
      end

      def line(row, why = row.action) = "#{row.path}: #{MEANINGS.fetch(why)}"

      # How it went: :done, :conflicted (conflicts marked) or :lost (its base too)
      def apply(row, entry, bases)
        case row.action
        when :delete, :orphan then File.delete(File.join(@dir, row.path))
        when :merge then return merge(row, entry || raise, bases[row])
        else Generator.write(@dir, entry || raise)
        end
        :done
      end

      def merge(row, entry, base)
        bytes, conflicts = Git.merge(@dir, row.path, base || "", entry.bytes)
        Generator.write(@dir, entry.with(bytes:))
        # without its base, even a merge git marks nothing in (yours emptied) is yours to check
        return :lost unless base

        conflicts.zero? ? :done : :conflicted
      end

      # Each merge's base, before any file is written: in the repository, or else written again by
      # the record's release; nil where neither has it
      def bases(merges)
        ids = merges.to_h { [it, it.base || raise] }
        rebuild unless ids.values.all? { Git.object?(@dir, it) }
        ids.transform_values { Git.output(@dir, "cat-file", "blob", it) if Git.object?(@dir, it) }.tap { lost(it) }
      end

      def lost(bases)
        paths = bases.select { |_, base| base.nil? }.map { |row, _| row.path }
        @output.puts "No base for #{paths.join(", ")}: veragem #{@record.version}'s, lost" unless paths.empty?
      end

      # The record's release writes its harness again, each file's object written: the bases. A
      # checkout's, or a release that cannot be fetched or run, leaves them lost.
      def rebuild
        return unless @record.source == "release"

        Source.harness(@record.version, @dir).each { |path, bytes| Git.id(@dir, path, bytes) }
      rescue Error => e
        @output.puts e.message
      end

      # The chosen applied, their bases read first; then the record written, and what is left to resolve
      # refused
      def finish(rows, chosen, entries)
        left = applied(chosen, entries).reject { |_, outcome| outcome == :done }
        record(Plan.recorded(rows, chosen))
        return if left.empty?

        raise Error, "resolve, then commit:\n#{left.map { |row, why| "  #{line(row, why)}" }.join("\n")}"
      end

      # Each chosen row's outcome; its executables staged
      def applied(chosen, entries)
        bases = bases(chosen.select { it.action == :merge })
        chosen.to_h { [it, apply(it, entries[it.path], bases)] }.tap do
          # an executable new to the gem staged, its mode with it, which a file system may lack
          # (Windows); one it had keeps its index's mode, a merge's markers out of the index
          Git.executable(@dir, chosen.reject(&:ours).filter_map { entries[it.path] }.select(&:executable).map(&:path))
        end
      end

      def record(files)
        Record.new(version: VERSION, source: Sync.source, name: @record.name, values: @record.values, files:)
              .write(@dir)
      end
    end
  end
end
