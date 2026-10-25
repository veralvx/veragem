# frozen_string_literal: true

# Bundler loads this file to find the plugin's command: `bundle veragem`.
require_relative "lib/veragem"

module Veragem
  # The command, Bundler's plugin API.
  class Command < Bundler::Plugin::API
    command "veragem"

    def exec(_command, args)
      Veragem.run(args)
    end
  end
end
