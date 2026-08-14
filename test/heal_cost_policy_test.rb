# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/heal_cost_policy"

class HealCostPolicyTest < Minitest::Test
  def setup
    @policy = HealCostPolicy.new
  end

  def test_default_cost_per_hp
    assert_equal 0.5, HealCostPolicy::DEFAULT_COST_PER_HP
  end

  def test_missing_hp_is_the_difference
    assert_equal 10, @policy.missing_hp(45, 35)
  end

  def test_missing_hp_is_zero_when_full
    assert_equal 0, @policy.missing_hp(45, 45)
  end

  def test_missing_hp_is_zero_when_above_max
    assert_equal 0, @policy.missing_hp(45, 60)
  end

  def test_missing_hp_is_zero_when_never_battled
    assert_equal 0, @policy.missing_hp(0, 0)
    assert_equal 0, @policy.missing_hp(0, 5)
  end

  def test_cost_is_proportional_to_missing_hp
    assert_equal 5, @policy.cost(10)
    assert_equal 23, @policy.cost(45)
    assert_equal 0, @policy.cost(0)
  end

  def test_cost_uses_injectable_rate
    policy = HealCostPolicy.new(cost_per_hp: 2)
    assert_equal 20, policy.cost(10)
    assert_equal 0, policy.cost(0)
  end
end
