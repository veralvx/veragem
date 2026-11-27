# frozen_string_literal: true

require "test_helper"

class TestSyncOptions < Minitest::Test
  include Veragem::SyncSupport

  def test_an_older_veragem_is_refused_unless_forced
    in_gem do |gem|
      older(gem, ".yardopts", "old\n", version: "99.0.0")

      assert_equal "veragem #{Veragem::VERSION} is older than 99.0.0, which last synced the harness (--force)",
                   refused(gem).first
      sync(gem, "--force")

      assert_equal YARDOPTS, read(gem, ".yardopts")
    end
  end

  # the checkout's changes may be none of the release's
  def test_a_release_after_a_checkout_of_its_version_is_refused_unless_forced
    in_gem do |gem|
      stubbed(Veragem::Sync, :source, -> { "release" }) do
        assert_equal "veragem #{Veragem::VERSION}'s release would undo the checkout of #{Veragem::VERSION} that last " \
                     "synced the harness: --path to a checkout (--force)", refused(gem).first
        assert_equal "Nothing to sync from veragem #{Veragem::VERSION} (release)\n", sync(gem, "--force")
        commit(gem)

        assert_equal "Nothing to sync from veragem #{Veragem::VERSION} (release)\n", sync(gem), "a release's record"
      end
    end
  end

  # the versions compared as versions: as written, the record's may differ
  def test_a_release_after_a_checkout_of_its_version_written_otherwise_is_refused
    in_gem do |gem|
      rerecord(gem, version: " #{Veragem::VERSION}")

      stubbed(Veragem::Sync, :source, -> { "release" }) { assert_match(/would undo the checkout/, refused(gem).first) }
    end
  end

  def test_a_release_after_an_older_checkout_is_synced
    in_gem do |gem|
      rerecord(gem, version: "0.0.1")

      stubbed(Veragem::Sync, :source, -> { "release" }) do
        assert_equal "Nothing to sync from veragem #{Veragem::VERSION} (release)\n", sync(gem)
      end
    end
  end

  def test_an_older_record_is_synced
    in_gem do |gem|
      rerecord(gem, version: "0.0.1", source: "path")

      assert_equal "Nothing to sync #{HEADING}\n", sync(gem)
    end
  end

  def test_a_gem_without_a_record_is_refused
    in_tmpdir do |dir|
      assert_equal "no .veragem.yml in #{dir}: a gem veragem generated has one", refused(dir).first
    end
  end

  def test_render_writes_the_harness
    in_gem do |gem|
      in_tmpdir do |out|
        # elsewhere than the tests' directory: a mutant's render would write into it
        Dir.chdir(out) { Veragem::Sync.render(Veragem::Record.read(gem), out) }

        assert_equal Veragem::Record.read(gem).files.keys.sort, files_in(out).sort
        assert_equal read(gem, "Rakefile"), read(out, "Rakefile")
      end
    end
  end

  # a release's alone, which a sync runs: from the command line, its harness would overwrite yours
  def test_render_is_no_option
    in_gem do |gem|
      in_tmpdir do |out|
        assert_equal "invalid option: --render (bundle veragem-sync --help)", refused(gem, "--render", out).first
        assert_empty files_in(out)
      end
    end
  end

  def test_options_are_read
    assert_equal [{ path: "x", dry_run: true, interactive: true, force: true }, nil],
                 Veragem::Sync.options(%w[--path x --dry-run --interactive --force])
    assert_equal [{ path: "x", dry_run: true, interactive: true, force: true }, nil], Veragem::Sync.options(%w[-nifp x])
    assert_equal [{ dry_run: true }, %w[my_gem --exe --path y]],
                 Veragem::Sync.options(%w[--dry-run --adopt my_gem --exe --path y])
    assert_equal [{}, []], Veragem::Sync.options(%w[--adopt])
  end

  def test_an_unknown_argument_is_refused
    {
      %w[--bogus] => "invalid option: --bogus (bundle veragem-sync --help)",
      %w[--path] => "missing argument: --path (bundle veragem-sync --help)",
      %w[my_gem other] => "no such argument my_gem (bundle veragem-sync --help)",
      %w[--dry --pa x] => "invalid option: --dry (bundle veragem-sync --help)",
      %w[-v] => "invalid option: -v (bundle veragem-sync --help)"
    }.each do |argv, message|
      assert_equal message, assert_raises(Veragem::Error) { Veragem::Sync.options(argv) }.message
    end
  end

  def test_help_and_version_are_syncs
    help, = capture_io { assert_raises(SystemExit) { Veragem::Sync.options(%w[--help]) } }
    version, = capture_io { assert_raises(SystemExit) { Veragem::Sync.options(%w[--version]) } }

    assert_match(/\AUsage: bundle veragem-sync \[--path DIR\]/, help)
    assert_match(/^ +-p, --path=DIR +Sync from the veragem checkout at DIR/, help)
    assert_match(/^ +-n, --dry-run +Show what would change/, help)
    assert_equal "bundle veragem-sync #{Veragem::VERSION}\n", version
  end
end
