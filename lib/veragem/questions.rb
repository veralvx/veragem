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
    def initialize(input, output, dir)
      @input = input
      @output = output
      @dir = dir
    end

    # The name, +given+ or else asked for: checked as far as it and +exe+ decide, before the rest.
    def name(given, exe:)
      return check_name(given, exe) if given

      ask("Gem name", check: -> { check_name(it, exe) }) #: String
    end

    # +given+ (the options) and the answers to the rest, +defaults+ offered.
    def values(name, given, defaults)
      defaults = { exe: "n", **defaults }
      asked = QUESTIONS.except(*given.keys).to_h do |key, question|
        [key, ask(format(question, name:), defaults[key], optional: key == :email, check: -> { answer(key, it, name) })]
      end
      asked.merge(given)
    end

    private

    def check_name(name, exe)
      Name.check(name).tap do |checked|
        Generator.check_name(checked, exe)
        Generator.check_target(File.join(@dir, checked))
      end
    end

    # What +text+ answers for +key+, or an Error saying why not.
    def answer(key, text, name)
      case key
      when :exe then yes?(text).tap { Generator.check_name(name, it) }
      when :license then Project.check(key, completed(text))
      else Project.check(key, text)
      end
    end

    # The answer, or the default, through +check+; asked again when there is neither, or the check
    # fails, but an +optional+ one is nil.
    def ask(question, default = nil, check:, optional: false)
      default = offered(default, check)
      loop do
        answer = read(question, default) || default
        return if optional && answer.nil?

        value = answer && checked(answer, check)
        return value unless value.nil?
      end
    end

    # +default+ if it passes +check+: one refused, said why, is not offered.
    def offered(default, check) = (default unless default.nil? || checked(default, check).nil?)

    # A line's text, nil when empty; one of invalid UTF-8 as bytes, as an argument's.
    def read(question, default)
      @output.print "#{question}#{" [#{default}]" if default}: "
      line = @input.gets or raise Error, "no answer to #{question}"
      answer = (line.valid_encoding? ? line : line.b).strip
      answer unless answer.empty?
    rescue SystemCallError, IOError => e
      raise Error, "cannot ask #{question}: #{e.message}"
    end

    # What +check+ makes of +answer+; nil, said why, when it refuses it.
    def checked(answer, check)
      check.call(answer)
    rescue Error => e
      @output.puts e.message
      nil
    end

    def yes?(answer)
      case answer.downcase
      in "y" | "yes" then true
      in "n" | "no" then false
      else raise Error, "y or n"
      end
    end

    # A licence abbreviated, completed as the option's is: when one licence alone starts so.
    def completed(answer)
      case Project::LICENSES.keys.select { it.start_with?(answer) }
      in [licence] then licence
      else answer
      end
    end
  end
end
