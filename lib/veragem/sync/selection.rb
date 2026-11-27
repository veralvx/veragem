# frozen_string_literal: true

module Veragem
  module Sync
    # --interactive's choice: numbers and ranges of the rows shown (1,3-5), all, none, or nothing,
    # the rows sync takes unasked.
    module Selection
      # The prompt, after the numbered rows.
      PROMPT = "Sync which (1,3-5, all, none; Enter: the ones marked *)? "

      # The numbers chosen of +count+ rows, asked on +output+ until +input+ gives a choice.
      # @param input [#gets] where the choice is typed
      # @param output [#print] where it is asked
      # @param count [Integer] the rows shown
      # @param defaults [Array<Integer>] the rows sync takes unasked
      # @return [Array<Integer>]
      # @raise [Veragem::Error] the input ends first
      def self.ask(input, output, count, defaults)
        loop do
          output.print PROMPT
          answer = input.gets or raise Error, "no choice made"
          chosen = parse(answer, count, defaults) and return chosen
        end
      end

      # The numbers +answer+ chooses of +count+ rows, from 1; nil when it is not a choice. Blank, the
      # +defaults+.
      # @param answer [String] as typed
      # @param count [Integer] the rows shown
      # @param defaults [Array<Integer>] the rows sync takes unasked
      # @return [Array<Integer>, nil]
      def self.parse(answer, count, defaults)
        case answer.strip.downcase
        when "" then defaults
        when "all" then (1..count).to_a
        when "none" then []
        when /\A\d+(?:-\d+)?(?:\s*,\s*\d+(?:-\d+)?)*\z/ then numbers(answer, count)
        end
      end

      # Each number and range's, or nil unless each is a row shown, first to last.
      private_class_method def self.numbers(list, count)
        ranges = list.split(",").map { it.split("-").map(&:to_i).then { |ends| ends.fetch(0)..ends.fetch(-1) } }
        ranges.flat_map(&:to_a).uniq.sort if ranges.all? { it.begin.between?(1, it.end) && it.end <= count }
      end
    end
  end
end
