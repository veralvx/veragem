# frozen_string_literal: true

require "test_helper"

class TestSyncRun < Minitest::Test
  include Veragem::SyncSupport

  def test_a_gem_as_generated_has_nothing_to_sync
    in_gem do |gem|
      assert_equal "Nothing to sync #{HEADING}\n", sync(gem)
      assert_empty status(gem)
    end
  end

  # veragem's change taken where you made none, and the record its id, its version and source this veragem's
  def test_veragems_change_is_taken
    in_gem do |gem|
      ids = Veragem::Record.read(gem).files
      older(gem, ".yardopts", "old\n", version: "0.0.1", source: "release")

      assert_equal "Sync #{HEADING}\n  sync .yardopts: veragem changed it, you did not\n", sync(gem)
      assert_equal YARDOPTS, read(gem, ".yardopts")
      record = Veragem::Record.read(gem)

      assert_equal [ids, Veragem::VERSION, "path"], [record.files, record.version, record.source]
    end
  end

  def test_your_change_is_kept
    in_gem do |gem|
      write(gem, "Rakefile", "# mine\n")
      commit(gem)

      assert_equal "Sync #{HEADING}\n  keep Rakefile: you changed it, veragem did not\n", sync(gem)
      assert_equal "# mine\n", read(gem, "Rakefile")
    end
  end

  def test_a_file_veragem_removed_is_deleted
    in_gem do |gem|
      older(gem, "old", "x\n")

      assert_equal "Sync #{HEADING}\n  sync old: veragem removed it\n", sync(gem)
      refute_path_exists File.join(gem, "old")
      assert_nil recorded(gem, "old")
    end
  end

  # and its base kept: the next sync says so again
  def test_a_file_veragem_removed_that_you_changed_is_kept
    in_gem do |gem|
      older(gem, "kept", "y\n", base: "x\n")

      assert_equal "Sync #{HEADING}\n  keep kept: veragem removed it, you changed it\n", sync(gem)
      assert_equal ["y\n", id(gem, "kept", "x\n")], [read(gem, "kept"), recorded(gem, "kept")]
    end
  end

  # its theirs recorded: removed it stays
  def test_a_file_you_removed_stays_removed
    in_gem do |gem|
      File.delete(File.join(gem, "Rakefile"))
      rerecord(gem, { "Rakefile" => id(gem, "Rakefile", "old\n") })

      assert_equal "Sync #{HEADING}\n  keep Rakefile: you removed it\n", sync(gem)
      refute_path_exists File.join(gem, "Rakefile")
      assert_equal theirs(gem, "Rakefile"), recorded(gem, "Rakefile")
    end
  end

  def test_a_file_veragem_added_is_added
    in_gem do |gem|
      File.delete(File.join(gem, ".yardopts"))
      rerecord(gem, { ".yardopts" => nil })

      assert_equal "Sync #{HEADING}\n  sync .yardopts: veragem added it\n", sync(gem)
      assert_equal YARDOPTS, read(gem, ".yardopts")
    end
  end

  # yours kept, and the record without it, written as the rest: the next sync says so again
  def test_a_file_veragem_added_that_you_have_is_left_to_resolve
    in_gem do |gem|
      write(gem, ".yardopts", "mine\n")
      rerecord(gem, { ".yardopts" => nil }, version: "0.0.1")

      assert_equal ["resolve, then commit:\n  .yardopts: veragem added it, yours differs",
                    "Sync #{HEADING}\n  keep .yardopts: veragem added it, yours differs\n"], refused(gem)
      assert_equal ["mine\n", nil], [read(gem, ".yardopts"), recorded(gem, ".yardopts")]
      assert_equal Veragem::VERSION, Veragem::Record.read(gem).version
    end
  end
end
