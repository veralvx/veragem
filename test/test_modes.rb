# frozen_string_literal: true

require "test_helper"

# The executables' mode, in git's index on every platform, in the file system where it has one.
class TestModes < Minitest::Test
  include Veragem::TestSupport
  include Veragem::GeneratedSupport

  EXECUTABLES = %w[bin/console bin/setup .githooks/commit-msg .githooks/pre-commit .githooks/pre-push
                   .github/release-notes.sh].freeze

  # in git's index, which a commit keeps, where the file system has no mode (core.fileMode false, as
  # on Windows)
  def test_the_executables_keep_their_mode
    with_env("GIT_CONFIG_COUNT" => "1", "GIT_CONFIG_KEY_0" => "core.fileMode", "GIT_CONFIG_VALUE_0" => "false") do
      each_kind do |gem, target, _|
        executables = EXECUTABLES + (gem.exe ? ["exe/#{gem.name}", ".github/image-registries.sh"] : [])

        assert_equal executables.sort, indexed_executables(target).sort
      end
    end
  end

  def test_the_modes_follow_the_umask
    skip "Windows has no file modes: the index keeps them (test_the_executables_keep_their_mode)" if Gem.win_platform?
    in_tmpdir do |dir|
      umask = File.umask(0o077)
      begin
        Veragem::Generator.generate(project, File.join(dir, "my_gem"))
      ensure
        File.umask(umask)
      end

      assert_equal([0o600, 0o700], %w[README.md bin/setup].map { File.stat(File.join(dir, "my_gem", it)).mode & 0o777 })
    end
  end
end
