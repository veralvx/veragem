#!/usr/bin/env bash
# The plugin as a user meets it: installed from this checkout (`bundle plugin install --path`), it
# generates a gem of each kind and licence, one with CITATION.cff, and each passes its own
# `rake checks` and builds, and the command's OCI image runs, on Linux where Docker runs, and the
# citation's release bumps -- its gems from rubygems.org, its tools the dev shell's: run it in
# `nix develop`. smoke.yml's.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# the plugin into a Bundler home of its own, not the user's
export BUNDLE_USER_HOME="$work/bundle"
cd "$work"
bundle plugin install veragem --path "$root"

# no terminal for input: nothing asked, the defaults taken
generate() {
  bundle veragem "$@" --author "Smoke Test" --email smoke@example.com --github veragem-smoke < /dev/null
}
generate smoke_lib
generate smoke-omniauth-google_oauth2 --exe --license mit
generate smoke_apache --license apache --citation --given-names Smöke --family-names Test \
  --orcid 0000-0002-1825-0097 --keywords smoke,test

for gem in smoke_lib smoke-omniauth-google_oauth2 smoke_apache; do
  echo "== $gem"
  (
    cd "$gem"
    bin/setup
    git add .
    git -c user.name="Smoke Test" -c user.email=smoke@example.com \
      commit --quiet --message "chore: initial commit from veragem"
    bundle exec rake checks typeprof build
    # the command's image, run as image.yml runs it, where Docker runs (the image is Linux's)
    if [ -e exe/"$gem" ] && [ "$(uname -s)" = Linux ] && docker info > /dev/null 2>&1; then
      "$(nix build --no-link --print-out-paths .#image.stream)" | docker load
      version="$(nix eval --raw .#image.imageTag)"
      actual="$(docker run --rm --pull never "$gem:$version" --version)"
      if [ "$actual" != "$gem $version" ]; then
        echo "the image's --version gave '$actual', expected '$gem $version'" >&2
        exit 1
      fi
    fi
    # a release's CITATION.cff: `rake bump` sets its version and date, under an ASCII locale too
    if [ -e CITATION.cff ]; then
      git tag v0.1.0
      export GIT_AUTHOR_NAME="Smoke Test" GIT_AUTHOR_EMAIL=smoke@example.com
      export GIT_COMMITTER_NAME="$GIT_AUTHOR_NAME" GIT_COMMITTER_EMAIL="$GIT_AUTHOR_EMAIL"
      git commit --quiet --allow-empty --message "fix: a smoke release"
      LC_ALL=C bundle exec rake "bump[patch]"
      grep -qx 'version: "0.1.1"' CITATION.cff
      grep -qx "date-released: \"$(date +%F)\"" CITATION.cff
      git diff --quiet HEAD
    fi
  )
done
