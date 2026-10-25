# frozen_string_literal: true

require "test_helper"

# What the generator refuses, and what a refusal leaves.
class TestRefusals < Minitest::Test
  include Veragem::TestSupport

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

  def test_a_failing_git_is_refused
    in_tmpdir do |dir|
      ["/nonexistent", dir].each do |where|
        error = assert_raises(Veragem::Error) { Veragem::Generator.git(where, "frobnicate") }

        assert_equal "git frobnicate failed in #{where}", error.message
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
