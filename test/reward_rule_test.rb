# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/reward_rule"

class RewardRuleTest < Minitest::Test
  def test_default_rewards_for_terminal_results
    rule = RewardRule.new

    assert_equal 50, rule.xp_for(:win)
    assert_equal 25, rule.xp_for(:draw)
    assert_equal 20, rule.xp_for(:lose)
  end

  def test_custom_rewards_are_injectable
    rule = RewardRule.new(win_xp: 100, draw_xp: 40, lose_xp: 10)

    assert_equal 100, rule.xp_for(:win)
    assert_equal 40, rule.xp_for(:draw)
    assert_equal 10, rule.xp_for(:lose)
  end

  def test_unknown_result_rewards_zero
    assert_equal 0, RewardRule.new.xp_for(:preparing)
    assert_equal 0, RewardRule.new.xp_for(nil)
  end

  def test_default_money_for_terminal_results
    rule = RewardRule.new

    assert_equal 100, rule.money_for(:win)
    assert_equal 50, rule.money_for(:draw)
    assert_equal 40, rule.money_for(:lose)
  end

  def test_custom_money_is_injectable
    rule = RewardRule.new(win_money: 200, draw_money: 100, lose_money: 50)

    assert_equal 200, rule.money_for(:win)
    assert_equal 100, rule.money_for(:draw)
    assert_equal 50, rule.money_for(:lose)
  end

  def test_unknown_result_money_zero
    assert_equal 0, RewardRule.new.money_for(:preparing)
    assert_equal 0, RewardRule.new.money_for(nil)
  end

  def test_xp_defaults_preserved_when_money_injected
    rule = RewardRule.new(win_money: 200, draw_money: 100, lose_money: 50)

    assert_equal 50, rule.xp_for(:win)
    assert_equal 25, rule.xp_for(:draw)
  end
end
