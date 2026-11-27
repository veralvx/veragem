# frozen_string_literal: true

require "test_helper"

# What sync refuses to write over: the harness's changes, and the record's, not committed.
class TestSyncClean < Minitest::Test
  include Veragem::SyncSupport

  DIRTY = "commit, stash or remove the harness's changes first:"

  def test_the_harness_changed_and_not_committed_is_refused
    in_gem do |gem|
      write(gem, "Rakefile", "# mine\n")

      assert_equal "#{DIRTY}\n M Rakefile\n", refused(gem).first
    end
  end

  def test_the_gems_own_files_changed_are_no_harness
    in_gem do |gem|
      write(gem, "README.md", "mine\n")

      assert_equal "Nothing to sync #{HEADING}\n", sync(gem)
    end
  end

  # an ignored file sync would delete: no commit restores it
  def test_an_ignored_file_is_refused
    in_gem do |gem|
      File.write(File.join(gem, ".git", "info", "exclude"), "secret\n", mode: "a")
      older(gem, "secret", "x\n")

      assert_equal "#{DIRTY}\n!! secret\n", refused(gem).first
      assert_equal "x\n", read(gem, "secret")
    end
  end

  # a path as written, no pattern of git's: * is no other file
  def test_a_path_is_no_pattern
    in_gem do |gem|
      rerecord(gem, { "*" => blob(gem, "x\n") })
      write(gem, "README.md", "mine\n")

      assert_equal "Nothing to sync #{HEADING}\n", sync(gem)
    end
  end

  def test_the_record_changed_and_not_committed_is_refused
    in_gem do |gem|
      write(gem, ".veragem.yml", "#{read(gem, ".veragem.yml")}# mine\n")

      assert_equal "#{DIRTY}\n M .veragem.yml\n", refused(gem).first
    end
  end
end
