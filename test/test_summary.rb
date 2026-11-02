# frozen_string_literal: true

require "test_helper"

# The summary: the module's comment too, which the gem's yard-lint and RuboCop take, and the README's
# text, as written.
class TestSummary < Minitest::Test
  include Veragem::TestSupport

  REFUSED_SUMMARIES = ["Note: a fork.", "see also: foo.", "EXAMPLE: x", "Parses `foo files.", "Bold **text.",
                       "@param x", "(see #foo)", "review the code", "Review: the code", "HACK: a fix",
                       "Note : a fork.", "Hack :x", "todo later", "NOTE a fork", "encoding: ascii",
                       "A gem: encoding: utf-8 inside", "A coding=utf-8 thing", "coding : x",
                       "Frozen_string_literal: true", "frozen-string-literal: x", "rubocop:disable all",
                       "Parses C# rubocop:disable all", "Rubocop:disable all", "Important: x", "Todo: x",
                       "Fixme: x", "Warning: x", "Deprecated: x", "Author: x", "Version: x", "Since: x",
                       "Returns: x", "Raises: x", "Optimize: x", "optimize the code"].freeze
  TAKEN_SUMMARIES = ["A note: inside.", "Note a fork.", "Parses `foo` files.", "Bold **text** too.",
                     "Squares: x ** 2.", "Code `a **b` too.", "Code `a`** b.", "Code ``** b.", "Review the code",
                     "Todo later", "Notebook support",
                     "Decoding: utf-8 fast", "see the docs", "Note-taking app", "Hack's toolkit", "Note.", "Review",
                     "note-taking app", "Notes: x", "Encoding: helpers", "Coding: kata", "Encoding=x",
                     "Frozen string literal: x", "A frozen_string_literal: true"].freeze

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

  # as written, as RubyGems shows it, whatever Markdown would make of it: its escapes alone added,
  # its spaces single, as dprint writes them (each case checked so in a generated gem)
  def test_a_markdown_value_shows_as_written
    { "A Ruby gem." => "A Ruby gem.", "A _fast_ my_gem" => "A \\_fast\\_ my_gem", "a  b" => "a b",
      "<!-- x" => "\\<!-- x", "`a` *b* [c] ~d~ $e & &amp; \\" => "\\`a\\` \\*b\\* \\[c\\] \\~d\\~ \\$e & \\&amp; \\\\",
      "# x" => "\\# x", "> x" => "\\> x", "- x" => "\\- x", "+ x" => "\\+ x", "2) x" => "2\\) x",
      "10. x" => "10\\. x", "1.5 x" => "1\\.5 x" }.each { |value, text| assert_equal text, project.markdown(value) }
    Pbt.assert do
      Pbt.property(Pbt.printable_string) do |value|
        assert_equal value.squeeze(" "), project.markdown(value).gsub(/\\(.)/m, "\\1")
      end
    end
  end
end
