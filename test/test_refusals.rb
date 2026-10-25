# frozen_string_literal: true

require "test_helper"

# What the generator refuses, and what a refusal leaves.
class TestRefusals < Minitest::Test
  include Veragem::TestSupport

  def test_a_symlink_is_refused_and_kept
    in_tmpdir do |dir|
      link = File.join(dir, "my_gem")
      File.symlink(File.join(dir, "nowhere"), link)

      assert_raises(Veragem::Error) { Veragem::Generator.generate(project, link) }
      assert File.symlink?(link)
    end
  end

  def test_a_missing_parent_is_refused
    in_tmpdir do |dir|
      error = assert_raises(Veragem::Error) { Veragem::Generator.generate(project, File.join(dir, "no/my_gem")) }

      assert_match(/No such file or directory/, error.message)
      refute_path_exists File.join(dir, "no")
    end
  end

  def test_an_existing_directory_is_refused
    in_tmpdir do |dir|
      error = assert_raises(Veragem::Error) { Veragem::Generator.generate(project, dir) }

      assert_match(/already exists/, error.message)
    end
  end

  def test_a_name_that_would_overwrite_a_template_file_is_refused
    [["helper", false], ["cli", true]].each do |name, exe|
      error = assert_raises(Veragem::Error) { Veragem::Generator.files(project(name, exe:)) }

      assert_match(%r{it would write test/test_#{name}\.rb twice}, error.message)
    end
    refute_empty Veragem::Generator.files(project("cli"))
  end

  # CLI::CLI's code would take its own module for CLI; CLI::X::CLI's finds CLI::X for X
  def test_a_command_line_in_a_module_cli_is_refused
    %w[c_l_i x-c_l_i].each do |name|
      error = assert_raises(Veragem::Error) { Veragem::Generator.files(project(name, exe: true)) }

      assert_match(/its command line, .*::CLI, would take itself for CLI\z/, error.message)
    end
    refute_empty Veragem::Generator.files(project("c_l_i"))
    refute_empty Veragem::Generator.files(project("c_l_i-x", exe: true))
  end

  def test_a_name_of_the_gemfiles_tools_is_refused
    %w[rubocop-rake rubocop-minitest rubocop-performance].each do |name|
      error = assert_raises(Veragem::Error) { Veragem::Generator.files(project(name)) }

      assert_equal "invalid gem name #{name}: the Gemfile's own tool", error.message
    end
  end

  def test_a_failing_git_is_refused
    in_tmpdir do |dir|
      ["/nonexistent", dir].each do |where|
        error = nil
        # git's own complaint goes to the user's terminal; here, nowhere
        _, err = capture_subprocess_io do
          error = assert_raises(Veragem::Error) { Veragem::Generator.git(where, "frobnicate") }
        end

        assert_equal "git frobnicate failed in #{where}", error.message
        assert_match(/frobnicate/, err) if where == dir
      end
    end
  end

  # as from a git hook, which points git at its own repository
  def test_another_repository_is_left_alone
    in_tmpdir do |dir|
      other = File.join(dir, "other")
      system("git", "init", "--quiet", other, exception: true)
      git = File.join(other, ".git")
      with_env("GIT_DIR" => git, "GIT_INDEX_FILE" => File.join(git, "index")) do
        Veragem::Generator.generate(project, File.join(dir, "my_gem"))
      end

      assert_path_exists File.join(dir, "my_gem/.git")
      assert_empty IO.popen(%w[git ls-files], chdir: other, &:read)
    end
  end

  def test_a_failure_leaves_nothing_behind
    in_tmpdir do |dir|
      target = File.join(dir, "my_gem")

      error = with_env("PATH" => "") { assert_raises(Veragem::Error) { Veragem::Generator.generate(project, target) } }

      assert_equal "git init --quiet --initial-branch=main failed in #{target}", error.message

      refute_path_exists target
    end
  end
end
