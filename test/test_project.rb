# frozen_string_literal: true

require "test_helper"
require "yaml"

# A project's values, checked, and what follows from them.
class TestProject < Minitest::Test
  include Veragem::TestSupport

  REFUSED_SUMMARIES = ["Note: a fork.", "see also: foo.", "EXAMPLE: x", "Parses `foo files.", "Bold **text.",
                       "@param x", "(see #foo)", "review the code", "Review: the code", "HACK: a fix",
                       "Note : a fork.", "Hack :x", "todo later", "NOTE a fork", "encoding: ascii",
                       "A gem: encoding: utf-8 inside", "A coding=utf-8 thing", "coding : x",
                       "Frozen_string_literal: true", "frozen-string-literal: x", "rubocop:disable all",
                       "Parses C# rubocop:disable all", "Rubocop:disable all"].freeze
  TAKEN_SUMMARIES = ["A note: inside.", "Note a fork.", "Parses `foo` files.", "Bold **text** too.",
                     "Squares: x ** 2.", "Code `a **b` too.", "Code `a`** b.", "Code ``** b.", "Review the code",
                     "Todo later", "Notebook support",
                     "Decoding: utf-8 fast", "see the docs", "Note-taking app", "Hack's toolkit", "Note.", "Review",
                     "note-taking app", "Notes: x", "Encoding: helpers", "Coding: kata", "Encoding=x",
                     "Frozen string literal: x", "A frozen_string_literal: true"].freeze

  def test_the_github_user_follows_githubs_rule
    ["jane", "jane-doe", "J4ne", "a" * 39].each { assert_equal it, project(github: it).github }

    ["-jane", "jane-", "jane--doe", "jane_doe", "a" * 40, "ſam", "\u212Aate", nil].each do |github|
      assert_raises(Veragem::Error, github.inspect) { project(github:) }
    end
  end

  def test_a_text_is_one_line_of_utf8_rubygems_takes
    ["", " ", "\u3000", "two\nlines", "two\u2028lines", "tab\there", "TODO: write", " FIXME", "\xFF".b,
     "x" * 99].each do |summary|
      assert_raises(Veragem::Error, summary.inspect) { project(summary:) }
    end
  end

  # the module's comment too: each refused fails the generated gem's yard-lint or RuboCop as it, and
  # each taken passes them (both checked so in a generated gem)
  def test_a_summary_is_a_comment_yard_lint_and_rubocop_take
    REFUSED_SUMMARIES.each do |summary|
      assert_raises(Veragem::Error, summary.inspect) { Veragem::Project.check(:summary, summary) }
    end
    TAKEN_SUMMARIES.each { assert_equal it, Veragem::Project.check(:summary, it) }
  end

  # the whole message: what is refused, as given, and why
  def test_a_refused_summary_says_why
    { "x" * 99 => "invalid summary: too long, its Ruby string at most 100 characters",
      "@param x" => 'invalid summary "@param x": YARD would read a tag',
      "Hack: a fix" => 'invalid summary "Hack: a fix": RuboCop would read an annotation or a directive',
      "Parses `foo" => 'invalid summary "Parses `foo": a backtick or ** left open' }.each do |summary, why|
      assert_equal why, assert_raises(Veragem::Error) { Veragem::Project.check(:summary, summary) }.message
    end
  end

  # ARGV under the C locale is binary: the bytes are taken as UTF-8.
  def test_a_text_is_taken_as_utf8
    author = project(author: "Jos\xC3\xA9".b).author

    assert_equal ["José", Encoding::UTF_8], [author, author.encoding]
  end

  def test_a_text_is_stripped
    assert_equal "Greets.", project(summary: " Greets.\u00A0 ").summary
    assert_equal "x" * 98, project(summary: "x" * 98).summary
  end

  def test_the_email_is_optional
    assert_nil project.email
    assert_nil project(email: false).email
    assert_equal "jane@example.com", project(email: "jane@example.com").email
  end

  def test_a_license_is_its_spdx_identifiers
    assert_equal([["MIT"], ["Apache-2.0"], ["MIT", "Apache-2.0"]],
                 %w[mit apache dual].map { project(license: it).licenses })
    assert_raises(Veragem::Error) { project(license: "gpl") }
  end

  # read as UTF-8 whatever its encoding, refused unless valid before any other check, named as elsewhere
  def test_a_value_is_utf8
    { author: "author", given_names: "given names", github: "GitHub user", license: "license (mit, apache or dual)",
      orcid: "ORCID iD" }.each do |key, field|
      error = assert_raises(Veragem::Error) { Veragem::Project.check(key, "a\xFF".b) }

      assert_equal %(invalid #{field} "a\\xFF": not UTF-8), error.message
    end
    assert_equal "José", Veragem::Project.check(:author, "Jos\xC3\xA9".b)
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

  def test_a_yaml_value_reads_back_as_itself
    gem = project
    Pbt.assert do
      Pbt.property(Pbt.printable_string) { |value| assert_equal value, YAML.safe_load("v: #{gem.yaml(value)}")["v"] }
    end
  end

  def test_code_nests_in_the_gems_modules
    assert_equal "# Doc.\nmodule MyGem\n  X = 1\n\n  Y = 2\nend\n", project.nest("X = 1\n\nY = 2\n", doc: "Doc.")
    assert_equal "module My\n  module Gem\n    X = 1\n  end\nend\n", project("my-gem").nest("X = 1\n")
    assert_equal "module A\n  module B\n    module C\n      X = 1\n    end\n  end\nend\n",
                 project("a-b-c").nest("X = 1\n")
    assert_equal "# The namespace of My::Gem.\nmodule My\n  # Doc.\n  module Gem\n    X = 1\n  end\nend\n",
                 project("my-gem").nest("X = 1\n", doc: "Doc.")
  end

  def test_the_year_is_this_one
    assert_equal Time.now.year, project.year
  end

  # UTC's, as git-cliff dates the changelog: in the zones 14 hours ahead and 12 behind, one of them
  # on another day whatever the hour
  def test_today_is_utcs
    %w[Etc/GMT-14 Etc/GMT+12].each do |zone|
      with_env("TZ" => zone) { assert_equal Time.now.utc.strftime("%F"), project.today, zone }
    end
  end
end
