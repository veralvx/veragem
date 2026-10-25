# frozen_string_literal: true

require "test_helper"

# This repository's harness is the template's: each file the template holds as is (no ERB) is
# here too, the same bytes and mode -- but those that must differ, below.
class TestSync < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  TEMPLATE = Veragem::Generator::TEMPLATE
  # Dependabot here moves the template's copies too.
  DIFFERENT = %w[.github/dependabot.yml].freeze

  def plain_files
    Dir.glob("**/*", File::FNM_DOTMATCH, base: TEMPLATE).reject do |file|
      file.end_with?(".erb") || File.directory?(File.join(TEMPLATE, file)) || DIFFERENT.include?(file)
    end
  end

  def copy?(file)
    ours = File.join(ROOT, file)
    theirs = File.join(TEMPLATE, file)
    File.file?(ours) && File.binread(ours) == File.binread(theirs) && File.executable?(ours) == File.executable?(theirs)
  end

  def test_the_harness_is_the_templates
    refute_empty plain_files
    assert_empty(plain_files.reject { copy?(it) })
  end

  def test_the_files_that_differ_are_the_templates_too
    DIFFERENT.each { assert_path_exists File.join(TEMPLATE, it) }
  end
end
