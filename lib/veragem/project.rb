# frozen_string_literal: true

module Veragem
  # The gem to generate: the values given, checked, and what follows from them.
  class Project
    # GitHub's rule for a user or organization name.
    GITHUB = /\A[a-z\d](?:[a-z\d]|-(?=[a-z\d])){0,38}\z/i
    # Each choice's SPDX identifiers: the gemspec's licenses, the LICENSE-* files.
    LICENSES = { "mit" => ["MIT"], "apache" => ["Apache-2.0"], "dual" => ["MIT", "Apache-2.0"] }.freeze
    # What yard-lint (.yard-lint.yml) takes for a tag written informally, first in a comment.
    INFORMAL_TAG = /\A(?:note|important|todo|fixme|see(?:\ also)?|warning|deprecated|author|version|since|returns
                     |raises|example):/xi

    attr_reader :name, :author, :email, :github, :summary, :license, :exe

    # +value+ as a Ruby string literal, as written whatever the locale (String#inspect escapes
    # what the locale cannot show): a quote, a backslash and an interpolation escaped.
    # @param value [String] a value of the gem's, checked
    # @return [String]
    def self.quote(value) = %("#{value.gsub(/["\\]|#(?=[{$@])/) { "\\#{it}" }}")

    # The value +key+ takes, an option's or an answer's: checked, or an Error saying why not.
    # @param key [Symbol] :author, :email, :github, :summary or :license
    # @param value [String] as given
    # @return [String] the value a file writes
    # @raise [Veragem::Error] +key+ cannot take it
    def self.check(key, value)
      case key
      when :github then valid("GitHub user", value) { GITHUB.match?(it) }
      when :license then valid("license (mit, apache or dual)", value) { LICENSES.key?(it) }
      when :summary then documented(text("summary", value))
      else text(key.name, value)
      end
    end

    # +name+, and +values+: the author, email, github, summary and license (strings, but an email false,
    # --no-email's, or nil for none), exe (true for a command line), as Options reads them.
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
      @exe = values[:exe] == true
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
    def licenses = LICENSES.fetch(license)

    # The copyright's year: this one.
    # @return [Integer]
    def year = Time.now.year

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

    # +value+, if the block takes it.
    # @param field [String] its name in the refusal
    # @param value [Object] as given
    # @yieldparam value [Object] as given
    # @yieldreturn [Boolean] whether it is valid
    # @return [Object] +value+
    # @raise [Veragem::Error] the block refuses it
    def self.valid(field, value)
      raise Error, "invalid #{field} #{value.inspect}" unless yield value

      value
    end
    private_class_method :valid

    # A value a file quotes: one line of valid UTF-8, its surrounding spaces stripped (Unicode's too),
    # short enough for the gemspec's line (RuboCop's 120 columns), which RubyGems does not refuse as
    # unfinished.
    # @param field [String] its name in the refusal
    # @param value [String] as given, in any encoding
    # @return [String] stripped, in UTF-8
    # @raise [Veragem::Error] it is not such a line
    def self.text(field, value)
      value = value.dup.force_encoding(Encoding::UTF_8)
      one_line = value.valid_encoding? && !value.match?(/[[:cntrl:]\u2028\u2029]/)
      line = one_line ? value.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "") : ""
      raise Error, "invalid #{field} #{value.inspect}: one line of text" if line.empty?
      raise Error, "invalid #{field}: too long, its Ruby string at most 100 characters" if quote(line).length > 100
      if line.match?(/\A(TODO|FIXME)/)
        raise Error,
              "invalid #{field} #{line.inspect}: RubyGems refuses one starting TODO or FIXME"
      end

      line
    end
    private_class_method :text

    # +summary+, which is the module's comment too: one the gem's own yard-lint takes, no informal tag
    # first and no backtick or bold left open -- a `**` outside code with a non-space beside it, as
    # yard-lint counts (`x ** 2` is no bold).
    # @param summary [String] a text, checked
    # @return [String] +summary+
    # @raise [Veragem::Error] yard-lint would refuse it
    def self.documented(summary)
      raise Error, "invalid summary #{summary.inspect}: YARD would read a tag" if summary.match?(INFORMAL_TAG)

      bold = summary.gsub(/`[^`]*`/, "").scan(/(?<=\S)\*\*|\*\*(?=\S)/).size
      if summary.count("`").odd? || bold.odd?
        raise Error, "invalid summary #{summary.inspect}: a backtick or ** left open"
      end

      summary
    end
    private_class_method :documented

    private

    # +code+, each line not empty indented a level.
    # @param code [String] Ruby code
    # @return [String]
    def indent(code) = code.gsub(/^(?=.)/, "  ")
  end
end
