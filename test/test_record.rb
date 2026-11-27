# frozen_string_literal: true

require "test_helper"

class TestRecord < Minitest::Test
  include Veragem::GeneratedSupport

  CITED = { citation: true, given_names: "Jane", family_names: "Doe", alias: "jd", orcid: "0000-0002-1825-0097",
            keywords: "gems, tools", email: "jane@example.com" }.freeze

  # each harness file, as git's index holds it: what sync tells your changes from veragem's by
  def test_a_gem_records_its_harness_as_generated
    each_kind do |gem, target, _|
      record = Veragem::Record.read(target)
      harness = Veragem::Generator.entries(gem).select(&:harness).map(&:path)

      assert_equal harness.sort, record.files.keys.sort
      assert_equal indexed_ids(target, harness), record.files
    end
  end

  # the gem's own files are no harness's
  def test_the_harness_is_every_file_but_the_gems_own
    each_kind do |_, target, _|
      files = Veragem::Record.read(target).files

      assert_includes files, "Rakefile"
      refute_includes files, "README.md"
    end
  end

  # this checkout's, from which the tests run: a path's
  def test_a_gem_records_the_veragem_that_wrote_it
    each_kind do |gem, target, _|
      record = Veragem::Record.read(target)

      assert_equal [Veragem::VERSION, "path", gem.name], [record.version, record.source, record.name]
    end
  end

  def test_the_record_is_added
    each_kind { |_, target, _| assert_includes git(target, "ls-files").lines(chomp: true), Veragem::Record::FILE }
  end

  def test_the_values_are_what_the_project_was_given
    expected = { author: "Jane Doe", email: "jane@example.com", github: "jane", summary: "A Ruby gem.", license: "dual",
                 exe: false, citation: true, badges: true, given_names: "Jane", family_names: "Doe", alias: "jd",
                 orcid: "https://orcid.org/0000-0002-1825-0097", keywords: "gems, tools" }

    assert_equal expected, Veragem::Record.values_of(project(**CITED))
  end

  def test_the_values_give_the_project_again
    tool = project("my-tool", exe: true, license: "mit", badges: false, email: false)
    [project, tool, project(**CITED)].each do |gem|
      values = Veragem::Record.values_of(gem)
      again = Veragem::Record.new(version: "1.0.0", source: "release", name: gem.name, values:, files: {}).project

      assert_equal [gem.name, values], [again.name, Veragem::Record.values_of(again)]
    end
  end

  def test_the_record_reads_as_written
    in_tmpdir do |dir|
      values = Veragem::Record.values_of(project(**CITED))
      record = Veragem::Record.new(version: "1.2.3", source: "release", name: "my_gem", values:,
                                   files: { "Rakefile" => "a" * 40 })
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
    files = [{ "Rakefile" => "abc" }, { "Rakefile" => 1 }, { "Rakefile" => "a" * 40, "Gemfile" => "abc" }]

    [*files.map { valid.merge("files" => it) }, "version: [", "- a list", valid.merge("source" => "elsewhere"),
     valid.except("name"), valid.merge("values" => "none")].each do |text|
      assert_match(/\Ainvalid \.veragem\.yml: /, refusal(text.is_a?(String) ? text : YAML.dump(text)), text.inspect)
    end
  end

  def test_a_checkout_is_a_path_an_installed_gem_a_release
    in_tmpdir do |dir|
      assert_equal "release", Veragem::Record.source_of(dir)
      File.write(File.join(dir, ".git"), "gitdir: elsewhere\n")

      assert_equal "path", Veragem::Record.source_of(dir)
    end
    in_tmpdir do |dir|
      Dir.mkdir(File.join(dir, ".git"))

      assert_equal "path", Veragem::Record.source_of(dir)
    end
  end

  # what the harness leaves out: each of the gem's own files a template of template/
  def test_the_gems_own_files_are_templates
    templates = Dir.glob("**/*", File::FNM_DOTMATCH, base: Veragem::Generator::TEMPLATE)

    assert_empty Veragem::Generator::OWN - templates
  end

  private

  def refusal(text)
    in_tmpdir do |dir|
      File.write(File.join(dir, ".veragem.yml"), text)
      assert_raises(Veragem::Error) { Veragem::Record.read(dir) }.message
    end
  end

  def valid
    { "version" => "1.0.0", "source" => "path", "name" => "my_gem", "values" => {}, "files" => {} }
  end

  def fields(record) = [record.version, record.source, record.name, record.values, record.files]

  def indexed_ids(target, paths)
    git(target, "ls-files", "--stage", "-z", "--", *paths).split("\0").to_h do |line|
      info, path = line.split("\t", 2)
      [path, info.split[1]]
    end
  end
end
