# veragem

`bundle veragem NAME`: a new Ruby gem with its whole toolchain wired up. A Bundler plugin, the
Ruby counterpart of the [templates](https://github.com/veralvx/templates) repository's Python and
Rust templates.

`bundle gem` gives a gemspec, a Rakefile, Minitest and RuboCop. veragem gives that and the rest:

- **Ruby 4.0** or later, `required_ruby_version` and CI alike.
- **Types**: Steep checks `lib/` against the signatures in `sig/`, its strictest diagnostics on;
  TypeProf infers signatures to start them from, and its editor support is configured.
- **Lint and format**: RuboCop, every new cop on, with rubocop-minitest, rubocop-performance and
  rubocop-rake.
- **Tests**: Minitest, a property test with [pbt](https://github.com/ohbarye/pbt), and SimpleCov's
  `strict` profile: every line, branch and method of `lib/` covered.
- **Security**: bundler-audit over `Gemfile.lock`, daily in CI; Dependabot for the gems, the
  actions and the flake.
- **Commits and releases**: Conventional Commits (cocogitto, CI and opt-in git hooks), a changelog
  written by git-cliff at each release, `rake "bump[minor]"` then Bundler's own `rake release`; the
  tag publishes to RubyGems by Trusted Publishing -- no API key stored -- and makes the GitHub
  release.
- **Nix**: a flake with the development shell (Ruby and every tool the checks run), `nix fmt`, and
  checks for the Nix, the shell scripts and the workflows.
- dprint for the Markdown and TOML, an `.editorconfig`, the community documents (`CONTRIBUTING.md`,
  `AGENTS.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`), issue and pull request templates.

`bundle exec rake` runs the Ruby checks, as CI does; `bundle exec rake checks` runs everything CI
runs.

## Install

```sh
bundle plugin install veragem
```

Run outside a project, it installs for your user, and `bundle veragem` then works anywhere. From
a clone instead: `bundle plugin install veragem --git https://github.com/veralvx/veragem` (or
`--path` a local checkout).

## Usage

```sh
bundle veragem my_gem
cd my_gem
bin/setup
git commit -m "chore: initial commit from veragem"
bundle exec rake checks
```

| Option              | Default                             | Goes into                                       |
| ------------------- | ----------------------------------- | ----------------------------------------------- |
| `NAME`              | --                                  | the gem, its module, its files: as `bundle gem` |
| `--exe`             | a library alone                     | a command line: `exe/NAME`, `lib/NAME/cli.rb`   |
| `--license=LICENSE` | `dual` (MIT OR Apache-2.0)          | `mit`, `apache` or `dual`: the gemspec, LICENSE |
| `--author=NAME`     | `git config user.name` (required)   | the gemspec, the licence's copyright line       |
| `--email=EMAIL`     | `git config user.email` (optional)  | the gemspec, the code of conduct                |
| `--github=USER`     | `git config github.user` (required) | the homepage, the repository's links            |
| `--summary=TEXT`    | `A Ruby gem.`                       | the gemspec, the README, the module's comment   |

The name follows `bundle gem`'s rules, lower-case: `my_gem` is `MyGem` in `lib/my_gem.rb`,
`my-gem` is `My::Gem` in `lib/my/gem.rb`. A name whose module is already defined (`set`), or that
`bundle gem` would mangle (`1gem`, `my--gem`), or one of the Gemfile's own tools (`rake`), is
refused before anything is written. The summary is plain text: written into the README as given,
Markdown in it is dprint's to check. As `bundle
gem` does, it makes the git repository and adds the files, and runs no `bundle install`:
`bin/setup` writes the lock, to commit. The generated `CONTRIBUTING.md` lists the first steps: the
repository's settings, RubyGems' pending trusted publisher.

## What you get

```
NAME.gemspec          the gem: its version from lib/NAME/version.rb, its files lib/, sig/, exe/
Gemfile               the gemspec, then the tools; Gemfile.lock pins them (written by bin/setup)
Rakefile              `rake`: RuboCop, Steep, the tests; `rake checks`: what CI runs;
                      `rake "bump[level]"`, `rake release`; `rake -T` lists them all
Steepfile, sig/       the types; typeprof.conf.jsonc, TypeProf's editor support
.rubocop.yml          RuboCop and its extensions
lib/, test/           starter code: typed, documented, every line and branch tested
bin/setup, bin/console
flake.nix, flake.lock the dev shell, `nix fmt`, the checks that need no gem
.githooks/            opt-in (`rake hooks`): the quick checks before a commit, Conventional Commits
cliff.toml, cog.toml  git-cliff's changelog, cocogitto's commit checks
dprint.json, .editorconfig
.github/              CI, the flake, bundler-audit, the release, the style checks, Dependabot and
                      its auto-merge; issue and pull request templates
README, CONTRIBUTING, AGENTS, SECURITY, CODE_OF_CONDUCT, LICENSE-MIT / LICENSE-APACHE
```

The development tools are unconstrained in the Gemfile: the lock pins them, at the versions current
when `bin/setup` first runs, and Dependabot moves it.

## How it is verified

- The plugin's own tests (`bundle exec rake`): the name rules (`bundle gem`'s constant, as a
  property), the options, every file of each kind and licence rendered, parsed and kept executable,
  the gemspec read back, the values written as given whatever the locale.
- The harness here is the template's: this repository's Gemfile, Rakefile, workflows, hooks, flake
  and tools' configuration are the template's own files, byte for byte (`test/test_sync.rb`), so
  the template's are checked in place by this repository's checks.
- The smoke test (`dev/smoke.sh`, `smoke.yml`, weekly too): the plugin installed from this checkout
  generates a gem of each kind and licence, and each passes its own `rake checks` and builds.

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) (the tools, the checks, the template, the release),
[AGENTS.md](AGENTS.md) (the rules), [SECURITY.md](SECURITY.md),
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
  <http://www.apache.org/licenses/LICENSE-2.0>)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or <http://opensource.org/licenses/MIT>)

at your option.

The generated gems are yours: their licence is the one you choose at generation.
