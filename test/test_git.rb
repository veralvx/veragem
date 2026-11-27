# frozen_string_literal: true

require "test_helper"

class TestGit < Minitest::Test
  include Veragem::TestSupport

  def test_its_output_as_bytes
    in_tmpdir do |dir|
      Veragem::Git.run(dir, "init", "--quiet")
      output = Veragem::Git.output(dir, "rev-parse", "--git-dir")

      assert_equal [".git\n", Encoding::BINARY], [output, output.encoding]
    end
  end

  # as `git add` writes them: the ids its index holds
  def test_the_ids_are_the_indexs
    in_tmpdir do |dir|
      Veragem::Git.run(dir, "init", "--quiet")
      %w[a b].each { File.binwrite(File.join(dir, it), "#{it}\n") }
      Veragem::Git.run(dir, "add", "a", "b")
      indexed = Veragem::Git.output(dir, "ls-files", "--format=%(path) %(objectname)").lines(chomp: true)

      assert_equal indexed.to_h(&:split), Veragem::Git.ids(dir, %w[a b])
      assert_empty Veragem::Git.ids(dir, [])
    end
  end

  def test_a_failure_says_which
    in_tmpdir do |dir|
      [-> { Veragem::Git.run(dir, "no", "such") }, -> { Veragem::Git.output(dir, "no", "such") }].each do |call|
        assert_equal "git no such failed in #{dir}", assert_raises(Veragem::Error, &call).message
      end
    end
  end

  def test_without_git_it_says_so
    in_tmpdir do |dir|
      with_env("PATH" => "") do
        [-> { Veragem::Git.run(dir, "status") }, -> { Veragem::Git.output(dir, "status") }].each do |call|
          assert_equal "cannot run git in #{dir}", assert_raises(Veragem::Error, &call).message
        end
      end
    end
  end

  # as `git add` hashes it there, and written
  def test_an_id_is_of_bytes_at_a_path
    in_tmpdir do |dir|
      Veragem::Git.run(dir, "init", "--quiet")
      File.binwrite(File.join(dir, "a"), "a\n")
      id = Veragem::Git.id(dir, "a", "a\n")

      assert_equal Veragem::Git.ids(dir, ["a"]).fetch("a"), id
      assert Veragem::Git.object?(dir, id)
      refute Veragem::Git.object?(dir, "0" * 40)
      assert_equal "a\n", Veragem::Git.output(dir, "cat-file", "blob", id)
    end
  end

  def test_a_merge_says_how_many_conflicts
    in_tmpdir do |dir|
      Veragem::Git.run(dir, "init", "--quiet")
      { "ours" => "a\nb\nc\n", "other" => "y\nb\n" }.each { |name, text| File.binwrite(File.join(dir, name), text) }

      assert_equal ["z\nb\nc\n", 0], Veragem::Git.merge(dir, "ours", "a\nb\n", "z\nb\n")
      assert_equal ["<<<<<<< other\ny\n=======\nz\n>>>>>>> veragem\nb\n", 1],
                   Veragem::Git.merge(dir, "other", "a\nb\n", "z\nb\n")
    end
  end

  # its status at most 127, however many: more is git's failure
  def test_a_merge_of_many_conflicts_is_one
    in_tmpdir do |dir|
      Veragem::Git.run(dir, "init", "--quiet")
      side = ->(name) { (1..130).map { "#{it}\n#{"-\n" * 4}#{name}\n" }.join }
      File.binwrite(File.join(dir, "ours"), side.call("ours"))

      assert_equal 127, Veragem::Git.merge(dir, "ours", side.call("base"), side.call("theirs")).last
    end
  end

  def test_a_merge_that_fails_says_so
    in_tmpdir do |dir|
      Veragem::Git.run(dir, "init", "--quiet")
      error = assert_raises(Veragem::Error) { capture_subprocess_io { Veragem::Git.merge(dir, "none", "a\n", "b\n") } }

      assert_equal "git merge-file none failed in #{dir}", error.message
    end
  end

  def test_input_is_given
    in_tmpdir do |dir|
      assert_equal "a\n", Veragem::Git.output(dir, "stripspace", input: "a\n\n")
    end
  end

  # in the index, whatever the file system's mode; none, nothing
  def test_files_are_staged_executable
    in_tmpdir do |dir|
      Veragem::Git.run(dir, "init", "--quiet")
      File.binwrite(File.join(dir, "a"), "a\n")
      Veragem::Git.executable(dir, [])
      Veragem::Git.executable(dir, ["a"])

      assert_equal "100755 a", Veragem::Git.output(dir, "ls-files", "--format=%(objectmode) %(path)").chomp
    end
  end
end
