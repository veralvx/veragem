# frozen_string_literal: true

# A warning Ruby reports from lib/ or the tests raises, failing the test, or the run when they load;
# a gem's only prints. Every category is on: `ruby -w` turns on the deprecations alone.
ours = [File.expand_path("../lib", __dir__), __dir__].map { "#{it}/" }
# Anonymous: a constant would meet a gem's own module (own_warnings: OwnWarnings)
own_warnings = Module.new do
  define_method(:warn) do |message, **options|
    # "PATH:LINE: ..." or, evaluated code's, "(eval at PATH:LINE):LINE: ..."; PATH relative or
    # absolute (Windows': C:/...)
    path = message[/\A(?:\(eval at )*(.+?):\d+[:)]/, 1]
    raise message if path && File.expand_path(path).start_with?(*ours)

    super(message, **options)
  end
end
Warning.singleton_class.prepend(own_warnings)
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

    # git's output in +dir+'s repository, whatever repository a git hook running the tests points at;
    # a failure raises, not read as no output
    def git(dir, *args)
      output = IO.popen(Generator.const_get(:GIT_LOCAL), ["git", *args], chdir: dir, &:read)
      raise "git #{args.join(" ")} failed in #{dir}" unless Process.last_status.success?

      output
    end

    # Pbt's printable strings, and its ASCII's: Unicode's alone hardly hold a quote, a backslash or
    # markup
    def texts = [Pbt.printable_string, Pbt.printable_ascii_string]

    # the block with +object+'s method +name+ replaced by +stub+: then its own again, or the one it
    # inherits
    def stubbed(object, name, stub)
      own = object.method(name) if object.singleton_class.method_defined?(name, false)
      silently { object.define_singleton_method(name, &stub) }
      yield
    ensure
      object.singleton_class.remove_method(name)
      object.define_singleton_method(name, own) if own
    end

    # Ruby's warnings off for the block: one of a method redefined, which the tests would count as
    # their own
    def silently
      verbose = $VERBOSE
      $VERBOSE = nil
      yield
    ensure
      $VERBOSE = verbose
    end

    # silently: Ruby warns of a default external encoding set
    def with_encodings(external, internal)
      saved = [Encoding.default_external, Encoding.default_internal]
      silently do
        Encoding.default_external = external
        Encoding.default_internal = internal
      end
      yield
    ensure
      silently { Encoding.default_external, Encoding.default_internal = saved }
    end

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

    # the project, and what the terminal showed: every answer read
    def ask(*argv, answers: [], config: CONFIG, dir: nil)
      input = terminal(*answers)
      output = screen
      gem = at_terminal(argv, input:, config:, dir:, output:)

      assert_empty input.read, "answers left unread"
      [gem, output.string]
    end

    # the refusal, and what the terminal showed by then
    def refused(*argv, answers: [], config: CONFIG, dir: nil)
      output = screen
      error = assert_raises(Error) { at_terminal(argv, input: terminal(*answers), config:, dir:, output:) }
      [error.message, output.string]
    end

    # what the terminal shows, as UTF-8's text whatever the default external encoding
    def screen = StringIO.new(+"")

    # +argv+ at a terminal, generating into +dir+, or else a directory of its own
    def at_terminal(argv, input:, config:, dir:, output:)
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
    include TestSupport

    # The files git's index of +dir+ holds as executable (mode 100755), under +paths+
    def indexed_executables(dir, *paths)
      git(dir, "ls-files", "--stage", "-z", "--", *paths).split("\0").filter_map do |entry|
        mode, *, path = entry.split(/\s/, 4)
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
      # without RUBYOPT, whose options (-v) would print before the JSON
      JSON.parse(IO.popen({ "RUBYOPT" => nil }, [RbConfig.ruby, "-rjson", "-e", script, "#{gem.name}.gemspec"],
                          chdir: target, external_encoding: Encoding::UTF_8, &:read))
    end
  end
end
