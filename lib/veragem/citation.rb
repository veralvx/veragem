# frozen_string_literal: true

module Veragem
  # CITATION.cff's rules beyond its values' text: who may give them, the name it takes, the ORCID iD
  # Zenodo's import takes.
  module Citation
    # The values CITATION.cff alone writes.
    KEYS = %i[given_names family_names orcid keywords].freeze
    # An ORCID iD, bare or as its URL: its 16th character, the check digit.
    ORCID = %r{\A(?:https?://orcid\.org/)?(\d{4}-\d{4}-\d{4}-\d{3}[\dX])\z}i
    # The ORCID iDs ORCID issues, without their check digit: those Zenodo's import takes (idutils).
    ORCID_BLOCKS = [15_000_000..35_000_000, 900_000_000_000..900_100_000_000].freeze
    private_constant :ORCID, :ORCID_BLOCKS

    # A citation's values, given only with a citation.
    # @param citation [Boolean] whether the gem has CITATION.cff
    # @param values [Hash{Symbol => String, Boolean, nil}] a citation's among them
    # @return [void]
    # @raise [Veragem::Error] one is given without a citation
    def self.check_values(citation, values)
      return if citation || values.values_at(*KEYS).none?

      raise Error, "--given-names, --family-names, --orcid and --keywords are CITATION.cff's: they need a citation"
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

    # The name +key+ offers, from the author's words: a guess, the last the family names, those before
    # the family names the given names -- none where the author does not end with them.
    # @param key [Symbol] the question's
    # @param values [Hash{Symbol => String, Boolean, nil}] the author and family names among them
    # @return [String, nil] nil for any other key
    def self.offered(key, values)
      author = values[:author].to_s.strip
      case key
      when :family_names then author.split.last
      when :given_names then author[/\A(.+?)\s+#{Regexp.escape(values[:family_names].to_s.strip)}\z/, 1]
      end
    end

    # An ORCID iD as CFF writes it, its URL, checked as Zenodo's import checks it (idutils' is_orcid):
    # its check digit ISO 7064 MOD 11-2's, its number in a block ORCID issues. Zenodo refuses the
    # whole citation for a bad one.
    # @param value [String] bare or its URL
    # @return [String] its https://orcid.org/ URL
    # @raise [Veragem::Error] it is no ORCID iD
    def self.orcid(value)
      # as bytes: an answer of invalid UTF-8 is refused, not raised on
      id = value.b.strip[ORCID, 1]&.upcase
      return "https://orcid.org/#{id}" if id && issued?(id.delete("-"))

      raise Error, "invalid ORCID iD #{value.inspect}: 0000-0002-1825-0097, or its https://orcid.org/ URL"
    end

    private_class_method def self.issued?(digits)
      *number, last = digits.chars
      sum = number.reduce(0) { |total, digit| (total + digit.to_i) * 2 }
      check = (12 - (sum % 11)) % 11
      last == (check == 10 ? "X" : check.to_s) && ORCID_BLOCKS.any? { it.cover?(number.join.to_i) }
    end
  end
end
