# The development shell, the formatter and the checks that need no gem:
#
#   nix develop      Ruby 4.0 and every tool `rake checks` runs besides the gems (Bundler's, from
#                    Gemfile.lock: `bin/setup`): cocogitto, git-cliff, dprint, shellcheck, shfmt,
#                    actionlint, nixfmt
#   nix fmt          the Nix, by nixfmt
#   nix flake check  the Nix format, the shell scripts (shellcheck, shfmt), the workflows
#                    (actionlint), offline in the sandbox: git's files alone
{
  description = "A Ruby gem's development shell and checks";

  # the unstable channel: its tools move with each `nix flake update` (Dependabot's, monthly)
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      # nixpkgs-unstable's platforms: it dropped x86_64-darwin in 26.11
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "aarch64-darwin"
      ];
      forAllSystems = f: lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
      # a check: its command run in the repository's files, its tools on PATH
      check =
        pkgs: name: tools: command:
        pkgs.runCommand name { nativeBuildInputs = tools; } ''
          cd ${self}
          ${command}
          touch $out
        '';
    in
    {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = [
            pkgs.ruby_4_0
            pkgs.cocogitto
            pkgs.git-cliff
            pkgs.dprint
            pkgs.shellcheck
            pkgs.shfmt
            pkgs.actionlint
            pkgs.nixfmt
          ];
        };
      });

      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);

      checks = forAllSystems (pkgs: {
        format = check pkgs "format" [ pkgs.nixfmt ] "nixfmt --check flake.nix";
        # shfmt finds the scripts, by extension or shebang, and formats them as .editorconfig says
        shell = check pkgs "shell" [ pkgs.shellcheck pkgs.shfmt ] ''
          shfmt --find . | xargs shellcheck
          shfmt --diff .
        '';
        # actionlint runs shellcheck on each `run:` script too
        workflows = check pkgs "workflows" [
          pkgs.actionlint
          pkgs.shellcheck
        ] "actionlint .github/workflows/*.yml";
      });
    };
}
