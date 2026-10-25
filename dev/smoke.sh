#!/usr/bin/env bash
# The plugin as a user meets it: installed from this checkout (`bundle plugin install --path`), it
# generates a gem of each kind and licence, and each passes its own `rake checks` and builds -- its
# gems from rubygems.org, its tools the dev shell's: run it in `nix develop`. smoke.yml's.
set -euo pipefail

root="$(cd "$(dirname "$0")/.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
# the plugin into a Bundler home of its own, not the user's
export BUNDLE_USER_HOME="$work/bundle"
cd "$work"
bundle plugin install veragem --path "$root"

generate() {
  bundle veragem "$@" --author "Smoke Test" --email smoke@example.com --github veragem-smoke
}
generate smoke_lib
generate smoke-omniauth-google_oauth2 --exe --license mit
generate smoke_apache --license apache

for gem in smoke_lib smoke-omniauth-google_oauth2 smoke_apache; do
  echo "== $gem"
  (
    cd "$gem"
    bin/setup
    git add .
    git -c user.name="Smoke Test" -c user.email=smoke@example.com \
      commit --quiet --message "chore: initial commit from veragem"
    bundle exec rake checks typeprof build
  )
done
