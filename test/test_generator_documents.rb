# frozen_string_literal: true

require "test_helper"

class TestGeneratorDocuments < Minitest::Test
  include Veragem::GeneratedSupport

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
end
