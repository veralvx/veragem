# frozen_string_literal: true

require "test_helper"
require "yaml"

# CITATION.cff as written: a citation's alone, its values read back as given.
class TestCitationFile < Minitest::Test
  include Veragem::TestSupport
  include Veragem::GeneratedSupport
  include Veragem::CitationSupport

  # the file, and CONTRIBUTING.md's steps for it: Zenodo, and the release that bumps it
  def test_the_file_is_a_citations_alone
    in_tmpdir do |dir|
      Veragem::Generator.generate(project, File.join(dir, "my_gem"))
      Veragem::Generator.generate(project("my_cited", citation: true, family_names: "Doe"), File.join(dir, "my_cited"))

      refute_path_exists File.join(dir, "my_gem/CITATION.cff")
      assert_path_exists File.join(dir, "my_cited/CITATION.cff")
      cited = %w[my_gem my_cited].map { read(dir, "#{it}/CONTRIBUTING.md").scan("CITATION.cff").size }

      assert_equal [0, 3], cited
    end
  end

  def test_the_file_holds_the_projects_values
    gem = project(citation: true, given_names: "Jane", family_names: "Doe", alias: "jdoe", orcid: ORCID,
                  keywords: "ruby, gem")
    cff, version = generated(gem)

    assert_equal({ "cff-version" => "1.2.0", "title" => "my_gem", "abstract" => "A Ruby gem.",
                   "authors" => [{ "family-names" => "Doe", "given-names" => "Jane", "alias" => "jdoe",
                                   "orcid" => ORCID }],
                   "keywords" => %w[ruby gem], "version" => version, "date-released" => Time.now.strftime("%F"),
                   "repository-code" => "https://github.com/jane/my_gem",
                   "repository-artifact" => "https://rubygems.org/gems/my_gem",
                   "url" => "https://rubydoc.info/gems/my_gem" }, cff.except("message"))
  end

  # Zenodo's DOIs, commented out until a release gives them: uncommented, the concept DOI and a
  # version's
  def test_the_dois_are_ready_to_uncomment
    in_tmpdir do |dir|
      Veragem::Generator.generate(project(citation: true, family_names: "Doe"), File.join(dir, "my_gem"))
      cff = YAML.safe_load(read(dir, "my_gem/CITATION.cff").gsub(/^# (?=doi:|identifiers:|  )/, ""))

      identifiers = cff["identifiers"].map { it.values_at("type", "value") }

      assert_equal "10.5281/zenodo.0000000", cff["doi"]
      assert_equal [%w[doi 10.5281/zenodo.0000000], %w[doi 10.5281/zenodo.0000001]], identifiers
    end
  end

  # one licence a string, and none for dual: CFF's list, its OR, fails Zenodo's import (zenodo/zenodo#2515)
  def test_the_licence_is_one_spdx_identifier_or_none
    { "mit" => { "license" => "MIT" }, "apache" => { "license" => "Apache-2.0" },
      "dual" => {} }.each do |license, written|
      cff, = generated(project(license:, citation: true, family_names: "Doe"))

      assert_equal written, cff.slice("license")
    end
  end

  def test_the_values_read_back_as_given
    names = "José \"Q\" \\ \#{x} # 'y': - [z] *a &b !c %d @e `f` {g}"
    cff, = generated(project(summary: names, citation: true, family_names: names))

    assert_equal [names, [{ "family-names" => names }]], cff.values_at("abstract", "authors")
  end

  private

  # +gem+'s CITATION.cff, parsed, and its VERSION
  def generated(gem)
    in_tmpdir do |dir|
      target = File.join(dir, gem.name)
      Veragem::Generator.generate(gem, target)
      [YAML.safe_load(read(target, "CITATION.cff")), read(target, "lib/#{gem.path}/version.rb")[/VERSION = "(.+)"/, 1]]
    end
  end
end
