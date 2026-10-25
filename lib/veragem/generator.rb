# frozen_string_literal: true

require "erb"
require "fileutils"

module Veragem
  # Writes a Project's gem from template/: each `.erb` file rendered, every other copied, each with
  # its mode; then a git repository, its files added, as `bundle gem` leaves one.
  module Generator
    TEMPLATE = File.expand_path("../../template", __dir__) # steep:ignore ArgumentTypeMismatch
    # The files a command line alone needs.
    EXE = %w[exe/%name%.erb lib/%path%/cli.rb.erb test/test_cli.rb.erb].freeze
    # Each LICENSE-* file's SPDX identifier.
    LICENSE_FILES = { "LICENSE-MIT.erb" => "MIT", "LICENSE-APACHE.erb" => "Apache-2.0" }.freeze

    # Each template file the project takes, and its path in the gem.
    def self.files(project)
      files = Dir.glob("**/*", File::FNM_DOTMATCH, base: TEMPLATE).sort.to_h { [it, path_of(it, project)] }
      files.reject! { |file, _| skipped(project).include?(file) || File.directory?(File.join(TEMPLATE, file)) }
      # a name can be a template file's: `helper`'s test would be test/test_helper.rb
      clash = files.values.tally.find { |_, count| count > 1 }
      raise Error, "invalid gem name #{project.name}: it would write #{clash[0]} twice" if clash

      files
    end

    # The files another kind or licence takes.
    def self.skipped(project)
      licenses = LICENSE_FILES.reject { |_, spdx| project.licenses.include?(spdx) }.keys
      project.exe ? licenses : licenses + EXE
    end

    def self.path_of(file, project)
      file.delete_suffix(".erb").gsub("%name%", project.name).gsub("%path%", project.path)
          .gsub("%underscored%", project.underscored)
    end

    def self.generate(project, target)
      raise Error, "#{target} already exists" if File.exist?(target)

      files = files(project)
      begin
        files.each { |file, path| write(File.join(TEMPLATE, file), File.join(target, path), project) }
        git(target, "init", "--quiet", "--initial-branch=main")
        git(target, "add", "--all")
      rescue StandardError
        FileUtils.rm_rf(target) # it did not exist: no half-made gem left behind
        raise
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
      system("git", *args, chdir: dir) or raise Error, "git #{args.join(" ")} failed in #{dir}"
    end
  end
end
