# frozen_string_literal: true

require "tmpdir"

module Veragem
  # A gem's name, checked: `bundle gem`'s rules, and what the gem's files and tools would meet.
  module Name
    # `bundle gem`'s names, lower-case: words of letters and digits joined by `_` (one constant,
    # `my_gem` is MyGem) or `-` (a namespace, `my-gem` is My::Gem), each constant a letter first.
    PATTERN = /\A[a-z][a-z0-9]*(?:_[a-z0-9]+)*(?:-[a-z][a-z0-9]*(?:_[a-z0-9]+)*)*\z/

    # Its modules, as `bundle gem` names them: `my-gem_tools`' My, GemTools.
    def self.modules(name) = name.split("-").map { |word| word.split("_").map(&:capitalize).join }

    # +name+, or an Error saying why a gem cannot have it.
    def self.check(name)
      unless PATTERN.match?(name)
        raise Error, "invalid gem name #{name.inspect}: lower-case words of letters and digits, each a " \
                     "letter first after a dash, joined by _ or - (my_gem, my-gem)"
      end
      # the generated code's lines within RuboCop's 120 columns
      if name.length > 40 || name.count("-") > 3
        raise Error, "invalid gem name #{name}: at most 40 characters and 4 modules deep"
      end
      # lib/test_helper.rb would shadow the tests' own (Minitest's -Ilib:test)
      raise Error, "invalid gem name #{name}: its lib/test_helper.rb would shadow the tests'" if name == "test_helper"

      check_modules(name)
      name
    end

    # The gem writes lib/<path>.rb, `module` for each of its modules, and tests that name the first.
    def self.check_modules(name)
      nestings = nestings_of(name)
      shadowed, found, *kinds = probe(library_of(name), name.tr("-", "/"), nestings)
      check_shadowing(name, shadowed.to_s, found.to_s)
      check_defined(name, nestings.zip(kinds).take_while { |_, kind| !kind.to_s.empty? }, nestings.last)
    end

    # Its lib/<path>.rb, first on the load path, must not shadow a library its tools require
    # (lib/json.rb, JSON's); its tests' classes, Minitest::Test's, must find its module, not one of
    # Minitest's (`lifecycle_hooks`: Minitest::Test::LifecycleHooks).
    def self.check_shadowing(name, shadowed, found)
      unless shadowed.empty?
        raise Error, "invalid gem name #{name}: its lib/#{name.tr("-", "/")}.rb would shadow #{shadowed}"
      end
      raise Error, "invalid gem name #{name}: its tests would find #{found} for its module" unless found.empty?
    end

    # The +defined+ nestings, outermost first, each with its class: the gem's own module, +innermost+,
    # one defined already (Comparable) would reopen; an outer one that is a class (Set, Logger), it
    # could not open.
    def self.check_defined(name, defined, innermost)
      raise Error, "invalid gem name #{name}: #{innermost} is already defined" if defined.last&.first == innermost

      outer = defined.find { |_, kind| kind != "Module" }
      raise Error, "invalid gem name #{name}: #{outer[0]} is a #{outer[1]}, not a module" if outer
    end

    # The gem's top-level library: `date-holidays`' date
    def self.library_of(name) = name.split("-").fetch(0)

    # My, My::Gem
    def self.nestings_of(name) = modules(name).then { |modules| (1..modules.size).map { modules.first(it).join("::") } }

    # The child: no stdin, a scratch directory, its arguments cleared before the libraries load, their
    # own output kept from the answers, no exit hooks.
    PROBE = <<~RUBY
      library, path, *nestings = ARGV
      first = nestings.fetch(0)
      ARGV.clear
      answers = $stdout.dup
      $stdout.reopen($stderr)
      ["bundler", "bundler/cli", "rake", "minitest", library].each do |feature|
        require feature
      rescue StandardError, ScriptError
        nil
      end
      answers.puts($LOAD_PATH.resolve_feature_path(path)&.last)
      tests = defined?(Minitest::Test) ? Minitest::Test.ancestors - Object.ancestors : []
      answers.puts(tests.find { it.const_defined?(first, false) }&.then { "\#{it}::\#{first}" })
      nestings.each { answers.puts(Object.const_defined?(it, false) ? Object.const_get(it, false).class : "") }
      answers.flush
      exit!(0)
    RUBY
    private_constant :PROBE

    # The file +path+ already requires, the constant a Minitest::Test finds for the first of
    # +nestings+, then each nesting's class -- Module, Class... --, each "" when none, where the gem
    # meets them: in Bundler's CLI, which reads its gemspec (bin/setup's `bundle install`), in Rake
    # and Minitest, and with its top-level +library+ (`date-holidays`: date), which its tools may
    # require. Asked of a Ruby of its own, so the answer is the same however this one was started.
    # Its answers come only once the libraries are loaded, then the child exits: one fewer is a
    # failure.
    def self.probe(library, path, nestings)
      command = [RbConfig.ruby, "-e", PROBE, library, path, *nestings]
      answers = Dir.mktmpdir do |dir|
        IO.popen(Bundler.unbundled_env, command, unsetenv_others: true, in: File::NULL, err: File::NULL, chdir: dir,
                 &:readlines)
      end
      raise Error, "could not check #{library}'s modules" unless answers.size == nestings.size + 2

      answers.map(&:chomp)
    end
  end
end
