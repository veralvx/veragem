# frozen_string_literal: true

require "test_helper"

class TestSyncChoices < Minitest::Test
  include Veragem::SyncSupport

  def test_a_dry_run_changes_nothing
    in_gem do |gem|
      older(gem, ".yardopts", "old\n")
      write(gem, "Rakefile", "# mine, not committed\n")

      assert_equal "Sync #{HEADING}\n  sync .yardopts: veragem changed it, you did not\n  " \
                   "keep Rakefile: you changed it, veragem did not\n", sync(gem, "--dry-run")
      assert_equal " M Rakefile\n", status(gem)
    end
  end

  # asked again until a choice; what is not chosen keeps its base
  def test_interactive_takes_what_is_chosen
    in_gem do |gem|
      older(gem, ".yardopts", "old\n")
      write(gem, "Rakefile", "# mine\n")
      commit(gem)

      assert_equal "Sync #{HEADING}\n*1. .yardopts: veragem changed it, you did not\n " \
                   "2. Rakefile: you changed it, veragem did not\n#{prompt * 3}",
                   sync(gem, "--interactive", input: terminal("x", "3", "2"))
      assert_equal ["old\n", theirs_text(gem, "Rakefile")], [read(gem, ".yardopts"), read(gem, "Rakefile")]
      assert_equal id(gem, ".yardopts", "old\n"), recorded(gem, ".yardopts")
    end
  end

  def test_interactive_with_nothing_to_sync_asks_nothing
    in_gem do |gem|
      assert_equal "Nothing to sync #{HEADING}\n", sync(gem, "--interactive", input: terminal)
    end
  end

  # the marked, wherever they are shown
  def test_interactive_takes_the_marked_by_default
    in_gem do |gem|
      older(gem, ".yardopts", "old\n")
      write(gem, ".editorconfig", "# mine\n")
      older(gem, "Rakefile", "old\n")
      sync(gem, "--interactive", input: terminal(""))

      assert_equal [YARDOPTS, "# mine\n", theirs_text(gem, "Rakefile")],
                   [read(gem, ".yardopts"), read(gem, ".editorconfig"), read(gem, "Rakefile")]
    end
  end

  # yours replaced by veragem's: an adopted file, a removed one
  def test_interactive_takes_veragems_over_yours
    in_gem do |gem|
      write(gem, ".yardopts", "mine\n")
      File.delete(File.join(gem, "Rakefile"))
      rerecord(gem, { ".yardopts" => nil, "Rakefile" => id(gem, "Rakefile", "old\n") })
      sync(gem, "--interactive", input: terminal("all"))

      assert_equal [YARDOPTS, theirs_text(gem, "Rakefile")], [read(gem, ".yardopts"), read(gem, "Rakefile")]
    end
  end

  # yours deleted, as veragem's is
  def test_interactive_deletes_an_orphan
    in_gem do |gem|
      older(gem, "orphan", "mine\n", base: "x\n")
      sync(gem, "--interactive", input: terminal("1"))

      assert_equal [false, nil], [File.exist?(File.join(gem, "orphan")), recorded(gem, "orphan")]
    end
  end

  def test_interactive_needs_a_terminal_and_a_choice
    in_gem do |gem|
      older(gem, ".yardopts", "old\n")

      assert_equal "--interactive needs a terminal", refused(gem, "--interactive").first
      assert_equal "no choice made", refused(gem, "--interactive", input: terminal).first
      assert_equal "old\n", read(gem, ".yardopts")
    end
  end

  # each file veragem writes recorded as its, yours that differ kept: then your changes
  def test_adopting_records_the_harness
    in_gem do |gem|
      ids = Veragem::Record.read(gem).files
      File.delete(File.join(gem, ".veragem.yml"))
      write(gem, "Rakefile", "# mine\n")
      commit(gem)

      assert_equal "Sync #{HEADING}\n  keep Rakefile: yours differs from veragem's\n", sync(gem, *adopt)
      assert_equal ids, Veragem::Record.read(gem).files
      commit(gem)

      assert_equal "Sync #{HEADING}\n  keep Rakefile: you changed it, veragem did not\n", sync(gem)
    end
  end

  def test_adopting_a_gem_with_a_record_is_refused
    in_gem do |gem|
      assert_equal "#{gem} has .veragem.yml already: sync it without --adopt", refused(gem, *adopt).first
    end
  end

  private

  def adopt = ["--adopt", "my_gem", "--author=Jane Doe", "--github=jane", "--no-email"]

  def prompt = Veragem::Sync::Selection::PROMPT
end
