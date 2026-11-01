# frozen_string_literal: true

module Veragem
  # CITATION.cff's rules beyond its values' text, as Zenodo's import takes them: who may give them,
  # the gem's name, the author's names (no comma), alias (which Zenodo reads not) and ORCID iD, the
  # keywords; and what its questions offer.
  module Citation
    # The values CITATION.cff alone writes.
    KEYS = %i[given_names family_names alias orcid keywords].freeze
    # An ORCID iD, bare or as its URL: its 16th character, the check digit.
    ORCID = %r{\A(?:https?://orcid\.org/)?(\d{4}-\d{4}-\d{4}-\d{3}[\dX])\z}i
    # The ORCID iDs ORCID issues, without their check digit: those Zenodo's import takes (idutils).
    ORCID_BLOCKS = [15_000_000..35_000_000, 900_000_000_000..900_100_000_000].freeze
    private_constant :ORCID, :ORCID_BLOCKS

    # Whether a citation's values are given: --no-given-names' false is none.
    # @param values [Hash{Symbol => String, Boolean, nil}]
    # @return [Boolean]
    def self.cited?(values) = values.values_at(*KEYS).any?

    # A citation's values, given only with a citation.
    # @param values [Hash{Symbol => String, Boolean, nil}] a citation's among them
    # @param citation [Boolean] whether the gem has CITATION.cff
    # @return [void]
    # @raise [Veragem::Error] one is given without a citation
    def self.check_values(values, citation)
      return if citation || !cited?(values)

      raise Error, "--given-names, --family-names, --alias, --orcid and --keywords are CITATION.cff's: " \
                   "they need a citation"
    end

    # The value a citation's +key+ takes, as Project.check's: an ORCID iD its URL, keywords joined by
    # ", ".
    # @param key [Symbol] one of KEYS
    # @param value [String] valid UTF-8, as Project.check passes it
    # @yieldparam field [String] a value's name, as a refusal names it
    # @yieldparam text [String] the value, or a keyword
    # @yieldreturn [String] it checked, one line
    # @return [String]
    # @raise [Veragem::Error] +key+ cannot take it
    def self.check(key, value)
      field = key.name.tr("_", " ")
      case key
      when :orcid then orcid(value)
      when :keywords then keywords(value) { yield("keyword", it) }.join(", ")
      # Zenodo's import reads no alias: a comma divides nothing in it
      when :alias then yield(field, value)
      else names(field, yield(field, value))
      end
    end

    # The name, CITATION.cff's title: Zenodo's import refuses one under 3 characters.
    # @param name [String] the gem's
    # @param citation [Boolean] whether the gem has CITATION.cff
    # @return [void]
    # @raise [Veragem::Error] the citation cannot have the name
    def self.check_name(name, citation)
      return unless citation && name.length < 3

      raise Error, "invalid gem name #{name} with --citation: Zenodo takes a title of 3 characters or more"
    end

    # What a citation's question offers. The citation, y where its values are given, which need one.
    # The names, guessed from the author's words, Unicode's spaces between them: the last the family
    # names, those before the family names the given names -- none where the author does not end
    # with them. The alias, the GitHub user: only offered, as it may name an organization.
    # @param key [Symbol] the question's
    # @param values [Hash{Symbol => String, Boolean, nil}] the answers so far, checked
    # @return [String, nil] nil for none, and for any other question
    def self.default(key, values)
      author = values[:author].to_s
      case key
      when :citation then cited?(values) ? "y" : "n"
      when :family_names then author.split(/[[:space:]]+/).last
      when :given_names then author[/\A(.+?)[[:space:]]+#{Regexp.escape(values[:family_names].to_s)}\z/, 1]
      when :alias then values[:github].to_s
      end
    end

    # An author's names, as one line: no comma, which Zenodo reads as the family names' end
    # ("family, given"), so "Smith, Jr." would lose its given names.
    # @param field [String] "given names" or "family names", as a refusal names them
    # @param names [String] one line of text
    # @return [String] +names+
    # @raise [Veragem::Error] they hold a comma
    def self.names(field, names)
      return names unless names.include?(",")

      raise Error, "invalid #{field} #{names.inspect}: no comma, Zenodo's divide of family and given names"
    end

    # Keywords, comma-separated, as CFF's list takes them: blanks and repeats dropped.
    # @param value [String] valid UTF-8, as Project.check passes it
    # @yieldparam keyword [String] each keyword
    # @yieldreturn [String] it checked, one line
    # @return [Array<String>]
    # @raise [Veragem::Error] none is left
    def self.keywords(value, &)
      words = value.split(",").grep_v(/\A[[:space:]]*\z/).map(&).uniq
      return words unless words.empty?

      raise Error, "invalid keywords #{value.inspect}: one or more, comma-separated"
    end

    # An ORCID iD as CFF writes it, its URL, checked as Zenodo's import checks it (idutils' is_orcid):
    # its check digit ISO 7064 MOD 11-2's, its number in a block ORCID issues. Zenodo refuses the
    # whole citation for a bad one.
    # @param value [String] bare or its URL, valid UTF-8 as Project.check passes it
    # @return [String] its https://orcid.org/ URL
    # @raise [Veragem::Error] it is no ORCID iD
    def self.orcid(value)
      id = value.strip[ORCID, 1]&.upcase
      return "https://orcid.org/#{id}" if id && valid?(id.delete("-"))

      raise Error, "invalid ORCID iD #{value.inspect}: 0000-0002-1825-0097, or its https://orcid.org/ URL"
    end

    private_class_method def self.valid?(digits)
      *number, last = digits.chars
      sum = number.reduce(0) { |total, digit| (total + digit.to_i) * 2 }
      check = (12 - (sum % 11)) % 11
      last == (check == 10 ? "X" : check.to_s) && ORCID_BLOCKS.any? { it.cover?(number.join.to_i) }
    end
  end
end
