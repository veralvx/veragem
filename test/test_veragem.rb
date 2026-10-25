# frozen_string_literal: true

require "test_helper"
require_relative "../plugins"

class TestVeragem < Minitest::Test
  include Veragem::TestSupport

  ARGS = %w[my_gem --author Jane --email jane@example.com --github jane].freeze

  def test_it_generates_the_gem_named_in_the_directory_given
    in_tmpdir do |dir|
      target = nil
      assert_output(%r{\ACreated my_gem\. Next: cd my_gem && bin/setup \(CONTRIBUTING\.md's first steps\)}) do
        target = Veragem.run(ARGS, dir:)
      end

      assert_equal File.join(dir, "my_gem"), target
      assert_path_exists File.join(target, "my_gem.gemspec")
    end
  end

  def test_bundle_veragem_runs_it_in_the_working_directory
    in_tmpdir do |dir|
      assert_output(/Created my_gem/) { Dir.chdir(dir) { Veragem::Command.new.exec("veragem", ARGS) } }

      assert_path_exists File.join(dir, "my_gem/my_gem.gemspec")
    end
  end

  def test_a_refusal_is_bundlers_plugin_error
    assert_operator Veragem::Error, :<, Bundler::PluginError
    assert_equal 29, Veragem::Error.new.status_code
  end
end
