# frozen_string_literal: true

require "bundler"
require_relative "veragem/version"
require_relative "veragem/name"
require_relative "veragem/project"
require_relative "veragem/questions"
require_relative "veragem/options"
require_relative "veragem/generator"

# `bundle veragem NAME`: a new gem, its toolchain wired up.
module Veragem
  # A refusal: Bundler prints its message alone, and exits with its status.
  class Error < Bundler::PluginError; end

  # Generates the gem +argv+ names into +dir+, what no option gives asked of +input+ when a terminal;
  # returns its directory.
  def self.run(argv, dir: Dir.pwd, input: $stdin)
    project = Options.parse(argv, dir:, input:)
    target = File.join(dir, project.name)
    Generator.generate(project, target)
    puts "Created #{project.name}. Next: cd #{project.name} && bin/setup (CONTRIBUTING.md's first steps)"
    target
  end
end
