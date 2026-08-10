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

  def test_from_preserves_sprite
    fighter = BattlePokemon.from(pikachu)

    assert_equal "https://example.com/pikachu.png", fighter.sprite
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

  def test_alive_and_fainted_are_coherent
    fighter = BattlePokemon.from(pikachu)

    assert_predicate fighter, :alive?
    refute_predicate fighter, :fainted?
  end

  def test_alive_and_fainted_update_after_damage_until_zero
    fighter = BattlePokemon.from(pikachu)

    fighter = fighter.take_damage(44)
    assert_predicate fighter, :alive?
    refute_predicate fighter, :fainted?

    fighter = fighter.take_damage(1)
    refute_predicate fighter, :alive?
    assert_predicate fighter, :fainted?
  end

  def test_stat_returns_the_stat_value
    fighter = BattlePokemon.from(pikachu)

    assert_equal 90, fighter.stat("Speed")
    assert_equal 45, fighter.stat("HP")
  end

  def test_stat_defaults_to_one_when_missing
    fighter = BattlePokemon.from(pikachu)

    assert_equal 1, fighter.stat("Attack")
    assert_equal 1, fighter.stat("Defense")
  end

  def test_from_defaults_to_level_one_and_preserves_stats
    fighter = BattlePokemon.from(pikachu)

    assert_equal 1, fighter.level
    assert_equal 45, fighter.hp_max
    assert_equal 45, fighter.hp_current
    assert_equal 90, fighter.stat("Speed")
  end

  def test_from_scales_stats_with_level_and_rounds_half_up
    fighter = BattlePokemon.from(pikachu, level: 3)

    assert_equal 3, fighter.level
    assert_equal 46, fighter.hp_max, "HP 45 + (3-1)*0.5 = 46"
    assert_equal 91, fighter.stat("Speed"), "Speed 90 + 1 = 91"
  end

  def test_from_rounds_half_away_from_zero_when_required
    fighter = BattlePokemon.from(pikachu, level: 4)

    assert_equal 47, fighter.hp_max, "HP 45 + 1.5 = 46.5 -> 47"
    assert_equal 92, fighter.stat("Speed"), "Speed 90 + 1.5 = 91.5 -> 92"
  end

  def test_from_uses_minimum_hp_when_stat_missing_even_scaled
    without_hp = Pokemon.new(
      name: "pikachu",
      sprite: "https://example.com/pikachu.png",
      number: 25,
      types: ["electric"],
      stats: [{ name: "Speed", value: 90 }]
    )

    assert_equal 1, BattlePokemon.from(without_hp, level: 8).hp_max
  end

  def test_scaled_stats_do_not_mutate_original_pokemon
    fighter = BattlePokemon.from(pikachu, level: 5)

    assert_equal 45, pikachu.stats.find { |stat| stat[:name] == "HP" }[:value]
    assert_equal 47, fighter.hp_max, "HP 45 + 2 = 47"
  end
end
