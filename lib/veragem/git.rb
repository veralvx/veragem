# frozen_string_literal: true

module Veragem
  # git, run in a gem's repository whatever repository a git hook running veragem points at.
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
      case system(LOCAL, "git", *args, chdir: dir)
      when nil then raise Error, "cannot run git in #{dir}"
      when false then raise Error, "git #{args.join(" ")} failed in #{dir}"
      end
    end
  end
end
