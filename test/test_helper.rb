# frozen_string_literal: true

# A warning Ruby reports from lib/ or the tests raises, failing the test, or the run when they load;
# a gem's only prints. Every category is on: `ruby -w` turns on the deprecations alone.
ours = [File.expand_path("../lib", __dir__), __dir__].map { "#{it}/" }
# Anonymous: a constant would be the module of a gem named for it (own_warnings' OwnWarnings)
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
require "rubygems/package"
require "zlib"

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
      output = IO.popen(Git.const_get(:LOCAL), ["git", *args], chdir: dir, &:read)
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

  # What sync's tests share: a gem generated and committed, its record rewritten as an older
  # veragem's, and a sync of it.
  module SyncSupport
    include GeneratedSupport

    HEADING = "from veragem #{VERSION} (path)".freeze
    YARDOPTS = File.read(File.join(Generator::TEMPLATE, ".yardopts"))

    # my_gem, generated into a directory of its own and committed
    def in_gem(**values)
      in_tmpdir do |dir|
        target = File.join(dir, "my_gem")
        Generator.generate(project(**values), target)
        commit(target)
        yield target
      end
    end

    def commit(target, message = "a commit")
      git(target, "add", "--all")
      git(target, "-c", "user.name=Jane", "-c", "user.email=jane@example.com", "commit", "--quiet", "--allow-empty",
          "-m", message)
    end

    # the record as an older veragem's would be, +changes+ its files' (nil: none), then committed
    def rerecord(target, changes = {}, **fields)
      record = Record.read(target)
      files = record.files.merge(changes).compact
      given = { version: record.version, source: record.source, name: record.name, values: record.values }
      Record.new(**given, **fields, files:).write(target)
      commit(target)
    end

    # +path+ as an older veragem wrote it, +base+, and as the gem has it, +ours+; committed
    def older(target, path, ours, base: ours, **fields)
      write(target, path, ours)
      rerecord(target, { path => id(target, path, base) }, **fields)
    end

    # the id of +bytes+ at +path+, written: a base sync finds
    def id(target, path, bytes) = Git.id(target, path, bytes)

    # the id of +text+ in +target+, its object not written
    def blob(target, text) = Git.output(target, "hash-object", "--stdin", input: text).chomp

    # what this veragem writes at +path+, and its id
    def theirs_text(target, path) = Generator.entries(Record.read(target).project).find { it.path == path }.bytes

    def theirs(target, path) = id(target, path, theirs_text(target, path))

    # the record's id of +path+
    def recorded(target, path) = Record.read(target).files[path]

    # what sync showed, its argv's
    def sync(target, *argv, input: StringIO.new)
      output = StringIO.new(+"")
      Sync.main(argv, dir: target, input:, output:)
      output.string
    end

    # the refusal, and what sync showed by then
    def refused(target, *argv, input: StringIO.new)
      output = StringIO.new(+"")
      error = assert_raises(Error) { Sync.main(argv, dir: target, input:, output:) }
      [error.message, output.string]
    end

    def status(target) = git(target, "status", "--porcelain")

    # as bytes: a text mode's (Windows') CRLF would differ from every side's LF
    def write(target, path, text) = File.binwrite(File.join(target, path), text)

    # +answers+ typed at a terminal, one a line
    def terminal(*answers) = StringIO.new(answers.map { "#{it}\n" }.join).tap { |io| def io.tty? = true }
  end

  # What the release's tests share: gem sources of this checkout built as a gem, and of a release
  # before sync.
  module ReleaseSupport
    ROOT = File.expand_path("..", __dir__)

    class << self
      # each built once, for every test
      attr_accessor :built, :old, :broken, :future
    end

    Minitest.after_run { [built, old, broken, future].compact.each { FileUtils.rm_rf(File.dirname(it)) } }

    def built = ReleaseSupport.built ||= build_gem

    def old = ReleaseSupport.old ||= build_old

    # a release whose sync cannot run: its lib/veragem.rb missing
    def broken = ReleaseSupport.broken ||= build_old("0.0.2", { "lib/veragem/sync.rb" => "" })

    # a release for a Ruby to come
    def future = ReleaseSupport.future ||= build_old("9.9.9", ruby: ">= 99")

    # the gem sources an index of +gems+ alone, as GEMRC names them; the test's environment, not
    # Bundler's from before it, a sync's
    def with_sources(*gems, &)
      in_tmpdir do |dir|
        index(dir, gems)
        File.write(File.join(dir, "gemrc"), ":sources:\n- file:///#{dir.delete_prefix("/")}/\n")
        with_env("GEMRC" => File.join(dir, "gemrc")) { stubbed(Bundler, :original_env, -> { ENV.to_h }, &) }
      end
    end

    private

    def build_gem
      out = File.join(Dir.mktmpdir("veragem-built"), "veragem.gem")
      script = "Gem::CommandManager.instance.run(ARGV)"
      system({ "RUBYOPT" => nil }, RbConfig.ruby, "-rrubygems/command_manager", "-e", script, "--", "build",
             "veragem.gemspec", "--output=#{out}", chdir: ROOT, out: File::NULL, exception: true)
      out
    end

    def build_old(version = "0.0.1", files = {}, ruby: ">= 0")
      dir = Dir.mktmpdir("veragem-old")
      files.each { |path, text| written(File.join(dir, path), text) }
      file = nil
      capture_io { file = Dir.chdir(dir) { Gem::Package.build(old_spec(version, files.keys, ruby)) } }
      File.join(dir, file)
    end

    def old_spec(version, files, ruby)
      Gem::Specification.new("veragem", version) do |gem|
        gem.summary = "old"
        gem.authors = ["x"]
        gem.files = files
        gem.required_ruby_version = ruby
      end
    end

    def written(path, text)
      FileUtils.mkdir_p(File.dirname(path))
      File.write(path, text)
    end

    # RubyGems' index of +gems+: their specs, the latest, none prereleased; each gem and its spec
    def index(dir, gems)
      specs = gems.map { Gem::Package.new(it).spec }
      lists(specs).each { |name, list| File.binwrite(File.join(dir, "#{name}.4.8.gz"), Zlib.gzip(Marshal.dump(list))) }
      gems.zip(specs).each { |gem, spec| publish(dir, gem, spec) }
    end

    def lists(specs)
      tuples = specs.map { [it.name, it.version, it.platform.to_s] }
      { "specs" => tuples, "latest_specs" => tuples.max_by(1) { it[1] }, "prerelease_specs" => [] }
    end

    def publish(dir, gem, spec)
      quick = File.join(dir, "quick", "Marshal.4.8")
      FileUtils.mkdir_p([File.join(dir, "gems"), quick])
      FileUtils.cp(gem, File.join(dir, "gems", "#{spec.full_name}.gem"))
      File.binwrite(File.join(quick, "#{spec.full_name}.gemspec.rz"), Zlib::Deflate.deflate(Marshal.dump(spec)))
    end
  end
end
