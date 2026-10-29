# AGENTS.md

Repository rules for `veragem`. These apply to every contributor, human or AI-assisted.
The template's rules -- what is ERB and what is plain, the copies this repository's harness keeps
-- the checks and the release are [CONTRIBUTING.md](CONTRIBUTING.md)'s. The rules below hold here
and in every gem veragem generates: `template/AGENTS.md.erb` is their source.

## 1. Lints and Types

RuboCop runs with its defaults and every new cop as it ships (`NewCops: enable`), its Minitest,
packaging, performance and Rake extensions on, and the project indexed first (`UseProjectIndex`, the
rubydex gem) for the cops that look across files (`.rubocop.yml`). Steep checks `lib/` against the
signatures in `sig/`, its strictest diagnostics on (`Steepfile`): every method of `lib/` is declared
in `sig/`, and a warning fails as an error does. Gemfile.lock pins both, so the verdict is the same
locally and in CI. Documentation follows Yard style, and it is linted with `yard-lint` (`.yard-lint.yml`).

The shell is held as the code is: shfmt formats it (`.editorconfig` holds its style) and it passes
ShellCheck. The Nix is nixfmt's. The workflows pass actionlint and, with Dependabot's
configuration, zizmor's security audit.

### 1.2. Rubocop

- Before finishing, check what you changed with `bundle exec rubocop --changed --format json`.
- Fix offenses with `bundle exec rubocop -a FILES`. Don't use `-A` unless asked.
- If an offense is unclear, run `bundle exec rubocop --explain Department/CopName`.
- Don't edit `.rubocop.yml` or `.rubocop_todo.yml` to make offenses go away,
  and don't regenerate the todo file.
- When an offense has to stay, disable the cop on that line and say why:
  `# rubocop:disable Department/CopName -- the reason`.

### 1.2. Yard

- Documentation is generated with `bundle exec yardoc` or `bundle exec rake yard`
- Linting for Yard documentation is done with `yard-lint`: `bundle exec yard-lint /lib --stats`
  or `bundle exec rake yard_lint`.
- `yardoc` supports queries: `--query '@return' --query '@param'`, `--query '@return && @param'`
  `--query '@api.text == "public"'`, `--query 'object.has_tag?(:api) && object.tag(:api).text == "public"'`,
  `--query 'has_tag?(:api) && tag(:api).text == "public"'`
- A graph can be generated using `yard graph`, and it can be rendered with Graphviz and `dot`:
  `yard graph --protected --private --full --dependencies`

### 1.2.3. Types: signatures by hand, TypeProf to start them

`sig/` is written by hand and Steep holds `lib/` to it. `bundle exec rake typeprof` prints the
signatures TypeProf infers from `lib/`: a start for a new method's, never a replacement for
reading them -- it says `untyped` where it cannot tell. A signature is as narrow as the code
allows: `untyped` only where the value truly is any value.

## 2. Comments: only what is essential

A comment says what the code cannot: why it is so, the source it follows, the constraint it keeps.
Make it concise and precise -- a line where a line does -- and never restate the code: that is
noise, and it goes stale. A change that falsifies a comment rewrites it.

## 3. Commits

[Conventional Commits](https://www.conventionalcommits.org/) are enforced by `cog check` locally
and in CI. The changelog is generated from the commits (`cliff.toml`), so the subject line is
user-facing text; `chore`, `ci` and `style` commits stay out of it, and `!` or a `BREAKING CHANGE`
footer lists a commit first:

```
feat(template): the gem as a Nix package, and a command's OCI image
fix(template): keep exe/NAME executable
docs: explain the template's ERB values
```

The git hooks (`bundle exec rake hooks`) check the same before a commit and a push; never bypass
them with `--no-verify`. `git revert` writes `Revert "..."`, which CI refuses: reword it as
`revert: ...`.

## 4. Before you claim a change is done

Run `bundle exec rake checks`, and for a change to the template the smoke test too
(`nix develop --command dev/smoke.sh`). `rake checks` is what CI runs: RuboCop, Steep, the tests
with every line, branch and method covered, Yard lints, bundler-audit, dprint, the commit messages, the shell,
the workflows, and the flake's checks. Reporting "done" on a change that has not passed it is the
one thing that wastes the most time here.

If a check fails for reasons unrelated to your change, say so explicitly rather than working
around it -- a broken check that everyone routes around stops protecting anything.
