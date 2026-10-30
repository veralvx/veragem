# frozen_string_literal: true

require "erb"
require "fileutils"

module Veragem
  # Writes a Project's gem from template/: each `.erb` file rendered, every other copied, each with
  # its mode; then a git repository, its files added, as `bundle gem` leaves one.
  module Generator
    # template/: a generated gem's files, ERB and plain. (Steep: __dir__ is nil only in code evaluated
    # from a string, never in a required file.)
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
    # The citation's file, a citation's alone (--citation).
    CITATION = "CITATION.cff.erb"
    # The tools' resolution: this repository's Gemfile is the template's (test_sync.rb), so its lock
    # names every gem a generated gem's tools load, theirs included. (Steep: as TEMPLATE.)
    TOOLS_LOCK = File.expand_path("../../Gemfile.lock", __dir__) # steep:ignore ArgumentTypeMismatch
    private_constant :GIT_LOCAL, :LICENSE_FILES, :CITATION, :TOOLS_LOCK

    # Into +target+, a new directory: a failure, an interrupt included, leaves none behind.
    # @param project [Veragem::Project] the gem
    # @param target [String] its directory, not yet there
    # @return [void]
    # @raise [Veragem::Error] +target+ exists, its name cannot be generated, or a write or git fails
    def self.generate(project, target)
      check(project.name, exe: project.exe, citation: project.citation, target:)
      written = files(project)
      Dir.mkdir(target)
      removed_unless_done(target) do
        written.each { |file, path| write(File.join(TEMPLATE, file), File.join(target, path), project) }
        git(target, "init", "--quiet", "--initial-branch=main")
        # --force: the user's own excludes (core.excludesFile) keep none of the gem's files out
        git(target, "add", "--all", "--force")
      end
    rescue SystemCallError => e
      raise Error, e.message
    end

    # Every rule a gem's name meets before anything is written, its kinds' and its directory's: the
    # questions' and the generation's one check.
    # @param name [String] as typed
    # @param exe [Boolean] whether the gem has a command line
    # @param citation [Boolean] whether the gem has CITATION.cff
    # @param target [String] its directory, not yet there
    # @return [String] +name+
    # @raise [Veragem::Error] the gem cannot have the name, or +target+ exists
    def self.check(name, exe:, citation:, target:)
      Name.check(name)
      check_name(name, exe)
      Citation.check_name(name, citation)
      Name.check_modules(name)
      check_target(target)
      name
    end

    # What a name and its kind decide. A gem the Gemfile's tools load (its lock's), the bundle would
    # resolve to the new gem itself and break them. A command line names
    # the gem's module from within it, <Gem>::CLI, whose constant lookup finds CLI and VERSION first:
    # neither can be its module. Two files at one path: `helper`'s test would be test/test_helper.rb.
    # @param name [String] one Name.check takes
    # @param exe [Boolean] whether the gem has a command line
    # @return [void]
    # @raise [Veragem::Error] the kind cannot have the name
    def self.check_name(name, exe)
      raise Error, "invalid gem name #{name}: a gem the Gemfile's tools load" if tools.include?(name)

      innermost = Name.modules(name).last
      if exe && %w[CLI VERSION].include?(innermost)
        raise Error, "invalid gem name #{name}: its command line would find another #{innermost} before its module"
      end

      clash = templates(exe).map { path_of(it, name) }.tally.find { |_, count| count > 1 }
      raise Error, "invalid gem name #{name}: it would write #{clash[0]} twice" if clash
    end

    # +target+ is free: neither a file nor a link, dangling ones too
    private_class_method def self.check_target(target)
      raise Error, "#{target} already exists" if File.exist?(target) || File.symlink?(target)
    end

    private_class_method def self.files(project)
      skipped = LICENSE_FILES.reject { |_, spdx| project.licenses.include?(spdx) }.keys
      skipped << CITATION unless project.citation
      (templates(project.exe) - skipped).to_h { [it, path_of(it, project.name)] }
    end

    # The template's files a kind takes (+exe+, a command line's too), each licence's included.
    private_class_method def self.templates(exe)
      files = Dir.glob("**/*", File::FNM_DOTMATCH, base: TEMPLATE).sort
      files.reject { File.directory?(File.join(TEMPLATE, it)) || (!exe && EXE.include?(it)) }
    end

    # The lock's gems, its GEM section's specs (a dependency indented deeper), its lines LF's or CRLF's
    private_class_method def self.tools
      File.read(TOOLS_LOCK)[/^GEM\r?\n.*?^\r?$/m].to_s.scan(/^ {4}(\S+) \(/).flatten
    end

    private_class_method def self.path_of(file, name)
      file.delete_suffix(".erb").gsub("%name%", name).gsub("%path%", Name.path(name))
          .gsub("%underscored%", Name.underscored(name))
    end

    private_class_method def self.removed_unless_done(target)
      done = false
      begin
        yield
        done = true
      ensure
        FileUtils.rm_rf(target) unless done
      end
    end

    private_class_method def self.write(source, destination, project)
      FileUtils.mkdir_p(File.dirname(destination))
      File.binwrite(destination, source.end_with?(".erb") ? render(source, project) : File.binread(source))
      return unless File.executable?(source)

      # executable where readable, as `chmod +x` under the umask
      mode = File.stat(destination).mode
      File.chmod(mode | ((mode & 0o444) >> 2), destination)
    end

    # The ERB's values are +project+'s: its methods, called bare.
    private_class_method def self.render(source, project)
      ERB.new(File.read(source, encoding: Encoding::UTF_8), trim_mode: "-").result(project.instance_eval { binding })
    end

    private_class_method def self.git(dir, *args)
      system(GIT_LOCAL, "git", *args, chdir: dir) or raise Error, "git #{args.join(" ")} failed in #{dir}"
    end
  end
end
