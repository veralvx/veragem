# frozen_string_literal: true

require "test_helper"

# Git.merge: git merge-file's three ways, its status the count of conflicts.
class TestGitMerge < Minitest::Test
  include Veragem::TestSupport

  def test_a_merge_says_how_many_conflicts
    in_tmpdir do |dir|
      Veragem::Git.run(dir, "init", "--quiet")
      { "ours" => "a\nb\nc\n", "other" => "y\nb\n" }.each { |name, text| File.binwrite(File.join(dir, name), text) }

      assert_equal ["z\nb\nc\n", 0], Veragem::Git.merge(dir, "ours", "a\nb\n", "z\nb\n")
      assert_equal ["<<<<<<< other\ny\n=======\nz\n>>>>>>> veragem\nb\n", 1],
                   Veragem::Git.merge(dir, "other", "a\nb\n", "z\nb\n")
    end
  end

  # its status at most 127, however many: more is git's failure
  def test_a_merge_of_many_conflicts_is_one
    in_tmpdir do |dir|
      Veragem::Git.run(dir, "init", "--quiet")
      side = ->(name) { (1..130).map { "#{it}\n#{"-\n" * 4}#{name}\n" }.join }
      File.binwrite(File.join(dir, "ours"), side.call("ours"))

      assert_equal 127, Veragem::Git.merge(dir, "ours", side.call("base"), side.call("theirs")).last
    end
  end

  def test_a_merge_that_fails_says_so
    in_tmpdir do |dir|
      Veragem::Git.run(dir, "init", "--quiet")
      error = assert_raises(Veragem::Error) { capture_subprocess_io { Veragem::Git.merge(dir, "none", "a\n", "b\n") } }

      assert_equal "git merge-file none failed in #{dir}", error.message
    end
  end

  # as merge.conflictStyle diff3 shows it, the base's label too
  def test_a_merge_labels_its_base
    in_tmpdir do |dir|
      Veragem::Git.run(dir, "init", "--quiet")
      Veragem::Git.run(dir, "config", "merge.conflictStyle", "diff3")
      File.binwrite(File.join(dir, "ours"), "y\n")

      assert_equal ["<<<<<<< ours\ny\n||||||| base\na\n=======\nz\n>>>>>>> veragem\n", 1],
                   Veragem::Git.merge(dir, "ours", "a\n", "z\n")
    end
  end

  # git's death (128, a bad config) counts no conflicts
  def test_a_merge_git_dies_in_fails
    in_tmpdir do |dir|
      Veragem::Git.run(dir, "init", "--quiet")
      File.write(File.join(dir, ".git", "config"), "[bad\n", mode: "a")
      error = assert_raises(Veragem::Error) { capture_subprocess_io { Veragem::Git.merge(dir, "ours", "a\n", "b\n") } }

      assert_equal "git merge-file ours failed in #{dir}", error.message
    end
  end

  # a git a signal kills has no status, nor its output all of the merge
  def test_a_merge_git_is_killed_in_fails
    skip "Windows runs no shell script as git" if Gem.win_platform?
    in_tmpdir do |dir|
      File.write(File.join(dir, "git"), "#!/bin/sh\nkill -KILL $$\n")
      File.chmod(0o755, File.join(dir, "git"))
      error = with_path(dir) { assert_raises(Veragem::Error) { Veragem::Git.merge(dir, "ours", "a\n", "b\n") } }

      assert_equal "git merge-file ours failed in #{dir}", error.message
    end
  end

  private

  # +dir+ first on the PATH for the block
  def with_path(dir)
    path = ENV.fetch("PATH")
    ENV["PATH"] = "#{dir}#{File::PATH_SEPARATOR}#{path}"
    yield
  ensure
    ENV["PATH"] = path
  end
end
