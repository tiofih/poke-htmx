# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/battle_pokemon"

class BattlePokemonTest < Minitest::Test
  def pikachu
    Pokemon.new(
      name: "pikachu",
      sprite: "https://example.com/pikachu.png",
      number: 25,
      types: ["electric"],
      stats: [{ name: "HP", value: 45 }, { name: "Speed", value: 90 }]
    )
  end

  def test_from_preserves_identity_fields
    fighter = BattlePokemon.from(pikachu)

    assert_equal 25, fighter.number
    assert_equal "pikachu", fighter.name
    assert_equal ["electric"], fighter.types
    assert_equal [{ name: "HP", value: 45 }, { name: "Speed", value: 90 }], fighter.stats
  end

  def test_from_derives_hp_max_and_current_from_hp_base_stat
    fighter = BattlePokemon.from(pikachu)

    assert_equal 45, fighter.hp_max
    assert_equal 45, fighter.hp_current
  end

  def test_from_uses_minimum_hp_when_stat_missing
    without_hp = Pokemon.new(
      name: "pikachu",
      sprite: "https://example.com/pikachu.png",
      number: 25,
      types: ["electric"],
      stats: [{ name: "Speed", value: 90 }]
    )

    assert_equal 1, BattlePokemon.from(without_hp).hp_max
  end

  def test_take_damage_returns_new_instance_with_reduced_hp
    fighter = BattlePokemon.from(pikachu)

    damaged = fighter.take_damage(10)

    assert_equal 35, damaged.hp_current
    assert_equal 45, fighter.hp_current, "instância original não muda"
    refute_same damaged, fighter
  end

  def test_take_damage_clamps_at_zero
    fighter = BattlePokemon.from(pikachu)

    assert_equal 0, fighter.take_damage(100).hp_current
  end

  def test_take_damage_ignores_non_positive_values
    fighter = BattlePokemon.from(pikachu)

    assert_equal 45, fighter.take_damage(0).hp_current
    assert_equal 45, fighter.take_damage(-5).hp_current
    assert_equal 45, fighter.hp_current
  end
end