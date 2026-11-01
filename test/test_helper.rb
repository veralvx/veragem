# frozen_string_literal: true

# A warning from lib/ or the tests raises, failing the test that caused it; a gem's only prints. Every
# category is on: `ruby -w` turns on the deprecations alone.
module OwnWarnings
  OURS = [File.expand_path("../lib", __dir__), __dir__].map { "#{it}/" }.freeze

  def warn(message, category: nil, **)
    # "PATH:LINE: ...", PATH relative or absolute (Windows': C:/...)
    path = message[/\A(.+?):\d+: /, 1]
    raise message if path && File.expand_path(path).start_with?(*OURS)

    super
  end
end
Warning.singleton_class.prepend(OwnWarnings)
Warning.categories.each { Warning[it] = true }

require "veragem"

require "minitest/autorun"
require "pbt"
require "json"
require "tmpdir"

module Veragem
  # What the tests share: a project's values, and a directory to generate into.
  module TestSupport
    VALUES = { author: "Jane Doe", github: "jane", summary: "A Ruby gem.", license: "dual" }.freeze
    # git's config, as `config:` reads it
    CONFIG = { "user.name" => "Jane Doe", "user.email" => "jane@example.com", "github.user" => "jane" }.freeze

    # rubocop:disable-next Lint/NameTypo -- the project index lacks Class#new, and takes Project#nest for it
    def project(name = "my_gem", **values) = Project.new(name, VALUES.merge(values))

    # not a terminal: nothing asked
    def parse(*argv, config: CONFIG) = Options.parse(argv, config: config.method(:[]), input: StringIO.new)

    def in_tmpdir(&) = Dir.mktmpdir("veragem-test", &)

    def with_env(values)
      saved = ENV.to_h
      ENV.update(values)
      yield
    ensure
      ENV.replace(saved)
    end
  end

  # What the questions' tests share: a terminal, and what it was asked.
  module TerminalSupport
    include TestSupport

    # +answers+ typed at a terminal, one a line
    def terminal(*answers) = StringIO.new(answers.map { "#{it}\n" }.join).tap { |io| def io.tty? = true }

    # the project, and what the terminal showed
    def ask(*argv, answers: [], config: CONFIG, dir: nil)
      output = StringIO.new
      [at_terminal(argv, answers:, config:, dir:, output:), output.string]
    end

    # the refusal, and what the terminal showed by then
    def refused(*argv, answers: [], config: CONFIG, dir: nil)
      output = StringIO.new
      error = assert_raises(Error) { at_terminal(argv, answers:, config:, dir:, output:) }
      [error.message, output.string]
    end

    # +argv+ at a terminal, generating into +dir+, or else a directory of its own
    def at_terminal(argv, answers:, config:, dir:, output:)
      input = terminal(*answers)
      into = ->(target) { Options.parse(argv, dir: target, config: config.method(:[]), input:, output:) }
      dir ? into.call(dir) : in_tmpdir(&into)
    end
  end

  # What the citation's tests share: the refusal of its values without one, and an ORCID iD.
  module CitationSupport
    NEEDED = "--given-names, --family-names, --alias, --orcid and --keywords are CITATION.cff's: they need a citation"
    ORCID = "https://orcid.org/0000-0002-1825-0097"
  end

  # What the generator's tests share: each kind generated, and what it holds.
  module GeneratedSupport
    # The files git's index of +dir+ holds as executable (mode 100755), under +paths+
    def indexed_executables(dir, *paths)
      IO.popen(["git", "ls-files", "--stage", "--", *paths], chdir: dir, &:readlines).filter_map do |entry|
        mode, *, path = entry.chomp.split(/\s/, 4)
        path if mode == "100755"
      end
    end

    # Each kind and license, generated: its project, its directory and its files.
    def each_kind
      [["my_gem", false, "dual"], ["my-tool", true, "mit"], ["my_lib", false, "apache"]].each do |name, exe, license|
        in_tmpdir do |dir|
          gem = project(name, exe:, license:, email: "jane@example.com")
          target = File.join(dir, name)
          Veragem::Generator.generate(gem, target)
          yield gem, target, files_in(target)
        end
      end
    end

    def files_in(target)
      Dir.glob("**/*", File::FNM_DOTMATCH, base: target).reject do |file|
        file.start_with?(".git/") || File.directory?(File.join(target, file))
      end
    end

    def read(target, file) = File.read(File.join(target, file), encoding: Encoding::UTF_8)

    # The gemspec's fields, read in a process of its own: loading it defines the gem's module.
    def spec_of(target, gem)
      script = "spec = Gem::Specification.load(ARGV[0]); " \
               "print JSON.dump(%w[name version authors email licenses homepage executables files summary]" \
               ".to_h { [it, spec.public_send(it).then { |v| v.is_a?(Gem::Version) ? v.to_s : v }] })"
      JSON.parse(IO.popen([RbConfig.ruby, "-rjson", "-e", script, "#{gem.name}.gemspec"],
                          chdir: target, external_encoding: Encoding::UTF_8, &:read))
    end
  end
end
