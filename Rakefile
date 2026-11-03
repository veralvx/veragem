# frozen_string_literal: true

# `rake` runs the Ruby checks, as ruby-ci.yml does; `rake checks` runs CI's checks, the links too
# (links.yml's, monthly), but mutates the changed lines alone (ruby-ci.yml: every line).
# `rake -T` lists the tasks.

require "bundler/audit/task"
require "bundler/gem_tasks"
require "csv"
require "json"
require "minitest/test_task"
require "rubocop/rake_task"
require "steep/rake_task"
require "yard"

# Coverage, `rake test`'s alone: started in the tests' process before they load lib/ (.simplecov);
# then the helper, whatever order the test files load in (shuffled): one loaded before it would only
# print its parse-time warnings
TEST_TASK = Minitest::TestTask.create do
  self.test_prelude = %(require "simplecov"; SimpleCov.start; require "test_helper")
end
RuboCop::RakeTask.new
Steep::RakeTask.new
Bundler::Audit::Task.new

# `rake yard`: lib/'s documentation, in doc/. Not sig/'s: YARD's RBS reader refuses a signature
# over several lines.
YARD::Rake::YardocTask.new { it.files = ["lib/**/*.rb"] }

task default: %i[rubocop steep steep:typed test yard_lint]

# A command's standard output, as UTF-8 whatever the locale (git-cliff's commits, their authors' names);
# its failure fails the task, as `sh`'s does.
def output(*command)
  IO.popen(command, external_encoding: Encoding::UTF_8, &:read).tap do
    raise "#{command.join(" ")} failed" unless Process.last_status.success?
  end
end

# The files git tracks, those still on disk
def tracked = output("git", "ls-files", "-z").split("\0").select { File.file?(it) }

# git's shell scripts, by name or shebang (shfmt --find)
def scripts = output("shfmt", "--find", *tracked).lines(chomp: true)

# A call is untyped where its receiver is: steep check passes it, and a steep:ignore leaves it so.
# steep stats counts them, exiting 0 whatever it counts; a file it cannot type (status error, as a
# syntax error, which strict steep check reports as information) it counts as none.
desc "Check that Steep types each call of lib/. steep stats counts the untyped calls"
task "steep:typed" do
  stats = CSV.parse(output("steep", "stats", "--format=csv"), headers: true)
  failed = stats.filter_map do |row|
    next "#{row["File"]}: not typed (#{row["Status"]})" unless row["Status"] == "success"

    "#{row["File"]}: #{row["Untyped calls"]} untyped" unless row["Untyped calls"] == "0"
  end
  abort "error: calls Steep does not type:\n#{failed.join("\n")}" unless failed.empty?
end

# Steep, against sig/, is the gate. TypeProf reads Ruby's core signatures alone, not the standard
# library's.
desc "Print the signatures TypeProf infers. It reads lib/, to start sig/ from, and prints what it finds amiss"
task :typeprof do
  sh "typeprof", "--show-errors", "lib"
end

# yard graph draws what yardoc records (.yardoc): lib/'s, quietly, so the graph alone is printed, and
# its private methods too (no .yardopts, whose query keeps the public API)
desc "Print lib/'s classes and modules as a graph. yard graph writes it for Graphviz's `dot`"
task :graph do
  sh "yard", "doc", "-n", "-q", "--no-stats", "--no-yardopts", "lib/**/*.rb"
  sh "yard", "graph", "--protected", "--private", "--full", "--dependencies"
end

# Every test file `rake test` runs (its globs) but test_helper.rb, which every test requires and holds
# none: mutineer pairs lib/a/b.rb with one test file by its path (test/a/test_b.rb), and a test may
# reach any file.
def mutate(*options)
  tests = FileList[*TEST_TASK.test_globs].exclude("test/test_helper.rb").uniq.flat_map { ["--test", it] }
  sh "mutineer", "run", *options, *FileList["lib/**/*.rb"], *tests
end

# An ignore whose mutant is gone (its method changed or moved) hides nothing and goes stale: migrate
# --dry-run names each and fails, writing nothing; it counts an ignored copy mutineer drops as used.
desc "Check that each ignore of .mutineer.yml names a mutant of lib/. mutineer migrate --dry-run"
task "mutation:ignores" do
  sh "mutineer", "migrate", "--dry-run", *FileList["lib/**/*.rb"]
end

desc "Mutate lib/ against the tests. A change none catches fails it (mutineer, .mutineer.yml)"
task(mutation: "mutation:ignores") { mutate }

# The lines changed since the branch left origin/main, uncommitted ones too, and every line of a file
# git does not track (a new one before `git add`), unless git ignores it; every line where there is
# no origin/main (a gem never pushed)
desc "Mutate lib/'s lines changed since origin/main. `rake mutation` mutates all of them"
task "mutation:changed" => "mutation:ignores" do
  base = IO.popen(%w[git merge-base HEAD origin/main], err: File::NULL, &:read).chomp
  mutate(*(["--since", base, "--allow-empty"] unless base.empty?))
end

desc "Lint lib/'s YARD documentation with yard-lint. Its rules: .yard-lint.yml"
task :yard_lint do
  sh "yard-lint", "lib", "--stats"
end

desc "Update the advisories, check Gemfile.lock. bundler-audit fetches its database, then checks the lock"
task audit: %w[bundle:audit:update bundle:audit:check]

desc "Check the Markdown and TOML format (dprint)"
task :dprint do
  sh "dprint", "check"
end

desc "Check every commit message with cocogitto. Each must be a Conventional Commit"
task :cog do
  sh "cog", "check"
end

desc "Lint and format-check the shell scripts. It checks those git tracks, with shellcheck and shfmt"
task :shell do
  files = scripts
  sh "shellcheck", *files
  sh "shfmt", "--diff", *files
end

desc "Lint the workflows, audit their security. It runs actionlint and zizmor"
task :workflows do
  sh "actionlint"
  sh "zizmor", "--offline", "--quiet", "--strict-collection", "."
end

desc "Run the flake's checks. They check the Nix format, the shell, the workflows and the package (git's files)"
task :nix do
  sh "nix", "flake", "check"
end

desc "Run CI's checks, mutating the changed lines. It checks the links too; CI mutates every line"
task checks: %i[default audit dprint cog shell workflows links mutation:changed nix]

# RuboCop last: it fails on an offense it cannot correct, after the others have formatted
desc "Format the Markdown, TOML, Nix, shell and Ruby files. It rewrites them in place"
task :format do
  sh "dprint", "fmt"
  sh "nix", "fmt"
  sh "shfmt", "--write", *scripts
  Rake::Task["rubocop:autocorrect"].invoke
end

desc "Use .githooks/ for git's hooks. They run the quick checks before a commit, and check that every " \
     "message is a Conventional Commit"
task :hooks do
  sh "git", "config", "core.hooksPath", ".githooks"
end

gemspec = Bundler::GemHelper.gemspec
# git-cliff's compare links: the repository, owner/name
repository = gemspec.metadata.fetch("source_code_uri").delete_prefix("https://github.com/")
cliff = ["git-cliff", "--offline", "--github-repo", repository]

# Online, a link that passed cached a day (.lycheecache); a refused connection or a 429 retried at
# least 10 s apart, so a brief outage is waited out. Not the tests' links, made up; nor GitHub's
# bare address, read off those the code builds; nor the gem's own pages, missing until it is pushed
# and published.
desc "Check the links in git's files with lychee. Not the tests', whose links are made up"
task :links do
  files = tracked.grep_v(%r{\Atest/})
  own = [gemspec.homepage, "https://rubygems.org/gems/#{gemspec.name}", "https://rubydoc.info/gems/#{gemspec.name}"]
  skip = ["^#{Regexp.escape("https://github.com/")}$", "^(#{own.map { Regexp.escape(it) }.join("|")})($|/)"]
  sh "lychee", "--no-progress", "--cache", "--retry-wait-time", "10", *skip.flat_map { ["--exclude", it] }, *files
end

desc "Preview the changelog's next section"
task :changelog do
  sh(*cliff, "--unreleased")
end

# The release tags, refused where they do not tell the releases: a shallow clone, or a clone without
# them that has a CHANGELOG.md
def release_tags
  if output("git", "rev-parse", "--is-shallow-repository") == "true\n"
    abort "error: a shallow clone, which the changelog cannot be written from: git fetch --unshallow"
  end
  tags = output("git", "tag", "--list", "v[0-9]*").lines(chomp: true)
  return tags unless tags.empty? && File.exist?("CHANGELOG.md")

  abort "error: a CHANGELOG.md but no v* tag: git fetch --tags, or release the version bumped first"
end

# The version to release: the declared one at the first release (no tag yet), else +level+'s
# number bumped (0 major, 1 minor, 2 patch), those after it zeroed. The current version must be
# tagged: else it was bumped and never released.
def next_version(current, level)
  abort "error: #{current} is not MAJOR.MINOR.PATCH" unless current.match?(/\A\d+\.\d+\.\d+\z/)
  tags = release_tags
  return current if tags.empty?

  abort "error: v#{current} is not tagged: git fetch --tags, or release it first" unless tags.include?("v#{current}")

  parts = current.split(".").map(&:to_i)
  parts[level] += 1
  parts.fill(0, level + 1).join(".")
end

# CITATION.cff, where the gem has one (bundle veragem --citation): its text with the release's version
# and date, or nil; read as UTF-8, as written, whatever the locale. The date is UTC's, as the
# changelog's (git-cliff's `date` filter).
def cited(version)
  return unless File.exist?("CITATION.cff")

  released = { "version" => version, "date-released" => Time.now.utc.strftime("%F") }
  released.reduce(File.read("CITATION.cff", encoding: Encoding::UTF_8)) do |cff, (key, value)|
    abort "error: CITATION.cff has no #{key}: line" unless cff.match?(/^#{key}: /)

    cff.sub(/^#{key}: [^\r\n]*/, %(#{key}: "#{value}"))
  end
end

# The release commit: the version, the lock, the changelog, and CITATION.cff's version and date.
desc "Bump the version, write the changelog, commit. The level is major, minor or patch; a first release " \
     "keeps the declared version"
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
Rake::Task["release"].add_description("Tag v#{gemspec.version}, push the branch and the tag. release.yml publishes it")
Rake::Task["release:rubygem_push"].clear_actions
desc "Push no gem: release.yml publishes the tag"
task "release:rubygem_push" do
  puts "release.yml publishes v#{gemspec.version} to RubyGems."
end
