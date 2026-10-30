# frozen_string_literal: true

require "test_helper"
require "yaml"

# CITATION.cff, a gem's with --citation alone: its author's names, asked or given, and the file.
class TestCitation < Minitest::Test
  include Veragem::TerminalSupport
  include Veragem::GeneratedSupport

  def parse(*argv) = Veragem::Options.parse(argv, config: CONFIG.method(:[]), input: StringIO.new)

  def test_a_citation_is_opt_in
    gem = parse("my_gem")

    assert_equal [false, nil, nil], [gem.citation, gem.given_names, gem.family_names]
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

  def test_names_without_a_citation_are_refused
    [%w[--family-names=Doe], %w[--given-names=Jane], %w[--no-citation --family-names=Doe]].each do |argv|
      error = assert_raises(Veragem::Error) { parse("my_gem", *argv) }

      assert_equal "--given-names and --family-names are CITATION.cff's: they need a citation", error.message
    end
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

  def test_at_a_terminal_the_names_are_asked_the_authors_words_offered
    config = CONFIG.merge("user.name" => "Ana María de Souza")
    gem, shown = ask("my_gem", "--license=mit", "--summary=Hi", answers: ["", "y", "", "", "", "", ""], config:)

    assert_equal [true, "Ana María de", "Souza"], [gem.citation, gem.given_names, gem.family_names]
    assert_includes shown, "Family names, CITATION.cff's [Souza]: Given names, CITATION.cff's [Ana María de]: "
  end

  # the given names offered: the author's words before the family names, whichever they are
  def test_at_a_terminal_the_given_names_offered_follow_the_family_names
    config = CONFIG.merge("user.name" => "Ana María de Souza")
    answers = [""] * 7
    { "de Souza" => "Ana María", "Plato" => nil }.each do |family, given|
      gem, shown = ask("my_gem", "--citation", "--family-names=#{family}", answers:, config:)

      assert_equal [given, family], [gem.given_names, gem.family_names]
      assert_includes shown, "Given names, CITATION.cff's#{" [#{given}]" if given}: Email"
    end
  end

  # one word, the family names alone: no given names offered, and none taken
  def test_at_a_terminal_the_given_names_may_be_none
    gem, shown = ask("my_gem", "--citation", "--author=Plato", answers: [""] * 7)

    assert_equal [nil, "Plato"], [gem.given_names, gem.family_names]
    assert_includes shown, "Family names, CITATION.cff's [Plato]: Given names, CITATION.cff's: "
  end

  def test_at_a_terminal_no_given_names_is_not_asked
    gem, shown = ask("my_gem", "--citation", "--no-given-names", answers: [""] * 7)

    assert_equal [nil, "Doe"], [gem.given_names, gem.family_names]
    refute_includes shown, "Given names"
  end

  def test_at_a_terminal_without_a_citation_no_name_is_asked
    _, shown = ask("my_gem", answers: ["", "n", "", "", "", "", ""])

    refute_includes shown, "names"
  end

  # names given: the citation's question refuses no
  def test_at_a_terminal_names_given_need_the_citation
    gem, shown = ask("my_gem", "--family-names=Doe", answers: ["", "n", "y", "", "", "", "", "", ""])

    assert_equal [true, "Doe"], [gem.citation, gem.family_names]
    assert_includes shown, "--given-names and --family-names are CITATION.cff's: they need a citation\n"
  end

  def test_the_file_is_a_citations_alone
    in_tmpdir do |dir|
      Veragem::Generator.generate(project, File.join(dir, "my_gem"))
      Veragem::Generator.generate(project("my_cited", citation: true, family_names: "Doe"), File.join(dir, "my_cited"))

      refute_path_exists File.join(dir, "my_gem/CITATION.cff")
      assert_path_exists File.join(dir, "my_cited/CITATION.cff")
    end
  end

  def test_the_file_holds_the_projects_values
    %w[mit apache dual].each do |license|
      gem = project(license:, citation: true, given_names: "Jane", family_names: "Doe")
      cff, version = generated(gem)

      assert_equal({ "cff-version" => "1.2.0", "title" => "my_gem", "abstract" => "A Ruby gem.",
                     "authors" => [{ "given-names" => "Jane", "family-names" => "Doe" }], "version" => version,
                     "date-released" => Time.now.strftime("%F"), "license" => gem.licenses,
                     "repository-code" => "https://github.com/jane/my_gem" }, cff.except("message"))
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
