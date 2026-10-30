# frozen_string_literal: true

require "optparse"

module Veragem
  # The command line, read into a Project; git's config gives the author, the email and the GitHub
  # user, as `bundle gem` reads them. With a terminal for input, what no option gives is asked for.
  module Options
    # The values git's config gives, and their keys there.
    GIT_CONFIG = { author: "user.name", email: "user.email", github: "github.user" }.freeze
    # The values no option and no git config need give.
    DEFAULTS = { summary: "A Ruby gem.", license: "dual" }.freeze
    # --help's first lines.
    BANNER = "Usage: bundle veragem NAME [options]\n" \
             "With a terminal for input, what no option gives (the name too) is asked for."

    # +dir+, where the gem is to be generated; the questions on +output+, as a prompt is.
    # @param argv [Array<String>] the command's arguments
    # @param dir [String] where the gem is to be generated
    # @param config [Proc] a git config key's value, nil when unset
    # @param input [#gets, #tty?] where the answers are typed; asked only when a terminal
    # @param output [#print, #puts] where the questions are shown
    # @return [Veragem::Project]
    # @raise [Veragem::Error] an argument or a value is refused, or a question has no answer
    def self.parse(argv, dir: Dir.pwd, config: ->(key) { git_config(key) }, input: $stdin, output: $stderr)
      names, given = arguments(argv)
      defaults = { **DEFAULTS, **GIT_CONFIG.transform_values(&config).compact }
      # rubocop:disable-next Lint/NameTypo -- the project index lacks Class#new, and takes Project#nest for it
      return Project.new(name_of(names), required(defaults.merge(given))) unless input.tty?

      ask(names, given, defaults, Questions.new(input, output, dir))
    rescue OptionParser::ParseError => e
      raise Error, "#{e.message} (bundle veragem --help)"
    end

    # The names and the options given, each option refused as OptionParser refuses a licence: before
    # the name, and any question.
    # @param argv [Array<String>] the command's arguments
    # @return [Array(Array<String>, Hash{Symbol => String, Boolean})] the names, and the options' values
    # @raise [OptionParser::ParseError] OptionParser refuses an argument
    # @raise [Veragem::Error] an option's value is refused
    def self.arguments(argv)
      given = {} #: Hash[Symbol, String | bool]
      # an argument of invalid UTF-8 as bytes, as git's values are: OptionParser's matching raises on
      # it, Project refuses it
      names = parser.permute(argv.map { it.valid_encoding? ? it : it.b }, into: given)
      given.each { |key, value| Project.check(key, value) if value.is_a?(String) }
      [names, given]
    end

    # From a terminal: the names counted, as without one, then the name checked before any question.
    # @param names [Array<String>] the arguments not options
    # @param given [Hash{Symbol => String, Boolean}] the options' values
    # @param defaults [Hash{Symbol => String}] git's and DEFAULTS
    # @param questions [Veragem::Questions] the terminal's
    # @return [Veragem::Project]
    # @raise [Veragem::Error] a name or a value is refused, or a question has no answer
    def self.ask(names, given, defaults, questions)
      name = questions.name((name_of(names) unless names.empty?), exe: given[:exe] == true)
      # rubocop:disable-next Lint/NameTypo -- the project index lacks Class#new, and takes Project#nest for it
      Project.new(name, questions.values(name, given, defaults))
    end

    # The one name of +names+.
    # @param names [Array<String>] the arguments not options
    # @return [String]
    # @raise [Veragem::Error] there is not one
    def self.name_of(names)
      return names.fetch(0) if names.size == 1

      raise Error, "one gem name, not #{names.size} (bundle veragem --help)"
    end

    # The values set, the author and the GitHub user required.
    # @param values [Hash{Symbol => String, Boolean, nil}] the defaults, the options' over them
    # @return [Hash{Symbol => String, Boolean}]
    # @raise [Veragem::Error] the author or the GitHub user is missing
    def self.required(values)
      %i[author github].each { raise Error, "no #{it}: --#{it}, or git config #{GIT_CONFIG[it]}" unless values[it] }
      values.compact
    end

    # The options, their --help.
    # @return [OptionParser]
    def self.parser
      OptionParser.new(BANNER) do |opts|
        opts.program_name = "bundle veragem"
        opts.version = VERSION
        opts.on("--[no-]exe", "Add a command line, exe/NAME (default: --no-exe, a library alone)")
        opts.on("--license=LICENSE", Project::LICENSES.keys, "mit, apache or dual (MIT OR Apache-2.0, the default)")
        opts.on("--author=NAME", "The author (default: git config user.name)")
        opts.on("--[no-]email=EMAIL", "The author's email (default: git config user.email; --no-email, none)")
        opts.on("--github=USER", "The GitHub user or organization (default: git config github.user)")
        opts.on("--summary=TEXT", "The gem's summary (default: A Ruby gem.)")
      end
    end

    # A git config value, nil when unset or git is missing: its bytes, which Project reads as UTF-8
    # whatever the locale.
    # @param key [String] user.name, user.email or github.user
    # @return [String, nil]
    def self.git_config(key)
      command = ["git", "config", "--get", key]
      value = IO.popen(command, err: File::NULL, external_encoding: Encoding::BINARY, &:read).strip
      value unless value.empty?
    rescue SystemCallError
      nil
    end
  end
end
