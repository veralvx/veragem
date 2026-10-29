# veragem

A Bundler plugin that generates a Ruby gem with its toolchain wired up: the Ruby counterpart of
the [templates](https://github.com/veralvx/templates) repository's Python and Rust templates.
`bundle gem` gives a gemspec, a Rakefile, Minitest and RuboCop; `bundle veragem NAME` gives that
and the rest:

- **Ruby 4.0** or later, `required_ruby_version` and CI alike.
- **Types**: Steep checks `lib/` against the signatures in `sig/`, its strictest diagnostics on;
  TypeProf infers signatures to start them from, and its editor support is configured.
- **Lint and format**: RuboCop with every new cop, rubocop-minitest, rubocop-packaging,
  rubocop-performance and rubocop-rake; the project is indexed first (rubydex), so the cops that see
  across files do. In CI, offences are annotated on the pull request and a failed run's summary
  holds the safe corrections as a patch; a Dependabot bump the new cops fail gets them as a commit,
  then merges as any bump once you approve its runs (`rubocop-autocorrect.yml`, no token to set).
- **Documentation**: YARD, every object of `lib/` documented, held by yard-lint at 100% coverage
  (`rake yard` writes it to `doc/`).
- **Tests**: Minitest, a property test with [pbt](https://github.com/ohbarye/pbt), and SimpleCov's
  `strict` profile: every line, branch and method of `lib/` covered.
- **Security**: bundler-audit over `Gemfile.lock`, daily in CI; a pull request's new gems and
  actions reviewed for their licences and advisories (`dependency-review.yml`, advisory, as in the
  Python and Rust templates); zizmor over the workflows and Dependabot's configuration; Dependabot
  for the gems, the actions and the flake, a release proposed once a week old.
- **Commits and releases**: Conventional Commits (cocogitto, in CI and opt-in git hooks), a
  changelog written by git-cliff at each release, `rake "bump[minor]"` then Bundler's own
  `rake release`; the tag publishes to RubyGems by Trusted Publishing, no API key stored, and makes
  the GitHub release.
- **Nix**: a flake with the development shell (Ruby and every tool the checks run), the gem as a
  package (`nix build`), `nix fmt`, and checks for the Nix, the shell scripts, the workflows and
  the package. With `--exe`, `nix run` runs the command, and its OCI image (`nix build .#image`)
  is published to GHCR at each release (`image.yml`), as in the Python and Rust templates.
- dprint for the Markdown and TOML, an `.editorconfig`, the community documents (`CONTRIBUTING.md`,
  `AGENTS.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`), issue and pull request templates.

In the generated gem, `bundle exec rake` runs the Ruby checks, as CI does;
`bundle exec rake checks` runs everything CI runs.

## Install

Ruby 4.0 or later, then:

```sh
bundle plugin install veragem
```

Run outside a project, it installs for your user, and `bundle veragem` then works anywhere. From
the repository instead: `bundle plugin install veragem --git https://github.com/veralvx/veragem`
(or `--path` a local checkout).

## Usage

```sh
bundle veragem my_gem   # with a terminal for input, it asks for what no option gives
cd my_gem
bin/setup               # the gems, and Gemfile.lock written
git add .
git commit -m "chore: initial commit from veragem"
bundle exec rake checks # its tools: the generated CONTRIBUTING.md's, or `nix develop`'s
```

| Option               | Default                                     | Goes into                                       |
| -------------------- | ------------------------------------------- | ----------------------------------------------- |
| `NAME`               | --                                          | the gem, its module, its files: as `bundle gem` |
| `--[no-]exe`         | `--no-exe`: a library alone                 | a command line: `exe/NAME`, `lib/NAME/cli.rb`   |
| `--license=LICENSE`  | `dual` (MIT OR Apache-2.0)                  | `mit`, `apache` or `dual`: the gemspec, LICENSE |
| `--author=NAME`      | `git config user.name` (required)           | the gemspec, the licence's copyright line       |
| `--[no-]email=EMAIL` | `git config user.email`; `--no-email`: none | the gemspec, the code of conduct                |
| `--github=USER`      | `git config github.user` (required)         | the homepage, the repository's links            |
| `--summary=TEXT`     | `A Ruby gem.`                               | the gemspec, the README, the module's comment   |

With a terminal for input, `bundle veragem` asks for each value no option gives, the name too,
once the options are checked. A question offers its default unless veragem refuses it, Enter takes
it, and a refused answer is asked again. With other input (CI, a pipe, `< /dev/null` to skip the
questions) nothing is asked: the defaults apply, and a missing name, author or GitHub user is
refused.

The name follows `bundle gem`'s rules, lower-case: `my_gem` is `MyGem` in `lib/my_gem.rb`, `my-gem`
is `My::Gem` in `lib/my/gem.rb`. Refused before anything is written, a name:

- whose module is already defined, by Ruby, Bundler, Rake or Minitest, or by its top-level library
  where this Ruby has one (`set`, `option_parser`, `date-holidays`: Date is a class);
- whose file would shadow a library this Ruby has (`json`: lib/json.rb);
- whose module its tests or `gem build` would take for Minitest's or RubyGems' own
  (`lifecycle_hooks`, `date_like`);
- that `bundle gem` would refuse or mangle (`1gem`, `my--gem`);
- one of the Gemfile's own tools (`rubocop-rake`);
- `test_helper`, whose lib/test_helper.rb would shadow the tests', or one that would write a
  template file twice (`helper`: test/test_helper.rb);
- longer than 40 characters or deeper than 4 modules (the generated code's lines fit RuboCop's);
- with `--exe`, whose module is CLI or VERSION (`my-c_l_i`: its command line would find another
  first).

The summary is plain text: written into the README as given, Markdown in it is dprint's to check.
As `bundle gem` does, veragem makes the git repository and adds the files, and runs no
`bundle install`: `bin/setup` writes the lock, to commit. The generated `CONTRIBUTING.md` lists
the first steps: the repository's settings, RubyGems' pending trusted publisher.

## What you get

```
NAME.gemspec          the gem: its version from lib/NAME/version.rb, its files lib/, sig/, exe/
Gemfile               the gemspec, then the tools; Gemfile.lock pins them (written by bin/setup)
Rakefile              `rake`: RuboCop, Steep, the tests, yard-lint; `rake checks`: what CI runs;
                      `rake "bump[level]"`, `rake release`; `rake -T` lists them all
Steepfile, sig/       the types; typeprof.conf.jsonc, TypeProf's editor support
.rubocop.yml          RuboCop and its extensions; .yard-lint.yml, the documentation's lint
lib/, test/           starter code: typed, documented, every line and branch tested
bin/setup, bin/console
flake.nix, flake.lock the dev shell, the package (and the command's image), `nix fmt`, the checks
.githooks/            opt-in (`rake hooks`): the quick checks before a commit, Conventional Commits
cliff.toml, cog.toml  git-cliff's changelog, cocogitto's commit checks
dprint.json, .editorconfig
.github/              CI, the flake, bundler-audit, the dependency review, the release (and the
                      image), the style checks, Dependabot, its auto-merge and its bumps'
                      RuboCop corrections; issue and pull request templates
README, CONTRIBUTING, AGENTS, SECURITY, CODE_OF_CONDUCT, LICENSE-MIT / LICENSE-APACHE
```

The Gemfile leaves the development tools unconstrained: the lock pins them at the versions current
when `bin/setup` first runs, and Dependabot moves it. They need no development group: the built gem
holds neither the Gemfile nor the lock, its dependencies the gemspec's alone. The dev shell gives
Ruby and the other tools; the gems are Bundler's, from the lock CI installs from too (nixpkgs
packages few of them, and older).

## How it is verified

- The plugin's own tests (`bundle exec rake`): the name rules (`bundle gem`'s constant, as a
  property), the options, every file of each kind and licence rendered, parsed and kept executable,
  the gemspec read back, the values written as given whatever the locale.
- The harness here is the template's: this repository's Gemfile, Rakefile, workflows, hooks, flake
  and tools' configuration are the template's own files, byte for byte (`test/test_sync.rb`), so
  the template's are checked in place by this repository's checks, and a command line's own
  (`image.yml`) by the smoke test's command gem.
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

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in
the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without
any additional terms or conditions.
