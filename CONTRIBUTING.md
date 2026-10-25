# Contributing to `veragem`

Thank you for considering contributing to `veragem`!

## Prerequisites

Either **Nix** -- `nix develop` gives Ruby and every tool below at the versions `flake.lock` pins
-- or, installed yourself: **Ruby 4.0** or later (with Bundler, Ruby's own), **ShellCheck**,
**shfmt**, **actionlint**, **dprint**, **cocogitto** (`cog`), **git-cliff**, and **Nix** for the
last of `rake checks`. `bin/setup` installs the gems `Gemfile.lock` pins.

## Setup

```sh
git clone https://github.com/<you>/veragem && cd veragem
bin/setup
bundle exec rake hooks   # optional: the quick checks before a commit, Conventional Commits
```

## Layout

```
plugins.rb              what Bundler loads: the `bundle veragem` command
lib/veragem.rb          Veragem.run: the command line, the project, the generation
lib/veragem/options.rb  OptionParser, git config's defaults
lib/veragem/name.rb     the gem's name, checked: bundle gem's rules, what its files and tools meet
lib/veragem/project.rb  the values, checked, and what follows from them
lib/veragem/generator.rb  template/ written out: ERB rendered, the rest copied, modes kept; git
template/               the generated gem
sig/, test/, dev/smoke.sh
```

## The template

`template/` is the generated gem. A file ending `.erb` is rendered with ERB (trim mode `-`), the
project its `self` (`lib/veragem/project.rb`: `name`, `path`, `constant`, `author`, `quote`,
`nest`...); every other file is copied as is. In a path, `%name%`, `%path%` and `%underscored%`
are the project's. The command line's files are the `--exe` kind's alone, and each LICENSE file its
licence's (`Generator::EXE`, `Generator::LICENSE_FILES`).

Keep a file plain unless it needs a value: a plain file is checked in place, as this repository's
own. **This repository's harness is the template's**: each plain file of `template/` is here too,
the same bytes and mode, and `test/test_sync.rb` fails on any drift -- but the files it names as
different (Dependabot's configuration, which moves both), and the command line's own
(`Generator::EXE`: this gem has none), which the smoke test's command gem checks. Change one,
change both: edit the template's, then copy it here (or the other way round).

A value written into a Ruby string goes through `quote`, which writes it as given whatever the
locale. Each value is checked first: one line of UTF-8 (`Project#text`), a gem name `bundle gem`
takes, a GitHub user GitHub takes.

## Checks

```sh
bundle exec rake          # RuboCop, Steep, the tests: ruby-ci.yml
bundle exec rake checks   # and bundler-audit, dprint, cog, the shell, actionlint, the flake's checks
nix develop --command dev/smoke.sh   # the plugin end to end: smoke.yml
```

The tests render every kind and licence and hold what they generate: the files each holds, nothing
left unrendered, each file parsing, the executables' modes, the gemspec, the git repository. The
smoke test installs the plugin from this checkout, generates each kind, and runs each one's `rake
checks` and build, its tools the dev shell's -- the template's: a change to the template is
finished when it passes. It needs the network: rubygems.org for the gems, GitHub and Nix's cache
for the flake.

## Development Workflow

[Conventional Commits](https://www.conventionalcommits.org/), enforced by `cog check` locally and
in CI; a commit's subject is its changelog entry. Read [AGENTS.md](AGENTS.md) before writing code.
Open a pull request against `main`, titled as a conventional commit, once `bundle exec rake
checks` and the smoke test pass.

## Maintainers

### Going live

- Enable the repository settings the auto-merge workflow needs, listed at the top of
  `.github/workflows/dependabot-automerge.yml`, with every job of `ruby-ci.yml`, `nix.yml`, `smoke.yml`
  and the style checks required.
- Enable private vulnerability reporting (Settings → Advanced Security; a public repository's alone).
- Enable the dependency graph there too, if it is off: `dependency-review.yml` fails without it.
- Add a pending trusted publisher on
  [RubyGems](https://rubygems.org/profile/oidc/pending_trusted_publishers) for the gem `veragem`:
  this repository, the workflow `release.yml`, the environment `release`; if you limit that
  environment's deployments, admit the tags `v*`.

### Releasing

From a clean `main`, CI green on it:

```sh
bundle exec rake changelog          # the changes the next release will list
bundle exec rake "bump[minor]"      # or major, or patch; the first keeps the version declared
bundle exec rake release
```

`rake bump` sets the version, updates the lock, writes the changelog (git-cliff) and commits;
`rake release`, Bundler's own, tags `v<version>` and pushes the branch and the tag. The tag runs
`release.yml`: the checks and the build, the push to RubyGems by Trusted Publishing, then the
GitHub release.
