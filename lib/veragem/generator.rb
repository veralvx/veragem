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
      skipped = LICENSE_FILES.reject { |_, spdx| project.licenses.include?(spdx) }.keys
      skipped += EXE unless project.exe
      Dir.glob("**/*", File::FNM_DOTMATCH, base: TEMPLATE).sort.filter_map do |file|
        [file, path_of(file, project)] unless skipped.include?(file) || File.directory?(File.join(TEMPLATE, file))
      end
    end

    def self.path_of(file, project)
      file.delete_suffix(".erb").gsub("%name%", project.name).gsub("%path%", project.path)
          .gsub("%underscored%", project.underscored)
    end

    def self.generate(project, target)
      raise Error, "#{target} already exists" if File.exist?(target)

      files(project).each { |file, path| write(File.join(TEMPLATE, file), File.join(target, path), project) }
      git(target, "init", "--quiet", "--initial-branch=main")
      git(target, "add", "--all")
    end

    def self.write(source, destination, project)
      FileUtils.mkdir_p(File.dirname(destination))
      File.binwrite(destination, source.end_with?(".erb") ? render(source, project) : File.binread(source))
      File.chmod(File.stat(source).mode & 0o755, destination)
    end

    def self.render(source, project)
      ERB.new(File.read(source, encoding: Encoding::UTF_8), trim_mode: "-").result(project.instance_eval { binding })
    end

    def self.git(dir, *args)
      system("git", *args, chdir: dir, exception: true)
    rescue SystemCallError, RuntimeError => e
      raise Error, "git #{args.first} in #{dir}: #{e.message}"
    end
  end
end
