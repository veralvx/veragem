# frozen_string_literal: true

require "rbconfig"
require "tmpdir"

module Veragem
  module Sync
    # The veragem a sync runs: a checkout (--path), or a release fetched from the gem sources, in a
    # Ruby of its own (Bundler's environment unset): its code, not the plugin's.
    module Source
      # What the Ruby of the veragem runs: the command's sync, or the harness it writes for the gem
      # into ARGV's directory; a refusal its message alone.
      SYNC = "Veragem::Sync.main(ARGV)"
      RENDER = "Veragem::Sync.render(Veragem::Record.read(Dir.pwd), ARGV.fetch(0))"
      # --path, or -p after the flags of a group: its directory, if joined to it
      PATH = /\A(?:--path(?:=(.*))?|-(?!-)[a-oq-z-]*p(.+)?)\z/m
      private_constant :SYNC, :RENDER, :PATH

      # Runs `bundle veragem-sync ARGV` in +dir+: the sync of the veragem --path names, or else of
      # the latest release.
      # @param argv [Array<String>] the command's arguments
      # @param dir [String] the gem's directory
      # @return [void]
      # @raise [Veragem::Error] --path has no directory, or no veragem with sync is found
      # @raise [SystemExit] the sync failed, its reason shown
      def self.launch(argv, dir: Dir.pwd)
        path = path_of(argv)
        Dir.mktmpdir("veragem-sync") do |tmp|
          root = path ? File.expand_path(path, dir) : fetch(nil, tmp)
          raise Error, "#{root} has no bundle veragem-sync: a veragem checkout has" unless sync?(root)

          exit(1) unless run(root, SYNC, argv, dir)
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
          next {} unless sync?(root) && run(root, RENDER, [out], dir)

          files = Dir.glob("**/*", File::FNM_DOTMATCH, base: out).select { File.file?(File.join(out, it)) }
          files.to_h { [it, File.binread(File.join(out, it))] }
        end
      end

      # The last --path's directory before --adopt and --, as OptionParser reads it: --path=DIR, or
      # -p closing a group of flags, DIR joined to it (-pDIR, -npDIR); else the next argument. Every
      # other argument is the veragem's to read.
      private_class_method def self.path_of(argv)
        args = argv.take_while { it != "--adopt" }.take_while { it != "--" }
        path = nil #: String?
        until args.empty?
          match = PATH.match(args.shift) or next
          path = match[1] || match[2] || args.shift ||
                 raise(Error, "missing argument: #{match[0]} (bundle veragem-sync --help)")
        end
        path
      end

      # veragem +version+, else the latest, unpacked into +dir+.
      private_class_method def self.fetch(version, dir)
        args = %w[fetch veragem]
        args << "--version=#{version}" if version
        gem_command(args, dir)
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

      private_class_method def self.run(root, call, argv, dir)
        script = "begin; #{call}; rescue Veragem::Error => e; abort(e.message); end"
        Bundler.with_unbundled_env do
          system(RbConfig.ruby, "-I", File.join(root, "lib"), "-rveragem", "-e", script, "--", *argv, chdir: dir)
        end
      end
    end
  end
end
