# frozen_string_literal: true

require "test_helper"

class TestOptions < Minitest::Test
  include Veragem::TestSupport

  # each option and what --help says it does
  HELP = { "--[no-]exe" => "Add a command line, exe/NAME (default: --no-exe, a library alone)",
           "--license=LICENSE" => "mit, apache or dual (MIT OR Apache-2.0, the default)",
           "--author=NAME" => "The author (default: git config user.name, else required)",
           "--[no-]email=EMAIL" => "The author's email (default: git config user.email; --no-email, none)",
           "--github=USER" => "The GitHub user or organization (default: git config github.user, else required)",
           "--summary=TEXT" => "The gem's summary (default: A Ruby gem.)",
           "--[no-]badges" => "Add README badges: CI, Nix, security, version, docs, licence, Ruby (default: --badges)",
           "--[no-]citation" => "Add CITATION.cff, the citation GitHub and Zenodo read (default: --no-citation)",
           "--family-names=NAMES" => "With --citation: the author's family names (required)",
           "--[no-]given-names=NAMES" => "With --citation: the author's given names (--no-given-names: none, unasked)",
           "--[no-]alias=ALIAS" => "With --citation: the author's alias, as a handle (--no-alias: none, unasked)",
           "--orcid=ID" => "With --citation: the author's ORCID iD",
           "--keywords=LIST" => "With --citation: keywords, comma-separated" }.freeze

  def test_git_config_gives_the_defaults
    gem = parse("my_gem")

    assert_equal ["my_gem", "Jane Doe", "jane@example.com", "jane", "A Ruby gem.", "dual", false, true],
                 [gem.name, gem.author, gem.email, gem.github, gem.summary, gem.license, gem.exe?, gem.badges?]
  end

  def test_the_options_override_them
    gem = parse("my_gem", "--exe", "--license=mit", "--author", "Ada", "--email=ada@example.com",
                "--github=ada", "--summary", "Greets.", "--no-badges")

    assert_equal ["Ada", "ada@example.com", "ada", "Greets.", "mit", true, false],
                 [gem.author, gem.email, gem.github, gem.summary, gem.license, gem.exe?, gem.badges?]
  end

  def test_the_email_may_be_unset
    assert_nil parse("my_gem", config: CONFIG.except("user.email")).email
    assert_nil parse("my_gem", "--no-email").email
  end

  # "-", a question's none, is no option's value, as no answer can give it
  def test_a_questions_none_is_refused_as_an_options_value
    { "--email=-" => "email \"-\": a question's none; for none, --no-email",
      "--given-names=-" => "given names \"-\": a question's none; for none, --no-given-names",
      "--alias= - " => "alias \"-\": a question's none; for none, --no-alias",
      "--alias=\u00A0-\u3000" => "alias \"-\": a question's none; for none, --no-alias",
      "--alias=\u00A0-".b => "alias \"-\": a question's none; for none, --no-alias",
      "--orcid=-" => "ORCID iD \"-\": a question's none; for none, leave --orcid out",
      "--keywords=-" => "keywords \"-\": a question's none; for none, leave --keywords out" }.each do |option, why|
      error = assert_raises(Veragem::Error) { parse("my_gem", "--citation", "--family-names=Doe", option) }

      assert_equal "invalid #{why}", error.message
    end
  end

  # within a value, as an answer can give it; and a value that cannot be none
  def test_a_dash_within_an_options_value_or_of_a_required_one_is_kept
    gem = parse("my_gem", "--citation", "--family-names=Doe", "--alias=-x", "--keywords=ruby,-")

    assert_equal ["-x", %w[ruby -]], [gem.alias_name, gem.keywords]
    gem = parse("my_gem", "--author=-", "--summary=-")

    assert_equal %w[- -], [gem.author, gem.summary]
  end

  def test_the_author_and_the_github_user_are_required
    { "user.name" => /no author: --author, or git config user.name/,
      "github.user" => /no GitHub user: --github, or git config github.user/ }.each do |key, message|
      error = assert_raises(Veragem::Error) { parse("my_gem", config: CONFIG.except(key)) }

      assert_match message, error.message
    end
  end

  # without a terminal as at one: the name, then git's values
  def test_the_name_is_refused_before_a_missing_value
    error = assert_raises(Veragem::Error) { parse("My_Gem", config: {}) }

    assert_match(/\Ainvalid gem name "My_Gem": /, error.message)
  end

  def test_one_name_is_required
    { [] => "no gem name", %w[one two] => "one gem name, not 2" }.each do |argv, why|
      error = assert_raises(Veragem::Error) { parse(*argv) }

      assert_equal "#{why} (bundle veragem --help)", error.message
    end
  end

  def test_an_option_is_refused_before_the_name
    error = assert_raises(Veragem::Error) { parse("1gem", "--github=-x") }

    assert_equal 'invalid GitHub user "-x": 1 to 39 ASCII letters, digits and inner single hyphens', error.message
  end

  def test_a_bad_option_is_refused_with_the_usage
    [["--nope"], ["--author"]].each do |argv|
      error = assert_raises(Veragem::Error) { parse("my_gem", *argv) }

      assert_match(/\A(invalid option|invalid argument|missing argument): .* \(bundle veragem --help\)\z/,
                   error.message)
    end
  end

  # ARGV under a UTF-8 locale: an invalid byte is refused as the value it is in
  def test_an_invalid_utf8_argument_is_refused
    invalid = "\xFF".dup.force_encoding(Encoding::UTF_8)

    { %W[#{invalid}] => /invalid gem name/, ["my_gem", "--author", invalid] => /invalid author/,
      ["my_gem", "--email", invalid] => /\Ainvalid email "\\xFF": not UTF-8\z/,
      ["my_gem", "--#{invalid}"] => /invalid option/ }.each do |argv, message|
      assert_match message, assert_raises(Veragem::Error) { parse(*argv) }.message
    end
  end

  def test_options_may_come_first_whatever_posixly_correct
    with_env("POSIXLY_CORRECT" => "1") do
      assert_predicate parse("--exe", "my_gem"), :exe?
      assert_predicate parse("my_gem", "--exe"), :exe?
    end
    refute_predicate parse("my_gem", "--no-exe"), :exe?
  end

  def test_the_help_says_what_each_option_does
    help, = capture_io { assert_raises(SystemExit) { parse("--help") } }

    HELP.each { |switch, does| assert_match(/^ +#{Regexp.escape(switch)} +#{Regexp.escape(does)}$/, help) }
  end

  def test_version
    assert_output("bundle veragem #{Veragem::VERSION}\n") { assert_raises(SystemExit) { parse("--version") } }
  end
end
