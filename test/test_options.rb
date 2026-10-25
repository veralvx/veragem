# frozen_string_literal: true

require "test_helper"

class TestOptions < Minitest::Test
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

      assert_match(/one gem name, not #{argv.size}\nUsage: bundle veragem NAME/, error.message)
    end
  end

  def test_a_bad_option_is_refused_with_the_usage
    [["--nope"], ["--license=gpl"], ["--author"]].each do |argv|
      error = assert_raises(Veragem::Error) { parse("my_gem", *argv) }

      assert_match(/\A(invalid option|invalid argument|missing argument).*\nUsage: bundle veragem NAME/, error.message)
    end
  end

  def test_git_config_reads_gits_config
    Dir.mktmpdir do |home|
      with_env("HOME" => home, "XDG_CONFIG_HOME" => home, "GIT_CONFIG_NOSYSTEM" => "1") do
        system("git", "config", "--global", "github.user", "ada", exception: true)

        assert_equal ["ada", nil], [Veragem::Options.git_config("github.user"), Veragem::Options.git_config("user.name")]
      end
    end
  end

  def test_without_git_no_value
    with_env("PATH" => "") { assert_nil Veragem::Options.git_config("user.name") }
  end

  def with_env(values)
    saved = ENV.to_h
    ENV.update(values)
    yield
  ensure
    ENV.replace(saved)
  end
end
