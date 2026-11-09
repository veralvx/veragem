# frozen_string_literal: true

require "test_helper"

class TestQuestionsAnswers < Minitest::Test
  include Veragem::TerminalSupport

  # typed under a UTF-8 locale: an invalid byte, refused as the value it is in
  def test_an_invalid_utf8_answer_is_asked_again
    invalid = "Jos\xC3".dup.force_encoding(Encoding::UTF_8)

    gem, shown = ask("my_gem", answers: ["", "", "", "", "", invalid, "Ada", "", ""])

    assert_equal "Ada", gem.author
    assert_includes shown, "invalid author"
  end

  # a valid answer is read as text, not bytes: a refusal shows it as typed
  def test_a_refused_answer_is_shown_as_typed
    _, shown = ask(answers: ["caf\u00E9", "my_gem", "", "", "", "", "", "", "", ""])

    assert_includes shown, "Gem name: invalid gem name #{"caf\u00E9".inspect}: lower-case words"
  end

  # under a locale not UTF-8's, a UTF-8 answer comes as its text: its bytes read as UTF-8 before
  # it is stripped (Latin-1's no-break space, "à"'s last byte)
  def test_a_utf8_answer_is_taken_whatever_the_locale
    voila = "Voil\u00E0".b.force_encoding(Encoding::ISO_8859_1)
    gem, = ask("my_gem", answers: ["", "", "", "", voila, "", "", ""])

    assert_equal "Voil\u00E0", gem.summary
  end
end
