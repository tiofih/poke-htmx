# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/battle_engine"
require_relative "../lib/move"

# rubocop:disable Metrics/ClassLength
class MoveEngineTest < Minitest::Test
  def type_effectiveness
    TypeEffectiveness.from_relations(
      "fire" => { "double" => %w[grass bug ice steel], "half" => %w[fire water rock dragon], "no" => [] },
      "grass" => { "double" => %w[water ground rock], "half" => %w[fire grass poison flying bug dragon], "no" => [] },
      "normal" => { "double" => [], "half" => %w[rock steel], "no" => %w[ghost] },
      "electric" => { "double" => %w[water flying], "half" => %w[electric grass dragon], "no" => %w[ground] }
    )
  end

  def move(name:, type:, power:, pp:)
    Move.new(name: name, type: type, power: power, accuracy: 100, pp: pp)
  end

  # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists, Naming/MethodParameterName
  def build_pokemon(number:, name:, types:, hp:, speed:, attack: 1, defense: 1, moves: [])
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
      hp_current: hp,
      moves: moves
    )
  end
  # rubocop:enable Metrics/MethodLength, Metrics/ParameterLists, Naming/MethodParameterName

  def test_engine_picks_move_with_highest_expected_damage
    fast = build_pokemon(
      number: 1, name: "flame", types: ["fire"], hp: 100, speed: 100, attack: 100, defense: 10,
      moves: [
        move(name: "normal-move", type: "normal", power: 40, pp: 20),
        move(name: "fire-move", type: "fire", power: 60, pp: 10)
      ]
    )
    slow = build_pokemon(number: 2, name: "leaf", types: ["grass"], hp: 100, speed: 1, defense: 40)

    result = BattleEngine.new(team_a: [fast], team_b: [slow], effectiveness: type_effectiveness).battle

    assert_equal "fire-move", result.log.first[:move], "escolhe o de maior dano esperado (fire vs grass = 2.0 x STAB)"
    assert_equal "fire", result.log.first[:move_type]
  end

  def test_engine_damage_uses_move_power_and_type_multiplier
    fast = build_pokemon(
      number: 1, name: "flame", types: ["fire"], hp: 200, speed: 100, attack: 100, defense: 10,
      moves: [move(name: "fire-move", type: "fire", power: 60, pp: 10)]
    )
    slow = build_pokemon(number: 2, name: "leaf", types: ["grass"], hp: 200, speed: 1, defense: 40)

    result = BattleEngine.new(team_a: [fast], team_b: [slow], effectiveness: type_effectiveness).battle

    base = [100 - 40, 1].max
    multiplier = 2.0 * 1.5
    expected = (base * (60 / 50.0) * multiplier).round
    assert_equal expected, result.log.first[:damage], "(A-D) x power/50 x efetividade x STAB"
  end

  def test_engine_decays_pp_of_used_move
    fast = build_pokemon(
      number: 1, name: "flame", types: ["fire"], hp: 200, speed: 100, attack: 100, defense: 10,
      moves: [
        move(name: "normal-move", type: "normal", power: 40, pp: 20),
        move(name: "fire-move", type: "fire", power: 60, pp: 10)
      ]
    )
    slow = build_pokemon(number: 2, name: "leaf", types: ["grass"], hp: 200, speed: 1, defense: 40)

    engine = BattleEngine.new(team_a: [fast], team_b: [slow], effectiveness: type_effectiveness)
    engine.play_round

    used = engine.teams[0].first.moves.find { |m| m.name == "fire-move" }
    unused = engine.teams[0].first.moves.find { |m| m.name == "normal-move" }
    assert_equal 9, used.pp, "pp do golpe usado decai em 1"
    assert_equal 20, unused.pp, "golpe nao usado mantem pp"
  end

  def test_engine_log_counts_round_attacker_move_type_move_and_ko
    fast = build_pokemon(
      number: 1, name: "flame", types: ["fire"], hp: 200, speed: 100, attack: 100, defense: 10,
      moves: [move(name: "fire-move", type: "fire", power: 60, pp: 10)]
    )
    slow = build_pokemon(number: 2, name: "leaf", types: ["grass"], hp: 200, speed: 1, defense: 40)

    result = BattleEngine.new(team_a: [fast], team_b: [slow], effectiveness: type_effectiveness).battle

    assert_equal %i[round attacker move_type damage ko move], result.log.first.keys
    assert_equal "fire-move", result.log.first[:move]
  end

  def test_engine_uses_move_with_its_type_for_effectiveness
    fast = build_pokemon(
      number: 1, name: "spark", types: ["electric"], hp: 200, speed: 100, attack: 100, defense: 10,
      moves: [move(name: "fire-move", type: "fire", power: 60, pp: 10)]
    )
    slow = build_pokemon(number: 2, name: "leaf", types: ["grass"], hp: 200, speed: 1, defense: 40)

    result = BattleEngine.new(team_a: [fast], team_b: [slow], effectiveness: type_effectiveness).battle

    base = [100 - 40, 1].max
    multiplier = 2.0 # sem STAB: atacante electric nao tem tipo fire
    expected = (base * (60 / 50.0) * multiplier).round
    assert_equal expected, result.log.first[:damage]
  end

  def test_engine_picks_higher_power_move_on_expected_damage_tie
    fast = build_pokemon(
      number: 1, name: "flame", types: [], hp: 200, speed: 100, attack: 100, defense: 10,
      moves: [
        move(name: "weak", type: "normal", power: 20, pp: 20),
        move(name: "strong", type: "normal", power: 80, pp: 20)
      ]
    )
    slow = build_pokemon(number: 2, name: "leaf", types: [], hp: 200, speed: 1, defense: 40)

    result = BattleEngine.new(team_a: [fast], team_b: [slow], effectiveness: type_effectiveness).battle

    assert_equal "strong", result.log.first[:move], "mesmo multiplicador: desempate pelo maior power"
  end

  def test_engine_ignores_status_moves_without_power
    fast = build_pokemon(
      number: 1, name: "flame", types: ["fire"], hp: 200, speed: 100, attack: 100, defense: 10,
      moves: [
        move(name: "growl", type: "normal", power: nil, pp: 30),
        move(name: "fire-move", type: "fire", power: 40, pp: 10)
      ]
    )
    slow = build_pokemon(number: 2, name: "leaf", types: ["grass"], hp: 200, speed: 1, defense: 40)

    result = BattleEngine.new(team_a: [fast], team_b: [slow], effectiveness: type_effectiveness).battle

    assert_equal "fire-move", result.log.first[:move], "golpe sem poder nunca e escolhido"
  end

  def test_engine_uses_struggle_when_all_moves_are_out_of_pp
    fast = build_pokemon(
      number: 1, name: "flame", types: ["fire"], hp: 200, speed: 100, attack: 100, defense: 10,
      moves: [move(name: "fire-move", type: "fire", power: 40, pp: 0)]
    )
    slow = build_pokemon(number: 2, name: "leaf", types: ["grass"], hp: 200, speed: 1, defense: 40)

    engine = BattleEngine.new(team_a: [fast], team_b: [slow], effectiveness: type_effectiveness)
    engine.play_round

    entry = engine.log.first
    assert_equal "Struggle", entry[:move], "todos com pp 0 -> Struggle"
    assert_equal "fire", entry[:move_type], "Struggle usa o tipo do atacante"
    assert_equal 0, engine.teams[0].first.moves.first.pp, "Struggle nao altera o pp dos golpes guardados"
  end

  def test_engine_uses_struggle_when_only_status_moves_are_available
    fast = build_pokemon(
      number: 1, name: "flame", types: ["fire"], hp: 200, speed: 100, attack: 100, defense: 10,
      moves: [move(name: "growl", type: "normal", power: nil, pp: 30)]
    )
    slow = build_pokemon(number: 2, name: "leaf", types: ["grass"], hp: 200, speed: 1, defense: 40)

    result = BattleEngine.new(team_a: [fast], team_b: [slow], effectiveness: type_effectiveness).battle

    assert_equal "Struggle", result.log.first[:move]
  end

  def test_struggle_still_deals_damage
    fast = build_pokemon(
      number: 1, name: "flame", types: ["fire"], hp: 200, speed: 100, attack: 100, defense: 10,
      moves: [move(name: "fire-move", type: "fire", power: 40, pp: 0)]
    )
    slow = build_pokemon(number: 2, name: "leaf", types: ["grass"], hp: 200, speed: 1, defense: 40)

    result = BattleEngine.new(team_a: [fast], team_b: [slow], effectiveness: type_effectiveness).battle

    base = [100 - 40, 1].max
    multiplier = 2.0 * 1.5
    expected = (base * (10 / 50.0) * multiplier).round
    assert_equal expected, result.log.first[:damage], "Struggle = power 10 x efetividade x STAB"
  end
end
# rubocop:enable Metrics/ClassLength