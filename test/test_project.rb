# frozen_string_literal: true

require "test_helper"

# A project's values, checked, and what follows from them.
class TestProject < Minitest::Test
  include Veragem::TestSupport

  def test_the_github_user_follows_githubs_rule
    ["jane", "jane-doe", "J4ne", "a" * 39].each { assert_equal it, project(github: it).github }

    ["-jane", "jane-", "jane--doe", "jane_doe", "a" * 40, nil].each do |github|
      assert_raises(Veragem::Error, github.inspect) { project(github:) }
    end
  end

  def test_a_text_is_one_line_of_utf8_rubygems_takes
    ["", " ", "two\nlines", "tab\there", "TODO: write", " FIXME", "\xFF".b, "x" * 99].each do |summary|
      assert_raises(Veragem::Error, summary.inspect) { project(summary:) }
    end
  end

  # ARGV under the C locale is binary: the bytes are taken as UTF-8.
  def test_a_text_is_taken_as_utf8
    author = project(author: "Jos\xC3\xA9".b).author

    assert_equal ["José", Encoding::UTF_8], [author, author.encoding]
  end

  def test_a_text_is_stripped
    assert_equal "Greets.", project(summary: " Greets.  ").summary
    assert_equal "x" * 98, project(summary: "x" * 98).summary
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
