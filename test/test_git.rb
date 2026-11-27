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
end
