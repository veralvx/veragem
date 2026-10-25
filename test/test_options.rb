# frozen_string_literal: true

require "test_helper"

class TestOptions < Minitest::Test
  include Veragem::TestSupport

  CONFIG = { "user.name" => "Jane Doe", "user.email" => "jane@example.com", "github.user" => "jane" }.freeze

  def parse(*argv, config: CONFIG) = Veragem::Options.parse(argv, config: config.method(:[]))

  def test_git_config_gives_the_defaults
    gem = parse("my_gem")

    assert_equal ["my_gem", "Jane Doe", "jane@example.com", "jane", "A Ruby gem.", "dual", false],
                 [gem.name, gem.author, gem.email, gem.github, gem.summary, gem.license, gem.exe]
  end

  def test_the_options_override_them
    gem = parse("my_gem", "--exe", "--license=mit", "--author", "Ada", "--email=ada@example.com",
                "--github=ada", "--summary", "Greets.")

    assert_equal ["Ada", "ada@example.com", "ada", "Greets.", "mit", true],
                 [gem.author, gem.email, gem.github, gem.summary, gem.license, gem.exe]
  end

  def test_the_email_may_be_unset
    assert_nil parse("my_gem", config: CONFIG.except("user.email")).email
  end

  def test_the_author_and_the_github_user_are_required
    { "user.name" => /no author: --author, or git config user.name/,
      "github.user" => /no github: --github, or git config github.user/ }.each do |key, message|
      error = assert_raises(Veragem::Error) { parse("my_gem", config: CONFIG.except(key)) }

      assert_match message, error.message
    end
  end

  def test_one_name_is_required
    [[], %w[one two]].each do |argv|
      error = assert_raises(Veragem::Error) { parse(*argv) }

      assert_equal "one gem name, not #{argv.size} (bundle veragem --help)", error.message
    end
  end

  def test_a_bad_option_is_refused_with_the_usage
    [["--nope"], ["--license=gpl"], ["--author"]].each do |argv|
      error = assert_raises(Veragem::Error) { parse("my_gem", *argv) }

      assert_match(/\A(invalid option|invalid argument|missing argument): .* \(bundle veragem --help\)\z/,
                   error.message)
    end
  end

  # ARGV under a UTF-8 locale: an invalid byte is refused as the value it is in
  def test_an_invalid_utf8_argument_is_refused
    invalid = "\xFF".dup.force_encoding(Encoding::UTF_8)

    { %W[#{invalid}] => /invalid gem name/, ["my_gem", "--author", invalid] => /invalid author/,
      ["my_gem", "--#{invalid}"] => /invalid option/ }.each do |argv, message|
      assert_match message, assert_raises(Veragem::Error) { parse(*argv) }.message
    end
  end

  def test_options_may_come_first_whatever_posixly_correct
    with_env("POSIXLY_CORRECT" => "1") { assert parse("--exe", "my_gem").exe }
    with_env("POSIXLY_CORRECT" => "1") { assert parse("my_gem", "--exe").exe }
  end

  def test_version
    assert_output("bundle veragem #{Veragem::VERSION}\n") { assert_raises(SystemExit) { parse("--version") } }
  end

  # in a directory of no repository, whose own config would answer too
  def test_git_config_reads_gits_config
    Dir.mktmpdir do |home|
      with_env("HOME" => home, "GIT_CONFIG_GLOBAL" => File.join(home, ".gitconfig"), "GIT_CONFIG_NOSYSTEM" => "1",
               "GIT_CONFIG_COUNT" => nil, "GIT_CONFIG_PARAMETERS" => nil) do
        Dir.chdir(home) { assert_git_config }
      end
    end
  end

  def assert_git_config
    system("git", "config", "--global", "github.user", "ada", exception: true)
    system("git", "config", "--global", "user.name", "Jos\u00E9", exception: true)

    assert_equal ["ada", nil], [Veragem::Options.git_config("github.user"), Veragem::Options.git_config("user.email")]
    # its bytes, whatever the locale: Project reads them as UTF-8
    assert_equal "José", parse("my_gem", config: ->(key) { Veragem::Options.git_config(key) || "x" }).author
  end

  def test_without_git_no_value
    with_env("PATH" => "") { assert_nil Veragem::Options.git_config("user.name") }
  end
end
