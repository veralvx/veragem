# The development shell, the gem as a package, and the checks that need no gem from the bundle:
#
#   nix develop      Ruby 4.0 and every tool `rake checks` runs besides the gems (Bundler's, from
#                    Gemfile.lock: `bin/setup`): cocogitto, git-cliff, dprint, shellcheck, shfmt,
#                    actionlint, nixfmt
#   nix build        the gem, built from its gemspec and installed (nixpkgs' buildRubyGem);
#                    with a command (exe/<name>): `nix run` runs it, and on Linux `nix build
#                    .#image` builds it as an OCI image (image.yml publishes it)
#   nix fmt          the Nix, by nixfmt
#   nix flake check  the Nix format, the shell scripts (shellcheck, shfmt), the workflows
#                    (actionlint), the package and its library loaded -- and the command run, and
#                    its image -- offline in the sandbox: git's files alone
#
# Nothing here names the gem: its name is the gemspec's file; its version, lib/<path>/version.rb's
# VERSION; its summary, homepage and licences, the gemspec's lines that set them.
{
  description = "A Ruby gem's development shell, package and checks";

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

      gemspecs = lib.filter (lib.hasSuffix ".gemspec") (lib.attrNames (builtins.readDir ./.));
      name =
        if lib.length gemspecs == 1 then
          lib.removeSuffix ".gemspec" (lib.head gemspecs)
        else
          throw "flake.nix: one *.gemspec expected, found ${toString gemspecs}";
      path = lib.replaceStrings [ "-" ] [ "/" ] name;
      # the groups of the first of +file+'s lines that +pattern+ matches whole, or null
      line =
        pattern: file:
        lib.findFirst (groups: groups != null) null (
          map (builtins.match pattern) (lib.splitString "\n" (builtins.readFile file))
        );
      # a Ruby string literal's value: its escapes read
      unquote = lib.replaceStrings [ "\\\\" "\\\"" "\\#" ] [ "\\" "\"" "#" ];
      # the gemspec's `spec.<attribute> = "<value>"`, its value; "" if no line sets it so
      field =
        attribute:
        let
          found = line ''[[:space:]]*spec\.${attribute} *= *"((\\.|[^"\\])*)" *'' ./${name}.gemspec;
        in
        if found == null then "" else unquote (lib.head found);
      version =
        let
          found = line ''[[:space:]]*VERSION *= *"([^"]+)"( *\.freeze)? *'' ./lib/${path}/version.rb;
        in
        if found == null then
          throw "flake.nix: no VERSION = \"...\" line in version.rb"
        else
          lib.head found;
      # the SPDX identifiers of `spec.licenses = [...]` or `spec.license = "..."`
      licences =
        let
          found = line ''[[:space:]]*spec\.licenses? *= *(.*)'' ./${name}.gemspec;
        in
        if found == null then
          [ ]
        else
          lib.concatLists (lib.filter lib.isList (builtins.split ''"([^"]*)"'' (lib.head found)));
      command = builtins.pathExists ./exe/${name};

      # a check: its command run in the repository's files, its tools on PATH
      check =
        pkgs: checkName: tools: script:
        pkgs.runCommand checkName { nativeBuildInputs = tools; } ''
          cd ${self}
          ${script}
          touch $out
        '';

      perSystem =
        pkgs:
        let
          ruby = pkgs.ruby_4_0;
          # the gem's runtime dependencies (its gemspec's add_dependency), as nixpkgs packages
          # them: pkgs.rubyPackages_4_0.<gem>. The `library` check fails on one missing
          dependencies = [ ];
          package = pkgs.buildRubyGem {
            gemName = name;
            inherit version ruby;
            src = self;
            gemPath = dependencies;
            meta = {
              description = field "summary";
              homepage = field "homepage";
              license = map lib.getLicenseFromSpdxId licences;
            }
            // lib.optionalAttrs command { mainProgram = name; };
          };
          # the command as an OCI image: its closure alone -- no base image, no /bin/sh -- run as
          # nobody. `.#image.stream` streams the archive uncompressed (image.yml's: no second copy
          # of the closure in the store)
          image = pkgs.dockerTools.buildLayeredImage {
            inherit name;
            tag = version;
            # Dir.tmpdir's default, and HOME's: the image has no other directory to write
            extraCommands = "mkdir -m 1777 tmp";
            config = {
              Entrypoint = [ (lib.getExe package) ];
              # nobody: nothing in it needs root, and a numeric user needs no /etc/passwd
              User = "65534:65534";
              Env = [
                # UTF-8 text, ARGV and files alike (glibc's built-in locale)
                "LANG=C.UTF-8"
                "HOME=/tmp"
                # what OpenSSL verifies HTTPS against: the image has no /etc/ssl
                "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
              ];
              # what GHCR reads (docs.github.com, "Working with the Container registry"): the
              # source links the image to its repository
              Labels = lib.filterAttrs (_: value: value != "") {
                "org.opencontainers.image.title" = name;
                "org.opencontainers.image.description" = field "summary";
                "org.opencontainers.image.version" = version;
                "org.opencontainers.image.source" = field "homepage";
                "org.opencontainers.image.licenses" = lib.concatStringsSep " OR " licences;
              };
            };
          };
          linuxCommand = command && pkgs.stdenv.hostPlatform.isLinux;
        in
        {
          packages = {
            default = package;
          }
          // lib.optionalAttrs linuxCommand { inherit image; };

          checks = {
            format = check pkgs "format" [ pkgs.nixfmt ] "find . -name '*.nix' -exec nixfmt --check {} +";
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
            inherit package;
            # the library as a user loads it: the gem activated -- its dependencies with it -- then
            # required, in an environment of nothing else (env -i)
            library =
              pkgs.runCommand "library"
                {
                  gemPath = lib.concatMapStringsSep ":" (gem: "${gem}/${ruby.gemPath}") ([ package ] ++ dependencies);
                }
                ''
                  env -i GEM_PATH="$gemPath" ${lib.getExe ruby} -e 'gem "${name}"; require "${path}"'
                  touch $out
                '';
          }
          // lib.optionalAttrs command {
            # the command as a user runs it: its wrapper alone gives it its environment (env -i)
            command =
              pkgs.runCommand "command"
                {
                  exe = lib.getExe package;
                  expected = "${name} ${version}";
                }
                ''
                  actual=$(env -i "$exe" --version)
                  if [ "$actual" != "$expected" ]; then
                    echo "--version gave '$actual', expected '$expected'" >&2
                    exit 1
                  fi
                  touch $out
                '';
          }
          // lib.optionalAttrs linuxCommand { inherit image; };

          devShells.default = pkgs.mkShell {
            packages = [
              ruby
              pkgs.cocogitto
              pkgs.git-cliff
              pkgs.dprint
              pkgs.shellcheck
              pkgs.shfmt
              pkgs.actionlint
              pkgs.nixfmt
            ];
          };
        };
      output = attribute: forAllSystems (pkgs: (perSystem pkgs).${attribute});
    in
    {
      packages = output "packages";
      checks = output "checks";
      devShells = output "devShells";
      formatter = forAllSystems (pkgs: pkgs.nixfmt-tree);
    };
}
