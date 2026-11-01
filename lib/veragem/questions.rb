# frozen_string_literal: true

module Veragem
  # A terminal's questions for what no option gives: each offers its default, which an empty answer
  # takes, and is asked again until the answer passes the check the project's value would.
  class Questions
    # Each value's question, in the order asked; the name's comes first.
    QUESTIONS = {
      exe: "A command line, exe/%<name>s (y/n)",
      citation: "A citation file, CITATION.cff (y/n)",
      license: "License (mit, apache or dual)",
      summary: "Summary",
      author: "Author",
      family_names: "Family names, CITATION.cff's",
      given_names: "Given names, CITATION.cff's",
      orcid: "ORCID iD, CITATION.cff's",
      keywords: "Keywords, comma-separated, CITATION.cff's",
      email: "Email",
      github: "GitHub user",
      alias: "Alias, CITATION.cff's"
    }.freeze
    private_constant :QUESTIONS

    # Whether +text+ is "-", an optional question's none: spaces around it stripped, Unicode's too, as
    # a value's are.
    # @param text [String] an answer or an option's value, its bytes as given
    # @return [Boolean]
    def self.none?(text)
      text = text.dup.force_encoding(Encoding::UTF_8)
      text.valid_encoding? && text.match?(/\A[[:space:]]*-[[:space:]]*\z/)
    end

    # Questions on +output+, answered on +input+, for a gem generated into +dir+.
    # @param input [#gets, #tty?] where the answers are typed
    # @param output [#print, #puts] where the questions are shown
    # @param dir [String] where the gem is to be generated
    # @return [void]
    def initialize(input, output, dir)
      @input = input
      @output = output
      @dir = dir
    end

    # The name, +given+ or else asked for: checked as far as it, +exe+ and +citation+ decide, before
    # the rest.
    # @param given [String, nil] the name the arguments give
    # @param exe [Boolean] whether --exe is given
    # @param citation [Boolean] whether --citation, or a citation's value, is given
    # @return [String]
    # @raise [Veragem::Error] +given+ is refused, or nothing is answered
    def name(given, exe:, citation:)
      return check_name(given, exe, citation) if given

      ask("Gem name", check: -> { check_name(it, exe, citation) }) #: String
    end

    # +given+ (the options) and the answers to the rest, +defaults+ offered; a citation's values asked
    # only for a citation, the author's words offered for its names, the GitHub user for its alias.
    # @param name [String] the gem's, checked
    # @param given [Hash{Symbol => String, Boolean}] the options' values
    # @param defaults [Hash{Symbol => String}] git's and Options' own
    # @return [Hash{Symbol => String, Boolean, nil}] a value for each key asked, nil for none
    # @raise [Veragem::Error] nothing is answered, or the terminal cannot be asked
    def values(name, given, defaults)
      values = given.dup #: Hash[Symbol, String | bool | nil]
      QUESTIONS.except(*given.keys).each do |key, question|
        next if Citation::KEYS.include?(key) && values[:citation] != true

        check = -> { answer(key, it, name, values) }
        offer = default(key, defaults, values)
        values[key] = ask(format(question, name:), offer, optional: Project::OPTIONAL.key?(key), check:)
      end
      values
    end

    private

    def check_name(name, exe, citation) = Generator.check(name, exe:, citation:, target: File.join(@dir, name))

    def answer(key, text, name, values)
      case key
      when :exe then yes?(text).tap { Generator.check_name(name, it) }
      when :citation
        yes?(text).tap do |cited|
          Citation.check_values(values, cited)
          Citation.check_name(name, cited)
        end
      else Project.check(key, text)
      end
    end

    # The answer, or the default, through +check+; asked again, saying why, when there is neither, or
    # the check fails, but an +optional+ one is nil -- and "-" its none, which a default would take
    # otherwise.
    def ask(question, default = nil, check:, optional: false)
      default = offered(question, default, check)
      loop do
        reply = read(question, default, optional) || default
        return if optional && (reply.nil? || Questions.none?(reply))

        # neither an answer nor a default: said so, as a refusal is
        next terminal(question) { @output.puts "an answer is required" } if reply.nil?

        value = checked(question, reply, check)
        return value unless value.nil?
      end
    end

    # +default+ if it passes +check+: one refused, said why, is not offered.
    def offered(question, default, check) = (default unless default.nil? || checked(question, default, check).nil?)

    # A line's text, nil when empty; one its encoding cannot read as bytes, as an argument's.
    def read(question, default, optional)
      line = terminal(question) do
        @output.print "#{question}#{" (- for none)" if optional}#{" [#{default}]" if default}: "
        @input.gets.tap { @output.puts unless it }
      end
      raise Error, "no answer to #{question}" unless line

      answer = (line.valid_encoding? ? line : line.b).strip
      answer unless answer.empty?
    end

    def checked(question, answer, check)
      check.call(answer)
    rescue Error => e
      terminal(question) { @output.puts e.message }
      nil
    end

    # The block's reading or writing of the terminal: one that fails cannot ask +question+, unlike a
    # check's own failure.
    def terminal(question)
      yield
    rescue SystemCallError, IOError => e
      raise Error, "cannot ask #{question}: #{e.message}"
    end

    def yes?(answer)
      case answer.downcase
      in "y" | "yes" then true
      in "n" | "no" then false
      else raise Error, "y or n"
      end
    end

    def default(key, defaults, values) = Citation.default(key, values) || { exe: "n", **defaults }[key]
  end
end
