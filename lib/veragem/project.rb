# frozen_string_literal: true

module Veragem
  # The gem to generate: the values given, checked, and what follows from them.
  class Project
    # `bundle gem`'s names, lower-case: words of letters and digits joined by `_` (one constant,
    # `my_gem` is MyGem) or `-` (a namespace, `my-gem` is My::Gem), each constant a letter first.
    NAME = /\A[a-z][a-z0-9]*(?:_[a-z0-9]+)*(?:-[a-z][a-z0-9]*(?:_[a-z0-9]+)*)*\z/
    # GitHub's rule for a user or organization name.
    GITHUB = /\A[a-z\d](?:[a-z\d]|-(?=[a-z\d])){0,38}\z/i
    # Each choice's SPDX identifiers: the gemspec's licenses, the LICENSE-* files.
    LICENSES = { "mit" => ["MIT"], "apache" => ["Apache-2.0"], "dual" => ["MIT", "Apache-2.0"] }.freeze

    attr_reader :name, :author, :email, :github, :summary, :license, :exe

    # +name+, and +values+: the author, email, github, summary and license (strings), exe (true or
    # absent), as Options reads them.
    def initialize(name, values)
      @name = check_name(name)
      @author = text("author", values[:author])
      @email = values[:email] && text("email", values[:email])
      @github = valid("GitHub user", values[:github]) { GITHUB.match?(it) }
      @summary = text("summary", values[:summary])
      @license = valid("license (mit, apache or dual)", values[:license]) { LICENSES.key?(it) }
      @exe = values[:exe] == true
    end

    # The file the gem requires: `my-gem`'s is my/gem.
    def path = name.tr("-", "/")

    def underscored = name.tr("-", "_")

    # Its module, as `bundle gem` names it.
    def constant = modules.join("::")

    def modules = modules_of(name)

    def licenses = LICENSES.fetch(license)

    def year = Time.now.year

    # +value+ as a Ruby string literal, as written whatever the locale (String#inspect escapes
    # what the locale cannot show): a quote, a backslash and an interpolation escaped.
    def quote(value) = %("#{value.gsub(/["\\]|#(?=[{$@])/) { "\\#{it}" }}")

    # +body+ inside the gem's modules, each nested and indented, +doc+ a comment on the innermost.
    def nest(body, doc: nil)
      *outer, inner = modules
      code = "#{"# #{doc}\n" if doc}module #{inner}\n#{indent(body)}end\n"
      outer.reverse.reduce(code) { |nested, mod| "module #{mod}\n#{indent(nested)}end\n" }
    end

    private

    def indent(code) = code.gsub(/^(?=.)/, "  ")

    def check_name(name)
      raise Error, "invalid gem name #{name.inspect}: #{NAME.source} (as my_gem or my-gem)" unless NAME.match?(name)

      # a module already defined here, as Set or Bundler, is one the gem would reopen
      defined = modules_of(name).inject(Object) do |scope, mod|
        break unless scope.is_a?(Module) && scope.const_defined?(mod, false)

        scope.const_get(mod, false)
      end
      raise Error, "invalid gem name #{name}: #{modules_of(name).join("::")} is already defined" if defined

      name
    end

    def valid(field, value)
      raise Error, "invalid #{field} #{value.inspect}" unless yield value

      value
    end

    def modules_of(name) = name.split("-").map { |word| word.split("_").map(&:capitalize).join }

    # A value a file quotes: one line of valid UTF-8, which RubyGems does not refuse as unfinished.
    def text(field, value)
      value = value.dup.force_encoding(Encoding::UTF_8)
      unless value.valid_encoding? && !value.strip.empty? && !value.match?(/[[:cntrl:]]/)
        raise Error, "invalid #{field} #{value.inspect}: one line of text"
      end
      if value.match?(/\A(TODO|FIXME)/)
        raise Error, "invalid #{field} #{value.inspect}: RubyGems refuses one starting TODO or FIXME"
      end

      value
    end
  end
end
