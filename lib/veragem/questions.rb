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
      github: "GitHub user"
    }.freeze
    # The questions an empty answer may leave unanswered.
    OPTIONAL = %i[email given_names orcid keywords].freeze
    private_constant :QUESTIONS, :OPTIONAL

    # Generating into +dir+.
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
    # @param citation [Boolean] whether --citation is given
    # @return [String]
    # @raise [Veragem::Error] +given+ is refused, or nothing is answered
    def name(given, exe:, citation:)
      return check_name(given, exe, citation) if given

      ask("Gem name", check: -> { check_name(it, exe, citation) }) #: String
    end

    # +given+ (the options) and the answers to the rest, +defaults+ offered; a citation's names asked
    # only for a citation, the author's words offered for them.
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
        default = default(key, defaults, values)
        values[key] = ask(format(question, name:), default, optional: OPTIONAL.include?(key), check:)
      end
      values
    end

    private

    def check_name(name, exe, citation)
      Name.check(name).tap do |checked|
        Generator.check_name(checked, exe)
        Citation.check_name(checked, citation)
        Generator.check_target(File.join(@dir, checked))
      end
    end

    def answer(key, text, name, values)
      case key
      when :exe then yes?(text).tap { Generator.check_name(name, it) }
      when :citation
        yes?(text).tap do |cited|
          Citation.check_values(cited, values)
          Citation.check_name(name, cited)
        end
      when :license then Project.check(key, completed(text))
      else Project.check(key, text)
      end
    end

    # The answer, or the default, through +check+; asked again when there is neither, or the check
    # fails, but an +optional+ one is nil.
    def ask(question, default = nil, check:, optional: false)
      default = offered(question, default, check)
      loop do
        answer = read(question, default) || default
        return if optional && answer.nil?

        value = answer && checked(question, answer, check)
        return value unless value.nil?
      end
    end

    # +default+ if it passes +check+: one refused, said why, is not offered.
    def offered(question, default, check) = (default unless default.nil? || checked(question, default, check).nil?)

    # A line's text, nil when empty; one its encoding cannot read as bytes, as an argument's.
    def read(question, default)
      line = terminal(question) do
        @output.print "#{question}#{" [#{default}]" if default}: "
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

    def default(key, defaults, values) = Citation.offered(key, values) || { exe: "n", citation: "n", **defaults }[key]

    # A licence abbreviated, completed as the option's is: when one licence alone starts so.
    def completed(answer)
      case Project::LICENSES.keys.select { it.start_with?(answer) }
      in [licence] then licence
      else answer
      end
    end
  end
end
