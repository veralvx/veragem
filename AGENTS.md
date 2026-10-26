# AGENTS.md

Repository rules for `veragem`. These apply to every contributor, human or AI-assisted.
The template's rules -- what is ERB and what is plain, the copies this repository's harness keeps
-- the checks and the release are [CONTRIBUTING.md](CONTRIBUTING.md)'s. The rules below hold here
and in every gem veragem generates: `template/AGENTS.md.erb` is their source.

## 1. The lint and type policy is the design

RuboCop runs with its defaults and every new cop as it ships (`NewCops: enable`), its Minitest,
packaging, performance and Rake extensions on, and the project indexed first (`UseProjectIndex`, the
rubydex gem) for the cops that look across files (`.rubocop.yml`). Steep checks `lib/` against the
signatures in `sig/`, its strictest diagnostics on (`Steepfile`): every method of `lib/` is declared
in `sig/`, and a warning fails as an error does. Gemfile.lock pins both, so the verdict is the same
locally and in CI.

**Never silence a new cop or diagnostic wholesale.** Either fix the site, or configure it in
`.rubocop.yml` (or the Steepfile) with a comment saying why it is wrong for this codebase.

The shell is held as the code is: shfmt formats it (`.editorconfig` holds its style) and it passes
ShellCheck. The Nix is nixfmt's. The workflows pass actionlint and, with Dependabot's
configuration, zizmor's security audit.

## 2. Types: signatures by hand, TypeProf to start them

`sig/` is written by hand and Steep holds `lib/` to it. `bundle exec rake typeprof` prints the
signatures TypeProf infers from `lib/`: a start for a new method's, never a replacement for
reading them -- it says `untyped` where it cannot tell. A signature is as narrow as the code
allows: `untyped` only where the value truly is any value.

## 3. Silence a cop or a diagnostic at the site, with a reason

```ruby
eval(code) # rubocop:disable Security/Eval -- code is this gem's own, never its input

# the library declares no signature -- above: text after Steep's diagnostic name voids the ignore
value = client.fetch # steep:ignore NoMethod
```

Name the cop or diagnostic. A reason that restates the rule is not a reason: say what makes the
site safe. RuboCop reports a disable that no longer applies (`Lint/RedundantCopDisableDirective`),
so a justification cannot outlive the code it justified.

## 4. Comments: only what is essential

A comment says what the code cannot: why it is so, the source it follows, the constraint it keeps.
Make it concise and precise -- a line where a line does -- and never restate the code: that is
noise, and it goes stale. A change that falsifies a comment rewrites it.

## 5. Commits

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

## 6. Before you claim a change is done

Run `bundle exec rake checks`, and for a change to the template the smoke test too (`nix develop
--command dev/smoke.sh`). `rake checks` is what CI runs: RuboCop, Steep, the tests with every line,
branch and method covered, bundler-audit, dprint, the commit messages, the shell, the workflows,
and the flake's checks. Reporting "done" on a change that has not passed it is the one thing that
wastes the most time here.

If a check fails for reasons unrelated to your change, say so explicitly rather than working
around it -- a broken check that everyone routes around stops protecting anything.
