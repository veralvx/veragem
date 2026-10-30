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
    # Each option after --exe and --license, and its --help.
    OPTIONS = [
      ["--author=NAME", "The author (default: git config user.name)"],
      ["--[no-]email=EMAIL", "The author's email (default: git config user.email; --no-email, none)"],
      ["--github=USER", "The GitHub user or organization (default: git config github.user)"],
      ["--summary=TEXT", "The gem's summary (default: A Ruby gem.)"],
      ["--[no-]citation", "Add CITATION.cff, the citation GitHub and Zenodo read (default: --no-citation)"],
      ["--family-names=NAMES", "With --citation: the author's family names, CITATION.cff's (required)"],
      ["--[no-]given-names=NAMES", "With --citation: the author's given names, CITATION.cff's (--no-given-names, none)"]
    ].freeze #: Array[[String, String]]
    private_constant :GIT_CONFIG, :DEFAULTS, :BANNER, :OPTIONS

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
    private_class_method def self.arguments(argv)
      given = {} #: Hash[Symbol, String | bool]
      # an argument of invalid UTF-8 as bytes, as git's values are: OptionParser's matching raises on
      # it, Project refuses it
      names = parser.permute(argv.map { it.valid_encoding? ? it : it.b }, into: given)
      # OptionParser keys --given-names as :"given-names"; Project's are :given_names
      given.transform_keys! { it.name.tr("-", "_").to_sym }
      given.each { |key, value| Project.check(key, value) if value.is_a?(String) }
      Project.check_citation(given[:citation] == true, given) if given.key?(:citation)
      [names, given]
    end

    # From a terminal: the names counted, as without one, then the name checked before any question.
    private_class_method def self.ask(names, given, defaults, questions)
      name = questions.name((name_of(names) unless names.empty?), exe: given[:exe] == true)
      # rubocop:disable-next Lint/NameTypo -- the project index lacks Class#new, and takes Project#nest for it
      Project.new(name, questions.values(name, given, defaults))
    end

    private_class_method def self.name_of(names)
      return names.fetch(0) if names.size == 1

      raise Error, "one gem name, not #{names.size} (bundle veragem --help)"
    end

    private_class_method def self.required(values)
      %i[author github].each { raise Error, "no #{it}: --#{it}, or git config #{GIT_CONFIG[it]}" unless values[it] }
      values.compact
    end

    private_class_method def self.parser
      OptionParser.new(BANNER) do |opts|
        opts.program_name = "bundle veragem"
        opts.version = VERSION
        opts.on("--[no-]exe", "Add a command line, exe/NAME (default: --no-exe, a library alone)")
        opts.on("--license=LICENSE", Project::LICENSES.keys, "mit, apache or dual (MIT OR Apache-2.0, the default)")
        OPTIONS.each { |switch, help| opts.on(switch, help) }
      end
    end

    # A git config value, nil when unset or git is missing: its bytes, which Project reads as UTF-8
    # whatever the locale.
    private_class_method def self.git_config(key)
      command = ["git", "config", "--get", key]
      value = IO.popen(command, err: File::NULL, external_encoding: Encoding::BINARY, &:read).strip
      value unless value.empty?
    rescue SystemCallError
      nil
    end
  end
end
