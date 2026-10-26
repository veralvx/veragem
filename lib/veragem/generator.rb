# frozen_string_literal: true

require "erb"
require "fileutils"

module Veragem
  # Writes a Project's gem from template/: each `.erb` file rendered, every other copied, each with
  # its mode; then a git repository, its files added, as `bundle gem` leaves one.
  module Generator
    # __dir__ is nil only in code evaluated from a string, never in a required file
    TEMPLATE = File.expand_path("../../template", __dir__) # steep:ignore ArgumentTypeMismatch
    # The files a command line alone needs: its code, its test, its OCI image's workflow.
    EXE = %w[exe/%name%.erb lib/%path%/cli.rb.erb test/test_cli.rb.erb .github/workflows/image.yml
             .github/image-registries.sh].freeze
    # git's variables that point it at another repository (`git rev-parse --local-env-vars`, but the
    # configuration given with `git -c`), which a git hook sets: unset, the repository is the gem's.
    GIT_LOCAL = %w[GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CONFIG GIT_OBJECT_DIRECTORY GIT_DIR GIT_WORK_TREE
                   GIT_IMPLICIT_WORK_TREE GIT_GRAFT_FILE GIT_INDEX_FILE GIT_NO_REPLACE_OBJECTS GIT_REPLACE_REF_BASE
                   GIT_PREFIX GIT_SHALLOW_FILE GIT_COMMON_DIR].to_h { [it, nil] }.freeze
    # Each LICENSE-* file's SPDX identifier.
    LICENSE_FILES = { "LICENSE-MIT.erb" => "MIT", "LICENSE-APACHE.erb" => "Apache-2.0" }.freeze

    # Each template file the project takes, and its path in the gem.
    def self.files(project)
      check_name(project.name, project.exe)
      licenses = LICENSE_FILES.reject { |_, spdx| project.licenses.include?(spdx) }.keys
      (templates(project.exe) - licenses).to_h { [it, path_of(it, project.name)] }
    end

    # The template's files a kind takes (+exe+, a command line's too), each licence's included.
    def self.templates(exe)
      files = Dir.glob("**/*", File::FNM_DOTMATCH, base: TEMPLATE).sort
      files.reject { File.directory?(File.join(TEMPLATE, it)) || (!exe && EXE.include?(it)) }
    end

    # What a name and its kind decide. A tool's, the Gemfile would name twice. A command line names
    # the gem's module from within it, <Gem>::CLI, whose constant lookup finds CLI and VERSION first:
    # neither can be its module. Two files at one path: `helper`'s test would be test/test_helper.rb.
    def self.check_name(name, exe)
      raise Error, "invalid gem name #{name}: the Gemfile's own tool" if tools.include?(name)

      innermost = Name.modules(name).last
      if exe && %w[CLI VERSION].include?(innermost)
        raise Error, "invalid gem name #{name}: its command line would find another #{innermost} before its module"
      end

      clash = templates(exe).map { path_of(it, name) }.tally.find { |_, count| count > 1 }
      raise Error, "invalid gem name #{name}: it would write #{clash[0]} twice" if clash
    end

    def self.check_target(target)
      raise Error, "#{target} already exists" if File.exist?(target) || File.symlink?(target)
    end

    # The gems template/Gemfile names.
    def self.tools = File.read(File.join(TEMPLATE, "Gemfile")).scan(/^gem "([^"]+)"/).flatten

    def self.path_of(file, name)
      file.delete_suffix(".erb").gsub("%name%", name).gsub("%path%", Name.path(name))
          .gsub("%underscored%", Name.underscored(name))
    end

    # Into +target+, a new directory: a failure, an interrupt included, leaves none behind.
    def self.generate(project, target)
      check_target(target)
      files = files(project)
      Dir.mkdir(target)
      removed_unless_done(target) do
        files.each { |file, path| write(File.join(TEMPLATE, file), File.join(target, path), project) }
        git(target, "init", "--quiet", "--initial-branch=main")
        git(target, "add", "--all")
      end
    rescue SystemCallError => e
      raise Error, e.message
    end

    def self.removed_unless_done(target)
      done = false
      begin
        yield
        done = true
      ensure
        FileUtils.rm_rf(target) unless done
      end
    end

    def self.write(source, destination, project)
      FileUtils.mkdir_p(File.dirname(destination))
      File.binwrite(destination, source.end_with?(".erb") ? render(source, project) : File.binread(source))
      return unless File.executable?(source)

      # executable where readable, as `chmod +x` under the umask
      mode = File.stat(destination).mode
      File.chmod(mode | ((mode & 0o444) >> 2), destination)
    end

    def self.render(source, project)
      ERB.new(File.read(source, encoding: Encoding::UTF_8), trim_mode: "-").result(project.instance_eval { binding })
    end

    def self.git(dir, *args)
      system(GIT_LOCAL, "git", *args, chdir: dir) or raise Error, "git #{args.join(" ")} failed in #{dir}"
    end
  end
end
