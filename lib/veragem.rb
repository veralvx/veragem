# frozen_string_literal: true

require "bundler"
require_relative "veragem/version"
require_relative "veragem/name"
require_relative "veragem/project"
require_relative "veragem/options"
require_relative "veragem/generator"

# `bundle veragem NAME`: a new gem, its toolchain wired up.
module Veragem
  # A refusal: Bundler prints its message alone, and exits with its status.
  class Error < Bundler::PluginError; end

  # Generates the gem +argv+ names into +dir+; returns its directory.
  def self.run(argv, dir: Dir.pwd)
    project = Options.parse(argv)
    target = File.join(dir, project.name)
    Generator.generate(project, target)
    puts "Created #{project.name}. Next: cd #{project.name} && bin/setup (CONTRIBUTING.md's first steps)"
    target
  end
end
