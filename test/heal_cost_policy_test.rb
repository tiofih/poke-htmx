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

  def test_cost_scales_with_average_level
    assert_equal 5, @policy.cost(10, 5), "nivel medio base mantem o custo"
    assert_equal 8, @policy.cost(10, 10), "nivel medio alto capa em 1.5x"
    assert_equal 1, @policy.cost(10, 1), "nivel medio menor reduz o custo"
  end

  def test_cost_clamps_negative_missing_hp_to_zero
    assert_equal 0, @policy.cost(-5)
    assert_equal 0, @policy.cost(-5, 10)
  end

  def test_cost_caps_level_multiplier_at_1_5x
    assert_equal 8, @policy.cost(10, 100), "multiplicador de nivel limitado a 1.5x"
    assert_equal 8, @policy.cost(10, 8), "nivel 8 (1.6x) ja capa em 1.5x"
    assert_equal 7, @policy.cost(10, 7), "nivel 7 (1.4x) abaixo do teto, sem capa"
  end

  def test_capped_cost_per_hp_never_exceeds_potion_rate
    assert_operator @policy.cost(20, 100) / 20.0, :<=, 1.0, "center <= pocao por HP"
  end
end
