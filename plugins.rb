# frozen_string_literal: true

# Bundler loads this file to find the plugin's command: `bundle veragem`.
require "veragem" # Bundler puts the plugin's lib/ on the load path first

module Veragem
  # The command, Bundler's plugin API.
  class Command < Bundler::Plugin::API
    command "veragem"

    def exec(_command, args)
      Veragem.run(args)
    end
  end
end
