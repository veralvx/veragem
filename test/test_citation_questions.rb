# frozen_string_literal: true

require "test_helper"

# From a terminal: a citation's values, asked only for a citation.
class TestCitationQuestions < Minitest::Test
  include Veragem::TerminalSupport
  include Veragem::CitationSupport

  def test_at_a_terminal_the_names_are_asked_the_authors_words_offered
    config = CONFIG.merge("user.name" => "Ana María de Souza")
    gem, shown = ask("my_gem", "--license=mit", "--summary=Hi", answers: ["", "y", "", "", "", "", "", "", ""], config:)

    assert_equal [true, "Ana María de", "Souza"], [gem.citation, gem.given_names, gem.family_names]
    assert_includes shown, "Family names, CITATION.cff's [Souza]: Given names, CITATION.cff's [Ana María de]: "
  end

  # the given names offered: the author's words before the family names, whichever they are
  def test_at_a_terminal_the_given_names_offered_follow_the_family_names
    config = CONFIG.merge("user.name" => "Ana María de Souza")
    answers = [""] * 9
    { "de Souza" => "Ana María", "Plato" => nil }.each do |family, given|
      gem, shown = ask("my_gem", "--citation", "--family-names=#{family}", answers:, config:)

      assert_equal [given, family], [gem.given_names, gem.family_names]
      assert_includes shown, "Given names, CITATION.cff's#{" [#{given}]" if given}: ORCID iD"
    end
  end

  # one word, the family names alone: no given names offered, and none taken
  def test_at_a_terminal_the_given_names_may_be_none
    gem, shown = ask("my_gem", "--citation", "--author=Plato", answers: [""] * 9)

    assert_equal [nil, "Plato"], [gem.given_names, gem.family_names]
    assert_includes shown, "Family names, CITATION.cff's [Plato]: Given names, CITATION.cff's: "
  end

  def test_at_a_terminal_no_given_names_is_not_asked
    gem, shown = ask("my_gem", "--citation", "--no-given-names", answers: [""] * 9)

    assert_equal [nil, "Doe"], [gem.given_names, gem.family_names]
    refute_includes shown, "Given names"
  end

  # asked after the names, each may be none; an answer refused is asked again
  # under a locale not UTF-8's, the arguments and the answers come as bytes: the family names given
  # are compared with the author answered as the values Project takes, UTF-8's
  def test_at_a_terminal_the_names_offered_whatever_the_locale
    family = "de Souz\u00E1".b.force_encoding(Encoding::US_ASCII)
    gem, = ask("my_gem", "--citation", "--family-names", family,
               answers: ["", "", "", "Ana de Souz\u00E1".b, "", "", "", "", ""])

    assert_equal ["Ana", "de Souz\u00E1"], [gem.given_names, gem.family_names]
  end

  def test_at_a_terminal_the_orcid_id_and_the_keywords_are_asked
    answers = ["", "", "", "", "", "", "0000-0002-1825-0098", "0000-0002-1825-0097", ",", "ruby, gem", "", ""]
    gem, shown = ask("my_gem", "--citation", answers:)

    assert_equal [ORCID, %w[ruby gem]], [gem.orcid, gem.keywords]
    assert_includes shown, "ORCID iD, CITATION.cff's: invalid ORCID iD"
    assert_includes shown, "Keywords, comma-separated, CITATION.cff's: invalid keywords"
    gem, = ask("my_gem", "--citation", answers: [""] * 10)

    assert_equal [nil, nil], [gem.orcid, gem.keywords]
  end

  def test_at_a_terminal_without_a_citation_none_of_its_values_is_asked
    _, shown = ask("my_gem", answers: ["", "n", "", "", "", "", ""])

    refute_match(/names|ORCID|Keywords/, shown)
  end

  # its values given: the citation's question offers y, and refuses n
  def test_at_a_terminal_a_citations_values_given_need_the_citation
    gem, shown = ask("my_gem", "--family-names=Doe", answers: ["", "n", "", "", "", "", "", "", "", "", ""])

    assert_equal [true, "Doe"], [gem.citation, gem.family_names]
    assert_includes shown, "CITATION.cff (y/n) [y]: #{NEEDED}\nA citation file"
  end

  # Unicode's spaces divide the author's words too
  def test_at_a_terminal_the_names_guessed_between_unicode_spaces
    gem, shown = ask("my_gem", "--citation", "--author=Ana\u00A0Mar\u00EDa\u3000Souza", answers: [""] * 9)

    assert_equal ["Ana\u00A0Mar\u00EDa", "Souza"], [gem.given_names, gem.family_names]
    assert_includes shown, "Family names, CITATION.cff's [Souza]: "
  end

  # a name under 3 characters: --citation refuses it before any question, and y is refused for it
  def test_at_a_terminal_a_short_name_cannot_have_a_citation
    why, shown = refused("ab", "--citation")

    assert_match(/\Ainvalid gem name ab with --citation/, why)
    assert_empty shown
    _, shown = ask("--citation", answers: ["ab", "abc", "", "", "", "", "", "", "", "", "", ""])

    assert_includes shown, "Gem name: invalid gem name ab with --citation"
    gem, shown = ask("ab", answers: ["", "y", "n", "", "", "", "", ""])

    assert_equal ["ab", false], [gem.name, gem.citation]
    assert_includes shown, "(y/n) [n]: invalid gem name ab with --citation"
  end

  # a citation's values given, the citation's question takes y alone: its name is refused first
  def test_at_a_terminal_a_citations_values_given_refuse_a_short_name
    why, shown = refused("ab", "--family-names=Doe")

    assert_match(/\Ainvalid gem name ab with --citation/, why)
    assert_empty shown
    gem, shown = ask("--orcid=0000-0002-1825-0097", answers: ["ab", "abc", "", "y", "", "", "", "", "", "", "", ""])

    assert_equal ["abc", true, ORCID], [gem.name, gem.citation, gem.orcid]
    assert_includes shown, "Gem name: invalid gem name ab with --citation"
  end
end
