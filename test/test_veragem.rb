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
        target = Veragem.run(ARGS, dir:, input: StringIO.new)
      end

      assert_equal File.join(dir, "my_gem"), target
      assert_path_exists File.join(target, "my_gem.gemspec")
    end
  end

  # its input not a terminal: nothing asked
  def test_bundle_veragem_runs_it_in_the_working_directory
    stdin = $stdin
    $stdin = StringIO.new
    in_tmpdir do |dir|
      assert_output(/Created my_gem/) { Dir.chdir(dir) { Veragem::Command.new.exec("veragem", ARGS) } }

      assert_path_exists File.join(dir, "my_gem/my_gem.gemspec")
    end
  ensure
    $stdin = stdin
  end

  # its input a terminal, the directory given is the one checked before any question
  def test_from_a_terminal_it_asks_into_the_directory_given
    in_tmpdir do |dir|
      terminal = StringIO.new("n\n\n\n").tap { |io| def io.tty? = true }
      _, err = capture_io { Veragem.run(ARGS, dir:, input: terminal) }

      assert_match(%r{\AA command line, exe/my_gem \(y/n\) \[n\]: License}, err)
      error = assert_raises(Veragem::Error) { Veragem.run(ARGS, dir:, input: terminal) }
      assert_equal "#{File.join(dir, "my_gem")} already exists", error.message
    end
  end

  def test_a_refusal_is_bundlers_plugin_error
    assert_operator Veragem::Error, :<, Bundler::PluginError
    assert_equal 29, Veragem::Error.new.status_code
  end
end
