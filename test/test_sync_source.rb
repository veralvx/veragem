# frozen_string_literal: true

require "test_helper"

class TestSyncSource < Minitest::Test
  include Veragem::SyncSupport
  include Veragem::ReleaseSupport

  def test_a_checkout_syncs
    in_gem do |gem|
      older(gem, ".yardopts", "old\n")

      assert_equal ["Sync #{HEADING}\n  sync .yardopts: veragem changed it, you did not\n", "", nil],
                   launched(gem, "--path", ROOT)
      assert_equal YARDOPTS, read(gem, ".yardopts")
    end
  end

  # --path relative to the gem's directory; the refusal shown alone, and the status failed
  def test_a_sync_that_fails_exits_so
    in_gem do |gem|
      rerecord(gem, version: "99.0.0")
      relative = relative_to(gem)

      refusal = "veragem #{Veragem::VERSION} is older than 99.0.0, which last synced the harness (--force)\n"

      assert_equal ["", refusal, 1], launched(gem, "--path=#{relative}")
    end
  end

  def test_the_latest_release_syncs_by_default
    in_gem do |gem|
      rerecord(gem, source: "release")

      with_sources(built, old) do
        assert_equal ["Nothing to sync from veragem #{Veragem::VERSION} (release)\n", "", nil], launched(gem)
      end
    end
  end

  def test_no_release_is_refused
    in_gem do |gem|
      with_sources do
        error = assert_raises(Veragem::Error) { capture_subprocess_io { Veragem::Sync::Source.launch([], dir: gem) } }

        assert_equal "cannot fetch veragem (the latest) from the gem sources", error.message
      end
    end
  end

  def test_a_release_without_sync_is_refused
    in_gem do |gem|
      with_sources(old) do
        error = assert_raises(Veragem::Error) { Veragem::Sync::Source.launch([], dir: gem) }

        assert_match %r{/veragem-0\.0\.1 has no bundle veragem-sync: a veragem checkout has\z}, error.message
      end
    end
  end

  def test_a_release_writes_its_harness
    in_gem do |gem|
      harness = Veragem::Generator.entries(project).select(&:harness).to_h { [it.path, it.bytes.b] }

      with_sources(built) { assert_equal harness, Veragem::Sync::Source.harness(Veragem::VERSION, gem) }
    end
  end

  # a release without sync runs nothing; one whose sync fails writes none either
  def test_a_release_without_a_sync_that_runs_writes_none
    in_gem do |gem|
      with_sources(old, broken) do
        assert_equal([{}, ""], capture_subprocess_io_value { Veragem::Sync::Source.harness("0.0.1", gem) })
        assert_equal({}, capture_subprocess_io_value { Veragem::Sync::Source.harness("0.0.2", gem) }.first)
      end
    end
  end

  def test_a_release_not_found_is_refused
    in_gem do |gem|
      with_sources(old) do
        error = assert_raises(Veragem::Error) { capture_subprocess_io { Veragem::Sync::Source.harness("9.9.9", gem) } }

        assert_equal "cannot fetch veragem 9.9.9 from the gem sources", error.message
      end
    end
  end

  private

  # +gem+'s path to this checkout, relative; none across Windows' drives
  def relative_to(gem)
    Pathname(ROOT).relative_path_from(gem).to_s
  rescue ArgumentError
    skip "#{gem} and #{ROOT} are on different drives"
  end

  # the block's value, and what it wrote to stderr
  def capture_subprocess_io_value
    value = nil
    _, err = capture_subprocess_io { value = yield }
    [value, err]
  end

  # what `bundle veragem-sync ARGV` showed in +gem+, and its status when it failed
  def launched(gem, *argv)
    status = nil
    out, err = capture_subprocess_io do
      Veragem::Sync::Source.launch(argv, dir: gem)
    rescue SystemExit => e
      status = e.status
    end
    [out, err, status]
  end
end
