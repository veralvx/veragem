#!/usr/bin/env bash
# The plugin as a user meets it: installed from this checkout (`bundle plugin install --path`), it
# generates a gem of each kind and licence, one with CITATION.cff, and each, its git hooks on,
# passes its own `rake checks` but the links, and builds, and the command's OCI image runs, on Linux
# where Docker runs; the citation's gem is released, its first release and two after, as
# `rake bump` and `rake release` do it. Its gems from rubygems.org, its tools the dev shell's: run
# it in `nix develop`. smoke.yml's. A failed run keeps its files and says where.
set -euo pipefail

# none of the caller's settings reach the gems: what `bundle exec` changed put back, as Bundler's
# with_original_env does (its BUNDLER_SETUP RubyGems would require, its RUBYOPT, BUNDLE_GEMFILE,
# PATH), then Bundler's settings and git's (a signed tag, a hook of theirs) dropped
for saved in "${!BUNDLER_ORIG_@}"; do
  if [ "${!saved}" = BUNDLER_ENVIRONMENT_PRESERVER_INTENTIONALLY_NIL ]; then
    unset "${saved#BUNDLER_ORIG_}"
  else
    export "${saved#BUNDLER_ORIG_}=${!saved}"
  fi
done
unset CDPATH "${!BUNDLE_@}" "${!BUNDLER_@}"
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
# a failed run's files kept, to look into
finish() {
  if [ "$1" -eq 0 ]; then rm -rf "$work"; else echo "smoke: failed; its files: $work" >&2; fi
}
trap 'finish $?' EXIT
# the plugin into a Bundler home of its own, the gems into a gem home of their own: not the user's
export BUNDLE_USER_HOME="$work/bundle" GEM_HOME="$work/gems"
cd "$work"
bundle plugin install veragem --path "$root"

fail() {
  echo "smoke: $*" >&2
  exit 1
}
# FILE has one of the LINEs, as written
has() {
  local file=$1 line
  shift
  [ -f "$file" ] || fail "no $file"
  for line; do grep -qxF -- "$line" "$file" && return; done
  cat -- "$file" >&2
  fail "$file has none of: $*"
}
# the work tree as committed, but what .gitignore ignores
committed() {
  local changes
  changes="$(git status --porcelain)"
  [ -z "$changes" ] || fail "$PWD changed: $changes"
}
# COMMAND fails, its output naming MESSAGE
refuses() {
  local message=$1 output
  shift
  if output="$("$@" 2>&1)" || [[ $output != *"$message"* ]]; then
    fail "$* did not refuse with \"$message\": $output"
  fi
}

gems=()
# no terminal for input: nothing asked, the defaults taken; a gem's own options last, which win
generate() {
  bundle veragem "$1" --author "Smoke Test" --email smoke@example.com --github veragem-smoke "${@:2}" < /dev/null
  gems+=("$1")
}
# a summary of Markdown's markup, which the README shows as written and dprint takes
# shellcheck disable=SC2016 # the backticks and $z are the summary's, as written
generate smoke_lib --summary '+ A __fast__ my_gem  for `JSON` <!-- x, 2) & &amp; ~y~ $z [l](u) http://x/_a_ www._b_'
# a summary the gemspec escapes and the flake reads back; no email
# shellcheck disable=SC2016 # the interpolations are the summary's, as written
generate smoke-omniauth-google_oauth2 --exe --license mit --no-email --summary 'Says "hi" \ to #{x} and #$y.'
generate smoke_apache --license apache --citation --given-names Smöke --family-names Test \
  --alias smoke-test --orcid 0000-0002-1825-0097 --keywords smoke,test

for gem in "${gems[@]}"; do
  echo "== $gem"
  (
    cd "$gem"
    bin/setup
    # in git's config, which the commit-msg hook's cog reads; not ASCII, as `rake bump` reads it
    # from git-cliff's commits, under an ASCII locale too
    git config user.name "Smöke Test"
    git config user.email smoke@example.com
    bundle exec rake hooks
    git add .
    git commit --quiet --message "chore: initial commit from veragem"
    echo "not a Conventional Commit" > "$work/message"
    if .githooks/commit-msg "$work/message" 2> /dev/null; then
      fail "the commit-msg hook took a message that is not a Conventional Commit"
    fi
    # `rake checks` but its links, links.yml's: a host's outage would fail an unrelated pull request
    prerequisites="$(bundle exec rake -P)"
    mapfile -t checks < <(awk '$0 == "rake checks" { f = 1; next } /^rake / { f = 0 } f && $1 != "links" { print $1 }' <<< "$prerequisites")
    [[ " ${checks[*]} " == *" default "* && " ${checks[*]} " == *" nix "* ]] ||
      fail "could not read the prerequisites of rake checks: ${checks[*]}"
    # typeprof is advisory: its crash alone fails it. `rake format` changes nothing generated.
    # rubocop:changed with no origin yet: every file
    bundle exec rake "${checks[@]}" typeprof build format rubocop:changed
    committed
    # the flake's description, read from the gemspec by a pattern: the summary, as Ruby reads it
    summary="$(ruby -e 'print Gem::Specification.load(ARGV[0]).summary' "$gem.gemspec")"
    [ "$(nix eval --raw .#default.meta.description)" = "$summary" ] ||
      fail "the flake's description is not the gemspec's summary: $summary"
    # the command's image, run as image.yml runs it, where Docker runs (the image is Linux's); CI's
    # runner has it, so there its absence fails
    if [ -e "exe/$gem" ]; then
      if [ "$(uname -s)" = Linux ] && docker info > /dev/null 2>&1; then
        stream="$(nix build --no-link --print-out-paths .#image.stream)"
        "$stream" | docker load
        version="$(nix eval --raw .#image.imageTag)"
        image="$(nix eval --raw .#image.imageName):$version"
        actual="$(docker run --rm --pull never "$image" --version)"
        docker rmi --force "$image" > /dev/null
        [ "$actual" = "$gem $version" ] || fail "the image's --version gave '$actual', expected '$gem $version'"
      elif [ "${GITHUB_ACTIONS:-}" = true ]; then
        fail "no Docker to run the image"
      else
        echo "smoke: no Docker daemon here: the image is not run (on Linux, rake nix builds it)" >&2
      fi
    fi
    if [ -e CITATION.cff ]; then
      # a release file not committed is refused: a failed bump's rollback (git reset --hard) would
      # delete it
      # a level checked first, its usage said whatever the tree
      echo >> README.md
      refuses 'usage: rake "bump[major|minor|patch]"' bundle exec rake "bump[bogus]"
      git checkout -- README.md
      git rm --cached --quiet Gemfile.lock
      git commit --quiet --message "chore: untrack the lock"
      refuses "Gemfile.lock not committed" bundle exec rake "bump[minor]"
      git reset --quiet HEAD~1
      committed
      # the first release: no tag yet, the declared version kept, the changelog begun
      bundle exec rake "bump[minor]"
      has CITATION.cff 'version: "0.1.0"'
      .github/release-notes.sh CHANGELOG.md 0.1.0 > /dev/null
      committed
      # `rake release` tags it and pushes the branch and the tag (the pre-push hook checks them)
      git init --quiet --bare "$work/$gem.git"
      git remote add origin "$work/$gem.git"
      bundle exec rake release
      # origin/main now: the files changed since its merge base, none
      inspected="$(bundle exec rake rubocop:changed)"
      [[ "$inspected" =~ (^|$'\n')"0 files inspected" ]] ||
        fail "rake rubocop:changed inspected files nothing changed: $inspected"
      # a release's CITATION.cff: `rake bump` sets its version and date, under an ASCII locale too;
      # the date UTC's, the changelog's, in a zone whose date is another, whatever the hour: UTC+14
      # from 11:00 UTC, UTC-12 before, either a day off from 10:00 to 12:00 (POSIX zones, which need
      # no tzdata). Either day, should the bump cross midnight.
      git commit --quiet --allow-empty --message "fix: a smöke release"
      zone='<-12>+12'
      if [ "$(date -u +%H)" -ge 11 ]; then zone='<+14>-14'; fi
      day="$(date -u +%F)"
      LC_ALL=C TZ="$zone" bundle exec rake "bump[patch]"
      has CITATION.cff 'version: "0.1.1"'
      has CITATION.cff "date-released: \"$day\"" "date-released: \"$(date -u +%F)\""
      # a release's notes are its own section: the newest
      .github/release-notes.sh CHANGELOG.md 0.1.1 > /dev/null
      if .github/release-notes.sh CHANGELOG.md 0.1.0 > /dev/null 2>&1; then
        fail "release-notes.sh gave 0.1.0's notes, which are not the newest"
      fi
      committed
      bundle exec rake release
      # a minor release zeroes the patch number
      git commit --quiet --allow-empty --message "feat: a smöke feature"
      bundle exec rake "bump[minor]"
      has CITATION.cff 'version: "0.2.0"'
      # a version bumped and not yet released is not bumped again
      refuses "v0.2.0 is not tagged" bundle exec rake "bump[patch]"
      .github/release-notes.sh CHANGELOG.md 0.2.0 > /dev/null
      # 0.1.1's section kept, as released
      grep -q '^## \[0\.1\.1\](' CHANGELOG.md || fail "CHANGELOG.md lost 0.1.1's section"
      committed
      bundle exec rake release
      for tag in v0.1.0 v0.1.1 v0.2.0; do
        git -C "$work/$gem.git" rev-parse --quiet --verify "refs/tags/$tag" > /dev/null ||
          fail "rake release pushed no $tag"
      done
      # a clone whose tags cannot tell the releases is not bumped: one without them (deleted: git's
      # newer releases bring a local clone's tags despite --no-tags), or shallow. The branch named:
      # the bare remote's HEAD names git's default, not the gem's
      branch="$(git branch --show-current)"
      git clone --quiet --branch "$branch" "$work/$gem.git" "$work/no-tags"
      git -C "$work/no-tags" for-each-ref --format="delete %(refname)" refs/tags |
        git -C "$work/no-tags" update-ref --stdin
      (cd "$work/no-tags" && refuses "no v* tag" bundle exec rake "bump[patch]")
      # nor is its changelog previewed
      (cd "$work/no-tags" && refuses "no v* tag" bundle exec rake changelog)
      git clone --quiet --branch "$branch" --depth 1 "file://$work/$gem.git" "$work/shallow"
      (cd "$work/shallow" && refuses "a shallow clone" bundle exec rake "bump[patch]")
      (cd "$work/shallow" && refuses "a shallow clone" bundle exec rake changelog)
    fi
  )
done
