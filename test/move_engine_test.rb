# frozen_string_literal: true

require_relative "test_helper"

module MoveEngineTestHelpers
  include TestSupport

  def fire_attacker(moves:, hp: 200, speed: 100, attack: 100, defense: 10)
    build_pokemon(
      number: 1, name: "flame", types: ["fire"], hp: hp, speed: speed, attack: attack, defense: defense,
      moves: moves
    )
  end

  def leaf_defender(hp: 200, speed: 1, defense: 40)
    build_pokemon(number: 2, name: "leaf", types: ["grass"], hp: hp, speed: speed, defense: defense)
  end

  def engine_with(team_a, team_b)
    BattleEngine.new(team_a: team_a, team_b: team_b, effectiveness: type_effectiveness)
  end
end

class MoveEngineSelectionTest < Minitest::Test
  include MoveEngineTestHelpers

  def test_engine_picks_move_with_highest_expected_damage
    fast = fire_attacker(
      moves: [
        build_move("normal-move", type: "normal", power: 40, pp: 20),
        build_move("fire-move", type: "fire", power: 60, pp: 10)
      ]
    )
    slow = leaf_defender

    result = engine_with([fast], [slow]).battle

    assert_equal "fire-move", result.log.first[:move], "escolhe o de maior dano esperado (fire vs grass = 2.0 x STAB)"
    assert_equal "fire", result.log.first[:move_type]
  end

  def test_engine_picks_higher_power_move_on_expected_damage_tie
    fast = build_pokemon(
      number: 1, name: "flame", types: [], hp: 200, speed: 100, attack: 100, defense: 10,
      moves: [
        build_move("weak", type: "normal", power: 20, pp: 20),
        build_move("strong", type: "normal", power: 80, pp: 20)
      ]
    )
    slow = build_pokemon(number: 2, name: "leaf", types: [], hp: 200, speed: 1, defense: 40)

    result = engine_with([fast], [slow]).battle

    assert_equal "strong", result.log.first[:move], "mesmo multiplicador: desempate pelo maior power"
  end

  def test_engine_ignores_status_moves_without_power
    fast = fire_attacker(
      moves: [
        build_move("growl", type: "normal", power: nil, pp: 30),
        build_move("fire-move", type: "fire", power: 40, pp: 10)
      ]
    )
    slow = leaf_defender

    result = engine_with([fast], [slow]).battle

    assert_equal "fire-move", result.log.first[:move], "golpe sem poder nunca e escolhido"
  end

  def test_engine_uses_move_with_its_type_for_effectiveness
    fast = build_pokemon(
      number: 1, name: "spark", types: ["electric"], hp: 200, speed: 100, attack: 100, defense: 10,
      moves: [build_move("fire-move", type: "fire", power: 60, pp: 10)]
    )
    slow = leaf_defender

    result = engine_with([fast], [slow]).battle

    base = [100 - 40, 1].max
    multiplier = 2.0 # sem STAB: atacante electric nao tem tipo fire
    expected = (base * (60 / 50.0) * multiplier).round
    assert_equal expected, result.log.first[:damage]
  end
end

class MoveEngineBattleTest < Minitest::Test
  include MoveEngineTestHelpers

  def test_engine_damage_uses_move_power_and_type_multiplier
    fast = fire_attacker(moves: [build_move("fire-move", type: "fire", power: 60, pp: 10)])
    slow = leaf_defender

    result = engine_with([fast], [slow]).battle

    base = [100 - 40, 1].max
    multiplier = 2.0 * 1.5
    expected = (base * (60 / 50.0) * multiplier).round
    assert_equal expected, result.log.first[:damage], "(A-D) x power/50 x efetividade x STAB"
  end

  def test_engine_decays_pp_of_used_move
    fast = fire_attacker(
      moves: [
        build_move("normal-move", type: "normal", power: 40, pp: 20),
        build_move("fire-move", type: "fire", power: 60, pp: 10)
      ]
    )
    slow = leaf_defender

    engine = engine_with([fast], [slow])
    engine.play_round

    used = engine.teams[0].first.moves.find { |m| m.name == "fire-move" }
    unused = engine.teams[0].first.moves.find { |m| m.name == "normal-move" }
    assert_equal 9, used.pp, "pp do golpe usado decai em 1"
    assert_equal 20, unused.pp, "golpe nao usado mantem pp"
  end

  def test_engine_log_counts_round_attacker_move_type_move_and_ko
    fast = fire_attacker(moves: [build_move("fire-move", type: "fire", power: 60, pp: 10)])
    slow = leaf_defender

    result = engine_with([fast], [slow]).battle

    assert_equal %i[round attacker move_type damage ko move attacker_name target_name], result.log.first.keys
    assert_equal "fire-move", result.log.first[:move]
    assert_equal "flame", result.log.first[:attacker_name]
    assert_equal "leaf", result.log.first[:target_name]
  end
end

class MoveEngineStruggleTest < Minitest::Test
  include MoveEngineTestHelpers

  def test_engine_uses_struggle_when_all_moves_are_out_of_pp
    fast = fire_attacker(moves: [build_move("fire-move", type: "fire", power: 40, pp: 0)])
    slow = leaf_defender

    engine = engine_with([fast], [slow])
    engine.play_round

    entry = engine.log.first
    assert_equal "Struggle", entry[:move], "todos com pp 0 -> Struggle"
    assert_equal "fire", entry[:move_type], "Struggle usa o tipo do atacante"
    assert_equal 0, engine.teams[0].first.moves.first.pp, "Struggle nao altera o pp dos golpes guardados"
  end

  def test_engine_uses_struggle_when_only_status_moves_are_available
    fast = fire_attacker(moves: [build_move("growl", type: "normal", power: nil, pp: 30)])
    slow = leaf_defender

    result = engine_with([fast], [slow]).battle

    assert_equal "Struggle", result.log.first[:move]
  end

  def test_struggle_still_deals_damage
    fast = fire_attacker(moves: [build_move("fire-move", type: "fire", power: 40, pp: 0)])
    slow = leaf_defender

    result = engine_with([fast], [slow]).battle

    base = [100 - 40, 1].max
    multiplier = 2.0 * 1.5
    expected = (base * (10 / 50.0) * multiplier).round
    assert_equal expected, result.log.first[:damage], "Struggle = power 10 x efetividade x STAB"
  end
end
