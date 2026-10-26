# frozen_string_literal: true

require "test_helper"

# From a terminal: what no option gives, asked for.
class TestQuestions < Minitest::Test
  include Veragem::TestSupport

  CONFIG = { "user.name" => "Jane Doe", "user.email" => "jane@example.com", "github.user" => "jane" }.freeze

  # +answers+ typed at a terminal, one a line, generating into +dir+; the project, and what the
  # terminal showed
  def ask(*argv, answers: [], config: CONFIG, dir: Dir.pwd)
    terminal = StringIO.new(answers.map { "#{it}\n" }.join)
    def terminal.tty? = true
    output = StringIO.new
    project = Veragem::Options.parse(argv, dir:, config: config.method(:[]), input: terminal, output:)
    [project, output.string]
  end

  def test_each_value_no_option_gives_is_asked_its_default_offered
    gem, shown = ask(answers: ["my_gem", "", "", "", "", "", ""])

    assert_equal ["my_gem", false, "dual", "A Ruby gem.", "Jane Doe", "jane@example.com", "jane"],
                 [gem.name, gem.exe, gem.license, gem.summary, gem.author, gem.email, gem.github]
    assert_equal "Gem name: A command line, exe/my_gem (y/n) [n]: License (mit, apache, dual) [dual]: " \
                 "Summary [A Ruby gem.]: Author [Jane Doe]: Email [jane@example.com]: GitHub user [jane]: ", shown
  end

  def test_the_answers_are_taken
    gem, = ask(answers: ["my-gem", "y", "m", "Greets.", "Ada", "ada@example.com", "ada"])

    assert_equal ["my-gem", true, "mit", "Greets.", "Ada", "ada@example.com", "ada"],
                 [gem.name, gem.exe, gem.license, gem.summary, gem.author, gem.email, gem.github]
  end

  def test_what_the_options_give_is_not_asked
    gem, shown = ask("my_gem", "--exe", "--license=mit", "--author=Ada", answers: ["", "", ""])

    assert_equal ["my_gem", true, "mit", "Ada"], [gem.name, gem.exe, gem.license, gem.author]
    assert_equal "Summary [A Ruby gem.]: Email [jane@example.com]: GitHub user [jane]: ", shown
  end

  def test_a_refused_answer_is_asked_again_saying_why
    gem, shown = ask(answers: ["1gem", "my_gem", "maybe", "Y", "MIT", "apache", "TODO", "Greets.",
                               "\u00A0", "Ada", "a\tb", "ada@example.com", "-ada", "ada"])

    assert_equal ["my_gem", true, "apache", "Greets.", "Ada", "ada@example.com", "ada"],
                 [gem.name, gem.exe, gem.license, gem.summary, gem.author, gem.email, gem.github]
    ["invalid gem name \"1gem\"", "y or n", "invalid license (mit, apache or dual) \"MIT\"",
     "invalid summary \"TODO\"", "invalid author", "invalid email", "invalid GitHub user \"-ada\""].each do |why|
      assert_includes shown, why
    end
  end

  def test_a_default_refused_is_asked_again_too
    invalid = "Jos\xE9".b

    gem, shown = ask("my_gem", answers: ["", "", "", "", "Ada", "", ""], config: CONFIG.merge("user.name" => invalid))

    assert_equal "Ada", gem.author
    assert_includes shown, "invalid author"
  end

  def test_with_no_default_an_empty_answer_is_asked_again_but_an_email_may_be_none
    gem, shown = ask("my_gem", answers: ["", "", "", "", "Ada", "", "ada"], config: {})

    assert_equal ["Ada", nil, "ada"], [gem.author, gem.email, gem.github]
    assert_match(/Author: Author: Email: GitHub user: \z/, shown)
  end

  # typed under a UTF-8 locale: an invalid byte, refused as the value it is in
  def test_an_invalid_utf8_answer_is_asked_again
    invalid = "Jos\xC3".dup.force_encoding(Encoding::UTF_8)

    gem, shown = ask("my_gem", answers: ["", "", "", invalid, "Ada", "", ""])

    assert_equal "Ada", gem.author
    assert_includes shown, "invalid author"
  end

  def test_a_name_the_generator_refuses_is_asked_again
    in_tmpdir do |dir|
      Dir.mkdir(File.join(dir, "taken"))

      gem, shown = ask(answers: ["rubocop-rake", "taken", "my-c_l_i", "y", "n", "", "", "", "", ""], dir:)

      assert_equal ["my-c_l_i", false], [gem.name, gem.exe]
      ["the Gemfile's own tool", "#{File.join(dir, "taken")} already exists",
       "its command line would find another CLI"].each { assert_includes shown, it }
    end
  end

  REFUSED = [%w[1gem], %w[taken], %w[my-c_l_i --exe], %w[my_gem --github=-x], %w[--github=-x], %w[--author=TODO]].freeze

  # no answer to give: a question asked first would stop it as unanswered
  def test_a_name_or_an_option_given_is_refused_before_any_question
    in_tmpdir do |dir|
      Dir.mkdir(File.join(dir, "taken"))

      REFUSED.each do |argv|
        refute_match(/\Ano answer/, assert_raises(Veragem::Error) { ask(*argv, dir:) }.message)
      end
    end
  end

  def test_with_exe_given_a_name_its_command_line_would_break_is_asked_again
    gem, shown = ask("--exe", answers: ["my-c_l_i", "my_gem", "", "", "", "", ""])

    assert_equal ["my_gem", true], [gem.name, gem.exe]
    assert_includes shown, "its command line would find another CLI"
  end

  # a refused default offered no more: an email, then, may be none
  def test_a_refused_default_is_dropped
    gem, shown = ask("my_gem", answers: ["", "", "", "", "", "", ""], config: CONFIG.merge("user.email" => "TODO@x"))

    assert_nil gem.email
    assert_match(/Email \[TODO@x\]: invalid email "TODO@x": .*\nEmail: GitHub user/, shown)
  end

  def test_no_answer_stops_it
    assert_equal "no answer to Gem name", assert_raises(Veragem::Error) { ask }.message
  end

  def test_one_name_still
    assert_equal "one gem name, not 2 (bundle veragem --help)",
                 assert_raises(Veragem::Error) { ask("one", "two") }.message
  end
end
