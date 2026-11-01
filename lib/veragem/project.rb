# frozen_string_literal: true

require "json"

module Veragem
  # The gem to generate: the values given, checked, and what follows from them.
  class Project
    # GitHub's rule for a user or organization name: ASCII's letters, which /i would widen to Unicode's
    # (ſ, the Kelvin sign).
    GITHUB = /\A[a-zA-Z\d](?:[a-zA-Z\d]|-(?=[a-zA-Z\d])){0,38}\z/
    # Each value a refusal names otherwise than its key, as its other refusals do.
    FIELDS = { github: "GitHub user", license: "license (#{License::CHOICES})", orcid: "ORCID iD" }.freeze
    # What YARD reads as a tag first in a comment: its own (`@param`, `(see`), and those yard-lint
    # (.yard-lint.yml) takes for one written informally.
    TAG = /\A(?:@|\(see\b|(?:note|important|todo|fixme|see(?:\ also)?|warning|deprecated|author|version|since
            |returns|raises|example):)/xi
    # A RuboCop annotation, no documentation, as its AnnotationComment reads one: a keyword first, then
    # a colon, spaces before it or not, or a space -- but a sentence's capitalized first word, a word
    # after it (a summary, stripped, has one after a space).
    ANNOTATION = /\A(todo|fixme|optimize|hack|review|note)\b(\s*:)?(\s+)?/i
    # A magic comment as RuboCop reads one -- an encoding's anywhere, lower-case (Ruby's rule), a
    # frozen string literal's first, in any case -- or a RuboCop directive, which would turn its cops
    # off, or fail them.
    MAGIC = /\b(?:en)?coding\s*[:=]|\A(?i:frozen[_-]string[_-]literal):|(?i:\brubocop\s*:)/
    # The values that may be none, and how an option gives none: a question takes "-".
    OPTIONAL = { email: "--no-email", given_names: "--no-given-names", alias: "--no-alias",
                 orcid: "leave --orcid out", keywords: "leave --keywords out" }.freeze
    private_constant :GITHUB, :FIELDS, :TAG, :ANNOTATION, :MAGIC

    attr_reader :name, :author, :email, :github, :summary, :license, :exe, :citation, :given_names, :family_names,
                :alias_name, :orcid, :keywords

    # +value+ as a Ruby string literal, as written whatever the locale (String#inspect escapes
    # what the locale cannot show): a quote, a backslash and an interpolation escaped.
    # @param value [String] a value of the gem's, checked
    # @return [String]
    def self.quote(value) = %("#{value.gsub(/["\\]|#(?=[{$@])/) { "\\#{it}" }}")

    # The value +key+ takes, an option's or an answer's: checked, or an Error saying why not.
    # @param key [Symbol] :author, :email, :github, :summary, :license, :given_names, :family_names,
    #   :alias, :orcid or :keywords
    # @param value [String, nil] as given; nil, none, is refused as "" is
    # @return [String] the value kept: a licence its choice (`MIT` mit, `Apache-2.0` apache), an ORCID
    #   iD its URL, keywords joined by ", "
    # @raise [Veragem::Error] +key+ cannot take it
    def self.check(key, value)
      value = utf8(key, value)
      case key
      when :github then github(value)
      when :license then License.check(value)
      when :summary then documented(text("summary", value))
      when *Citation::KEYS then Citation.check(key, value) { |name, text| line(name, text) }
      else text(key.name, value)
      end
    end

    # +name+, and +values+: the author, email, github, summary, license and a citation's given and
    # family names, alias, ORCID iD and keywords (strings, but an email, given names or alias false,
    # --no-email's, --no-given-names', --no-alias', or nil for none), exe and citation (true for a
    # command line, for CITATION.cff), as Options reads them.
    # @param name [String] the gem's name, as given
    # @param values [Hash{Symbol => String, Boolean, nil}] the rest, as given
    # @return [void]
    # @raise [Veragem::Error] a value is refused
    def initialize(name, values)
      @name = Name.check(name)
      @author = Project.check(:author, values[:author])
      @email = (Project.check(:email, values[:email]) if values[:email])
      @github = Project.check(:github, values[:github])
      @summary = Project.check(:summary, values[:summary])
      @license = Project.check(:license, values[:license])
      extras(values)
    end

    # The file the gem requires, lib/'s: `my-gem`'s my/gem.
    # @return [String]
    def path = Name.path(name)

    # Its name, its words joined by `_` alone: its test's and its CLI's file names.
    # @return [String]
    def underscored = Name.underscored(name)

    # Its module, as `bundle gem` names it.
    # @return [String]
    def constant = modules.join("::")

    # Its modules, outermost first.
    # @return [Array<String>]
    def modules = Name.modules(name)

    # The SPDX identifiers of its licence.
    # @return [Array<String>]
    def licenses = License::SPDX.fetch(license)

    # The copyright's year: this one.
    # @return [Integer]
    def year = Time.now.year

    # Today in UTC, as CFF writes a date: CITATION.cff's date-released until `rake bump` sets a
    # release's, UTC's too.
    # @return [String]
    def today = Time.now.utc.strftime("%F")

    # +value+ as a YAML double-quoted string: JSON's, which YAML reads alike.
    # @param value [String] a value of the gem's, checked
    # @return [String]
    def yaml(value) = JSON.generate(value)

    # Project.quote, for the templates.
    # @param value [String] a value of the gem's, checked
    # @return [String]
    def quote(value) = Project.quote(value)

    # +body+ inside the gem's modules, each nested and indented, +doc+ a comment on the innermost and
    # the outer ones each a namespace's: one file documents them, as YARD would have it.
    # @param body [String] Ruby code
    # @param doc [String, nil] the comment
    # @return [String]
    def nest(body, doc: nil)
      *outer, inner = modules
      code = "#{"# #{doc}\n" if doc}module #{inner}\n#{indent(body)}end\n"
      outer.reverse.reduce(code) do |nested, mod|
        "#{"# The namespace of #{constant}.\n" if doc}module #{mod}\n#{indent(nested)}end\n"
      end
    end

    # +value+'s bytes as UTF-8, whatever their encoding (ARGV's and git's are binary under a locale
    # not UTF-8's), refused unless valid: every check after it takes valid UTF-8. None (nil) is "",
    # which each check refuses.
    private_class_method def self.utf8(key, value)
      value = value.to_s.dup.force_encoding(Encoding::UTF_8)
      field = FIELDS.fetch(key) { key.name.tr("_", " ") }
      raise Error, "invalid #{field} #{value.inspect}: not UTF-8" unless value.valid_encoding?

      value
    end

    private_class_method def self.github(value)
      return value if GITHUB.match?(value)

      raise Error, "invalid GitHub user #{value.inspect}: up to 39 ASCII letters, digits and inner single hyphens"
    end

    # A value a file quotes, which RubyGems does not refuse as unfinished.
    private_class_method def self.text(field, value)
      line = line(field, value)
      unfinished = line.match?(/\A(TODO|FIXME)/)
      raise Error, "invalid #{field} #{line.inspect}: RubyGems refuses one starting TODO or FIXME" if unfinished

      line
    end

    # One line, its surrounding spaces stripped (Unicode's too), short enough for the gemspec's line
    # (RuboCop's 120 columns). U+FFFE and U+FFFF are outside YAML's printable characters:
    # CITATION.cff's.
    private_class_method def self.line(field, value)
      line = value.match?(/[[:cntrl:]\u2028\u2029\uFFFE\uFFFF]/) ? "" : value.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
      raise Error, "invalid #{field} #{value.inspect}: one line of text" if line.empty?
      raise Error, "invalid #{field}: too long, its Ruby string at most 100 characters" if quote(line).length > 100

      line
    end

    # +summary+, which is the module's comment too: one the gem's own yard-lint and RuboCop take as its
    # documentation, no tag, annotation or magic comment, and no backtick or bold left open -- a `**`
    # outside code with a non-space beside it, as yard-lint counts (`x ** 2` is no bold).
    private_class_method def self.documented(summary)
      raise Error, "invalid summary #{summary.inspect}: YARD would read a tag" if summary.match?(TAG)

      misread = annotation?(summary) || summary.match?(MAGIC)
      raise Error, "invalid summary #{summary.inspect}: RuboCop would read an annotation or a directive" if misread

      bold = summary.gsub(/`[^`]*`/, "").scan(/(?<=\S)\*\*|\*\*(?=\S)/).size
      left_open = summary.count("`").odd? || bold.odd?
      raise Error, "invalid summary #{summary.inspect}: a backtick or ** left open" if left_open

      summary
    end

    private_class_method def self.annotation?(summary)
      keyword, colon, space = summary.match(ANNOTATION)&.captures
      return false unless keyword && (colon || space)

      !(keyword == keyword.capitalize && !colon)
    end

    private

    # What the gem holds beyond the library: a command line, a citation.
    def extras(values)
      @exe, @citation = values.values_at(:exe, :citation).map { it == true }
      Citation.check_values(values, citation)
      cite(values) if citation
    end

    # CITATION.cff's author is a person: the family names it needs, the rest it may have.
    def cite(values)
      given, family, aka, orcid, keywords = values.values_at(:given_names, :family_names, :alias, :orcid, :keywords)
      raise Error, "no family names: --family-names, CITATION.cff's author" unless family

      @given_names = (Project.check(:given_names, given) if given)
      @family_names = Project.check(:family_names, family)
      @alias_name = (Project.check(:alias, aka) if aka)
      @orcid = (Project.check(:orcid, orcid) if orcid)
      @keywords = (Project.check(:keywords, keywords).split(", ") if keywords)
    end

    # a blank line left blank, no trailing spaces
    def indent(code) = code.gsub(/^(?=.)/, "  ")
  end
end
