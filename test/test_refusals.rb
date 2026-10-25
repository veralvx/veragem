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

  def test_a_failure_leaves_nothing_behind
    in_tmpdir do |dir|
      target = File.join(dir, "my_gem")

      error = with_env("PATH" => "") { assert_raises(Veragem::Error) { Veragem::Generator.generate(project, target) } }

      assert_equal "git init --quiet --initial-branch=main failed in #{target}", error.message

      refute_path_exists target
    end
  end
end
