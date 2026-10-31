# frozen_string_literal: true

# `rake` runs the Ruby checks, as ruby-ci.yml does; `rake checks` runs everything CI runs.
# `rake -T` lists the tasks.

require "bundler/audit/task"
require "bundler/gem_tasks"
require "json"
require "minitest/test_task"
require "rubocop/rake_task"
require "steep/rake_task"
require "yard"

Minitest::TestTask.create
RuboCop::RakeTask.new
Steep::RakeTask.new
Bundler::Audit::Task.new

# `rake yard`: lib/'s documentation, in doc/. Not sig/'s: YARD's RBS reader refuses a signature
# over several lines.
YARD::Rake::YardocTask.new { it.files = ["lib/**/*.rb"] }

task default: %i[rubocop steep test yard_lint]

# Steep, against sig/, is the gate. TypeProf reads Ruby's core signatures alone, not the standard
# library's.
desc "Print the signatures TypeProf infers from lib/, to start sig/ from, and what it finds amiss"
task :typeprof do
  sh "typeprof", "--show-errors", "lib"
end

# yard graph draws what yardoc records (.yardoc): lib/'s, quietly, so the graph alone is printed, and
# its private methods too (no .yardopts, whose query keeps the public API)
desc "Print lib/'s classes and modules as a Graphviz graph (yard graph), for `dot`"
task :graph do
  sh "yard", "doc", "-n", "-q", "--no-stats", "--no-yardopts", "lib/**/*.rb"
  sh "yard", "graph", "--protected", "--private", "--full", "--dependencies"
end

# Every test file, as mutineer pairs a source with its tests by name alone; SimpleCov off, as a
# mutant runs only the tests that reach it (test_helper.rb).
desc "Mutate lib/ and run the tests against each change: what none catches (mutineer, .mutineer.yml)"
task :mutation do
  tests = FileList["test/test_*.rb"].exclude("test/test_helper.rb").flat_map { ["--test", it] }
  sh({ "MUTATION" => "1" }, "mutineer", "run", *FileList["lib/**/*.rb"], *tests)
end

desc "Lint the YARD documentation of lib/ (yard-lint, .yard-lint.yml)"
task :yard_lint do
  sh "yard-lint", "lib", "--stats"
end

desc "Update the advisory database, then check Gemfile.lock against it (bundler-audit)"
task audit: %w[bundle:audit:update bundle:audit:check]

desc "Check the Markdown and TOML format (dprint)"
task :dprint do
  sh "dprint", "check"
end

desc "Check that every commit is a Conventional Commit (cocogitto)"
task :cog do
  sh "cog", "check"
end

# A command's standard output, as UTF-8 whatever the locale (git-cliff's commits, their authors' names);
# its failure fails the task, as `sh`'s does.
def output(*command)
  IO.popen(command, external_encoding: Encoding::UTF_8, &:read).tap do
    raise "#{command.join(" ")} failed" unless Process.last_status.success?
  end
end

desc "Lint and check the format of the shell scripts git tracks (shellcheck, shfmt)"
task :shell do
  tracked = output("git", "ls-files", "-z").split("\0").select { File.file?(it) }
  scripts = output("shfmt", "--find", *tracked).lines(chomp: true)
  sh "shellcheck", *scripts
  sh "shfmt", "--diff", *scripts
end

desc "Lint the workflows and audit their security (actionlint, zizmor)"
task :workflows do
  sh "actionlint"
  sh "zizmor", "--offline", "--quiet", "--strict-collection", "."
end

desc "Run the flake's checks: the Nix format, the shell, the workflows, the package (git's files alone)"
task :nix do
  sh "nix", "flake", "check"
end

desc "Run every check CI runs"
task checks: %i[default audit dprint cog shell workflows nix]

desc "Format the Ruby, the Markdown and TOML, and the Nix (modifies files)"
task format: "rubocop:autocorrect" do
  sh "dprint", "fmt"
  sh "nix", "fmt"
end

desc "Use .githooks/: the quick checks before a commit, Conventional Commits for every message"
task :hooks do
  sh "git", "config", "core.hooksPath", ".githooks"
end

gemspec = Bundler::GemHelper.gemspec
# git-cliff's compare links: the repository, owner/name
repository = gemspec.metadata.fetch("source_code_uri").delete_prefix("https://github.com/")
cliff = ["git-cliff", "--offline", "--github-repo", repository]

desc "Preview the changelog's next section"
task :changelog do
  sh(*cliff, "--unreleased")
end

# The version to release: the declared one at the first release (no tag yet), else +level+'s
# number bumped (0 major, 1 minor, 2 patch), those after it zeroed.
def next_version(current, level)
  abort "error: #{current} is not MAJOR.MINOR.PATCH" unless current.match?(/\A\d+\.\d+\.\d+\z/)
  return current if output("git", "tag", "--list", "v[0-9]*").empty?

  parts = current.split(".").map(&:to_i)
  parts[level] += 1
  parts.fill(0, level + 1).join(".")
end

# CITATION.cff, where the gem has one (bundle veragem --citation): its text with the release's version
# and date, or nil; read as UTF-8, as written, whatever the locale.
def cited(version)
  return unless File.exist?("CITATION.cff")

  released = { "version" => version, "date-released" => Time.now.strftime("%F") }
  released.reduce(File.read("CITATION.cff", encoding: Encoding::UTF_8)) do |cff, (key, value)|
    abort "error: CITATION.cff has no #{key}: line" unless cff.match?(/^#{key}: /)

    cff.sub(/^#{key}: .*$/, %(#{key}: "#{value}"))
  end
end

# The release commit: the version, the lock, the changelog, and CITATION.cff's version and date.
desc "Bump the version (major, minor or patch), write the changelog and commit"
task :bump, [:level] => "release:guard_clean" do |_, args|
  level = %w[major minor patch].index(args[:level]) or abort 'usage: rake "bump[major|minor|patch]"'
  current = gemspec.version.to_s
  version = next_version(current, level)
  tagged = system("git", "rev-parse", "--quiet", "--verify", "refs/tags/v#{version}", out: File::NULL)
  abort "error: v#{version} is already tagged" if tagged
  entries = JSON.parse(output(*cliff, "--unreleased", "--context")).sum { it["commits"].size }
  abort "error: nothing to release: no commit since the last tag enters the changelog" if entries.zero?

  file = "lib/#{gemspec.name.tr("-", "/")}/version.rb"
  abort "error: #{file} declares no \"#{current}\"" unless File.read(file).include?(%("#{current}"))
  citation = cited(version)
  first = !File.exist?("CHANGELOG.md")
  begin
    File.write(file, File.read(file).sub(%("#{current}"), %("#{version}")))
    File.write("CITATION.cff", citation) if citation
    sh "bundle", "lock"
    sh(*cliff, "--tag", "v#{version}", "--output", "CHANGELOG.md")
    sh "git", "add", file, "Gemfile.lock", "CHANGELOG.md", *("CITATION.cff" if citation)
    sh "git", "commit", "--message", "chore(release): v#{version}"
  rescue StandardError, Interrupt
    # The tracked files were committed (release:guard_clean): put back what this changed.
    sh "git", "reset", "--hard", "--quiet"
    rm_f "CHANGELOG.md" if first
    raise
  end
  puts "v#{version} committed: `rake release` tags and pushes it, then release.yml publishes the tag."
end

# The gem is published by release.yml, on the tag, through RubyGems' Trusted Publishing:
# `rake release` builds it, tags v<version> and pushes the branch and the tag, and pushes no gem.
Rake::Task["release"].clear_comments
Rake::Task["release"].add_description("Tag v#{gemspec.version}, push the branch and the tag: release.yml publishes it")
Rake::Task["release:rubygem_push"].clear_actions
desc "Push no gem: release.yml publishes the tag"
task "release:rubygem_push" do
  puts "release.yml publishes v#{gemspec.version} to RubyGems."
end
