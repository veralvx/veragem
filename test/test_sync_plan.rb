# frozen_string_literal: true

require "test_helper"

class TestSyncPlan < Minitest::Test
  Plan = Veragem::Sync::Plan
  Selection = Veragem::Sync::Selection

  # base, ours, theirs: the action
  ACTIONS = {
    %w[b t t] => :same, [nil, "o", "o"] => :same, ["b", nil, nil] => :same,
    [nil, nil, "t"] => :add, [nil, "o", "t"] => :conflict,
    ["b", nil, "t"] => :removed, ["b", "b", nil] => :delete, ["b", "o", nil] => :orphan,
    %w[b b t] => :update, %w[b o b] => :keep, %w[b o t] => :merge
  }.freeze

  def test_each_case_has_its_action
    ACTIONS.each { |ids, action| assert_equal action, Plan.action(*ids), ids.inspect }
  end

  # adopted, a file that differs is the gem's own; every other case as without
  def test_adopting_a_file_that_differs_keeps_it
    assert_equal :adopted, Plan.action(nil, "o", "t", adopt: true)
    assert_equal :add, Plan.action(nil, nil, "t", adopt: true)
    assert_equal :same, Plan.action(nil, "t", "t", adopt: true)
  end

  def test_the_rows_are_every_path_sorted
    rows = Plan.rows({ "b" => "1", "c" => "1" }, { "a" => "2", "b" => "1" }, { "b" => "3", "a" => "2" })

    assert_equal [Plan::Row.new("a", :same, nil, "2", "2"), Plan::Row.new("b", :update, "1", "1", "3"),
                  Plan::Row.new("c", :same, "1", nil, nil)], rows
  end

  def test_the_rows_adopt
    assert_equal [:adopted], Plan.rows({}, { "a" => "1" }, { "a" => "2" }, adopt: true).map(&:action)
  end

  # applied: theirs; removed, adopted and same: theirs, unapplied; every other its base; none, unrecorded
  def test_the_record_takes_the_applied_files_theirs
    rows = %i[update keep removed adopted same orphan delete conflict].map.with_index do |action, n|
      Plan::Row.new("f#{n}", action, ("b#{n}" unless action == :conflict), "o#{n}", ("t#{n}" unless action == :delete))
    end
    applied = [rows[0], rows[6]]

    assert_equal({ "f0" => "t0", "f1" => "b1", "f2" => "t2", "f3" => "t3", "f4" => "t4", "f5" => "b5" },
                 Plan.recorded(rows, applied))
  end

  def test_only_the_safe_actions_apply_unasked
    assert_equal %i[add update delete merge], Plan::APPLIED
  end

  def test_a_choice_is_numbers_ranges_all_none_or_the_defaults
    {
      "" => [2], "  \n" => [2], "all" => [1, 2, 3, 4], "ALL\n" => [1, 2, 3, 4], "none" => [], "3" => [3],
      "1,3-4" => [1, 3, 4], " 4 , 1-2 " => [1, 2, 4], "2-2,2" => [2], "1-4" => [1, 2, 3, 4]
    }.each { |answer, chosen| assert_equal chosen, Selection.parse(answer, 4, [2]), answer.inspect }
  end

  def test_what_is_no_choice_is_nil
    ["0", "5", "1-5", "3-1", "0-2", "1,", "a", "1 2", "-1", "1-", "all,1"].each do |answer|
      assert_nil Selection.parse(answer, 4, [2]), answer.inspect
    end
  end
end
