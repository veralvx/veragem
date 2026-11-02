# frozen_string_literal: true

require "test_helper"

# From a terminal: what is refused before any question, and what stops the questions.
class TestQuestionsRefused < Minitest::Test
  include Veragem::TerminalSupport

  REFUSED = {
    %w[1gem] => /\Ainvalid gem name "1gem"/,
    %w[taken] => %r{/taken already exists\z},
    %w[dangling] => %r{/dangling already exists\z},
    %w[helper] => /\Ainvalid gem name helper: it would write test/,
    %w[cli --exe] => /\Ainvalid gem name cli: it would write test/,
    %w[my-c_l_i --exe] => /its command line would find another CLI/,
    %w[my_gem --github=-x] => /\Ainvalid GitHub user "-x": 1 to 39 /,
    %w[--github=-x] => /\Ainvalid GitHub user "-x": 1 to 39 /,
    %w[--author=TODO] => /\Ainvalid author "TODO"/,
    %w[my_gem --alias=-] => /\Ainvalid alias "-": a question's none; for none, --no-alias\z/,
    %w[1gem --github=-x] => /\Ainvalid GitHub user "-x": 1 to 39 /,
    %w[one two] => /\Aone gem name, not 2/
  }.freeze

  def test_a_name_or_an_option_given_is_refused_before_any_question
    in_tmpdir do |dir|
      Dir.mkdir(File.join(dir, "taken"))
      File.symlink(File.join(dir, "nowhere"), File.join(dir, "dangling"))

      REFUSED.each do |argv, message|
        why, shown = refused(*argv, dir:)

        assert_match message, why
        assert_empty shown
      end
    end
  end

  def test_no_answer_stops_it
    assert_equal ["no answer to Gem name", "Gem name: \n"], refused
  end

  def test_the_questions_are_on_stderr
    out, err = capture_io do
      assert_raises(Veragem::Error) { Veragem::Options.parse([], config: CONFIG.method(:[]), input: terminal) }
    end

    assert_equal ["", "Gem name: \n"], [out, err]
  end

  def test_a_terminal_that_cannot_be_asked_stops_it
    # input closed, then a prompt and a refusal that cannot be shown
    [{ input: terminal.tap(&:close_read), output: StringIO.new }, { input: terminal, output: broken(:print) },
     { input: terminal("1gem"), output: broken(:puts) }].each do |io|
      error = assert_raises(Veragem::Error) { Veragem::Options.parse([], config: CONFIG.method(:[]), **io) }

      assert_match(/\Acannot ask Gem name: /, error.message)
    end
  end

  def test_a_check_that_fails_is_not_a_terminal_that_cannot_be_asked
    questions = Veragem::Questions.new(terminal("x"), StringIO.new, Dir.pwd)

    assert_raises(Errno::ENOSPC) { questions.send(:ask, "Gem name", check: ->(_) { raise Errno::ENOSPC }) }
  end

  private

  def broken(write) = StringIO.new.tap { it.define_singleton_method(write) { |*| raise Errno::EPIPE } }
end
