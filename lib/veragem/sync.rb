# frozen_string_literal: true

require "optparse"
require "stringio"
require_relative "sync/plan"
require_relative "sync/selection"
require_relative "sync/run"
require_relative "sync/source"

module Veragem
  # `bundle veragem-sync`: a gem's harness brought to a veragem's, the latest release's or a
  # checkout's (--path), each file as `git merge-file` would: veragem's changes taken where you made
  # none, merged where you made some, and yours kept where veragem made none. The gem's own files
  # (Generator::OWN) it never touches.
  #
  # Stable across versions, as one veragem runs another's (Source): lib/veragem/sync.rb, main's
  # arguments, render, Record.read and the record's fields, Veragem::Error, and veragem loaded with
  # the standard library alone. An installed plugin's launcher reads --path as Source::PATH does:
  # --path never abbreviated, and a short option before -p in a group takes no value.
  module Sync
    # --help's first line.
    BANNER = "Usage: bundle veragem-sync [--path DIR] [--dry-run] [--interactive] [--force] " \
             "[--adopt NAME [bundle veragem's options]]"
    # Each option and its --help.
    OPTIONS = [
      ["-p", "--path=DIR", "Sync from the veragem checkout at DIR (default: the latest release)"],
      ["-n", "--dry-run", "Show what would change, and change nothing"],
      ["-i", "--interactive", "Choose which files change"],
      ["-f", "--force", "Sync from an older veragem, or a release after a checkout of its version"],
      ["--adopt", "A gem with no .veragem.yml: its values, as bundle veragem takes them, follow"]
    ].freeze #: Array[Array[String]]
    private_constant :OPTIONS

    # Syncs the gem in +dir+ from this veragem, as +argv+ says.
    # @param argv [Array<String>] the command's arguments
    # @param dir [String] the gem's directory
    # @param input [#gets, #tty?] where --interactive's choice is typed
    # @param output [#puts, #print] where the plan is shown
    # @return [void]
    # @raise [Veragem::Error] sync refuses, or a file is left in conflict
    def self.main(argv, dir: Dir.pwd, input: $stdin, output: $stdout)
      options, adopt = options(argv)
      record = adopt ? adopted(adopt, dir) : Record.read(dir).tap { check(it, options.key?(:force)) }
      Run.new(dir, record, options, input:, output:).call
    rescue SystemCallError => e
      raise Error, e.message
    end

    # The options +argv+ gives, and the arguments that follow --adopt, nil without it.
    # @param argv [Array<String>] the command's arguments
    # @return [Array(Hash{Symbol => String, Boolean}, Array<String>), Array(Hash{Symbol => String, Boolean}, nil)]
    # @raise [Veragem::Error] an option is refused
    def self.options(argv)
      own, adopt = argv.index("--adopt").then { it ? [argv.take(it), argv.drop(it + 1)] : [argv, nil] }
      given = {} #: options
      rest = parser.parse(own, into: given)
      raise Error, "no such argument #{rest.first} (bundle veragem-sync --help)" unless rest.empty?

      [given.transform_keys { it.name.tr("-", "_").to_sym }, adopt]
    rescue OptionParser::ParseError => e
      raise Error, "#{e} (bundle veragem-sync --help)"
    end

    # The harness this veragem writes for the gem +record+ holds, written into +dir+.
    # @param record [Veragem::Record]
    # @param dir [String]
    # @return [void]
    def self.render(record, dir)
      Generator.entries(record.project).select(&:harness).each { Generator.write(dir, it) }
    end

    # Where this veragem comes from: "release" or "path".
    # @return [String]
    def self.source = Record.source_of(File.dirname(Generator::TEMPLATE))

    # The record a gem with none starts from: the values +argv+ gives, as `bundle veragem` reads
    # them, and no file.
    private_class_method def self.adopted(argv, dir)
      if File.exist?(File.join(dir, Record::FILE))
        raise Error, "#{dir} has #{Record::FILE} already: sync it without --adopt"
      end

      project = Options.parse(argv, dir:, input: StringIO.new)
      Record.new(version: VERSION, source:, name: project.name, values: Record.values_of(project), files: {})
    end

    # An older veragem than the record's would undo its changes, and a release those of the checkout
    # at its version, which the record had.
    private_class_method def self.check(record, force)
      return if force

      recorded = Gem::Version.new(record.version)
      if Gem::Version.new(VERSION) < recorded
        raise Error, "veragem #{VERSION} is older than #{record.version}, which last synced the harness (--force)"
      end
      return unless Gem::Version.new(VERSION) == recorded && source == "release" && record.source == "path"

      raise Error, "veragem #{VERSION}'s release would undo the checkout of #{VERSION} that last synced the " \
                   "harness: --path to a checkout (--force)"
    end

    private_class_method def self.parser
      OptionParser.new(BANNER) do |opts|
        opts.program_name = "bundle veragem-sync"
        # the launcher reads --path as given, never abbreviated
        opts.require_exact = true
        opts.version = VERSION
        OPTIONS.each { opts.on(*it) }
      end
    end
  end
end
