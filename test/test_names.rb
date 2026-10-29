# frozen_string_literal: true

require "test_helper"

# A gem's name: bundle gem's rules, and what the template can generate.
class TestNames < Minitest::Test
  include Veragem::TestSupport

  # bundle gem's own constant (Bundler's cli/gem.rb)
  def bundle_gem_constant(name)
    namespaced = name.gsub(/-[_-]*(?![_-]|$)/) { "::" }
    namespaced.gsub(/([_-]+|(::)|^)(.|$)/) { Regexp.last_match(2).to_s + Regexp.last_match(3).upcase }
  end

  def test_an_underscore_joins_words_into_one_constant
    gem = project("my_gem")

    assert_equal %w[MyGem my_gem my_gem], [gem.constant, gem.path, gem.underscored]
  end

  def test_a_dash_nests_a_constant
    gem = project("my-gem_tools")

    assert_equal ["My::GemTools", "my/gem_tools", "my_gem_tools"], [gem.constant, gem.path, gem.underscored]
  end

  def test_names_bundle_gem_would_refuse_or_mangle_are_refused
    ["", "1gem", "My_gem", "my--gem", "my_-gem", "my-2gem", "gem_", "-gem", "my.gem", "my gem"].each do |name|
      assert_raises(Veragem::Error, name) { project(name) }
    end
  end

  def test_a_name_whose_module_is_already_defined_is_refused
    { "set" => "Set", "comparable" => "Comparable",
      "bundler-thor" => "Bundler::Thor", "option_parser" => "OptionParser" }
      .each do |name, defined|
        error = assert_raises(Veragem::Error) { project(name) }

        assert_equal "invalid gem name #{name}: #{defined} is already defined", error.message
      end
  end

  # lib/json.rb, first on the load path, would be every tool's `require "json"`
  def test_a_name_whose_library_would_shadow_another_is_refused
    %w[json logger bundler bundler-plugin].each do |name|
      error = assert_raises(Veragem::Error) { project(name) }

      path = name.tr("-", "/")

      assert_match %r{\Ainvalid gem name #{name}: its lib/#{path}\.rb would shadow /.*/#{path}\.rb\z}, error.message
    end
  end

  # a test's class body, and the gemspec as `gem build` evaluates it, find a constant of Minitest::Test's
  # or Gem::Specification's ancestors before the gem's module
  def test_a_name_its_tests_or_gem_build_would_take_for_their_own_is_refused
    { "lifecycle_hooks" => "its tests would find Minitest::Test::LifecycleHooks",
      "u_n_d_e_f_i_n_e_d" => "its tests would find Minitest::Assertions::UNDEFINED",
      "date_like" => "gem build would find Gem::Specification::DateLike" }.each do |name, found|
      error = assert_raises(Veragem::Error) { project(name) }

      assert_equal "invalid gem name #{name}: #{found} for its module", error.message
    end
  end

  # `module Set` cannot reopen the class Set; nor `module Date`, once a tool requires date
  def test_a_name_nested_in_a_class_is_refused
    { "set-extras" => "Set", "string-utils" => "String", "date-holidays" => "Date" }.each do |name, outer|
      error = assert_raises(Veragem::Error) { project(name) }

      assert_equal "invalid gem name #{name}: #{outer} is a Class, not a module", error.message
    end
  end

  # in a Ruby of its own: nothing the library prints is taken for an answer, and it loads with no
  # arguments, in an empty directory
  def test_the_probe_requires_the_top_level_library_alone
    assert_equal ["", "", "Module", "Class"], Veragem::Name.probe("date", "my_gem", %w[Comparable Date])
    in_tmpdir do |dir|
      noisy = File.join(dir, "noisy.rb")
      File.write(noisy, "puts 'Class'\nwarn 'Class'\nNoisy = 1\nCleared = 1 if ARGV.empty?\n" \
                        "Scratch = 1 if Dir.empty?('.')\n")

      assert_equal ["", "", "Integer", "", "Integer", "Integer"],
                   Veragem::Name.probe(noisy, "my_gem", %w[Noisy Quiet Cleared Scratch])
    end
  end

  def test_a_failing_probe_refuses
    error = assert_raises(Veragem::Error) { Veragem::Name.probe("set", "my_gem", ["not a constant"]) }

    assert_equal "could not check set's modules", error.message
  end

  def test_a_name_nested_in_a_module_reopens_it
    assert_equal "Bundler::Extras", project("bundler-extras").constant
  end

  def test_a_name_is_at_most_40_characters_and_4_modules_deep
    assert_equal "A::B::C::D", project("a-b-c-d").constant
    assert_equal "a" * 40, project("a" * 40).name
    ["a" * 41, "a-b-c-d-e"].each { |name| assert_raises(Veragem::Error, name) { project(name) } }
  end

  def test_test_helper_would_shadow_the_tests_helper
    assert_raises(Veragem::Error) { project("test_helper") }
  end

  # Over names of a few letters, digits, underscores and dashes: one accepted is bundle gem's
  # constant, each part a valid one.
  def test_an_accepted_name_is_bundle_gems_constant
    Pbt.assert do
      Pbt.property(Pbt.array(Pbt.one_of("a", "b", "0", "_", "-"), min: 1, max: 8)) do |chars|
        name = chars.join
        next unless Veragem::Name::PATTERN.match?(name)

        gem = project(name)

        assert_equal bundle_gem_constant(name), gem.constant
        assert(gem.modules.all? { it.match?(/\A[A-Z][A-Za-z0-9]*\z/) })
      end
    end
  end
end
