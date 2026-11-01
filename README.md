# veragem

A Bundler plugin that generates a Ruby gem with its toolchain wired up: the Ruby counterpart of
the [templates](https://github.com/veralvx/templates) repository's Python and Rust templates.
`bundle gem` gives a gemspec, a Rakefile, Minitest and RuboCop; `bundle veragem NAME` gives that
and the rest:

- **Ruby 4.0** or later, `required_ruby_version` and CI alike, on Linux, macOS and Windows:
  Gemfile.lock holds Windows' platform (`bin/setup`), `.gitattributes` keeps every text file LF,
  and the executables' mode is in git's index, which a commit keeps where the file system has none.
- **Types**: Steep checks `lib/` against the signatures in `sig/`, its strictest diagnostics on;
  TypeProf infers signatures to start them from, and its editor support is configured.
- **Lint and format**: RuboCop with every new cop, rubocop-minitest, rubocop-packaging,
  rubocop-performance and rubocop-rake; the project is indexed first (rubydex), so the cops that see
  across files do. In CI, offences are annotated on the pull request and a failed run's summary
  holds the safe corrections as a patch, to `git apply`: a Dependabot bump the new cops fail stays
  unmerged until you apply it, no workflow pushing code the bumped gems wrote.
- **Documentation**: YARD, every public object of `lib/` documented, held by yard-lint at 100%
  coverage (`rake yard` writes it to `doc/`).
- **Tests**: Minitest, a property test with [pbt](https://github.com/ohbarye/pbt), and SimpleCov's
  `strict` profile: every line, branch and method of `lib/` covered; a warning from `lib/` or the
  tests fails them. [mutineer](https://github.com/davidteren/mutineer) mutates `lib/`, and one
  mutant no test catches fails it: `rake checks` the lines changed since `origin/main`, CI every
  line (`rake mutation`).
- **Links**: lychee checks the links of the files git tracks (`rake links`), in `rake checks` and
  monthly (`links.yml`).
- **Security**: bundler-audit over `Gemfile.lock`, daily and on every pull request; a pull request's
  new gems and actions reviewed for their licences and advisories (`dependency-review.yml`,
  advisory, as in the Python and Rust templates); zizmor over the workflows and Dependabot's
  configuration; Dependabot for the gems, the actions and the flake, a release proposed once a week
  old.
- **Commits and releases**: Conventional Commits (cocogitto, in CI and opt-in git hooks), a
  changelog written by git-cliff at each release, `rake "bump[minor]"` then Bundler's own
  `rake release`; the tag publishes to RubyGems by Trusted Publishing, no API key stored, the gem
  built apart from the tools' gems and signed (its Sigstore attestation, RubyGems' provenance), and
  makes the GitHub release.
- **Nix**: a flake with the development shell (Ruby and every tool the checks run), the gem as a
  package (`nix build`), `nix fmt`, and checks for the Nix, the shell scripts, the workflows and
  the package. With `--exe`, `nix run` runs the command, and its OCI image (`nix build .#image`)
  is published to GHCR at each release (`image.yml`), as in the Python and Rust templates.
- dprint for the Markdown and TOML, an `.editorconfig`, the community documents (`CONTRIBUTING.md`,
  `AGENTS.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`), issue and pull request templates.

In the generated gem, `bundle exec rake` runs the Ruby checks, as CI does;
`bundle exec rake checks` runs CI's checks, the links too, but mutates the changed lines alone.

## Install

Ruby 4.0 or later and git, then:

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

| Option                     | Default                                     | Goes into                                              |
| -------------------------- | ------------------------------------------- | ------------------------------------------------------ |
| `NAME`                     | --                                          | the gem, its module, its files: as `bundle gem`        |
| `--[no-]exe`               | `--no-exe`: a library alone                 | a command line: `exe/NAME`, `lib/NAME/cli.rb`          |
| `--license=LICENSE`        | `dual` (MIT OR Apache-2.0)                  | `mit`, `apache` or `dual`: the gemspec, LICENSE        |
| `--author=NAME`            | `git config user.name` (required)           | the gemspec, the licence's copyright line              |
| `--[no-]email=EMAIL`       | `git config user.email`; `--no-email`: none | the gemspec, the code of conduct                       |
| `--github=USER`            | `git config github.user` (required)         | the homepage, the repository's links                   |
| `--summary=TEXT`           | `A Ruby gem.`                               | the gemspec, the README, the module's comment          |
| `--[no-]citation`          | `--no-citation`                             | `CITATION.cff`: GitHub's "Cite this repository"        |
| `--family-names=NAMES`     | (required with `--citation`)                | with `--citation`: the author's, `CITATION.cff`        |
| `--[no-]given-names=NAMES` | optional; `--no-given-names`: none          | with `--citation`: the author's, `CITATION.cff`        |
| `--[no-]alias=ALIAS`       | optional; `--no-alias`: none                | with `--citation`: the author's handle, `CITATION.cff` |
| `--orcid=ID`               | optional                                    | with `--citation`: the author's ORCID iD               |
| `--keywords=LIST`          | optional                                    | with `--citation`: keywords, comma-separated           |

With a terminal for input, `bundle veragem` asks for each value no option gives, the name too,
once the options are checked. A question offers its default unless veragem refuses it, Enter takes
it, an optional one takes `-` for none, and a refused answer is asked again. `-` is no option's
value, as no answer can give it: `--no-email`, `--no-given-names` and `--no-alias` give none, and
an `--orcid` or `--keywords` left out does. With other input (CI, a pipe, `< /dev/null` to skip
the questions) nothing is asked: the defaults apply, and a missing name, author, GitHub user or,
with `--citation`, family names is refused.

`CITATION.cff` (Citation File Format 1.2.0) is for software meant to be cited, research's: GitHub
offers its "Cite this repository", and Zenodo, once the repository is enabled there (the generated
CONTRIBUTING.md's first steps), archives each release with its values and gives it a DOI. Its
author is a person, family names required, given names, alias, ORCID iD and keywords optional.
Asked at a terminal, the family names offer the author's last word, the given names the words before
the family names, where the author ends with them, and the alias, asked last, the GitHub user. That
user may be an organization, so it is only offered: without a terminal, there is no alias unless
`--alias` gives one. Its values need a citation: without one they are refused, and at a terminal
its question takes y alone.

It holds what GitHub and Zenodo read, written as Zenodo's import takes it, narrower than CFF:

- one licence as its SPDX identifier, and none for `dual`: CFF writes an OR as a list, and Zenodo
  refuses the whole file for one ([zenodo/zenodo#2515](https://github.com/zenodo/zenodo/issues/2515)),
  so it takes the licence GitHub detects instead -- Apache-2.0 for veragem's own two files today,
  CC-BY-4.0 where GitHub detects none -- and the record's licences are yours to correct;
- an ORCID iD Zenodo's check takes, its check digit and its block ORCID's, written as its URL;
- names without a comma: Zenodo reads one as the end of the family names (`Smith, Jr.`); an alias
  may hold one, as Zenodo reads no alias;
- a name of 3 characters or more, Zenodo's least title;
- the repository, RubyGems' page as its artifact, and its API documentation on rubydoc.info as
  its URL (there from the first release); no email (CFF's pattern is stricter than veragem's);
- its DOIs commented out, the concept DOI and a version's, to uncomment once Zenodo gives them
  after a release.

`rake bump` sets its version and date at each release, and `nix flake check` validates it against
CFF's schema (cffconvert): a check of the schema alone, which passes files Zenodo's import refuses.

The name follows `bundle gem`'s rules, lower-case: `my_gem` is `MyGem` in `lib/my_gem.rb`, `my-gem`
is `My::Gem` in `lib/my/gem.rb`. Refused before anything is written, a name:

- whose module is already defined, by Ruby, Bundler, Rake or Minitest, or by its top-level library
  where this Ruby has one (`set`, `option_parser`, `date-holidays`: Date is a class);
- whose file would shadow a library this Ruby has (`json`: lib/json.rb);
- whose module its tests or `gem build` would take for Minitest's or RubyGems' own
  (`lifecycle_hooks`, `date_like`);
- that `bundle gem` would refuse or mangle (`1gem`, `my--gem`);
- a gem the Gemfile's tools load, theirs included (`rubocop-rake`, `parser`): the tools' bundle
  would resolve it to the new gem;
- `test_helper`, whose lib/test_helper.rb would shadow the tests', or one that would write a
  template file twice (`helper`: test/test_helper.rb);
- longer than 40 characters or deeper than 4 modules (the generated code's lines fit RuboCop's);
- with `--exe`, whose module is CLI or VERSION (`my-c_l_i`: its command line would find another
  first).

The summary is plain text: written into the README as given, Markdown in it is dprint's to check.
It is the module's comment too, so one the gem's yard-lint or RuboCop would not take as its
documentation is refused: a tag first, YARD's (`@param`, `(see`) or written informally (`Note:`,
`See also:`), a RuboCop annotation (`HACK:`, `review the code`), a magic comment (`encoding:`), a
backtick or `**` left open.

As `bundle gem` does, veragem makes the git repository and adds the files, and runs no
`bundle install`: `bin/setup` writes the lock, to commit. The generated `CONTRIBUTING.md` lists
the first steps: the repository's settings, RubyGems' pending trusted publisher.

## What you get

```
NAME.gemspec          the gem: its version from lib/PATH/version.rb (`my-gem`'s lib/my/gem/), its
                      files lib/, sig/, exe/
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
                      image), the style checks, Dependabot and its auto-merge; issue and pull
                      request templates
README, CONTRIBUTING, AGENTS, SECURITY, CODE_OF_CONDUCT, LICENSE-MIT / LICENSE-APACHE
CITATION.cff          with --citation: the citation, its version and date `rake bump`'s
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
  and tools' configuration are the template's own files, byte for byte (`test/test_sync.rb`; but
  `dependabot.yml`, whose directories differ, `.mutineer.yml`, whose ignored mutants are the
  plugin's, and the smoke test's workflow, the plugin's alone), so
  the template's are checked in place by this repository's checks, and a command line's own
  (`image.yml`) by the smoke test's command gem.
- The smoke test (`dev/smoke.sh`, `smoke.yml`, weekly too): the plugin installed from this checkout
  generates a gem of each kind and licence, and each passes its own `rake checks` and builds; the
  citation's gem releases twice (`rake bump`), a patch and a minor.

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
