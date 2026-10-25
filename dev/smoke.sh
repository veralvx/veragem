#!/usr/bin/env bash
# The plugin as a user meets it: installed from this checkout (`bundle plugin install --path`), it
# generates a gem of each kind and licence, and each passes its own `rake checks` and builds, and
# the command's OCI image runs where Docker is -- its gems from rubygems.org, its tools the dev
# shell's: run it in `nix develop`. smoke.yml's.
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
    # the command's image, run as image.yml runs it, where Docker runs (the image is Linux's)
    if [ -e exe/"$gem" ] && [ "$(uname -s)" = Linux ] && docker info > /dev/null 2>&1; then
      "$(nix build --no-link --print-out-paths .#image.stream)" | docker load
      version="$(nix eval --raw .#image.imageTag)"
      [ "$(docker run --rm --pull never "$gem:$version" --version)" = "$gem $version" ]
    fi
  )
done
