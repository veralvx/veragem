# frozen_string_literal: true

require "tmpdir"

module Veragem
  # A gem's name, checked: `bundle gem`'s rules, and what the gem's files and tools would meet.
  module Name
    # `bundle gem`'s names, lower-case: words of letters and digits joined by `_` (one constant,
    # `my_gem` is MyGem) or `-` (a namespace, `my-gem` is My::Gem), each constant a letter first.
    PATTERN = /\A[a-z][a-z0-9]*(?:_[a-z0-9]+)*(?:-[a-z][a-z0-9]*(?:_[a-z0-9]+)*)*\z/
    # Windows' devices, whose names no file there takes: a path's word, of its dashes
    RESERVED = /\A(?:con|prn|aux|nul|com\d|lpt\d)\z/

    # Its modules, as `bundle gem` names them: `my-gem_tools`' My, GemTools.
    # @param name [String] one PATTERN matches
    # @return [Array<String>] outermost first
    def self.modules(name) = name.split("-").map { |word| word.split("_").map(&:capitalize).join }

    # The file the gem requires: `my-gem`'s is my/gem.
    # @param name [String] one PATTERN matches
    # @return [String]
    def self.path(name) = name.tr("-", "/")

    # Its words joined by `_` alone: `my-gem`'s my_gem, its test's file name.
    # @param name [String] one PATTERN matches
    # @return [String]
    def self.underscored(name) = name.tr("-", "_")

    # +name+, or an Error saying why a gem cannot have it, as written: Generator.check adds what its
    # modules and its kind decide.
    # @param name [String] a gem's name, as typed
    # @return [String] +name+
    # @raise [Veragem::Error] a gem cannot have it
    def self.check(name)
      unless PATTERN.match?(name)
        raise Error, "invalid gem name #{name.inspect}: lower-case words of letters and digits, each a " \
                     "letter first after a dash, joined by _ or - (my_gem, my-gem)"
      end
      # the generated code's lines within RuboCop's 120 columns
      if name.length > 40 || name.count("-") > 3
        raise Error, "invalid gem name #{name}: at most 40 characters and 4 modules deep"
      end

      check_paths(name)
      name
    end

    # The gem writes lib/<path>.rb, `module` for each of its modules, and tests that name the first:
    # none may meet what its tools load.
    # @param name [String] one Name.check takes
    # @return [void]
    # @raise [Veragem::Error] a module or its file would meet another, or they could not be checked
    def self.check_modules(name)
      nestings = nestings_of(name)
      answers = probe(library_of(name), path(name), nestings)
      check_shadowing(name, answers.fetch(0), answers.fetch(1))
      check_defined(name, nestings.zip(answers.drop(2)).take_while { |_, kind| !kind.to_s.empty? }, nestings.last)
    end

    # What the gem's tools load with its code, where installed: Bundler's CLI, which reads its gemspec
    # (bin/setup's `bundle install`); the Rakefile's libraries and its tasks' (RuboCop's, Steep's,
    # YARD's ERB); bin/console's IRB; its tests' (SimpleCov, Pbt).
    LIBRARIES = %w[bundler bundler/cli rake bundler/audit/task csv json minitest/test_task rubocop/rake_task
                   steep/rake_task yard rubocop steep erb irb simplecov minitest/autorun pbt].freeze
    # Its files' paths: lib/test_helper.rb would shadow the tests' own (Minitest's -Ilib:test); a
    # device's name, whatever its extension, is no file of Windows' (lib/con.rb), nor git's there.
    private_class_method def self.check_paths(name)
      raise Error, "invalid gem name #{name}: its lib/test_helper.rb would shadow the tests'" if name == "test_helper"

      reserved = name.split("-").grep(RESERVED).first
      raise Error, "invalid gem name #{name}: Windows reserves #{reserved} as a file's name" if reserved
    end

    # The child: no stdin, a scratch directory, its arguments cleared before the libraries load, their
    # own output kept from the answers, no exit hooks (minitest/autorun's). A file shadowed in any
    # case: a file system may ignore it (macOS', Windows').
    PROBE = <<~RUBY.freeze
      library, path, *nestings = ARGV
      first = nestings.fetch(0)
      ARGV.clear
      answers = $stdout.dup
      $stdout.reopen($stderr)
      [*#{LIBRARIES.inspect}, library].each do |feature|
        require feature
      rescue StandardError, ScriptError
        nil
      end
      files = "\#{path.gsub(/[a-z]/) { "[\#{it}\#{it.upcase}]" }}.{rb,\#{RbConfig::CONFIG["DLEXT"]}}"
      shadowed = $LOAD_PATH.resolve_feature_path(path)&.last ||
                 $LOAD_PATH.lazy.flat_map { |dir| Dir.glob(files, base: dir).map { File.join(dir, it) } }
                           .first
      answers.puts(shadowed)
      readers = { "its tests" => defined?(Minitest::Test) && Minitest::Test, "gem build" => Gem::Specification }
      found = readers.filter_map do |reader, context|
        owner = context && (context.ancestors - Object.ancestors).find { it.const_defined?(first, false) }
        "\#{reader} would find \#{owner}::\#{first}" if owner
      end
      answers.puts(found.first)
      nestings.each do |nesting|
        answers.puts(Object.const_defined?(nesting, false) ? Object.const_get(nesting, false).class : "")
      rescue TypeError # an outer one no module (`Noisy = 1`): nothing within it
        answers.puts("")
      end
      answers.flush
      exit!(0)
    RUBY
    private_constant :RESERVED, :LIBRARIES, :PROBE
    # Each probe's answers: a question asked once a process
    @probed = {} #: Hash[[String, String, Array[String]], Array[String]]

    # The file +path+ already requires, what a Minitest::Test or Gem::Specification finds for the
    # first of +nestings+, then each nesting's class (Module, Class...), each "" when none, where the
    # gem meets them: with what its tools load (LIBRARIES), and its top-level +library+
    # (`date-holidays`: date), which they may require. Asked of a Ruby of its own, the same however
    # this one was started (RUBYOPT's options would print before the answers), and once a process:
    # the answer cannot change. The child answers once the libraries are loaded, then exits: fewer
    # answers are a failure.
    # @param library [String] the gem's top-level library
    # @param path [String] the file the gem requires, lib/'s
    # @param nestings [Array<String>] its modules' full names, outermost first
    # @return [Array<String>] the shadowed file, what is found, then each nesting's class
    # @raise [Veragem::Error] the child did not answer them all, or could not be run
    def self.probe(library, path, nestings)
      @probed[[library, path, nestings]] ||= answers(library, path, nestings)
    end

    private_class_method def self.answers(library, path, nestings)
      command = [RbConfig.ruby, "-e", PROBE, library, path, *nestings]
      env = Bundler.unbundled_env.except("RUBYOPT")
      answers = Dir.mktmpdir do |dir|
        IO.popen(env, command, unsetenv_others: true, in: File::NULL, err: File::NULL, chdir: dir, &:readlines)
      end
      return answers.map(&:chomp).freeze if answers.size == nestings.size + 2

      # rubocop:disable-next Style/SpecialGlobalVars -- RBS types $?, and has no English for $CHILD_STATUS
      unchecked(nestings, "their Ruby ended: #{$?}")
    rescue SystemCallError => e
      # a refusal, not a raw Errno, which Bundler would report as its own bug
      unchecked(nestings, e.message)
    end

    private_class_method def self.unchecked(nestings, why)
      raise Error, "could not check #{nestings.last} against its tools: #{why}"
    end

    # Its lib/<path>.rb, first on the load path, must not shadow a library its tools may require:
    # this Ruby's (lib/json.rb, JSON's), a gem's they load too; its tests' classes, Minitest::Test's,
    # and its gemspec, which `gem build` evaluates in Gem::Specification, must find its module, not
    # one of theirs (`lifecycle_hooks`: Minitest::Test::LifecycleHooks).
    private_class_method def self.check_shadowing(name, shadowed, found)
      raise Error, "invalid gem name #{name}: its lib/#{path(name)}.rb would shadow #{shadowed}" unless shadowed.empty?
      raise Error, "invalid gem name #{name}: #{found} for its module" unless found.empty?
    end

    # The +defined+ nestings, outermost first, each with its class: the gem's own module, +innermost+,
    # one defined already (Comparable) would reopen; an outer one that is a class (Set, Logger), it
    # could not open.
    private_class_method def self.check_defined(name, defined, innermost)
      raise Error, "invalid gem name #{name}: #{innermost} is already defined" if defined.last&.first == innermost

      outer = defined.find { |_, kind| kind != "Module" }
      raise Error, "invalid gem name #{name}: #{outer[0]} is a #{outer[1]}, not a module" if outer
    end

    # The gem's top-level library: `date-holidays`' date
    private_class_method def self.library_of(name) = name.split("-").fetch(0)

    # Each of its modules' full names, outermost first: `my-gem`'s My, My::Gem.
    private_class_method def self.nestings_of(name)
      modules(name).then { |modules| (1..modules.size).map { modules.first(it).join("::") } }
    end
  end
end
