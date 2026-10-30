# frozen_string_literal: true

require "test_helper"

# CITATION.cff's values, as options give them: a citation's alone, checked as Zenodo's import takes them.
class TestCitation < Minitest::Test
  include Veragem::TerminalSupport
  include Veragem::CitationSupport

  def parse(*argv) = Veragem::Options.parse(argv, config: CONFIG.method(:[]), input: StringIO.new)

  def test_a_citation_is_opt_in
    gem = parse("my_gem")

    assert_equal [false, nil, nil, nil, nil], [gem.citation, gem.given_names, gem.family_names, gem.orcid, gem.keywords]
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
    [%w[--family-names=Doe], %w[--given-names=Jane], %w[--orcid=0000-0002-1825-0097], %w[--keywords=ruby],
     %w[--no-citation --family-names=Doe]].each do |argv|
      assert_equal NEEDED, assert_raises(Veragem::Error) { parse("my_gem", *argv) }.message
    end
  end

  # ORCID's own examples, its check digit an X too; and its blocks' bounds, as Zenodo's idutils has them
  def test_an_orcid_id_is_one_zenodo_takes_written_as_its_url
    { "0000-0002-1825-0097" => ORCID, " http://orcid.org/0000-0002-9079-593X " => "https://orcid.org/0000-0002-9079-593X",
      "https://orcid.org/0000-0002-1694-233x" => "https://orcid.org/0000-0002-1694-233X",
      "0000-0001-5000-0007" => "https://orcid.org/0000-0001-5000-0007",
      "0009-0000-1234-567X" => "https://orcid.org/0009-0000-1234-567X" }.each do |given, written|
      assert_equal written, parse("my_gem", "--citation", "--family-names=Doe", "--orcid=#{given}").orcid
    end
  end

  def test_an_orcid_id_zenodo_refuses_is_refused
    ["0000-0002-1825-0098", "0000-0001-4999-9992", "0009-0010-0000-0011", "0000000218250097", "orcid",
     "https://isni.org/0000-0002-1825-0097", "0000-0002-1825-0097\nx", "0000-0002-1825-009\xFF"].each do |given|
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
    error = assert_raises(Veragem::Error) { parse("ab", "--citation", "--family-names=Doe") }

    assert_equal "invalid gem name ab with --citation: Zenodo takes a title of 3 characters or more", error.message
    assert_equal "abc", parse("abc", "--citation", "--family-names=Doe").name
    assert_equal "ab", parse("ab").name
  end

  def test_no_given_names_is_none
    gem = parse("my_gem", "--citation", "--family-names=Doe", "--no-given-names")

    assert_equal [nil, "Doe"], [gem.given_names, gem.family_names]
  end

  # U+FFFE and U+FFFF are outside YAML's printable characters: CITATION.cff would not parse
  def test_a_name_is_checked_as_any_text
    { "--family-names=TODO" => /\Ainvalid family names "TODO"/, "--given-names=a\tb" => /\Ainvalid given names/,
      "--given-names=a\uFFFEb" => /\Ainvalid given names/, "--given-names=a\uFFFFb" => /\Ainvalid given names/ }
      .each do |name, message|
      error = assert_raises(Veragem::Error) { parse("my_gem", "--citation", "--family-names=Doe", name) }

      assert_match message, error.message
    end
  end
end
