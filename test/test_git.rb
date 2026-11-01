# frozen_string_literal: true

require "test_helper"

# git's config, the defaults it gives, and git refused for what it is: missing, or unable to read its
# config, or giving a value Project refuses.
class TestGit < Minitest::Test
  include Veragem::TestSupport

  # in a directory of no repository, whose own config would answer too
  def test_git_config_reads_gits_config
    in_git_home do |home|
      system("git", "config", "--global", "github.user", "ada", exception: true)
      system("git", "config", "--global", "user.name", "José", exception: true)

      gem = Dir.chdir(home) { Veragem::Options.parse(["my_gem"], input: StringIO.new) }

      # no user.email, none; its bytes, whatever the locale: Project reads them as UTF-8
      assert_equal ["ada", nil, "José"], [gem.github, gem.email, gem.author]
    end
  end

  # read as text, a Latin-1 locale's would transcode the UTF-8 bytes to "JosÃ©"
  def test_git_config_is_its_bytes_whatever_the_locale
    in_git_home do |home|
      system("git", "config", "--global", "user.name", "José", exception: true)

      gem = with_encodings(Encoding::ISO_8859_1, Encoding::UTF_8) do
        Dir.chdir(home) { Veragem::Options.parse(["my_gem", "--github=ada"], input: StringIO.new) }
      end

      assert_equal "José", gem.author
    end
  end

  # git's reason, not a value unset, nor an email silently none
  def test_a_config_git_cannot_read_is_refused_with_gits_reason
    in_git_home do |home|
      File.write(File.join(home, ".gitconfig"), "[user\n")

      error = assert_raises(Veragem::Error) do
        Dir.chdir(home) { Veragem::Options.parse(["my_gem", "--author=Ada", "--github=ada"], input: StringIO.new) }
      end

      assert_match(/\Agit config --get user\.name: fatal: bad config line 1 in file .+\z/, error.message)
    end
  end

  # refused as such, not as a value its config lacks
  def test_without_git_it_says_so
    with_env("PATH" => "") do
      error = assert_raises(Veragem::Error) do
        Veragem::Options.parse(["my_gem", "--author=Ada", "--github=ada"], input: StringIO.new)
      end

      assert_match(/\Acannot run git: /, error.message)
    end
  end

  # without a terminal: where the value is from, and the option that replaces it; an option given,
  # git's value is not checked
  def test_a_refused_git_value_says_where_it_is_from
    config = CONFIG.merge("user.name" => "TODO Lee", "user.email" => "\xFF")

    { [] => 'invalid author "TODO Lee": RubyGems refuses one starting TODO or FIXME ' \
            "(git config user.name; --author replaces it)",
      ["--author=Ada"] => 'invalid email "\xFF": one line of text (git config user.email; --email replaces it)' }
      .each do |argv, message|
        assert_equal message, assert_raises(Veragem::Error) { parse("my_gem", *argv, config:) }.message
      end
    assert_equal(["Ada", nil], parse("my_gem", "--author=Ada", "--no-email", config:).then { [it.author, it.email] })
  end

  private

  # Ruby warns of a default external encoding set, which the tests would count as their own
  def with_encodings(external, internal)
    verbose = $VERBOSE
    $VERBOSE = nil
    saved = [Encoding.default_external, Encoding.default_internal]
    Encoding.default_external = external
    Encoding.default_internal = internal
    yield
  ensure
    Encoding.default_external, Encoding.default_internal = saved
    $VERBOSE = verbose
  end

  def in_git_home
    Dir.mktmpdir do |home|
      with_env("HOME" => home, "GIT_CONFIG_GLOBAL" => File.join(home, ".gitconfig"), "GIT_CONFIG_NOSYSTEM" => "1",
               "GIT_CONFIG_COUNT" => nil, "GIT_CONFIG_PARAMETERS" => nil) { yield home }
    end
  end
end
