# frozen_string_literal: true

require "optparse"

module Veragem
  # The command line, read into a Project; git's config gives the author, the email and the GitHub
  # user, as `bundle gem` reads them.
  module Options
    GIT_CONFIG = { author: "user.name", email: "user.email", github: "github.user" }.freeze

    def self.parse(argv, config: ->(key) { git_config(key) })
      values = GIT_CONFIG.transform_values { config.call(it) }
      # an argument of invalid UTF-8 as bytes, as git's values are: OptionParser's matching raises on
      # it, Project refuses it
      names = parser.permute(argv.map { it.valid_encoding? ? it : it.b }, into: values)
      raise Error, "one gem name, not #{names.size} (bundle veragem --help)" unless names.size == 1

      # rubocop:disable-next Lint/NameTypo -- the project index lacks Class#new, and takes Project#nest for it
      Project.new(names.fetch(0), { summary: "A Ruby gem.", license: "dual", **given(values) })
    rescue OptionParser::ParseError => e
      raise Error, "#{e.message} (bundle veragem --help)"
    end

    # The values set, the author and the GitHub user required.
    def self.given(values)
      %i[author github].each { raise Error, "no #{it}: --#{it}, or git config #{GIT_CONFIG[it]}" unless values[it] }
      values.compact
    end

    def self.parser
      OptionParser.new("Usage: bundle veragem NAME [options]") do |opts|
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
