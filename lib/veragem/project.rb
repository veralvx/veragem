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
      unless NAME.match?(name)
        raise Error, "invalid gem name #{name.inspect}: lower-case words of letters and digits, each a " \
                     "letter first after a dash, joined by _ or - (my_gem, my-gem)"
      end
      # the generated code's lines within RuboCop's 120 columns
      if name.length > 40 || name.count("-") > 3
        raise Error, "invalid gem name #{name}: at most 40 characters and 4 modules deep"
      end
      # lib/test_helper.rb would shadow the tests' own (Minitest's -Ilib:test)
      raise Error, "invalid gem name #{name}: its lib/test_helper.rb would shadow the tests'" if name == "test_helper"

      check_modules(name)
      name
    end

    # The gem writes `module` for each of its modules: one defined already, as Set or Logger, it would
    # reopen -- and an outer one that is a class, it could not. Asked of a Ruby of its own, which
    # requires the gem's paths first (`date-holidays`: date), as its tools may load them.
    def check_modules(name)
      nestings = nestings_of(name)
      defined = nestings.zip(kinds(name, nestings)).take_while { |_, kind| !kind.to_s.empty? }
      raise Error, "invalid gem name #{name}: #{nestings.last} is already defined" if defined.size == nestings.size

      outer = defined.find { |_, kind| kind != "Module" }
      raise Error, "invalid gem name #{name}: #{outer[0]} is a #{outer[1]}, not a module" if outer
    end

    # My, My::Gem
    def nestings_of(name) = modules_of(name).then { |modules| (1..modules.size).map { modules.first(it).join("::") } }

    # Each of +nestings+' class -- Module, Class... -- or "" when undefined, once each of the gem's
    # paths is required (date, date/holidays), in a Ruby outside any bundle.
    def kinds(name, nestings)
      paths = (1..nestings.size).map { name.split("-").first(it).join("/") }
      probe = "ARGV.shift(Integer(ARGV.shift)).each { begin; require it; rescue LoadError; end }; " \
              "ARGV.each { puts Object.const_defined?(it, false) ? Object.const_get(it, false).class : '' }"
      command = [RbConfig.ruby, "-e", probe, paths.size.to_s, *paths, *nestings]
      IO.popen(Bundler.unbundled_env, command, unsetenv_others: true, &:readlines).map(&:chomp)
    end

    def valid(field, value)
      raise Error, "invalid #{field} #{value.inspect}" unless yield value

      value
    end

    def modules_of(name) = name.split("-").map { |word| word.split("_").map(&:capitalize).join }

    # A value a file quotes: one line of valid UTF-8, its surrounding spaces stripped, short enough
    # for the gemspec's line (RuboCop's 120 columns), which RubyGems does not refuse as unfinished.
    def text(field, value)
      value = value.dup.force_encoding(Encoding::UTF_8)
      line = value.valid_encoding? && !value.match?(/[[:cntrl:]]/) ? value.strip : ""
      raise Error, "invalid #{field} #{value.inspect}: one line of text" if line.empty?
      raise Error, "invalid #{field}: too long, its Ruby string at most 100 characters" if quote(line).length > 100
      if line.match?(/\A(TODO|FIXME)/)
        raise Error,
              "invalid #{field} #{line.inspect}: RubyGems refuses one starting TODO or FIXME"
      end

      line
    end
  end
end
