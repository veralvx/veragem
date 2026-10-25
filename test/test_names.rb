# frozen_string_literal: true

require "test_helper"

# A gem's name: bundle gem's rules, and what the template can generate.
class TestNames < Minitest::Test
  include Veragem::TestSupport

  # bundle gem's own constant (Bundler's cli/gem.rb)
  def bundle_gem_constant(name)
    namespaced = name.gsub(/-[_-]*(?![_-]|$)/) { "::" }
    namespaced.gsub(/([_-]+|(::)|^)(.|$)/) { ::Regexp.last_match(2).to_s + ::Regexp.last_match(3).upcase }
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
    { "set" => "Set", "logger" => "Logger", "bundler" => "Bundler", "bundler-plugin" => "Bundler::Plugin" }
      .each do |name, defined|
        error = assert_raises(Veragem::Error) { project(name) }

        assert_equal "invalid gem name #{name}: #{defined} is already defined", error.message
      end
  end

  # `module Set` cannot reopen the class Set; nor `module Date`, once a tool requires date
  def test_a_name_nested_in_a_class_is_refused
    { "set-extras" => "Set", "string-utils" => "String", "date-holidays" => "Date" }.each do |name, outer|
      error = assert_raises(Veragem::Error) { project(name) }

      assert_equal "invalid gem name #{name}: #{outer} is a Class, not a module", error.message
    end
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
        next unless Veragem::Project::NAME.match?(name)

        gem = project(name)

        assert_equal bundle_gem_constant(name), gem.constant
        assert(gem.modules.all? { it.match?(/\A[A-Z][A-Za-z0-9]*\z/) })
      end
    end
  end
end
