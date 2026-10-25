# frozen_string_literal: true

require_relative "lib/veragem/version"

Gem::Specification.new do |spec|
  spec.name = "veragem"
  spec.version = Veragem::VERSION
  spec.authors = ["veralvx"]

  spec.summary = "bundle veragem NAME: a new Ruby gem, its toolchain wired up"
  spec.description = "A Bundler plugin that generates a Ruby 4.0+ gem with what `bundle gem` gives and " \
                     "the rest: Steep and TypeProf, RuboCop and its extensions, Minitest with a 100% " \
                     "coverage gate and property tests, bundler-audit, Conventional Commits, a " \
                     "generated changelog, a Nix flake, and a release by Trusted Publishing."
  spec.homepage = "https://github.com/veralvx/veragem"
  spec.licenses = ["MIT", "Apache-2.0"]
  spec.required_ruby_version = ">= 4.0"

  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["bug_tracker_uri"] = "#{spec.homepage}/issues"
  spec.metadata["rubygems_mfa_required"] = "true"

  # What the gem ships, as git tracks it: the plugin (plugins.rb, which Bundler loads), its code and
  # signatures, the template -- its dotfiles too -- and the documents.
  spec.files = IO.popen(%w[git ls-files -z -- plugins.rb lib sig template README.md CHANGELOG.md LICENSE-*],
                        chdir: __dir__, &:read).split("\0")
  raise "veragem.gemspec: git ls-files failed: build from a git checkout" unless Process.last_status.success?

  spec.require_paths = ["lib"]
end
