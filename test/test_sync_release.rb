# frozen_string_literal: true

require "test_helper"

# The releases a sync refuses: none, one without sync, one this Ruby cannot run or read.
class TestSyncRelease < Minitest::Test
  include Veragem::SyncSupport
  include Veragem::ReleaseSupport

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

        assert_equal "veragem-0.0.1, the latest release, has no bundle veragem-sync: --path a checkout", error.message
      end
    end
  end

  # nor gem fetch, which takes the latest whatever Ruby it needs
  def test_a_release_this_ruby_cannot_run_is_refused
    in_gem do |gem|
      with_sources(future) do
        refusal = "veragem 9.9.9 needs Ruby >= 99, not #{Gem.ruby_version}"

        assert_equal refusal, assert_raises(Veragem::Error) { Veragem::Sync::Source.launch([], dir: gem) }.message
        assert_equal refusal, assert_raises(Veragem::Error) { Veragem::Sync::Source.harness("9.9.9", gem) }.message
      end
    end
  end

  # a download its format refuses
  def test_a_release_that_cannot_be_read_is_refused
    in_tmpdir do |dir|
      gem = File.join(dir, "veragem-0.0.1.gem")
      File.write(gem, "no gem")
      error = assert_raises(Veragem::Error) { Veragem::Sync::Source.send(:check_ruby, gem) }

      assert_match(/\Acannot read veragem-0\.0\.1\.gem: /, error.message)
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
end
