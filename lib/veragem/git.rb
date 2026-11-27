# frozen_string_literal: true

require "tmpdir"

module Veragem
  # git, run in a gem's repository whatever repository a git hook running veragem points at, and
  # never reading the terminal's input.
  module Git
    # git's variables that point it at another repository (`git rev-parse --local-env-vars`, but the
    # configuration given with `git -c`), which a git hook sets: unset, the repository is the gem's.
    LOCAL = %w[GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CONFIG GIT_OBJECT_DIRECTORY GIT_DIR GIT_WORK_TREE
               GIT_IMPLICIT_WORK_TREE GIT_GRAFT_FILE GIT_INDEX_FILE GIT_NO_REPLACE_OBJECTS GIT_REPLACE_REF_BASE
               GIT_PREFIX GIT_SHALLOW_FILE GIT_COMMON_DIR].to_h { [it, nil] }.freeze
    private_constant :LOCAL

    # Runs git in +dir+.
    # @param dir [String] the repository's directory
    # @param args [Array<String>] git's arguments
    # @return [void]
    # @raise [Veragem::Error] git could not run, or failed
    def self.run(dir, *args)
      # system's nil: git could not run; false: it failed
      case system(LOCAL, "git", *args, chdir: dir, in: File::NULL)
      when nil then raise Error, "cannot run git in #{dir}"
      when false then raise Error, "git #{args.join(" ")} failed in #{dir}"
      end
    end

    # git's output in +dir+, as bytes.
    # @param dir [String] the repository's directory
    # @param args [Array<String>] git's arguments
    # @param input [String, nil] its input; none, an empty one
    # @return [String]
    # @raise [Veragem::Error] git could not run, or failed
    def self.output(dir, *args, input: nil)
      output, status = capture(dir, args, input)
      raise Error, "git #{args.join(" ")} failed in #{dir}" unless status.success?

      output
    end

    # The object id git gives each of +paths+ in +dir+, as `git add` would: its attributes' filters
    # applied.
    # @param dir [String] the repository's directory
    # @param paths [Array<String>] files in it
    # @return [Hash{String => String}] each path's id
    # @raise [Veragem::Error] git could not run, or failed
    def self.ids(dir, paths)
      paths.zip(output(dir, "hash-object", "--", *paths).lines(chomp: true)).to_h
    end

    # The object id of +bytes+ as `git add` would give them at +path+ in +dir+, the object written,
    # so that a merge finds it as a base.
    # @param dir [String] the repository's directory
    # @param path [String] where in it
    # @param bytes [String]
    # @return [String]
    # @raise [Veragem::Error] git could not run, or failed
    def self.id(dir, path, bytes) = output(dir, "hash-object", "-w", "--stdin", "--path=#{path}", input: bytes).chomp

    # Whether +dir+'s repository holds the object +id+.
    # @param dir [String] the repository's directory
    # @param id [String]
    # @return [Boolean]
    # @raise [Veragem::Error] git could not run
    def self.object?(dir, id) = capture(dir, ["cat-file", "-e", id], nil)[1].success?

    # +ours+ with what changed from +base+ to +theirs+, as `git merge-file` merges them, and how many
    # conflicts it marked.
    # @param dir [String] the repository's directory
    # @param ours [String] the file to merge into, in +dir+
    # @param base [String] their common base's bytes
    # @param theirs [String] the other side's bytes
    # @return [Array(String, Integer)]
    # @raise [Veragem::Error] git could not run, or failed
    def self.merge(dir, ours, base, theirs)
      Dir.mktmpdir("veragem-merge") do |tmp|
        files = { "base" => base, "theirs" => theirs }.map { |name, bytes| written(File.join(tmp, name), bytes) }
        labels = ["-L", ours, "-L", "base", "-L", "veragem"]
        output, status = capture(dir, ["merge-file", "--stdout", *labels, ours, *files], nil)
        # its status the count of conflicts, at most 127; an error's -1, 255
        conflicts = status.exitstatus.to_i
        raise Error, "git merge-file #{ours} failed in #{dir}" if conflicts > 127

        [output, conflicts]
      end
    end

    private_class_method def self.written(path, bytes) = path.tap { File.binwrite(path, bytes) }

    private_class_method def self.capture(dir, args, input)
      output = IO.popen(LOCAL, ["git", *args], "r+", chdir: dir, binmode: true) do |git|
        git.write(input) if input
        git.close_write
        git.read
      end #: String
      status = $? #: Process::Status
      [output, status]
    rescue SystemCallError
      raise Error, "cannot run git in #{dir}"
    end
  end
end
