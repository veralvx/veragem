# frozen_string_literal: true

require "test_helper"

# CITATION.cff's values, as options give them: a citation's alone, checked as Zenodo's import takes them.
class TestCitation < Minitest::Test
  include Veragem::TestSupport
  include Veragem::CitationSupport

  def test_a_citation_is_opt_in
    gem = parse("my_gem")

    assert_equal [false, nil, nil, nil, nil, nil],
                 [gem.citation, gem.given_names, gem.family_names, gem.alias_name, gem.orcid, gem.keywords]
  end

  def test_with_a_citation_the_family_names_are_required_the_given_names_optional
    gem = parse("my_gem", "--citation", "--given-names", " Jane ", "--family-names=van Doe")

    assert_equal [true, "Jane", "van Doe"], [gem.citation, gem.given_names, gem.family_names]
    assert_nil parse("my_gem", "--citation", "--family-names=Doe").given_names
    [%w[--citation], %w[--citation --given-names=Jane]].each do |argv|
      error = assert_raises(Veragem::Error) { parse("my_gem", *argv) }

      assert_equal "no family names: --family-names, CITATION.cff's author", error.message
    end
  end

  def test_a_citations_values_without_one_are_refused
    [%w[--family-names=Doe], %w[--given-names=Jane], %w[--alias=jdoe], %w[--orcid=0000-0002-1825-0097],
     %w[--keywords=ruby], %w[--no-citation --family-names=Doe]].each do |argv|
      assert_equal NEEDED, assert_raises(Veragem::Error) { parse("my_gem", *argv) }.message
    end
  end

  # ORCID's own examples, its check digit an X too; and its blocks' bounds, as Zenodo's idutils has them
  def test_an_orcid_id_is_one_zenodo_takes_written_as_its_url
    { "0000-0002-1825-0097" => ORCID, " http://orcid.org/0000-0002-9079-593X " => "https://orcid.org/0000-0002-9079-593X",
      "https://orcid.org/0000-0002-1694-233x" => "https://orcid.org/0000-0002-1694-233X",
      "0000-0001-5000-0007" => "https://orcid.org/0000-0001-5000-0007",
      "0000-0003-5000-0001" => "https://orcid.org/0000-0003-5000-0001",
      "0009-0000-1234-567X" => "https://orcid.org/0009-0000-1234-567X" }.each do |given, written|
      assert_equal written, parse("my_gem", "--citation", "--family-names=Doe", "--orcid=#{given}").orcid
    end
  end

  def test_an_orcid_id_zenodo_refuses_is_refused
    refused = ["0000-0002-1825-0098", "0000-0001-4999-9992", "0000-0003-5000-001X", "0009-0010-0000-0011",
               "0000000218250097", "orcid", "https://isni.org/0000-0002-1825-0097", "0000-0002-1825-0097\nx",
               "0000-0002-1825-009\xFF"]
    refused.each do |given|
      error = assert_raises(Veragem::Error) { parse("my_gem", "--citation", "--family-names=Doe", "--orcid=#{given}") }

      assert_match(/\Ainvalid ORCID iD /, error.message)
    end
  end

  def test_keywords_are_comma_separated_their_blanks_and_repeats_dropped
    gem = parse("my_gem", "--citation", "--family-names=Doe", "--keywords= ruby, gem,, ruby ,\u00A0,")

    assert_equal %w[ruby gem], gem.keywords
    [",", " , ", "a\tb", "x" * 99].each do |given|
      error = assert_raises(Veragem::Error) { parse("my_gem", "--citation", "--family-names=Doe", "--keywords=#{given}") }

      assert_match(/\Ainvalid keyword/, error.message)
    end
  end

  # its title the name: Zenodo's import refuses one under 3 characters
  def test_a_name_under_three_characters_cannot_have_a_citation
    in_tmpdir do |dir|
      check = ->(name, citation) { Veragem::Generator.check(name, exe: false, citation:, target: File.join(dir, name)) }
      error = assert_raises(Veragem::Error) { check.call("ab", true) }

      assert_equal "invalid gem name ab with --citation: Zenodo takes a title of 3 characters or more", error.message
      assert_equal %w[abc ab], [check.call("abc", true), check.call("ab", false)]
    end
  end

  # one line, a comma too: Zenodo's import reads no alias; without a terminal, none unless given
  def test_an_alias_is_one_line
    citing = %w[my_gem --citation --family-names=Doe]

    aliases = [" jdoe ", "Doe, J."].map { parse(*citing, "--alias=#{it}").alias_name }

    assert_equal ["jdoe", "Doe, J."], aliases
    assert_nil parse(*citing).alias_name
    assert_nil parse(*citing, "--no-alias").alias_name
    error = assert_raises(Veragem::Error) { parse(*citing, "--alias=a\tb") }

    assert_match(/\Ainvalid alias "a\\tb": one line/, error.message)
  end

  def test_no_given_names_is_none
    gem = parse("my_gem", "--citation", "--family-names=Doe", "--no-given-names")

    assert_equal [nil, "Doe"], [gem.given_names, gem.family_names]
  end

  # one line, U+FFFE and U+FFFF refused (outside YAML's printable characters: CITATION.cff would not
  # parse), and no comma, which Zenodo reads as the family names' end; RubyGems' TODO is no rule here
  def test_a_name_is_one_line_without_a_comma
    { "--given-names=a\tb" => /\Ainvalid given names/, "--given-names=a\uFFFEb" => /\Ainvalid given names/,
      "--given-names=a\uFFFFb" => /\Ainvalid given names/,
      "--family-names=Smith, Jr." => /\Ainvalid family names "Smith, Jr\.": no comma/ }.each do |name, message|
      error = assert_raises(Veragem::Error) { parse("my_gem", "--citation", "--family-names=Doe", name) }

      assert_match message, error.message
    end
    assert_equal "TODO", parse("my_gem", "--citation", "--family-names=TODO").family_names
  end

  # as bytes, as a locale not UTF-8's gives them: a blank of Unicode's dropped, invalid UTF-8 refused
  def test_keywords_as_bytes
    assert_equal %w[a b], Veragem::Project.check(:keywords, "a,\u00A0,b".b).split(", ")
    error = assert_raises(Veragem::Error) { Veragem::Project.check(:keywords, "a,\xFF".dup.force_encoding(Encoding::UTF_8)) }

    assert_match(/\Ainvalid keyword /, error.message)
  end
end
