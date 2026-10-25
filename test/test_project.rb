# frozen_string_literal: true

require "test_helper"

class TestProject < Minitest::Test
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
    %w[set bundler veragem].each do |name|
      error = assert_raises(Veragem::Error) { project(name) }

      assert_match(/already defined/, error.message)
    end
  end

  # Over names of a few letters, digits, underscores and dashes: one accepted is bundle gem's
  # constant, each part a valid one.
  def test_an_accepted_name_is_bundle_gems_constant
    Pbt.assert do
      Pbt.property(Pbt.array(Pbt.one_of("a", "b", "0", "_", "-"), min: 1, max: 8)) do |chars|
        name = chars.join
        next unless Veragem::Project::NAME.match?(name)

        assert_equal bundle_gem_constant(name), project(name).constant
        assert(project(name).modules.all? { it.match?(/\A[A-Z][A-Za-z0-9]*\z/) })
      end
    end
  end

  def test_the_github_user_follows_githubs_rule
    ["jane", "jane-doe", "J4ne", "a" * 39].each { assert_equal it, project(github: it).github }

    ["-jane", "jane-", "jane--doe", "jane_doe", "a" * 40, nil].each do |github|
      assert_raises(Veragem::Error, github.inspect) { project(github:) }
    end
  end

  def test_a_text_is_one_line_of_utf8_rubygems_takes
    ["", " ", "two\nlines", "tab\there", "TODO: write", "FIXME", "\xFF".b].each do |summary|
      assert_raises(Veragem::Error, summary.inspect) { project(summary:) }
    end
  end

  # ARGV under the C locale is binary: the bytes are taken as UTF-8.
  def test_a_text_is_taken_as_utf8
    author = project(author: "Jos\xC3\xA9".b).author

    assert_equal ["José", Encoding::UTF_8], [author, author.encoding]
  end

  def test_the_email_is_optional
    assert_nil project.email
    assert_equal "jane@example.com", project(email: "jane@example.com").email
  end

  def test_a_license_is_its_spdx_identifiers
    assert_equal([["MIT"], ["Apache-2.0"], ["MIT", "Apache-2.0"]],
                 %w[mit apache dual].map { project(license: it).licenses })
    assert_raises(Veragem::Error) { project(license: "gpl") }
  end

  def test_exe_is_true_or_absent
    assert project(exe: true).exe
    refute project.exe
  end

  def test_a_quoted_value_reads_back_as_itself
    gem = project
    ["José \"Q\" \\ \#{x} \#@y \#$z # done"].each { assert_equal it, eval(gem.quote(it)) } # rubocop:disable Security/Eval -- the test's own strings
    Pbt.assert do
      Pbt.property(Pbt.printable_string) do |value|
        assert_equal value, eval(gem.quote(value)) # rubocop:disable Security/Eval -- generated strings, read back
      end
    end
  end

  def test_code_nests_in_the_gems_modules
    assert_equal "# Doc.\nmodule MyGem\n  X = 1\n\n  Y = 2\nend\n", project.nest("X = 1\n\nY = 2\n", doc: "Doc.")
    assert_equal "module My\n  module Gem\n    X = 1\n  end\nend\n", project("my-gem").nest("X = 1\n")
  end

  def test_the_year_is_this_one
    assert_equal Time.now.year, project.year
  end
end
