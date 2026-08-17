# frozen_string_literal: true

require "minitest/autorun"
require_relative "test_support"
require_relative "../lib/item_use_policy"

class ItemUsePolicyTest < Minitest::Test
  include TestSupport

  def member_with_hp(hp_current, hp_max = 100)
    build_pokemon(number: 1, name: "pikachu", types: ["electric"], hp: hp_max, speed: 90)
            .new(hp_current: hp_current)
  end

  def policy(threshold: 0.5)
    ItemUsePolicy.new(threshold: threshold)
  end

  def test_default_threshold_is_half
    assert_equal 0.5, ItemUsePolicy::DEFAULT_THRESHOLD
  end

  def test_decide_returns_nil_when_hp_is_full
    assert_nil policy.decide(member: member_with_hp(100), stock: { "potion" => 2 })
  end

  def test_decide_returns_nil_when_hp_is_above_threshold
    assert_nil policy.decide(member: member_with_hp(70), stock: { "potion" => 2 })
  end

  def test_decide_returns_nil_with_empty_stock
    assert_nil policy.decide(member: member_with_hp(30), stock: {})
  end

  def test_decide_chooses_smallest_heal_that_covers_missing_hp
    stock = { "potion" => 2, "super-potion" => 1, "hyper-potion" => 1 }

    assert_equal "super-potion", policy.decide(member: member_with_hp(50), stock: stock)
  end

  def test_decide_uses_larger_heal_when_none_covers_missing
    stock = { "potion" => 1, "super-potion" => 1, "hyper-potion" => 1 }

    assert_equal "hyper-potion", policy.decide(member: member_with_hp(10), stock: stock)
  end

  def test_decide_uses_best_available_when_none_covers
    assert_equal "potion", policy.decide(member: member_with_hp(1), stock: { "potion" => 1 })
  end

  def test_decide_ignores_items_not_in_catalog
    member = member_with_hp(30)
    stock = { "master-ball" => 5, "potion" => 1 }

    assert_equal "potion", policy.decide(member: member, stock: stock)
  end

  def test_decide_ignores_zero_quantity
    assert_nil policy.decide(member: member_with_hp(30), stock: { "potion" => 0 })
  end

  def test_decide_respects_injectable_threshold
    relaxed = policy(threshold: 0.9)

    assert_nil policy.decide(member: member_with_hp(80), stock: { "potion" => 1 }), "default 0.5 nao usa em 80%"
    assert_equal "potion", relaxed.decide(member: member_with_hp(80), stock: { "potion" => 1 })
  end

  def test_decide_is_deterministic
    stock = { "potion" => 1, "hyper-potion" => 1 }
    member = member_with_hp(50)

    assert_equal "hyper-potion", policy.decide(member: member, stock: stock)
    assert_equal "hyper-potion", policy.decide(member: member, stock: stock)
  end
end
