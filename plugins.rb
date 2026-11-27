# frozen_string_literal: true

# Bundler loads this file to find the plugin's commands: `bundle veragem` and `bundle veragem-sync`.
require "veragem" # Bundler puts the plugin's lib/ on the load path first

module Veragem
  # The commands, Bundler's plugin API.
  class Command < Bundler::Plugin::API
    command "veragem"
    command "veragem-sync"

    # Runs `bundle veragem ARGS`, or `bundle veragem-sync ARGS`.
    # @param command [String] "veragem" or "veragem-sync"
    # @param args [Array<String>] the command's arguments
    # @return [String, nil] the new gem's directory; a sync's none
    def exec(command, args)
      command == "veragem-sync" ? Sync::Source.launch(args) : Veragem.run(args)
    end
  end
end
