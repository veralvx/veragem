# frozen_string_literal: true

module Veragem
  # A terminal's questions for what no option gives: each offers its default, which an empty answer
  # takes, and is asked again until the answer passes the check the project's value would.
  class Questions
    # Each value's question, in the order asked; the name's comes first.
    QUESTIONS = {
      exe: "A command line, exe/%<name>s (y/n)",
      license: "License (mit, apache or dual)",
      summary: "Summary",
      author: "Author",
      email: "Email",
      github: "GitHub user"
    }.freeze
    private_constant :QUESTIONS

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

    # The name, +given+ or else asked for: checked as far as it and +exe+ decide, before the rest.
    # @param given [String, nil] the name the arguments give
    # @param exe [Boolean] whether --exe is given
    # @return [String]
    # @raise [Veragem::Error] +given+ is refused, or nothing is answered
    def name(given, exe:)
      return check_name(given, exe) if given

      ask("Gem name", check: -> { check_name(it, exe) }) #: String
    end

    # +given+ (the options) and the answers to the rest, +defaults+ offered.
    # @param name [String] the gem's, checked
    # @param given [Hash{Symbol => String, Boolean}] the options' values
    # @param defaults [Hash{Symbol => String}] git's and Options' own
    # @return [Hash{Symbol => String, Boolean, nil}] a value for each key, the email's nil for none
    # @raise [Veragem::Error] nothing is answered, or the terminal cannot be asked
    def values(name, given, defaults)
      defaults = { exe: "n", **defaults }
      asked = QUESTIONS.except(*given.keys).to_h do |key, question|
        [key, ask(format(question, name:), defaults[key], optional: key == :email, check: -> { answer(key, it, name) })]
      end
      asked.merge(given)
    end

    private

    # +name+ checked as Name, Generator and the target directory would.
    # @param name [String] as typed
    # @param exe [Boolean] whether the gem has a command line
    # @return [String] +name+
    # @raise [Veragem::Error] it is refused
    def check_name(name, exe)
      Name.check(name).tap do |checked|
        Generator.check_name(checked, exe)
        Generator.check_target(File.join(@dir, checked))
      end
    end

    # What +text+ answers for +key+, or an Error saying why not.
    # @param key [Symbol] a QUESTIONS key
    # @param text [String] as typed, stripped
    # @param name [String] the gem's, checked
    # @return [String, Boolean]
    # @raise [Veragem::Error] it is refused
    def answer(key, text, name)
      case key
      when :exe then yes?(text).tap { Generator.check_name(name, it) }
      when :license then Project.check(key, completed(text))
      else Project.check(key, text)
      end
    end

    # The answer, or the default, through +check+; asked again when there is neither, or the check
    # fails, but an +optional+ one is nil.
    # @param question [String] its prompt
    # @param default [String, nil] what an empty answer takes
    # @param check [Proc] an answer's value, raising an Error to refuse it
    # @param optional [Boolean] whether no answer at all may be
    # @return [String, Boolean, nil] what +check+ makes of the answer, nil for none
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
    # @param question [String] its prompt
    # @param default [String, nil] git's, or Options', to offer
    # @param check [Proc] an answer's value, raising an Error to refuse it
    # @return [String, nil]
    def offered(question, default, check) = (default unless default.nil? || checked(question, default, check).nil?)

    # A line's text, nil when empty; one its encoding cannot read as bytes, as an argument's.
    # @param question [String] its prompt
    # @param default [String, nil] the default the prompt offers
    # @return [String, nil]
    # @raise [Veragem::Error] no line comes, or the terminal cannot be asked
    def read(question, default)
      line = terminal(question) do
        @output.print "#{question}#{" [#{default}]" if default}: "
        @input.gets.tap { @output.puts unless it }
      end
      raise Error, "no answer to #{question}" unless line

      answer = (line.valid_encoding? ? line : line.b).strip
      answer unless answer.empty?
    end

    # What +check+ makes of +answer+; nil, said why, when it refuses it.
    # @param question [String] its prompt
    # @param answer [String] typed, or a default
    # @param check [Proc] an answer's value, raising an Error to refuse it
    # @return [String, Boolean, nil]
    # @raise [Veragem::Error] the terminal cannot show why
    def checked(question, answer, check)
      check.call(answer)
    rescue Error => e
      terminal(question) { @output.puts e.message }
      nil
    end

    # The block's reading or writing of the terminal: one that fails cannot ask +question+, unlike a
    # check's own failure.
    # @param question [String] its prompt
    # @yield reads or writes the terminal
    # @yieldreturn [Object] what is read
    # @return [Object] the block's value
    # @raise [Veragem::Error] the terminal fails
    def terminal(question)
      yield
    rescue SystemCallError, IOError => e
      raise Error, "cannot ask #{question}: #{e.message}"
    end

    # Whether +answer+ says yes, y or n, case aside.
    # @param answer [String] as typed
    # @return [Boolean]
    # @raise [Veragem::Error] it is neither
    def yes?(answer)
      case answer.downcase
      in "y" | "yes" then true
      in "n" | "no" then false
      else raise Error, "y or n"
      end
    end

    # A licence abbreviated, completed as the option's is: when one licence alone starts so.
    # @param answer [String] as typed
    # @return [String] the licence, or +answer+
    def completed(answer)
      case Project::LICENSES.keys.select { it.start_with?(answer) }
      in [licence] then licence
      else answer
      end
    end
  end
end
