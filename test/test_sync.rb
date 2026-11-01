# frozen_string_literal: true

require "test_helper"

# This repository's harness is the template's: each file the template holds as is (no ERB) is
# here too, the same bytes and mode -- but those that must differ, below, and a command line's
# alone (this gem has none).
class TestSync < Minitest::Test
  include Veragem::GeneratedSupport

  ROOT = File.expand_path("..", __dir__)
  TEMPLATE = Veragem::Generator::TEMPLATE
  # Dependabot here moves the template's copies too; mutineer's ignores this repository's mutants.
  DIFFERENT = %w[.github/dependabot.yml .mutineer.yml].freeze

  def plain_files
    Dir.glob("**/*", File::FNM_DOTMATCH, base: TEMPLATE).reject do |file|
      file.end_with?(".erb") || File.directory?(File.join(TEMPLATE, file)) ||
        (DIFFERENT + Veragem::Generator::EXE).include?(file)
    end
  end

  def copy?(file)
    ours = File.join(ROOT, file)
    theirs = File.join(TEMPLATE, file)
    File.file?(ours) && File.binread(ours) == File.binread(theirs) && File.executable?(ours) == File.executable?(theirs)
  end

  # the modes git records, the same on every platform
  def test_the_executables_are_the_generators
    executables = indexed_executables(ROOT, "template").map { it.delete_prefix("template/") }

    assert_equal executables.sort, Veragem::Generator::EXECUTABLES.sort
  end

  def test_the_harness_is_the_templates
    refute_empty plain_files
    assert_empty(plain_files.reject { copy?(it) })
  end

  # the gems a name cannot take, which Generator reads from it wherever the plugin is installed
  def test_the_gem_ships_the_tools_lock
    assert_includes Gem::Specification.load(File.join(ROOT, "veragem.gemspec")).files, "Gemfile.lock"
  end

  def test_the_files_that_differ_are_the_templates_too
    DIFFERENT.each { assert_path_exists File.join(TEMPLATE, it) }
  end
end
