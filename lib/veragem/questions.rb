# frozen_string_literal: true

module Veragem
  # A terminal's questions for what no option gives: each offers its default, which an empty answer
  # takes, and is asked again until the answer passes the check the project's value would.
  class Questions
    # Each value's question, in the order asked; the name's comes first.
    QUESTIONS = {
      exe: "A command line, exe/%<name>s (y/n)",
      license: "License (#{Project::LICENSES.keys.join(", ")})",
      summary: "Summary",
      author: "Author",
      email: "Email",
      github: "GitHub user"
    }.freeze

    # Generating into +dir+.
    def initialize(input, output, dir)
      @input = input
      @output = output
      @dir = dir
    end

    # The options' values, but --exe's (the name's to check): refused before any question.
    def check(given)
      given.each { |key, value| checks.fetch(key).call(value.to_s) unless key == :exe }
    end

    # The name, +given+ or else asked for: checked as far as it and +exe+ decide, before the rest.
    def name(given, exe:)
      return check_name(given, exe) if given

      ask("Gem name", check: -> { check_name(it, exe) }) #: String
    end

    # +given+ (the options) and the answers to the rest, +defaults+ offered.
    def values(name, given, defaults)
      all = { exe: -> { yes?(it).tap { |exe| Generator.check_command(name, exe) } }, **checks }
      defaults = { exe: "n", **defaults }
      asked = QUESTIONS.except(*given.keys).to_h do |key, question|
        [key, ask(format(question, name:), defaults[key], optional: key == :email, check: all.fetch(key))]
      end
      asked.merge(given)
    end

    private

    def check_name(name, exe)
      Name.check(name).tap do |checked|
        Generator.check_tool(checked)
        Generator.check_target(File.join(@dir, checked))
        Generator.check_command(checked, exe)
      end
    end

    # Each value's check but the command line's: what an answer gives, or an Error saying why not.
    def checks
      {
        license: -> { Project.license(completed(it)) },
        summary: -> { Project.text("summary", it) },
        author: -> { Project.text("author", it) },
        email: -> { Project.text("email", it) },
        github: -> { Project.github(it) }
      }
    end

    # The answer, or the default, through +check+; asked again when there is neither, or the check
    # fails, but an +optional+ one is nil. A default refused is offered no more.
    def ask(question, default = nil, check:, optional: false)
      loop do
        answer = read(question, default) || default
        return answer if answer.nil? && optional

        value = answer && checked(answer, check)
        return value unless value.nil?

        default = nil if answer == default
      end
    end

    # A line's text, nil when empty; one of invalid UTF-8 as bytes, as an argument's. The question
    # flushed: shown when the output is a pipe too.
    def read(question, default)
      @output.print "#{question}#{" [#{default}]" if default}: "
      @output.flush
      line = @input.gets or raise Error, "no answer to #{question}"
      answer = (line.valid_encoding? ? line : line.b).strip
      answer unless answer.empty?
    end

    # What +check+ makes of +answer+; nil, said why, when it refuses it.
    def checked(answer, check)
      check.call(answer)
    rescue Error => e
      @output.puts e.message
      nil
    end

    def yes?(answer)
      return true if %w[y yes].include?(answer.downcase)
      return false if %w[n no].include?(answer.downcase)

      raise Error, "y or n"
    end

    # A licence abbreviated, completed as the option's is: while one licence starts so.
    def completed(answer)
      matches = Project::LICENSES.keys.select { it.start_with?(answer) }
      matches.one? ? matches.fetch(0) : answer
    end
  end
end
