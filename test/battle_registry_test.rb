# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/battle_registry"

class BattleRegistryTest < Minitest::Test
  def setup
    @registry = BattleRegistry.new
  end

  def test_fetch_unknown_user_returns_nil
    assert_nil @registry.fetch("unknown")
  end

  def test_set_and_fetch_returns_battle_for_user
    battle = Object.new

    @registry.set("user-a", battle)

    assert_same battle, @registry.fetch("user-a")
  end

  def test_clear_removes_battle_for_user
    @registry.set("user-a", Object.new)

    @registry.clear("user-a")

    assert_nil @registry.fetch("user-a")
  end

  def test_battles_are_isolated_per_user
    battle_a = Object.new
    battle_b = Object.new

    @registry.set("user-a", battle_a)
    @registry.set("user-b", battle_b)

    assert_same battle_a, @registry.fetch("user-a")
    assert_same battle_b, @registry.fetch("user-b")
  end
end
