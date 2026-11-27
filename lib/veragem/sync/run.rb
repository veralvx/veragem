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
        orphan: "veragem removed it, you changed it", conflict: "veragem added it, yours differs",
        adopted: "yours differs from veragem's", conflicted: "merged, its conflicts marked",
        unmerged: "veragem and you changed it, and its base is lost: merge it by hand"
      }.freeze
      private_constant :MEANINGS

      # @param dir [String] the gem's directory
      # @param record [Veragem::Record] its record, or the one --adopt starts from
      # @param options [Hash{Symbol => String, Boolean}] Sync.options', and adopt
      # @param input [#gets, #tty?] where --interactive's choice is typed
      # @param output [#puts, #print] where the plan is shown
      # @option options [Boolean] :dry_run show the plan, and change nothing
      # @option options [Boolean] :interactive ask which files change
      # @option options [Boolean] :adopt the gem has no record yet
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

        entries = Generator.entries(@record.project).select(&:harness).to_h { [it.path, it] }
        rows = rows(entries)
        chosen = choose(rows.reject { it.action == :same })
        finish(rows, chosen, entries) unless @options[:dry_run]
      end

      private

      def rows(entries)
        paths = @record.files.keys | entries.keys
        check_clean(paths) unless @options[:dry_run]
        theirs = entries.transform_values { Git.id(@dir, it.path, it.bytes) }
        Plan.rows(@record.files, ours(paths), theirs, adopt: @options.key?(:adopt))
      end

      def check_clean(paths)
        changed = Git.output(@dir, "status", "--porcelain", "--", Record::FILE, *paths)
        raise Error, "commit or stash the harness's changes first:\n#{changed}" unless changed.empty?
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
        choice(shown.size, taken.map { shown.index(it).to_i + 1 }).map { shown.fetch(it - 1) }
      end

      # The numbers chosen, asked again until a choice
      def choice(count, defaults)
        loop do
          @output.print Selection::PROMPT
          answer = @input.gets or raise Error, "no choice made"
          chosen = Selection.parse(answer, count, defaults) and return chosen
        end
      end

      def line(row) = "#{row.path}: #{MEANINGS.fetch(row.action)}"

      # How it went: :done, :conflicted (merged, conflicts marked) or :unmerged (no base, kept)
      def apply(row, entry)
        case row.action
        when :delete, :orphan then File.delete(File.join(@dir, row.path))
        when :merge then return merge(row, entry || raise)
        else Generator.write(@dir, entry || raise)
        end
        :done
      end

      def merge(row, entry)
        base = base(row.base || raise) or return :unmerged
        bytes, conflicts = merged(row.path, base, entry.bytes)
        Generator.write(@dir, entry.with(bytes:))
        conflicts.zero? ? :done : :conflicted
      end

      def merged(path, base, theirs)
        Dir.mktmpdir("veragem-sync") do |tmp|
          File.binwrite(File.join(tmp, "base"), base)
          File.binwrite(File.join(tmp, "theirs"), theirs)
          Git.merge(@dir, path, File.join(tmp, "base"), File.join(tmp, "theirs"))
        end
      end

      # The base's bytes: in the repository, or else rebuilt by its release, once; nil if neither
      def base(id)
        rebuild unless @rebuilt || Git.object?(@dir, id)
        Git.output(@dir, "cat-file", "blob", id) if Git.object?(@dir, id)
      end

      # The record's release writes its harness again, each file's object written: the bases
      def rebuild
        @rebuilt = true
        return unless @record.source == "release"

        Source.harness(@record.version, @dir).each { |path, bytes| Git.id(@dir, path, bytes) }
      end

      def finish(rows, chosen, entries)
        outcomes = chosen.to_h { [it, apply(it, entries[it.path])] }
        files = Plan.recorded(rows, chosen.reject { outcomes[it] == :unmerged })
        Record.new(version: VERSION, source: Sync.source, name: @record.name, values: @record.values, files:)
              .write(@dir)
        left = unresolved(rows, chosen, outcomes)
        raise Error, "resolve, then commit:\n#{left.join("\n")}" unless left.empty?
      end

      # A conflict not taken, and a merge not done
      def unresolved(rows, chosen, outcomes)
        left = rows.select { it.action == :conflict && !chosen.include?(it) }.to_h { [it, :conflict] }
        left.merge(outcomes.reject { |_, outcome| outcome == :done }).map do |row, why|
          "  #{row.path}: #{MEANINGS.fetch(why)}"
        end
      end
    end
  end
end
