# frozen_string_literal: true

require "test_helper"

class TestGit < Minitest::Test
  include Veragem::TestSupport

  def test_a_failure_says_which
    in_tmpdir do |dir|
      error = assert_raises(Veragem::Error) { Veragem::Git.run(dir, "no", "such") }

      assert_equal "git no such failed in #{dir}", error.message
    end
  end

  def test_without_git_it_says_so
    in_tmpdir do |dir|
      error = with_env("PATH" => "") { assert_raises(Veragem::Error) { Veragem::Git.run(dir, "status") } }

      assert_equal "cannot run git in #{dir}", error.message
    end
  end
end
