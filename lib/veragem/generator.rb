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
      skipped = skipped(project)
      files = Dir.glob("**/*", File::FNM_DOTMATCH, base: TEMPLATE).sort.to_h { [it, path_of(it, project)] }
      files.reject! { |file, _| skipped.include?(file) || File.directory?(File.join(TEMPLATE, file)) }
      check(project, files.values)
      check_command(project)
      files
    end

    # A name can be a tool's, which the Gemfile would name twice, or a template file's: `helper`'s
    # test would be test/test_helper.rb.
    def self.check(project, paths)
      raise Error, "invalid gem name #{project.name}: the Gemfile's own tool" if tools.include?(project.name)

      clash = paths.tally.find { |_, count| count > 1 }
      raise Error, "invalid gem name #{project.name}: it would write #{clash[0]} twice" if clash
    end

    # A command line in a module CLI: its code, in CLI::CLI, would take itself for CLI, the gem's.
    def self.check_command(project)
      return unless project.exe && project.modules.last == "CLI"

      raise Error, "invalid gem name #{project.name}: its command line, #{project.constant}::CLI, would take " \
                   "itself for CLI"
    end

    # The gems template/Gemfile names.
    def self.tools = File.read(File.join(TEMPLATE, "Gemfile")).scan(/^gem "([^"]+)"/).flatten

    # The files another kind or licence takes.
    def self.skipped(project)
      licenses = LICENSE_FILES.reject { |_, spdx| project.licenses.include?(spdx) }.keys
      project.exe ? licenses : licenses + EXE
    end

    def self.path_of(file, project)
      file.delete_suffix(".erb").gsub("%name%", project.name).gsub("%path%", project.path)
          .gsub("%underscored%", project.underscored)
    end

    # Into +target+, a new directory: a failure, an interrupt included, leaves none behind.
    def self.generate(project, target)
      raise Error, "#{target} already exists" if File.exist?(target) || File.symlink?(target)

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
