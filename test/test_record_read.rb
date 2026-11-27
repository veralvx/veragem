# frozen_string_literal: true

require "test_helper"

class TestRecordRead < Minitest::Test
  include Veragem::GeneratedSupport

  CITED = { citation: true, given_names: "Jane", family_names: "Doe", alias: "jd", orcid: "0000-0002-1825-0097",
            keywords: "gems, tools", email: "jane@example.com" }.freeze

  def test_the_record_reads_as_written
    in_tmpdir do |dir|
      values = Veragem::Record.values_of(project(**CITED))
      record = Veragem::Record.new(version: "1.2.3", source: "release", name: "my_gem", values:,
                                   files: { "Rakefile" => "a" * 40, ".github/workflows/ci.yml" => "b" * 64 })
      record.write(dir)
      read = Veragem::Record.read(dir)

      assert_equal fields(record), fields(read)
      assert_match(/\A# bundle veragem-sync reads this file, and rewrites it\n---\n/,
                   File.read(File.join(dir, ".veragem.yml")))
    end
  end

  def test_no_record_is_refused
    in_tmpdir do |dir|
      error = assert_raises(Veragem::Error) { Veragem::Record.read(dir) }

      assert_equal "no .veragem.yml in #{dir}: a gem veragem generated has one", error.message
    end
  end

  def test_a_record_that_is_not_one_is_refused
    [*invalid_files.map { valid.merge("files" => it) }, *invalid_fields].each do |text|
      assert_match(/\Ainvalid \.veragem\.yml: /, refusal(text.is_a?(String) ? text : YAML.dump(text)), text.inspect)
    end
  end

  private

  def refusal(text)
    in_tmpdir do |dir|
      File.write(File.join(dir, ".veragem.yml"), text)
      assert_raises(Veragem::Error) { Veragem::Record.read(dir) }.message
    end
  end

  def invalid_fields
    ["version: [", "- a list", valid.merge("source" => "elsewhere"), valid.except("name"),
     valid.merge("values" => "none"), valid.merge("version" => "not one"), valid.merge("values" => { "author" => 5 }),
     valid.merge("values" => { "author" => "Jane", "exe" => ["yes"] })]
  end

  # ids no git object has, nor git writes, and paths outside the gem, git's own, none, or in another
  # system's syntax
  def invalid_files
    [{ "Rakefile" => "abc" }, { "Rakefile" => 1 }, { "Rakefile" => "a" * 40, "Gemfile" => "abc" },
     { "Rakefile" => "a" * 41 }, { "Rakefile" => "a" * 63 }, { "Rakefile" => "g" * 40 }, { "Rakefile" => "A" * 40 },
     *["/etc/x", "../x", "a/../x", "a/..", ".", "a//b", "a/", "C:/x", "a\\b", "", "a\0b", ".git/HEAD", "a/.GIT/x",
       ".git./x", ".git /x", "GIT~1/HEAD"].map { { it => "a" * 40 } }]
  end

  def valid
    { "version" => "1.0.0", "source" => "path", "name" => "my_gem", "values" => {}, "files" => {} }
  end

  def fields(record) = [record.version, record.source, record.name, record.values, record.files]
end
