# frozen_string_literal: true

require "optparse"

module Veragem
  # The command line, read into a Project; git's config gives the author, the email and the GitHub
  # user, as `bundle gem` reads them. With a terminal for input, what no option gives is asked for.
  module Options
    GIT_CONFIG = { author: "user.name", email: "user.email", github: "github.user" }.freeze
    DEFAULTS = { summary: "A Ruby gem.", license: "dual" }.freeze
    BANNER = "Usage: bundle veragem NAME [options]\n" \
             "With a terminal for input, what no option gives (the name too) is asked for."

    # +dir+, where the gem is to be generated; the questions on +output+, as a prompt is.
    def self.parse(argv, dir: Dir.pwd, config: ->(key) { git_config(key) }, input: $stdin, output: $stderr)
      given = {} #: Hash[Symbol, String | bool]
      # an argument of invalid UTF-8 as bytes, as git's values are: OptionParser's matching raises on
      # it, Project refuses it
      names = parser.permute(argv.map { it.valid_encoding? ? it : it.b }, into: given)
      defaults = { **DEFAULTS, **GIT_CONFIG.transform_values(&config).compact }
      # rubocop:disable-next Lint/NameTypo -- the project index lacks Class#new, and takes Project#nest for it
      return Project.new(name_of(names), required(defaults.merge(given))) unless input.tty?

      ask(names, given, defaults, Questions.new(input, output, dir))
    rescue OptionParser::ParseError => e
      raise Error, "#{e.message} (bundle veragem --help)"
    end

    def self.ask(names, given, defaults, questions)
      questions.check(given)
      name = questions.name(names.empty? ? nil : name_of(names), exe: given[:exe] == true)
      # rubocop:disable-next Lint/NameTypo -- the project index lacks Class#new, and takes Project#nest for it
      Project.new(name, required(questions.values(name, given, defaults)))
    end

    def self.name_of(names)
      return names.fetch(0) if names.size == 1

      raise Error, "one gem name, not #{names.size} (bundle veragem --help)"
    end

    # The values set, the author and the GitHub user required.
    def self.required(values)
      %i[author github].each { raise Error, "no #{it}: --#{it}, or git config #{GIT_CONFIG[it]}" unless values[it] }
      values.compact
    end

    def self.parser
      OptionParser.new(BANNER) do |opts|
        opts.program_name = "bundle veragem"
        opts.version = VERSION
        opts.on("--exe", "Add a command line, exe/NAME")
        opts.on("--license=LICENSE", Project::LICENSES.keys, "mit, apache or dual (MIT OR Apache-2.0, the default)")
        opts.on("--author=NAME", "The author (default: git config user.name)")
        opts.on("--email=EMAIL", "The author's email (default: git config user.email)")
        opts.on("--github=USER", "The GitHub user or organization (default: git config github.user)")
        opts.on("--summary=TEXT", "The gem's summary (default: A Ruby gem.)")
      end
    end

    # A git config value, nil when unset or git is missing: its bytes, which Project reads as UTF-8
    # whatever the locale.
    def self.git_config(key)
      command = ["git", "config", "--get", key]
      value = IO.popen(command, err: File::NULL, external_encoding: Encoding::BINARY, &:read).strip
      value unless value.empty?
    rescue SystemCallError
      nil
    end
  end
end
