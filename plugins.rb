# frozen_string_literal: true

# Bundler loads this file to find the plugin's command: `bundle veragem`.
require "veragem" # Bundler puts the plugin's lib/ on the load path first

module Veragem
  # The command, Bundler's plugin API.
  class Command < Bundler::Plugin::API
    command "veragem"

    # Runs `bundle veragem ARGS`.
    # @param _command [String] "veragem"
    # @param args [Array<String>] the command's arguments
    # @return [String] the gem's directory
    def exec(_command, args)
      Veragem.run(args)
    end
  end
end
