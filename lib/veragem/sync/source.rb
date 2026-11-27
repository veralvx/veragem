# frozen_string_literal: true

require "rbconfig"
require "tmpdir"

module Veragem
  module Sync
    # The veragem a sync runs: a checkout (--path), or a release fetched from the gem sources, in a
    # Ruby of its own (Bundler's environment unset): its code, not the plugin's.
    module Source
      # What the Ruby of the veragem runs: Sync.main, a refusal its message alone.
      SCRIPT = "begin; Veragem::Sync.main(ARGV); rescue Veragem::Error => e; abort(e.message); end"
      private_constant :SCRIPT

      # Runs `bundle veragem-sync ARGV` in +dir+: the sync of the veragem --path names, or else of
      # the latest release.
      # @param argv [Array<String>] the command's arguments
      # @param dir [String] the gem's directory
      # @return [void]
      # @raise [Veragem::Error] an option is refused, or no veragem with sync is found
      # @raise [SystemExit] the sync failed, its reason shown
      def self.launch(argv, dir: Dir.pwd)
        path = Sync.options(argv).first[:path]
        Dir.mktmpdir("veragem-sync") do |tmp|
          root = path ? File.expand_path(path.to_s, dir) : fetch(nil, tmp)
          raise Error, "#{root} has no bundle veragem-sync: a veragem checkout has" unless sync?(root)

          exit(1) unless run(root, argv, dir)
        end
      end

      # The harness the release +version+ writes for the gem in +dir+, each file's bytes by its path;
      # none if the release has no sync, or it fails.
      # @param version [String]
      # @param dir [String] the gem's directory
      # @return [Hash{String => String}]
      # @raise [Veragem::Error] the release cannot be fetched
      def self.harness(version, dir)
        Dir.mktmpdir("veragem-sync") do |tmp|
          root = fetch(version, tmp)
          out = File.join(tmp, "harness")
          next {} unless sync?(root) && run(root, ["--render", out], dir)

          files = Dir.glob("**/*", File::FNM_DOTMATCH, base: out).select { File.file?(File.join(out, it)) }
          files.to_h { [it, File.binread(File.join(out, it))] }
        end
      end

      # veragem +version+, else the latest, unpacked into +dir+.
      private_class_method def self.fetch(version, dir)
        gem_command(["fetch", "veragem", "--version=#{version || ">= 0"}"], dir)
        gem = Dir.glob("veragem-*.gem", base: dir).first
        raise Error, "cannot fetch veragem #{version || "(the latest)"} from the gem sources" unless gem

        gem_command(["unpack", gem, "--target=#{dir}"], dir)
        File.join(dir, File.basename(gem, ".gem"))
      end

      # RubyGems' `gem` command, of this Ruby whichever `gem` is first in PATH, and no gem's plugin
      private_class_method def self.gem_command(args, dir)
        Bundler.with_unbundled_env do
          system(RbConfig.ruby, "-rrubygems/command_manager", "-e", "Gem::CommandManager.instance.run(ARGV)", "--",
                 *args, chdir: dir, out: File::NULL)
        end
      end

      private_class_method def self.sync?(root) = File.file?(File.join(root, "lib", "veragem", "sync.rb"))

      private_class_method def self.run(root, argv, dir)
        Bundler.with_unbundled_env do
          system(RbConfig.ruby, "-I", File.join(root, "lib"), "-rveragem", "-e", SCRIPT, "--", *argv, chdir: dir)
        end
      end
    end
  end
end
