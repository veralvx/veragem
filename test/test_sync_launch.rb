# frozen_string_literal: true

require "test_helper"

# What the plugin reads of the arguments itself: --path alone.
class TestSyncLaunch < Minitest::Test
  include Veragem::SyncSupport
  include Veragem::ReleaseSupport

  # each form OptionParser reads, the last; a value taken, not read as a flag; none after -- or --adopt;
  # the rest the veragem's
  def test_path_is_read_as_optionparser_reads_it
    in_tmpdir do |dir|
      forms(dir).each do |argv, root|
        error = assert_raises(Veragem::Error) { Veragem::Sync::Source.launch(argv, dir:) }

        assert_equal "#{root} has no bundle veragem-sync: a veragem checkout has", error.message, argv.inspect
      end
    end
  end

  # the gem's values', as bundle veragem reads them
  def test_a_path_after_adopt_is_not_read
    in_tmpdir do |dir|
      with_sources(old) do
        error = assert_raises(Veragem::Error) { Veragem::Sync::Source.launch(%w[--adopt --path /none], dir:) }

        assert_match(/\Averagem-0\.0\.1, the latest release, has no bundle veragem-sync/, error.message)
      end
    end
  end

  def test_a_path_without_a_directory_is_refused
    in_tmpdir do |dir|
      { %w[--dry-run --path] => "--path", %w[-np] => "-np" }.each do |argv, flag|
        error = assert_raises(Veragem::Error) { Veragem::Sync::Source.launch(argv, dir:) }

        assert_equal "missing argument: #{flag} (bundle veragem-sync --help)", error.message
      end
    end
  end

  private

  # arguments naming a checkout, each with the directory it names
  def forms(dir)
    {
      ["--path", dir] => dir, ["-p", dir] => dir, ["-p#{dir}"] => dir, ["--paths", "-np", dir] => dir,
      ["-nfp#{dir}"] => dir, ["-n-p#{dir}"] => dir, ["-pelsewhere", "--path=#{dir}", "--dry-run"] => dir,
      ["--path=elsewhere", "-p", dir, "--", "-pnone", "--adopt", "-pnone"] => dir,
      ["-p", "-pdeeper"] => File.join(dir, "-pdeeper")
    }
  end
end
