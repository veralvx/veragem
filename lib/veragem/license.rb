# frozen_string_literal: true

module Veragem
  # The gem's licence: one of three choices, each its SPDX identifiers.
  module License
    # Each choice's SPDX identifiers: the gemspec's licenses, the LICENSE-* files.
    SPDX = { "mit" => ["MIT"], "apache" => ["Apache-2.0"], "dual" => ["MIT", "Apache-2.0"] }.freeze
    # The choices, as --help, the question and a refusal name them.
    CHOICES = "mit, apache or dual"

    # The choice +value+ names: a choice, its SPDX expression (its ORs in either order) or the start
    # of one choice alone, in any case and spaces around it aside (`Apache-2.0`, `apache-2.0 or mit`,
    # `a`).
    # @param value [String] valid UTF-8, as Project.check passes it
    # @return [String] the choice
    # @raise [Veragem::Error] it names none
    def self.check(value)
      given = value.strip.downcase
      spdx = SPDX.find { |_, ids| ids.map(&:downcase).sort == given.split(" or ").sort }&.first
      return spdx if spdx

      case SPDX.keys.select { it.start_with?(given) }
      in [choice] then choice
      else raise Error, "invalid license (#{CHOICES}) #{value.inspect}"
      end
    end
  end
end
