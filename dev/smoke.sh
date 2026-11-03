#!/usr/bin/env bash
# The plugin as a user meets it: installed from this checkout (`bundle plugin install --path`), it
# generates a gem of each kind and licence, one with CITATION.cff, and each, its git hooks on,
# passes its own `rake checks` but the links, and builds, and the command's OCI image runs, on Linux
# where Docker runs; the citation's gem is released, its first release and two after, as
# `rake bump` and `rake release` do it. Its gems from rubygems.org, its tools the dev shell's: run
# it in `nix develop`. smoke.yml's. A failed run keeps its files and says where.
set -euo pipefail

# none of the caller's settings reach the gems: `bundle exec`'s (its PATH, RUBYOPT, BUNDLER_SETUP,
# which RubyGems requires, BUNDLE_GEMFILE), Bundler's and git's (a signed tag, a hook of theirs)
PATH="${BUNDLER_ORIG_PATH:-$PATH}"
unset CDPATH RUBYOPT "${!BUNDLE_@}" "${!BUNDLER_@}"
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
  for line; do grep -qxF -- "$line" "$file" && return; done
  cat -- "$file" >&2
  fail "$file has none of: $*"
}
# the work tree as committed, but what .gitignore ignores
committed() {
  [ -z "$(git status --porcelain)" ] || fail "$PWD changed: $(git status --short)"
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
    # in git's config, which the commit-msg hook's cog reads; not ASCII, as the changelog writes it
    git config user.name "Smöke Test"
    git config user.email smoke@example.com
    bundle exec rake hooks
    git add .
    git commit --quiet --message "chore: initial commit from veragem"
    if git commit --quiet --allow-empty --message "not a Conventional Commit" 2> /dev/null; then
      fail "the commit-msg hook took a message that is not a Conventional Commit"
    fi
    # `rake checks` but its links, links.yml's: a host's outage would fail an unrelated pull request
    prerequisites="$(bundle exec rake -P)"
    mapfile -t checks < <(awk '$0 == "rake checks" { f = 1; next } /^rake / { f = 0 } f && $1 != "links" { print $1 }' <<< "$prerequisites")
    [[ " ${checks[*]} " == *" default "* && " ${checks[*]} " == *" nix "* ]] ||
      fail "could not read the prerequisites of rake checks: ${checks[*]}"
    # typeprof is advisory: its crash alone fails it
    bundle exec rake "${checks[@]}" typeprof build
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
        echo "smoke: no Docker here: the image is built (rake nix), not run" >&2
      fi
    fi
    if [ -e CITATION.cff ]; then
      # the first release: no tag yet, the declared version kept, the changelog begun
      bundle exec rake "bump[minor]"
      has CITATION.cff 'version: "0.1.0"'
      .github/release-notes.sh CHANGELOG.md 0.1.0 > /dev/null
      committed
      # `rake release` tags it and pushes the branch and the tag (the pre-push hook checks them)
      git init --quiet --bare "$work/$gem.git"
      git remote add origin "$work/$gem.git"
      bundle exec rake release
      git -C "$work/$gem.git" rev-parse --quiet --verify refs/tags/v0.1.0 > /dev/null ||
        fail "rake release pushed no v0.1.0"
      # a release's CITATION.cff: `rake bump` sets its version and date, under an ASCII locale too;
      # the date UTC's, the changelog's, in a zone whose date is another, whatever the hour: UTC+14
      # from 12:00 UTC, UTC-12 before (POSIX zones, which need no tzdata). Either day, should the
      # bump cross midnight.
      git commit --quiet --allow-empty --message "fix: a smöke release"
      zone='<-12>+12'
      if [ "$(date -u +%H)" -ge 12 ]; then zone='<+14>-14'; fi
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
      # a minor release zeroes the patch number
      git commit --quiet --allow-empty --message "feat: a smöke feature"
      bundle exec rake "bump[minor]"
      has CITATION.cff 'version: "0.2.0"'
      committed
    fi
  )
done
