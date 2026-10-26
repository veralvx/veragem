# frozen_string_literal: true

require "test_helper"

# From a terminal: what no option gives, asked for.
class TestQuestions < Minitest::Test
  include Veragem::TerminalSupport

  def test_each_value_no_option_gives_is_asked_its_default_offered
    gem, shown = ask(answers: ["my_gem", "", "", "", "", "", ""])

    assert_equal ["my_gem", false, "dual", "A Ruby gem.", "Jane Doe", "jane@example.com", "jane"],
                 [gem.name, gem.exe, gem.license, gem.summary, gem.author, gem.email, gem.github]
    assert_equal "Gem name: A command line, exe/my_gem (y/n) [n]: License (mit, apache or dual) [dual]: " \
                 "Summary [A Ruby gem.]: Author [Jane Doe]: Email [jane@example.com]: GitHub user [jane]: ", shown
  end

  def test_the_answers_are_taken_their_spaces_stripped
    gem, = ask(answers: [" my-gem ", "y", " m ", "Greets.", "Ada", "ada@example.com", "ada"])

    assert_equal ["my-gem", true, "mit", "Greets.", "Ada", "ada@example.com", "ada"],
                 [gem.name, gem.exe, gem.license, gem.summary, gem.author, gem.email, gem.github]
  end

  def test_what_the_options_give_is_not_asked
    gem, shown = ask("my_gem", "--exe", "--license=mit", "--author=Ada", answers: ["", "", ""])

    assert_equal ["my_gem", true, "mit", "Ada"], [gem.name, gem.exe, gem.license, gem.author]
    assert_equal "Summary [A Ruby gem.]: Email [jane@example.com]: GitHub user [jane]: ", shown
  end

  def test_with_every_option_nothing_is_asked
    gem, shown = ask("my_gem", "--no-exe", "--license=mit", "--summary=Hi", "--author=Ada", "--email=a@b.c",
                     "--github=ada")

    assert_equal ["my_gem", false], [gem.name, gem.exe]
    assert_empty shown
  end

  def test_a_refused_answer_is_asked_again_saying_why
    gem, shown = ask(answers: ["1gem", "my_gem", "maybe", "YES", "MIT", "apache", "TODO", "Greets.",
                               " ", "Ada", "a\tb", "ada@example.com", "-ada", "ada"])

    assert_equal ["my_gem", true, "apache", "Greets.", "Ada", "ada@example.com", "ada"],
                 [gem.name, gem.exe, gem.license, gem.summary, gem.author, gem.email, gem.github]
    ["invalid gem name \"1gem\"", "y or n", "invalid license (mit, apache or dual) \"MIT\"",
     "invalid summary \"TODO\"", "invalid author", "invalid email", "invalid GitHub user \"-ada\""].each do |why|
      assert_includes shown, why
    end
  end

  # said why before its question, which offers none
  def test_a_refused_default_is_not_offered
    invalid = "Jos\xE9".b

    gem, shown = ask("my_gem", answers: ["", "", "", "", "Ada", "", ""], config: CONFIG.merge("user.name" => invalid))

    assert_equal "Ada", gem.author
    assert_match(/\[A Ruby gem\.\]: invalid author "Jos\\xE9": one line of text\nAuthor: Author: Email/, shown)
  end

  def test_with_no_default_an_empty_answer_is_asked_again_but_an_email_may_be_none
    gem, shown = ask("my_gem", answers: ["", "", "", "", "Ada", "", "ada"], config: {})

    assert_equal ["Ada", nil, "ada"], [gem.author, gem.email, gem.github]
    assert_match(/Author: Author: Email: GitHub user: \z/, shown)
  end

  def test_with_its_default_refused_an_email_may_be_none
    gem, shown = ask("my_gem", answers: ["", "", "", "", "", ""], config: CONFIG.merge("user.email" => "TODO@x"))

    assert_nil gem.email
    assert_match(/\[Jane Doe\]: invalid email "TODO@x": [^\n]*\nEmail: GitHub user/, shown)
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

      gem, shown = ask(answers: ["rubocop-rake", "taken", "helper", "cli", "y", "no", "", "", "", "", ""], dir:)

      assert_equal ["cli", false], [gem.name, gem.exe]
      ["the Gemfile's own tool", "#{File.join(dir, "taken")} already exists",
       "it would write test/test_helper.rb twice", "it would write test/test_cli.rb twice"].each do |why|
        assert_includes shown, why
      end
    end
  end

  def test_with_exe_given_a_name_its_command_line_would_break_is_asked_again
    gem, shown = ask("--exe", answers: ["my-c_l_i", "cli", "my_gem", "", "", "", "", ""])

    assert_equal ["my_gem", true], [gem.name, gem.exe]
    ["its command line would find another CLI", "it would write test/test_cli.rb twice"].each do |why|
      assert_includes shown, why
    end
  end
end
