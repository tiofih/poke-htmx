# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/battle_engine"

class BattleEngineTest < Minitest::Test
  def type_effectiveness
    TypeEffectiveness.from_relations(
      "fire" => { "double" => %w[grass bug ice steel], "half" => %w[fire water rock dragon], "no" => [] },
      "grass" => { "double" => %w[water ground rock], "half" => %w[fire grass poison flying bug dragon], "no" => [] },
      "electric" => { "double" => %w[water flying], "half" => %w[electric grass dragon], "no" => %w[ground] },
      "normal" => { "double" => [], "half" => %w[rock steel], "no" => %w[ghost] }
    )
  end

  def build_pokemon(number:, name:, types:, hp:, speed:, attack: 1, defense: 1)
    BattlePokemon.new(
      number: number,
      name: name,
      types: types,
      stats: [
        { name: "HP", value: hp },
        { name: "Attack", value: attack },
        { name: "Defense", value: defense },
        { name: "Speed", value: speed }
      ],
      hp_max: hp,
      hp_current: hp
    )
  end

  def test_new_accepts_two_teams_and_effectiveness
    a = build_pokemon(number: 1, name: "a", types: ["fire"], hp: 100, speed: 100, attack: 60, defense: 10)
    b = build_pokemon(number: 2, name: "b", types: ["grass"], hp: 100, speed: 10, attack: 20, defense: 40)

    engine = BattleEngine.new(team_a: [a], team_b: [b], effectiveness: type_effectiveness)

    result = engine.battle

    assert_instance_of BattleResult, result
    assert_equal 0, result.winner, "time A é mais rápido e causa mais dano"
  end

  def test_battle_logs_the_actions
    a = build_pokemon(number: 1, name: "a", types: ["fire"], hp: 100, speed: 100, attack: 60, defense: 10)
    b = build_pokemon(number: 2, name: "b", types: ["grass"], hp: 100, speed: 10, attack: 20, defense: 40)

    result = BattleEngine.new(team_a: [a], team_b: [b], effectiveness: type_effectiveness).battle

    refute_empty result.log
    assert_kind_of Hash, result.log.first
    assert result.log.first.key?(:round)
    assert result.log.first.key?(:attacker)
  end
end