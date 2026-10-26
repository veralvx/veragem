# frozen_string_literal: true

module Veragem
  # The gem to generate: the values given, checked, and what follows from them.
  class Project
    # GitHub's rule for a user or organization name.
    GITHUB = /\A[a-z\d](?:[a-z\d]|-(?=[a-z\d])){0,38}\z/i
    # Each choice's SPDX identifiers: the gemspec's licenses, the LICENSE-* files.
    LICENSES = { "mit" => ["MIT"], "apache" => ["Apache-2.0"], "dual" => ["MIT", "Apache-2.0"] }.freeze

    attr_reader :name, :author, :email, :github, :summary, :license, :exe

    # +name+, and +values+: the author, email, github, summary and license (strings), exe (true for a
    # command line), as Options reads them.
    def initialize(name, values)
      @name = Name.check(name)
      @author = Project.text("author", values[:author])
      @email = values[:email] && Project.text("email", values[:email])
      @github = Project.github(values[:github])
      @summary = Project.text("summary", values[:summary])
      @license = Project.license(values[:license])
      @exe = values[:exe] == true
    end

    # The file the gem requires: `my-gem`'s is my/gem.
    def path = name.tr("-", "/")

    def underscored = name.tr("-", "_")

    # Its module, as `bundle gem` names it.
    def constant = modules.join("::")

    def modules = Name.modules(name)

    def licenses = LICENSES.fetch(license)

    def year = Time.now.year

    def quote(value) = Project.quote(value)

    # +body+ inside the gem's modules, each nested and indented, +doc+ a comment on the innermost.
    def nest(body, doc: nil)
      *outer, inner = modules
      code = "#{"# #{doc}\n" if doc}module #{inner}\n#{indent(body)}end\n"
      outer.reverse.reduce(code) { |nested, mod| "module #{mod}\n#{indent(nested)}end\n" }
    end

    # +value+ as a Ruby string literal, as written whatever the locale (String#inspect escapes
    # what the locale cannot show): a quote, a backslash and an interpolation escaped.
    def self.quote(value) = %("#{value.gsub(/["\\]|#(?=[{$@])/) { "\\#{it}" }}")

    # Each value's check, a question's too: the value a project takes, or an Error saying why not.
    def self.github(value) = valid("GitHub user", value) { GITHUB.match?(it) }

    def self.license(value) = valid("license (mit, apache or dual)", value) { LICENSES.key?(it) }

    def self.valid(field, value)
      raise Error, "invalid #{field} #{value.inspect}" unless yield value

      value
    end
    private_class_method :valid

    # A value a file quotes: one line of valid UTF-8, its surrounding spaces stripped (Unicode's too),
    # short enough for the gemspec's line (RuboCop's 120 columns), which RubyGems does not refuse as
    # unfinished.
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

    private

    def indent(code) = code.gsub(/^(?=.)/, "  ")
  end
end
