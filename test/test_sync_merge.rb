# frozen_string_literal: true

require "test_helper"

class TestSyncMerge < Minitest::Test
  include Veragem::SyncSupport

  LOST = "merged without its base, which is lost: check it, from its first difference to its last"
  BOTH = "veragem and you changed it\n"
  # shown after the plan
  NO_BASE = "No base for .yardopts: veragem #{Veragem::VERSION}'s, lost\n".freeze

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

  # a checkout's: no release writes it again. Said so, the differences marked, veragem's recorded:
  # resolved, then synced again, yours
  def test_a_merge_without_its_base_marks_each_difference
    in_gem do |gem|
      older(gem, ".yardopts", "#{YARDOPTS}--mine\n", base: "lost\n")
      git(gem, "gc", "--quiet", "--prune=now")

      message = stubbed(Veragem::Sync::Source, :harness, ->(*) { flunk "a checkout's fetches no release" }) { refused(gem) }

      shown = "Sync #{HEADING}\n  sync .yardopts: #{BOTH}#{NO_BASE}"

      assert_equal ["resolve, then commit:\n  .yardopts: #{LOST}", shown], message
      assert_equal "#{YARDOPTS}<<<<<<< .yardopts\n--mine\n=======\n>>>>>>> veragem\n", read(gem, ".yardopts")
      older(gem, ".yardopts", "#{YARDOPTS}--mine\n", base: YARDOPTS)

      assert_equal "Sync #{HEADING}\n  keep .yardopts: you changed it, veragem did not\n", sync(gem)
    end
  end

  # yours emptied: veragem's whole, as a merge without a base gives it, but yours to check; an
  # executable the gem had, not staged, its markers out of the index
  def test_a_merge_without_its_base_is_left_to_check_whatever_it_marks
    in_gem do |gem|
      older(gem, "bin/setup", "", base: "lost\n")
      git(gem, "gc", "--quiet", "--prune=now")

      assert_equal "resolve, then commit:\n  bin/setup: #{LOST}", refused(gem).first
      assert_equal theirs_text(gem, "bin/setup"), read(gem, "bin/setup")
      assert_includes status(gem), " M bin/setup\n"
      refute_match(/^\S/, status(gem), "nothing staged")
    end
  end

  # a release that cannot be fetched: said so, and its bases lost; before any file is written
  def test_a_release_not_fetched_leaves_its_bases_lost
    in_gem do |gem|
      lost_bases(gem, read(gem, ".editorconfig"))
      unfetched = ->(*) { raise Veragem::Error, "cannot fetch veragem 0.0.1 from the gem sources" }
      message, shown = stubbed(Veragem::Sync::Source, :harness, unfetched) { refused(gem) }

      assert_equal "resolve, then commit:\n  .editorconfig: #{LOST}\n  .yardopts: #{LOST}", message
      assert_match(/^cannot fetch veragem 0\.0\.1 from the gem sources\n/, shown)
      assert_match(/^No base for \.editorconfig, \.yardopts: veragem 0\.0\.1's, lost\n\z/, shown)
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
    rerecord(gem, bases.to_h { |path, base| [path, blob(gem, base)] }, version: "0.0.1", source: "release")
    bases
  end
end
