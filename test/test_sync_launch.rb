# frozen_string_literal: true

require "test_helper"

# What the plugin reads of the arguments itself: --path alone.
class TestSyncLaunch < Minitest::Test
  include Veragem::SyncSupport
  include Veragem::ReleaseSupport

  # either form, the first; the rest the veragem's
  def test_path_is_read_alone
    in_tmpdir do |dir|
      [["--path", dir], ["--path=#{dir}", "--dry-run", "--path", "elsewhere", "--adopt", "x"]].each do |argv|
        error = assert_raises(Veragem::Error) { Veragem::Sync::Source.launch(argv, dir:) }

        assert_equal "#{dir} has no bundle veragem-sync: a veragem checkout has", error.message
      end
    end
  end

  # the gem's values', as bundle veragem reads them
  def test_a_path_after_adopt_is_not_read
    in_tmpdir do |dir|
      with_sources(old) do
        error = assert_raises(Veragem::Error) { Veragem::Sync::Source.launch(%w[--adopt --path /none], dir:) }

        assert_match %r{/veragem-0\.0\.1 has no bundle veragem-sync}, error.message
      end
    end
  end

  def test_a_path_without_a_directory_is_refused
    in_tmpdir do |dir|
      error = assert_raises(Veragem::Error) { Veragem::Sync::Source.launch(%w[--dry-run --path], dir:) }

      assert_equal "missing argument: --path (bundle veragem-sync --help)", error.message
    end
  end
end
