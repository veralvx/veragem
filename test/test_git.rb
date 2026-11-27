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
      %w[a b].each { File.write(File.join(dir, it), "#{it}\n") }
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
      File.write(File.join(dir, "a"), "a\n")
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
      { "base" => "a\nb\n", "ours" => "a\nb\nc\n", "theirs" => "z\nb\n", "other" => "y\nb\n" }.each do |name, text|
        File.write(File.join(dir, name), text)
      end

      assert_equal ["z\nb\nc\n", 0], Veragem::Git.merge(dir, "ours", "base", "theirs")
      assert_equal ["<<<<<<< other\ny\n=======\nz\n>>>>>>> veragem\nb\n", 1],
                   Veragem::Git.merge(dir, "other", "base", "theirs")
    end
  end

  # its status at most 127, however many: more is git's failure
  def test_a_merge_of_many_conflicts_is_one
    in_tmpdir do |dir|
      Veragem::Git.run(dir, "init", "--quiet")
      %w[base ours theirs].each do |side|
        File.write(File.join(dir, side), (1..130).map { "#{it}\n#{"-\n" * 4}#{side}\n" }.join)
      end

      assert_equal 127, Veragem::Git.merge(dir, "ours", "base", "theirs").last
    end
  end

  def test_a_merge_that_fails_says_so
    in_tmpdir do |dir|
      Veragem::Git.run(dir, "init", "--quiet")
      File.write(File.join(dir, "ours"), "a\n")

      error = assert_raises(Veragem::Error) { capture_subprocess_io { Veragem::Git.merge(dir, "ours", "none", "ours") } }

      assert_equal "git merge-file ours failed in #{dir}", error.message
    end
  end

  def test_input_is_given
    in_tmpdir do |dir|
      assert_equal "a\n", Veragem::Git.output(dir, "stripspace", input: "a\n\n")
    end
  end
end
