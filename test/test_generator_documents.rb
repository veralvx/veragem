# frozen_string_literal: true

require "test_helper"

class TestGeneratorDocuments < Minitest::Test
  include Veragem::GeneratedSupport

  # the README's badges, my_gem's: jane's, its licence the default, dual
  WORKFLOWS = "https://github.com/jane/my_gem/actions/workflows"
  BADGES = ["[![Ruby CI](#{WORKFLOWS}/ruby-ci.yml/badge.svg)](#{WORKFLOWS}/ruby-ci.yml)",
            "[![Nix](#{WORKFLOWS}/nix.yml/badge.svg)](#{WORKFLOWS}/nix.yml)",
            "[![Security](#{WORKFLOWS}/security.yml/badge.svg)](#{WORKFLOWS}/security.yml)",
            "[![Gem version](https://img.shields.io/gem/v/my_gem)](https://rubygems.org/gems/my_gem)",
            "[![Docs](https://img.shields.io/badge/docs-rubydoc.info-blue)](https://rubydoc.info/gems/my_gem)",
            "[![License](https://img.shields.io/badge/license-MIT%20OR%20Apache--2.0-blue)](#license)",
            "[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%204.0-red)](#requirements)"].freeze

  # where the documents send a reporter: the gem's own advisories, its maintainer's email alone where
  # one is given
  def test_the_documents_point_at_the_gems_own_reports
    in_tmpdir do |dir|
      Veragem::Generator.generate(project(email: "jane@example.com"), File.join(dir, "my_gem"))
      Veragem::Generator.generate(project("no_email"), File.join(dir, "no_email"))
      advisories = "https://github.com/jane/my_gem/security/advisories/new"

      %w[SECURITY.md .github/ISSUE_TEMPLATE/config.yml].each { assert_includes read(dir, "my_gem/#{it}"), advisories }

      assert_includes read(dir, "my_gem/CODE_OF_CONDUCT.md"), "maintainers at jane@example.com."
      refute_includes read(dir, "no_email/CODE_OF_CONDUCT.md"), "maintainers at"
    end
  end

  # as Markdown's text, which would read _jane_ as emphasis
  def test_the_email_is_written_as_given
    in_tmpdir do |dir|
      Veragem::Generator.generate(project(email: "_jane_@example.com"), File.join(dir, "my_gem"))

      assert_includes read(dir, "my_gem/CODE_OF_CONDUCT.md"), "maintainers at \\_jane\\_@example.com."
    end
  end

  # each badge's image and link, between the title and the summary
  def test_the_readme_has_its_badges
    in_tmpdir do |dir|
      Veragem::Generator.generate(project, File.join(dir, "my_gem"))

      assert_equal ["# my_gem\n", "\n", *BADGES.map { "#{it}\n" }, "\n", "A Ruby gem.\n"],
                   read(dir, "my_gem/README.md").lines.first(11)
    end
  end

  def test_without_badges_the_summary_follows_the_title
    in_tmpdir do |dir|
      Veragem::Generator.generate(project(badges: false), File.join(dir, "my_gem"))

      assert_equal ["# my_gem\n", "\n", "A Ruby gem.\n"], read(dir, "my_gem/README.md").lines.first(3)
    end
  end
end
