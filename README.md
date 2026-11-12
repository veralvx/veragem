# veragem

[![Ruby CI](https://github.com/veralvx/veragem/actions/workflows/ruby-ci.yml/badge.svg)](https://github.com/veralvx/veragem/actions/workflows/ruby-ci.yml)
[![Nix](https://github.com/veralvx/veragem/actions/workflows/nix.yml/badge.svg)](https://github.com/veralvx/veragem/actions/workflows/nix.yml)
[![Security](https://github.com/veralvx/veragem/actions/workflows/security.yml/badge.svg)](https://github.com/veralvx/veragem/actions/workflows/security.yml)
[![Smoke](https://github.com/veralvx/veragem/actions/workflows/smoke.yml/badge.svg)](https://github.com/veralvx/veragem/actions/workflows/smoke.yml)
[![Coverage](https://img.shields.io/badge/coverage-100%25-brightgreen)](.simplecov)
[![Mutation score](https://img.shields.io/badge/mutation%20score-100%25-brightgreen)](.mutineer.yml)
[![Documented](https://img.shields.io/badge/documented-100%25-brightgreen)](.yard-lint.yml)
[![Docs](https://img.shields.io/badge/docs-rubydoc.info-blue)](https://rubydoc.info/gems/veragem)
[![License](https://img.shields.io/badge/license-MIT%20OR%20Apache--2.0-blue)](#license)
[![Gem version](https://img.shields.io/gem/v/veragem)](https://rubygems.org/gems/veragem)
[![Ruby](https://img.shields.io/badge/ruby-%3E%3D%204.0-red)](#install)

veragem is a Bundler plugin that generates a Ruby 4.0+ gem with its toolchain set up and passing
from the first commit: Steep types, RuboCop, Minitest at 100% coverage with mutation testing, YARD,
CI on Linux, macOS and Windows, a Nix flake, and releases to RubyGems by Trusted Publishing. It is
the Ruby counterpart of the Python and Rust templates in the
[templates](https://github.com/veralvx/templates) repository.

```sh
bundle plugin install veragem
bundle veragem my_gem
```

## Compared with `bundle gem`

`bundle gem` writes a gemspec, a Gemfile, a Rakefile, `lib/`, an RBS stub in `sig/`, `bin/setup`,
`bin/console` and a README, and asks whether to add a test framework, CI and a linter. veragem
writes what `bundle gem` does, then configures the rest:

| Area          | `bundle gem`                                                      | `bundle veragem`                                                                                      |
| ------------- | ----------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| Tests         | Minitest, RSpec or test-unit, if chosen                           | Minitest and a property test; every line, branch and method covered; mutation testing                 |
| Types         | an RBS stub                                                       | Steep checks `lib/` against `sig/`, strict, every call typed; TypeProf                                |
| Lint          | RuboCop or Standard, if chosen                                    | RuboCop with every new cop and five extensions, the signatures linted too                             |
| Documentation | the README                                                        | YARD, every public object documented (yard-lint)                                                      |
| CI            | GitHub Actions, GitLab CI or CircleCI, if chosen: one Ruby, Linux | GitHub Actions on Linux, macOS and Windows, with mutation, link, security and Nix checks              |
| Security      | --                                                                | bundler-audit daily, dependency review, zizmor, Dependabot                                            |
| Releases      | Bundler's `rake release`, pushing the gem from your machine       | `rake bump` (version, changelog), then a tag that publishes by Trusted Publishing, signed, no API key |
| Commits       | --                                                                | Conventional Commits, checked in CI and in opt-in git hooks                                           |
| Nix           | --                                                                | a flake: the development shell, the gem as a package, and a command's OCI image                       |
| Licence       | MIT, if chosen                                                    | MIT, Apache-2.0, or both                                                                              |
| Citation      | --                                                                | `CITATION.cff`, with `--citation`                                                                     |

## What a generated gem holds

- **Ruby 4.0** or later, in `required_ruby_version` and in CI, on Linux, macOS and Windows.
  `Gemfile.lock` holds Windows' platform (`bin/setup` adds it), `.gitattributes` keeps every text
  file LF, and git's index records the executables' mode, so a commit keeps it even from a file
  system that has none.
- **Types**: Steep checks `lib/` against the signatures in `sig/`, its `strict` diagnostics on.
  `rake steep:typed` fails on any call on an untyped receiver. TypeProf infers signatures to start
  from, and its editor support is configured.
- **Lint and format**: RuboCop with every new cop, and the rubocop-minitest, rubocop-packaging,
  rubocop-performance, rubocop-rake and rubocop-on-rbs extensions; the last lints the signatures.
  The project is indexed first (rubydex), so the cops that look across files work. In CI, offences
  are annotated on the pull request, and a failed run's summary holds the safe corrections as a
  patch to `git apply`. No workflow pushes code the bumped gems wrote: a Dependabot bump that new
  cops fail stays unmerged until you apply the patch.
- **Documentation**: YARD, every public object of `lib/` documented, and yard-lint holding that at
  100%. `rake yard` writes it to `doc/`.
- **Tests**: Minitest, a property test with [pbt](https://github.com/ohbarye/pbt), and SimpleCov's
  `strict` profile: every line, branch and method of `lib/` covered. A warning from `lib/` or the
  tests fails them. [mutineer](https://github.com/davidteren/mutineer) mutates `lib/`: a mutant no
  test catches fails the run, and so does an ignore that matches no mutant. `rake checks` mutates
  the lines changed since `origin/main`; CI mutates every line (`rake mutation`).
- **Links**: lychee checks the links in the files git tracks, but the tests' (`rake links`), in
  `rake checks` and monthly (`links.yml`).
- **Security**: bundler-audit checks `Gemfile.lock` daily and on every pull request.
  `dependency-review.yml` reviews a pull request's new gems for their licences and advisories, and
  its new actions for their licences; it is not a required check, as in the Python and Rust
  templates. zizmor audits the workflows and Dependabot's configuration. Dependabot updates the
  gems, the actions and the flake, each update proposed once its release is a week old.
- **Commits and releases**: Conventional Commits, checked by cocogitto in CI and in opt-in git
  hooks. `rake "bump[minor]"` sets the version, writes the changelog with git-cliff and commits;
  Bundler's own `rake release` tags and pushes. The tag's workflow builds the gem apart from the
  tools' gems, signs it (its Sigstore attestation, RubyGems' provenance), publishes it to RubyGems
  by Trusted Publishing with no API key stored, and makes the GitHub release.
- **Nix**: a flake with the development shell (Ruby and every tool the checks run), the gem as a
  package (`nix build`), `nix fmt`, and checks of the Nix, the shell scripts, the workflows and the
  package. With `--exe`, `nix run` runs the command, and its OCI image (on Linux,
  `nix build .#image`) is published to GHCR at each release (`image.yml`), as in the Python and Rust
  templates.
- **Project files**: dprint for the Markdown and TOML, an `.editorconfig`, the community documents
  (`CONTRIBUTING.md`, `AGENTS.md`, `SECURITY.md`, `CODE_OF_CONDUCT.md`), and issue and pull request
  templates.

In the generated gem, `bundle exec rake` runs the Ruby checks, as CI does. `bundle exec rake checks`
runs all of CI's checks, the links too, but mutates only the changed lines.

## Install

veragem needs Ruby 4.0 or later and git:

```sh
bundle plugin install veragem
```

Run outside a project, this installs the plugin for your user, so `bundle veragem` works anywhere.
To install from the repository instead, use
`bundle plugin install veragem --git https://github.com/veralvx/veragem`, or `--path` with a local
checkout. This README follows `main`, which can be ahead of the release: `--git` installs `main`,
and [CHANGELOG.md](CHANGELOG.md) lists what each release holds.

## Usage

```sh
bundle veragem my_gem   # with a terminal for input, it asks for what no option gives
cd my_gem
bin/setup               # installs the gems and writes Gemfile.lock
git add .
git commit -m "chore: initial commit from veragem"
bundle exec rake checks # needs the tools the generated CONTRIBUTING.md lists, or `nix develop`
```

Like `bundle gem`, veragem creates the git repository and adds the files, but runs no
`bundle install`: `bin/setup` writes the lock, which you commit. The generated `CONTRIBUTING.md`
lists the first steps: the repository's settings, and RubyGems' pending trusted publisher.

### Options

| Option                     | Default                                     | Goes into                                                                                   |
| -------------------------- | ------------------------------------------- | ------------------------------------------------------------------------------------------- |
| `NAME`                     | --                                          | the gem, its module, its files: as `bundle gem`                                             |
| `--[no-]exe`               | `--no-exe`: a library alone                 | a command line: `exe/NAME`, `lib/PATH/cli.rb`                                               |
| `--license=LICENSE`        | `dual` (MIT OR Apache-2.0)                  | `mit`, `apache` or `dual`: the gemspec, LICENSE                                             |
| `--author=NAME`            | `git config user.name` (required)           | the gemspec, the licence's copyright line                                                   |
| `--[no-]email=EMAIL`       | `git config user.email`; `--no-email`: none | the gemspec, the code of conduct                                                            |
| `--github=USER`            | `git config github.user` (required)         | the homepage, the repository's links                                                        |
| `--summary=TEXT`           | `A Ruby gem.`                               | the gemspec, the README, the module's comment, the flake; with `--citation`, `CITATION.cff` |
| `--[no-]badges`            | `--badges`                                  | the README's badges: CI, its 100% gates, the gem's version, docs, licence, Ruby             |
| `--[no-]citation`          | `--no-citation`                             | `CITATION.cff`: GitHub's "Cite this repository"; the README's Citation section              |
| `--family-names=NAMES`     | (required with `--citation`)                | with `--citation`: the author's, `CITATION.cff`                                             |
| `--[no-]given-names=NAMES` | optional; `--no-given-names`: none          | with `--citation`: the author's, `CITATION.cff`                                             |
| `--[no-]alias=ALIAS`       | optional; `--no-alias`: none                | with `--citation`: the author's handle, `CITATION.cff`                                      |
| `--orcid=ID`               | optional                                    | with `--citation`: the author's ORCID iD                                                    |
| `--keywords=LIST`          | optional                                    | with `--citation`: keywords, comma-separated                                                |

A licence, given as an option or an answer, is taken in any case, abbreviated (`a`), or as its SPDX
expression (`Apache-2.0`, or `MIT OR Apache-2.0` in either order). Without a terminal, when veragem
refuses a value from git's config, its error names the key and the options that replace it.

The badges sit under the README's title, each a link:

- the status of CI, of the flake's checks and of the daily bundler-audit: GitHub's own badges of
  `ruby-ci.yml`, `nix.yml` and `security.yml`, each linking to its runs;
- the gates CI holds at 100% (coverage, mutation score and documentation): fixed shields.io badges,
  each linking to the file that sets its gate;
- the documentation on rubydoc.info, the licence, the version on RubyGems and the Ruby required:
  shields.io's, the licence and Ruby linking to the README's own sections.

Until the gem is first released, the version badge reads "not found" and its RubyGems and
rubydoc.info pages are missing; `rake links` skips them, as it skips the gem's GitHub pages.

### Questions

With a terminal for input, `bundle veragem` checks the options, then asks for each value no option
gives, the name included. A question offers its default, unless veragem refuses that default, in
which case it says why and where the default came from (`git config user.name`). Enter takes the
default. An optional question takes `-` for none. A refused answer, or an empty one where there is
no default, is asked again, saying why.

`-` is never an option's value, since no answer can give it: `--no-email`, `--no-given-names` and
`--no-alias` give none, and so does leaving `--orcid` or `--keywords` out.

With other input (CI, a pipe, or `< /dev/null` to skip the questions), nothing is asked: the
defaults apply, and a missing name, author or GitHub user is refused, as are missing family names
with `--citation`.

### CITATION.cff

`CITATION.cff` (Citation File Format 1.2.0) is for research software meant to be cited. GitHub shows
it as "Cite this repository", the README's Citation section says how to cite the gem, and Zenodo,
once the repository is enabled there (the generated CONTRIBUTING.md's first steps), archives each
release with its values and gives it a DOI.

Its author is a person: family names are required; given names, alias, ORCID iD and keywords are
optional. At a terminal, the family names question offers the author's last word, and the given
names question the words before the family names, when the author ends with them. The alias
question comes last and offers the GitHub user; since that user may be an organization, it is only
offered. Without a terminal nothing is guessed: there are no given names or alias unless
`--given-names` or `--alias` gives them. The citation's options need `--citation`: given without it,
they are refused, and at a terminal they make its question accept only y.

The file holds what GitHub and Zenodo read, written as Zenodo's import takes it (narrower than CFF),
except the licences, which are written as CFF has them:

- one licence as its SPDX identifier, and `dual`'s two as a list, CFF's OR. Zenodo's import refuses
  a list, so it archives no release of a dual-licensed gem until
  [zenodo/zenodo-rdm#1509](https://github.com/zenodo/zenodo-rdm/issues/1509) is fixed (first
  reported as [zenodo/zenodo#2515](https://github.com/zenodo/zenodo/issues/2515));
- an ORCID iD that passes Zenodo's check (its check digit, in ORCID's blocks), written as its URL;
- names without a comma, as Zenodo reads one as the end of the family names (`Smith, Jr.`); an
  alias may hold one, since Zenodo reads no alias;
- a name of 3 characters or more, Zenodo's shortest title;
- the repository, RubyGems' page as its artifact, and its API documentation on rubydoc.info as its
  URL (there from the first release); no email, as CFF's pattern is stricter than veragem's;
- its DOIs commented out, the concept DOI and a version's, to uncomment once Zenodo gives them after
  a release.

`rake bump` sets its version and date at each release. `nix flake check` validates it against CFF's
schema (cffconvert): a check of the schema alone, which passes files Zenodo's import refuses.

### The name

The name follows `bundle gem`'s rules, in lower case: `my_gem` is `MyGem` in `lib/my_gem.rb`, and
`my-gem` is `My::Gem` in `lib/my/gem.rb`. veragem refuses a name before writing anything when:

- its module is already defined: by Ruby; by what its tools load with its code (Bundler, the
  Rakefile and its tasks, the console, the tests: `c_s_v`, `j_s_o_n`, `weak_ref`), where those are
  installed; or by the library its top-level module names, where this Ruby has one (`set`,
  `option_parser`, `date-holidays`, since Date is a class);
- its file would shadow a library this Ruby has, in any case, as macOS and Windows ignore case
  (`ripper`: lib/ripper.rb; `english`: English.rb);
- its tests or `gem build` would take its module for Minitest's or RubyGems' own
  (`lifecycle_hooks`, `date_like`);
- `bundle gem` would refuse or mangle it (`1gem`, `my--gem`);
- it names a gem the Gemfile's tools load, theirs included (`rubocop-rake`, `parser`): the tools'
  bundle would resolve it to the new gem;
- it is `test_helper`, whose lib/test_helper.rb would shadow the tests', or would make veragem write
  a template file twice (`helper`: test/test_helper.rb);
- a word between its dashes is one of Windows' device names (`con`, `my-nul`), which Windows allows
  no file to be named;
- it is longer than 40 characters or deeper than 4 modules, so the generated code's lines fit
  RuboCop's;
- with `--exe`, its module is CLI or VERSION (`my-c_l_i`): its command line would find another
  first.

### The summary

The summary is plain text, as RubyGems shows it. The README shows it as written: its Markdown
characters escaped (`_`, `` ` ``, `<`...), a URL's `://` and `www.` too, which GitHub would link
with the escapes shown, and its spaces single, as dprint writes them. Only GitHub's emoji
shortcodes (`:gem:`) cannot be kept.

It is the module's comment too, so veragem refuses a summary the gem's yard-lint or RuboCop would
not take as documentation:

- one starting with a tag, YARD's (`@param`, `(see`) or an informal one (`Note:`, `See also:`);
- a RuboCop annotation (`HACK:`, `review the code`) or a magic comment (`encoding:`,
  `warn_indent:`);
- Markdown yard-lint refuses: an em or en dash outside code, a `•` list marker, or a code fence
  first;
- a backtick or `**` left open.

## Generated files

```
NAME.gemspec          the gem: its version from lib/PATH/version.rb (`my-gem`'s lib/my/gem/), its
                      files lib/, sig/, exe/, the README, the changelog and the licences
Gemfile               the gemspec, then the tools; Gemfile.lock pins them (written by bin/setup)
Rakefile              `rake`: RuboCop, Steep, the tests, yard-lint; `rake checks`: what CI runs;
                      `rake "bump[level]"`, `rake release`; `rake -T` lists them all
Steepfile, sig/       the types; typeprof.conf.jsonc, TypeProf's editor support
.rubocop.yml          RuboCop and its extensions; .yard-lint.yml, the documentation's lint
.simplecov, .mutineer.yml  the coverage gate; the mutation test's operators and its ignores
lib/, test/, exe/     starter code (exe/NAME with --exe): typed, documented, every line and
                      branch tested
bin/setup, bin/console
flake.nix, flake.lock the dev shell, the package (and the command's image), `nix fmt`, the checks
.githooks/            opt-in (`rake hooks`): the quick checks before a commit, Conventional Commits
cliff.toml, cog.toml  git-cliff's changelog, cocogitto's commit checks
dprint.json, .editorconfig
.github/              CI, the flake, bundler-audit, the dependency review, the release (and the
                      image), the style checks, the links, Dependabot and its auto-merge; issue
                      and pull request templates
README, CONTRIBUTING, AGENTS, SECURITY, CODE_OF_CONDUCT, LICENSE-MIT / LICENSE-APACHE
CITATION.cff          with --citation: the citation, its version and date `rake bump`'s
```

The Gemfile leaves the development tools unconstrained: the lock pins them at the versions current
when `bin/setup` first runs, and Dependabot moves it. They need no development group, because the
built gem holds neither the Gemfile nor the lock; its dependencies are the gemspec's alone. The dev
shell gives Ruby and the other tools. The gems come from Bundler, from the same lock CI installs
from (nixpkgs packages few of them, and older versions).

## How it is verified

- **The plugin's own tests** (`bundle exec rake`): the name rules (`bundle gem`'s constant, as a
  property), the options, every file of each kind and licence rendered, parsed and kept executable,
  the gemspec read back, and the values written as given whatever the locale.
- **The template's harness, used here**: this repository's Gemfile, Rakefile, workflows, hooks,
  flake and tools' configuration are the template's own plain files, byte for byte
  (`test/test_sync.rb`). The exceptions are `dependabot.yml`, which updates both; `.mutineer.yml`,
  whose ignored mutants are the plugin's; and the smoke test's workflow, the plugin's alone. So this
  repository's checks check the template's files in place, and the smoke test's command gem checks
  a command line's own (`image.yml`).
- **The smoke test** (`dev/smoke.sh`, `smoke.yml`, weekly too): the plugin, installed from this
  checkout, generates a gem of each kind and licence. Each passes its own `rake checks` with its
  git hooks on, the links aside (`links.yml`'s), and builds. The citation's gem is released three
  times (`rake bump`, then `rake release` to a local remote): its first release, a patch and a
  minor.

## Contributing

[CONTRIBUTING.md](CONTRIBUTING.md) covers the tools, the checks, the template and the release;
[AGENTS.md](AGENTS.md) the rules a change follows. See also [SECURITY.md](SECURITY.md) and the
[CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).

## Citation

If you use veragem in your work, please cite it: [CITATION.cff](CITATION.cff) holds its
citation, in the [Citation File Format](https://citation-file-format.github.io/). On GitHub, the
repository's sidebar has "Cite this repository", which gives it in APA and BibTeX, to copy.

## License

Licensed under either of

- Apache License, Version 2.0 ([LICENSE-APACHE](LICENSE-APACHE) or
  <https://www.apache.org/licenses/LICENSE-2.0>)
- MIT license ([LICENSE-MIT](LICENSE-MIT) or <https://opensource.org/license/MIT>)

at your option.

The generated gems are yours: their licence is the one you choose at generation.

### Contribution

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in
the work by you, as defined in the Apache-2.0 license, shall be dual licensed as above, without
any additional terms or conditions.
