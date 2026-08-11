# frozen_string_literal: true

require_relative "test_helper"

module BattleEngineTestHelpers
  include TestSupport

  def battle_engine(team_a:, team_b:)
    BattleEngine.new(team_a: team_a, team_b: team_b, effectiveness: type_effectiveness)
  end

  def fire_pokemon(name: "a", types: ["fire"], hp: 100, speed: 100, attack: 60, defense: 10)
    build_pokemon(number: 1, name: name, types: types, hp: hp, speed: speed, attack: attack, defense: defense)
  end

  def grass_pokemon(name: "d", types: ["grass"], hp: 100, speed: 10, attack: 20, defense: 40)
    build_pokemon(number: 2, name: name, types: types, hp: hp, speed: speed, attack: attack, defense: defense)
  end
end

class BattleEngineBattleTest < Minitest::Test
  include BattleEngineTestHelpers

  def test_new_accepts_two_teams_and_effectiveness
    a = fire_pokemon
    b = grass_pokemon

    engine = battle_engine(team_a: [a], team_b: [b])

    result = engine.battle

    assert_instance_of BattleResult, result
    assert_equal 0, result.winner, "time A é mais rápido e causa mais dano"
  end

  def test_battle_logs_the_actions
    a = fire_pokemon
    b = grass_pokemon

    result = battle_engine(team_a: [a], team_b: [b]).battle

    refute_empty result.log
    assert_kind_of Hash, result.log.first
    assert result.log.first.key?(:round)
    assert result.log.first.key?(:attacker)
  end

  def test_damage_is_attack_minus_defense
    a = build_pokemon(number: 1, name: "a", types: [], hp: 100, speed: 100, attack: 100, defense: 10)
    d = build_pokemon(number: 2, name: "d", types: ["electric"], hp: 100, speed: 1, attack: 1, defense: 40)

    result = battle_engine(team_a: [a], team_b: [d]).battle

    assert_equal 60, result.log.first[:damage]
  end

  def test_damage_never_goes_below_one
    a = fire_pokemon(attack: 20, defense: 40)
    d = build_pokemon(number: 2, name: "d", types: ["electric"], hp: 100, speed: 90, attack: 1, defense: 40)

    result = battle_engine(team_a: [a], team_b: [d]).battle

    assert result.log.first[:damage] >= 1
  end

  def test_damage_applies_type_multiplier_with_stab
    a = fire_pokemon(hp: 200, attack: 100, defense: 10)
    d = grass_pokemon(hp: 200)

    result = battle_engine(team_a: [a], team_b: [d]).battle

    assert_equal 180, result.log.first[:damage]
  end

  def test_move_type_is_the_best_type_against_the_target
    a = build_pokemon(number: 1, name: "a", types: %w[grass poison], hp: 100, speed: 100, attack: 100, defense: 10)
    d = build_pokemon(number: 2, name: "d", types: ["water"], hp: 100, speed: 1, attack: 1, defense: 40)

    result = battle_engine(team_a: [a], team_b: [d]).battle

    assert_equal "grass", result.log.first[:move_type]
  end

  def test_immune_best_type_falls_back_to_neutral_damage
    a = build_pokemon(number: 1, name: "a", types: ["electric"], hp: 100, speed: 100, attack: 100, defense: 10)
    d = build_pokemon(number: 2, name: "d", types: ["ground"], hp: 100, speed: 1, attack: 1, defense: 40)

    result = battle_engine(team_a: [a], team_b: [d]).battle

    assert_equal 60, result.log.first[:damage]
  end

  def test_actions_follow_speed_order_with_team_then_slot_tiebreak
    fast_a1 = build_pokemon(number: 1, name: "a1", types: [], hp: 100, speed: 80, attack: 100, defense: 10)
    slow_a2 = build_pokemon(number: 2, name: "a2", types: [], hp: 100, speed: 10, attack: 100, defense: 10)
    fast_b1 = build_pokemon(number: 3, name: "b1", types: [], hp: 100, speed: 80, attack: 1, defense: 10)
    slow_b2 = build_pokemon(number: 4, name: "b2", types: [], hp: 100, speed: 5, attack: 1, defense: 10)

    result = battle_engine(
      team_a: [fast_a1, slow_a2],
      team_b: [fast_b1, slow_b2]
    ).battle

    assert_equal([0, 1, 0, 1], result.log.take(4).map { |entry| entry[:attacker] })
  end

  def test_full_battle_ends_when_one_side_has_no_alive
    team_a = Array.new(3) do |i|
      build_pokemon(number: i + 1, name: "a#{i}", types: [], hp: 200, speed: 100, attack: 100, defense: 10)
    end
    team_b = Array.new(3) do |i|
      build_pokemon(number: i + 10, name: "b#{i}", types: ["electric"], hp: 200, speed: 5, attack: 1, defense: 40)
    end

    result = battle_engine(team_a: team_a, team_b: team_b).battle

    assert_includes [0, 1], result.winner
    assert result.log.last[:ko], "última ação da batalha é um KO"
  end

  def test_fainted_pokemon_do_not_act
    team_a = [fire_pokemon(hp: 100, defense: 10)]
    team_b = [build_pokemon(number: 2, name: "b", types: [], hp: 1, speed: 1, attack: 1, defense: 40)]

    result = battle_engine(team_a: team_a, team_b: team_b).battle

    assert_equal 0, result.winner
    assert_equal 1, result.log.count { |entry| entry[:attacker].zero? }, "apos dar KO no unico b, o b nao age"
    assert_equal 1, result.log.count
  end

  def test_log_entries_carry_full_action_shape_and_rounds
    a = fire_pokemon(hp: 60, attack: 100)
    d = grass_pokemon(hp: 60)

    result = battle_engine(team_a: [a], team_b: [d]).battle

    assert_equal %i[round attacker move_type damage ko attacker_name target_name], result.log.first.keys
    assert_equal(
      { round: 1, attacker: 0, move_type: "fire", damage: 180, ko: true, attacker_name: "a", target_name: "d" },
      result.log.first
    )
    assert_equal 1, result.rounds
  end

  def test_log_records_attacker_and_target_names
    a = fire_pokemon(hp: 60)
    d = grass_pokemon(hp: 60)

    result = battle_engine(team_a: [a], team_b: [d]).battle

    assert_equal "a", result.log.first[:attacker_name]
    assert_equal "d", result.log.first[:target_name]
  end

  def test_rounds_counts_each_round_of_actions_taken
    team_a = [fire_pokemon(hp: 100, defense: 10)]
    team_b = [build_pokemon(number: 2, name: "b", types: [], hp: 250, speed: 1, attack: 1, defense: 40)]

    result = battle_engine(team_a: team_a, team_b: team_b).battle

    assert result.rounds >= 2
    assert_equal 0, result.winner
    assert result.log.map { |entry| entry[:round] }.uniq.length == result.rounds
  end

  def test_empty_team_loses_without_actions
    team_a = []
    team_b = [build_pokemon(number: 2, name: "b", types: [], hp: 100, speed: 1, attack: 1, defense: 40)]

    result = battle_engine(team_a: team_a, team_b: team_b).battle

    assert_equal 1, result.winner
    assert_empty result.log
    assert_equal 0, result.rounds
  end

  def test_empty_team_b_loses_without_actions
    team_a = [build_pokemon(number: 1, name: "a", types: [], hp: 100, speed: 1, attack: 1, defense: 40)]
    team_b = []

    result = battle_engine(team_a: team_a, team_b: team_b).battle

    assert_equal 0, result.winner
    assert_empty result.log
    assert_equal 0, result.rounds
  end

  def test_both_empty_teams_draw
    result = battle_engine(team_a: [], team_b: []).battle

    assert_nil result.winner
    assert_empty result.log
    assert_equal 0, result.rounds
  end
end

class BattleEngineRoundTest < Minitest::Test
  include BattleEngineTestHelpers

  def test_play_round_advances_one_round_and_exposes_state
    a = fire_pokemon
    b = grass_pokemon

    engine = battle_engine(team_a: [a], team_b: [b])

    refute engine.finished?
    engine.play_round
    assert_equal 1, engine.rounds
    refute_empty engine.log
    assert_includes [0, 1], engine.winner, "uma rodada só não termina a batalha"
  end

  def testincremental_play_reaches_same_result_as_battle
    team_a = Array.new(3) do |i|
      build_pokemon(number: i + 1, name: "a#{i}", types: [], hp: 200, speed: 100, attack: 100, defense: 10)
    end
    team_b = Array.new(3) do |i|
      build_pokemon(number: i + 10, name: "b#{i}", types: ["electric"], hp: 200, speed: 5, attack: 1, defense: 40)
    end

    batch = battle_engine(team_a: team_a.dup, team_b: team_b.dup).battle

    engine = battle_engine(team_a: team_a, team_b: team_b)
    engine.play_round until engine.finished?

    assert_equal batch.winner, engine.winner
    assert_equal batch.rounds, engine.rounds
    assert_equal batch.log, engine.log
  end

  def test_play_round_exposes_team_state_with_hp_per_member
    a = fire_pokemon
    b = grass_pokemon

    engine = battle_engine(team_a: [a], team_b: [b])

    assert_equal 2, engine.teams.size
    assert_equal 1, engine.teams[0].size
    assert_equal 100, engine.teams[0].first.hp_current

    engine.play_round

    assert_operator engine.teams[1].first.hp_current, :<, 100, "b apanha na primeira rodada"
  end

  def test_play_round_after_finished_is_idempotent
    a = fire_pokemon
    b = grass_pokemon

    engine = battle_engine(team_a: [a], team_b: [b])
    engine.play_round until engine.finished?
    log_size = engine.log.size
    rounds = engine.rounds

    engine.play_round

    assert_equal log_size, engine.log.size, "play_round após o fim não gera log novo"
    assert_equal rounds, engine.rounds
    assert_includes [0, 1], engine.winner
  end
end

class BattleEngineResultTest < Minitest::Test
  include BattleEngineTestHelpers

  def test_result_is_nil_while_in_progress
    engine = battle_engine(team_a: [fire_pokemon], team_b: [grass_pokemon])

    refute_predicate engine, :finished?
    assert_nil engine.result
  end

  def test_result_is_win_when_player_team_wins
    engine = battle_engine(team_a: [fire_pokemon], team_b: [grass_pokemon])
    engine.play_round until engine.finished?

    assert_equal 0, engine.winner
    assert_equal :win, engine.result
  end

  def test_result_is_lose_when_opponent_team_wins
    strong = build_pokemon(
      number: 9, name: "strong", types: ["electric"],
      hp: 200, speed: 100, attack: 100, defense: 10
    )
    weak = build_pokemon(number: 1, name: "weak", types: [], hp: 40, speed: 5, attack: 1, defense: 40)
    engine = battle_engine(team_a: [weak], team_b: [strong])
    engine.play_round until engine.finished?

    assert_equal 1, engine.winner
    assert_equal :lose, engine.result
  end

  def test_result_is_draw_when_both_teams_are_gone
    engine = battle_engine(team_a: [], team_b: [])

    assert_predicate engine, :finished?
    assert_nil engine.winner
    assert_equal :draw, engine.result
  end

  def test_replace_team_a_swaps_player_team_keeping_opponent_intact
    original = fire_pokemon(name: "charmander", hp: 50, speed: 10, attack: 50, defense: 10)
    opponent = grass_pokemon(name: "bulbasaur", hp: 60, speed: 5, attack: 10, defense: 40)
    engine = battle_engine(team_a: [original], team_b: [opponent])

    engine.play_round

    assert_equal "charmander", engine.teams[0].first.name

    evolved = build_pokemon(number: 5, name: "charmeleon", types: ["fire"],
                            hp: 50, speed: 10, attack: 50, defense: 10)
    engine.replace_team_a([evolved])

    assert_equal "charmeleon", engine.teams[0].first.name
    assert_equal "bulbasaur", engine.teams[1].first.name
    assert_equal 1, engine.rounds
    refute_empty engine.log
  end
end
