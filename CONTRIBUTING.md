# Contributing to `veragem`

Thank you for considering contributing to `veragem`!

## Prerequisites

Either **Nix** -- `nix develop` gives Ruby and every tool below at the versions `flake.lock` pins
-- or, installed yourself: **Ruby 4.0** or later (with Bundler, Ruby's own), **ShellCheck**,
**shfmt**, **actionlint**, **zizmor**, **dprint**, **cocogitto** (`cog`), **git-cliff**,
**lychee**, and **Nix** for the last of `rake checks`, for `rake format` (`nix fmt`) and for the
smoke test. `bin/setup` installs the gems `Gemfile.lock` pins.

## Setup

```sh
git clone https://github.com/<you>/veragem && cd veragem
bin/setup
bundle exec rake hooks   # optional: the quick checks before a commit and a push
```

## Layout

```
plugins.rb              what Bundler loads: the `bundle veragem` command
lib/veragem.rb          Veragem.run: the command line, the project, the generation
lib/veragem/options.rb  OptionParser, git config's defaults
lib/veragem/questions.rb  a terminal's questions for what no option gives
lib/veragem/name.rb     the gem's name, checked: bundle gem's rules, what its files and tools meet
lib/veragem/citation.rb  CITATION.cff's rules: who may give its values, its title, its ORCID iD
lib/veragem/license.rb  the licence's choices, their SPDX identifiers, the one a value names
lib/veragem/summary.rb  the summary, the module's comment too: what yard-lint and RuboCop take
lib/veragem/project.rb  the values, checked, and what follows from them
lib/veragem/generator.rb  template/ written out (ERB rendered, executables marked); git
template/               the generated gem
sig/, test/, dev/smoke.sh
```

## The template

`template/` is the generated gem. A file ending `.erb` is rendered with ERB (trim mode `-`), the
project its `self` (`lib/veragem/project.rb`: `name`, `path`, `constant`, `author`, `quote`,
`nest`...); every other file is copied as is. In a path, `%name%`, `%path%` and `%underscored%`
are the project's. The command line's files are the `--exe` kind's alone, each LICENSE file its
licence's, and CITATION.cff a `--citation`'s (`Generator::EXE`, `Generator::LICENSE_FILES`,
`Generator::CITATION`). A file `Generator::EXECUTABLES` lists is executable, on the disk and in
git's index (`test/test_sync.rb` holds the list to the template's modes).

Keep a file plain unless it needs a value: a plain file is checked in place, as this repository's
own. **This repository's harness is the template's**: each plain file of `template/` is here too,
the same bytes and mode, and `test/test_sync.rb` fails on any drift -- but the files it names as
different (Dependabot's configuration, which moves both, and `.mutineer.yml`, whose ignored mutants
are the plugin's), and the command line's own (`Generator::EXE`: this gem has none), which the
smoke test's command gem checks. Change one, change both: edit the template's, then copy it here
(or the other way round).

A value written into a Ruby string goes through `quote`, which writes it as given whatever the
locale. Each value is checked first: one line of UTF-8 (`Project.check`), a gem name `bundle gem`
takes, a GitHub user GitHub takes.

## Checks

```sh
bundle exec rake          # RuboCop, Steep, the tests, yard-lint: ruby-ci.yml
bundle exec rake checks   # and bundler-audit, dprint, cog, the shell, the workflows, the links,
                          # the changed lines' mutations, the flake's checks
nix develop --command dev/smoke.sh   # the plugin end to end: smoke.yml
bundle exec rake mutation # every line of lib/ mutated: what no test catches (mutineer), minutes
bundle exec rake rubocop:changed     # RuboCop on the files changed since origin/main
bundle exec rake format   # dprint, nixfmt, shfmt and RuboCop's corrections, in place
```

`bundle exec rake -T` lists every task, and `bundle exec rake -D` describes each in full.

A warning from `lib/` or the tests fails them (`test/test_helper.rb`). One surviving mutant fails
mutineer (`.mutineer.yml`'s `threshold: 100`): `rake checks` mutates the lines changed since
`origin/main` alone, `ruby-ci.yml` every line. Each first fails on an ignore that names no mutant
(`rake mutation:ignores`). `links.yml` runs `rake links` monthly.

The tests render every kind and licence and hold what they generate: the files each holds, nothing
left unrendered, the Ruby, the YAML and the lock parsing, the executables' modes, the gemspec, the
git repository. The smoke test installs the plugin from this checkout, generates each kind, and runs
each one's `rake checks`, its git hooks on, but the links (`links.yml`'s), builds it, runs the
command's image where Docker runs, and releases the citation's, its tools the dev shell's (the
template's): a change to the template is finished when it passes. It needs the network: rubygems.org
for the gems, which it installs in a directory of its own, GitHub and Nix's cache for the flake. A
failed run keeps that directory and says where.

Coverage is measured by `rake test` alone (`.simplecov`). Some tests alone
(`bundle exec rake test N=/probe/`) fail its gate (exit 2) though they pass: Minitest's verdict is
printed above SimpleCov's. One file run alone is not measured, its warnings raised as `rake test`
raises them: `bundle exec ruby -w -Ilib -Itest -rtest_helper test/test_names.rb` (the helper first,
before the file is parsed).

## Development Workflow

[Conventional Commits](https://www.conventionalcommits.org/), enforced by `cog check` locally and
in CI; a commit's subject is its changelog entry. Read [AGENTS.md](AGENTS.md) before writing code.
Open a pull request against `main`, titled as a conventional commit, once
`bundle exec rake checks` passes, and the smoke test for a change to the template.

## Maintainers

### Going live

- Enable the repository settings the auto-merge workflow needs, listed at the top of
  `.github/workflows/dependabot-automerge.yml`, with every job of `ruby-ci.yml`, `nix.yml`,
  `smoke.yml`, `security.yml` and the style checks required.
- Enable private vulnerability reporting (Settings → Advanced Security; a public repository's
  alone).
- Enable the dependency graph there too, if it is off: `dependency-review.yml` fails without it.
- Add a pending trusted publisher on
  [RubyGems](https://rubygems.org/profile/oidc/pending_trusted_publishers) for the gem `veragem`:
  this repository, the workflow `release.yml`, the environment `release` (a publisher without one
  admits any of the workflow's jobs) -- and limit that environment's deployments to the tags `v*`
  (Settings → Environments, a rule of ref type Tag): a trusted publisher names the environment,
  not a ref, so without the rule a workflow pushed to any branch could publish. Limit who creates
  those tags too (Settings → Rules → Rulesets, a tag ruleset on `v*`): a tag pushed on any
  commit runs that commit's workflows in the environment.

### Releasing

From a clean `main`, CI green on it:

```sh
bundle exec rake changelog          # the changes the next release will list
bundle exec rake "bump[minor]"      # or major, or patch
bundle exec rake release
```

`rake bump` sets the version (`lib/veragem/version.rb`) and `CITATION.cff`'s version and date,
updates the lock, writes the changelog (git-cliff) and commits; it refuses a release with nothing in
it, a shallow clone, a clone missing the tags (`git fetch --tags`), a version bumped but not yet
released, and one already tagged. `rake release`, Bundler's own, builds the gem, tags `v<version>`
and pushes the branch and the tag; it pushes no gem. The tag runs `release.yml`: the Ruby checks
(`rake`), then the build (`gem build`, no bundle loaded) and its Sigstore attestation, the push to
RubyGems by Trusted Publishing, then the GitHub release.

Should a run fail, re-run its failed jobs, not all of them: those keep the build's gem and
digests, and RubyGems refuses a version pushed twice. If the gem reached RubyGems but its job
failed anyway, the release job cannot run: make the GitHub release as it would, from the tag, with
`--latest=false` unless it is the highest release and `--prerelease` for a pre-release:

```sh
git checkout vVERSION
gem fetch veragem --version VERSION
.github/release-notes.sh CHANGELOG.md VERSION > notes.md
gh release create vVERSION veragem-VERSION.gem --verify-tag --title vVERSION --notes-file notes.md
```

`rake release` pushes to `main` directly, and a `v*` tag: with "Require a pull request before
merging" on, the maintainer cutting it needs the rule's bypass, and the tag ruleset's leave to
create the tag. A refused push leaves the release commit and removes the tag (Bundler's doing): run
`rake release` again once allowed. An interrupted push (Ctrl-C) can keep the tag, and a second
`rake release` then pushes nothing: delete it first (`git tag -d v<version>`).

## Updating the tools

Dependabot moves the gems (`Gemfile.lock`) and the actions weekly, and the flake's inputs monthly;
`dependabot-automerge.yml` merges the minor and patch bumps once the checks pass. An action's
updates are grouped across this repository's workflows and the template's, which `test/test_sync.rb`
holds equal; a security update is not grouped: join its two pull requests. An advisory with no fixed
version yet fails `security.yml` on every pull request until weighed: its ID under `ignore:` in
`.bundler-audit.yml` (bundler-audit's own file, created then) lets the checks pass. dprint's
plugins, pinned in `dprint.json`, move by hand: `dprint config update`. A new RuboCop brings new
cops (`NewCops: enable`), a new Steep new diagnostics: read them before silencing any. A bump the
new cops fail stays unmerged: its failed run's summary holds RuboCop's safe corrections as a patch,
to `git apply` on its branch (no workflow pushes code the bumped gems wrote); what they leave is
yours to fix.
