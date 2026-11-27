# frozen_string_literal: true

require "test_helper"

class TestSyncMerge < Minitest::Test
  include Veragem::SyncSupport

  def test_both_changes_are_merged
    in_gem do |gem|
      base = YARDOPTS.lines.drop(1).join
      older(gem, ".yardopts", "#{base}--mine\n", base:)

      assert_equal "Sync #{HEADING}\n  sync .yardopts: veragem and you changed it\n", sync(gem)
      assert_equal "#{YARDOPTS}--mine\n", read(gem, ".yardopts")
      assert_equal theirs(gem, ".yardopts"), recorded(gem, ".yardopts")
    end
  end

  # merged, the conflicts marked, the record theirs: resolved, the next sync takes it as yours
  def test_a_merge_in_conflict_is_left_to_resolve
    in_gem do |gem|
      older(gem, ".yardopts", "mine\n", base: "old\n")

      assert_equal ["resolve, then commit:\n  .yardopts: merged, its conflicts marked",
                    "Sync #{HEADING}\n  sync .yardopts: veragem and you changed it\n"], refused(gem)
      assert_match(/\A<<<<<<< \.yardopts\nmine\n=======\n#{Regexp.escape(YARDOPTS)}>>>>>>> veragem\n\z/o,
                   read(gem, ".yardopts"))
      assert_equal theirs(gem, ".yardopts"), recorded(gem, ".yardopts")
    end
  end

  # a checkout's: no release writes it again; yours kept, and its base
  def test_a_merge_without_its_base_is_left_to_resolve
    in_gem do |gem|
      lost = "0" * 40
      write(gem, ".yardopts", "mine\n")
      rerecord(gem, { ".yardopts" => lost })

      assert_equal ["resolve, then commit:\n  .yardopts: veragem and you changed it, and its base is lost: " \
                    "merge it by hand", "Sync #{HEADING}\n  sync .yardopts: veragem and you changed it\n"], refused(gem)
      assert_equal ["mine\n", lost], [read(gem, ".yardopts"), recorded(gem, ".yardopts")]
    end
  end

  # a release's, written again, once, as the bases a clone lacks
  def test_a_release_writes_the_lost_bases_again
    in_gem do |gem|
      editorconfig = read(gem, ".editorconfig")
      bases = lost_bases(gem, editorconfig)
      calls = []
      stubbed(Veragem::Sync::Source, :harness, ->(*args) { bases.tap { calls << args } }) { sync(gem) }

      assert_equal [["0.0.1", gem]], calls
      assert_equal ["#{YARDOPTS}# mine\n", "#{editorconfig}# mine\n"],
                   [read(gem, ".yardopts"), read(gem, ".editorconfig")]
    end
  end

  private

  # two files you and veragem changed, their bases not in the repository, recorded by a release
  def lost_bases(gem, editorconfig)
    bases = { ".yardopts" => YARDOPTS.lines.drop(1).join, ".editorconfig" => "# old\n#{editorconfig}" }
    bases.each { |path, base| write(gem, path, "#{base}# mine\n") }
    rerecord(gem, bases.to_h { |path, base| [path, blob(base)] }, version: "0.0.1", source: "release")
    bases
  end
end
