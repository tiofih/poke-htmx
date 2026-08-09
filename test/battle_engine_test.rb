# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/battle_engine"

# rubocop:disable Metrics/ClassLength
class BattleEngineTest < Minitest::Test
  def type_effectiveness
    TypeEffectiveness.from_relations(
      "fire" => { "double" => %w[grass bug ice steel], "half" => %w[fire water rock dragon], "no" => [] },
      "grass" => { "double" => %w[water ground rock], "half" => %w[fire grass poison flying bug dragon], "no" => [] },
      "electric" => { "double" => %w[water flying], "half" => %w[electric grass dragon], "no" => %w[ground] },
      "normal" => { "double" => [], "half" => %w[rock steel], "no" => %w[ghost] }
    )
  end

  # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists, Naming/MethodParameterName
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
  # rubocop:enable Metrics/MethodLength, Metrics/ParameterLists, Naming/MethodParameterName

  def test_new_accepts_two_teams_and_effectiveness
    a = build_pokemon(number: 1, name: "a", types: ["fire"], hp: 100, speed: 100, attack: 60, defense: 10)
    b = build_pokemon(number: 2, name: "b", types: ["grass"], hp: 100, speed: 10, attack: 20, defense: 40)

    engine = BattleEngine.new(team_a: [a], team_b: [b], effectiveness: type_effectiveness)

    result = engine.battle

    assert_instance_of BattleResult, result
    assert_equal 0, result.winner, "time A é mais rápido e causa mais dano"
  end

  # rubocop:disable Metrics/AbcSize
  def test_battle_logs_the_actions
    a = build_pokemon(number: 1, name: "a", types: ["fire"], hp: 100, speed: 100, attack: 60, defense: 10)
    b = build_pokemon(number: 2, name: "b", types: ["grass"], hp: 100, speed: 10, attack: 20, defense: 40)

    result = BattleEngine.new(team_a: [a], team_b: [b], effectiveness: type_effectiveness).battle

    refute_empty result.log
    assert_kind_of Hash, result.log.first
    assert result.log.first.key?(:round)
    assert result.log.first.key?(:attacker)
  end
  # rubocop:enable Metrics/AbcSize

  def test_damage_is_attack_minus_defense
    a = build_pokemon(number: 1, name: "a", types: [], hp: 100, speed: 100, attack: 100, defense: 10)
    d = build_pokemon(number: 2, name: "d", types: ["electric"], hp: 100, speed: 1, attack: 1, defense: 40)

    result = BattleEngine.new(team_a: [a], team_b: [d], effectiveness: type_effectiveness).battle

    assert_equal 60, result.log.first[:damage]
  end

  def test_damage_never_goes_below_one
    a = build_pokemon(number: 1, name: "a", types: ["fire"], hp: 100, speed: 100, attack: 20, defense: 40)
    d = build_pokemon(number: 2, name: "d", types: ["electric"], hp: 100, speed: 90, attack: 1, defense: 40)

    result = BattleEngine.new(team_a: [a], team_b: [d], effectiveness: type_effectiveness).battle

    assert result.log.first[:damage] >= 1
  end

  def test_damage_applies_type_multiplier_with_stab
    a = build_pokemon(number: 1, name: "a", types: ["fire"], hp: 200, speed: 100, attack: 100, defense: 10)
    d = build_pokemon(number: 2, name: "d", types: ["grass"], hp: 200, speed: 1, attack: 1, defense: 40)

    result = BattleEngine.new(team_a: [a], team_b: [d], effectiveness: type_effectiveness).battle

    assert_equal 180, result.log.first[:damage]
  end

  def test_move_type_is_the_best_type_against_the_target
    a = build_pokemon(number: 1, name: "a", types: %w[grass poison], hp: 100, speed: 100, attack: 100, defense: 10)
    d = build_pokemon(number: 2, name: "d", types: ["water"], hp: 100, speed: 1, attack: 1, defense: 40)

    result = BattleEngine.new(team_a: [a], team_b: [d], effectiveness: type_effectiveness).battle

    assert_equal "grass", result.log.first[:move_type]
  end

  def test_immune_best_type_falls_back_to_neutral_damage
    a = build_pokemon(number: 1, name: "a", types: ["electric"], hp: 100, speed: 100, attack: 100, defense: 10)
    d = build_pokemon(number: 2, name: "d", types: ["ground"], hp: 100, speed: 1, attack: 1, defense: 40)

    result = BattleEngine.new(team_a: [a], team_b: [d], effectiveness: type_effectiveness).battle

    assert_equal 60, result.log.first[:damage]
  end

  def test_actions_follow_speed_order_with_team_then_slot_tiebreak
    fast_a1 = build_pokemon(number: 1, name: "a1", types: [], hp: 100, speed: 80, attack: 100, defense: 10)
    slow_a2 = build_pokemon(number: 2, name: "a2", types: [], hp: 100, speed: 10, attack: 100, defense: 10)
    fast_b1 = build_pokemon(number: 3, name: "b1", types: [], hp: 100, speed: 80, attack: 1, defense: 10)
    slow_b2 = build_pokemon(number: 4, name: "b2", types: [], hp: 100, speed: 5, attack: 1, defense: 10)

    result = BattleEngine.new(
      team_a: [fast_a1, slow_a2],
      team_b: [fast_b1, slow_b2],
      effectiveness: type_effectiveness
    ).battle

    assert_equal([0, 1, 0, 1], result.log.take(4).map { |entry| entry[:attacker] })
  end

  # rubocop:disable Metrics/MethodLength
  def test_full_battle_ends_when_one_side_has_no_alive
    team_a = Array.new(3) do |i|
      build_pokemon(number: i + 1, name: "a#{i}", types: [], hp: 200, speed: 100, attack: 100, defense: 10)
    end
    team_b = Array.new(3) do |i|
      build_pokemon(number: i + 10, name: "b#{i}", types: ["electric"], hp: 200, speed: 5, attack: 1, defense: 40)
    end

    result = BattleEngine.new(
      team_a: team_a,
      team_b: team_b,
      effectiveness: type_effectiveness
    ).battle

    assert_includes [0, 1], result.winner
    assert result.log.last[:ko], "última ação da batalha é um KO"
  end
  # rubocop:enable Metrics/MethodLength

  def test_fainted_pokemon_do_not_act
    team_a = [build_pokemon(number: 1, name: "a", types: [], hp: 100, speed: 100, attack: 100, defense: 10)]
    team_b = [build_pokemon(number: 2, name: "b", types: [], hp: 1, speed: 1, attack: 1, defense: 40)]

    result = BattleEngine.new(
      team_a: team_a,
      team_b: team_b,
      effectiveness: type_effectiveness
    ).battle

    assert_equal 0, result.winner
    assert_equal 1, result.log.count { |entry| entry[:attacker].zero? }, "apos dar KO no unico b, o b nao age"
    assert_equal 1, result.log.count
  end

  def test_log_entries_carry_full_action_shape_and_rounds
    a = build_pokemon(number: 1, name: "a", types: ["fire"], hp: 60, speed: 100, attack: 100, defense: 10)
    d = build_pokemon(number: 2, name: "d", types: ["grass"], hp: 60, speed: 1, attack: 1, defense: 40)

    result = BattleEngine.new(team_a: [a], team_b: [d], effectiveness: type_effectiveness).battle

    assert_equal %i[round attacker move_type damage ko attacker_name target_name], result.log.first.keys
    assert_equal(
      { round: 1, attacker: 0, move_type: "fire", damage: 180, ko: true, attacker_name: "a", target_name: "d" },
      result.log.first
    )
    assert_equal 1, result.rounds
  end

  def test_log_records_attacker_and_target_names
    a = build_pokemon(number: 1, name: "a", types: ["fire"], hp: 60, speed: 100, attack: 100, defense: 10)
    d = build_pokemon(number: 2, name: "d", types: ["grass"], hp: 60, speed: 1, attack: 1, defense: 40)

    result = BattleEngine.new(team_a: [a], team_b: [d], effectiveness: type_effectiveness).battle

    assert_equal "a", result.log.first[:attacker_name]
    assert_equal "d", result.log.first[:target_name]
  end

  def test_rounds_counts_each_round_of_actions_taken
    team_a = [build_pokemon(number: 1, name: "a", types: [], hp: 100, speed: 100, attack: 100, defense: 10)]
    team_b = [build_pokemon(number: 2, name: "b", types: [], hp: 250, speed: 1, attack: 1, defense: 40)]

    result = BattleEngine.new(team_a: team_a, team_b: team_b, effectiveness: type_effectiveness).battle

    assert result.rounds >= 2
    assert_equal 0, result.winner
    assert result.log.map { |entry| entry[:round] }.uniq.length == result.rounds
  end

  def test_empty_team_loses_without_actions
    team_a = []
    team_b = [build_pokemon(number: 2, name: "b", types: [], hp: 100, speed: 1, attack: 1, defense: 40)]

    result = BattleEngine.new(team_a: team_a, team_b: team_b, effectiveness: type_effectiveness).battle

    assert_equal 1, result.winner
    assert_empty result.log
    assert_equal 0, result.rounds
  end

  def test_empty_team_b_loses_without_actions
    team_a = [build_pokemon(number: 1, name: "a", types: [], hp: 100, speed: 1, attack: 1, defense: 40)]
    team_b = []

    result = BattleEngine.new(team_a: team_a, team_b: team_b, effectiveness: type_effectiveness).battle

    assert_equal 0, result.winner
    assert_empty result.log
    assert_equal 0, result.rounds
  end

  def test_both_empty_teams_draw
    result = BattleEngine.new(team_a: [], team_b: [], effectiveness: type_effectiveness).battle

    assert_nil result.winner
    assert_empty result.log
    assert_equal 0, result.rounds
  end

  def test_play_round_advances_one_round_and_exposes_state
    a = build_pokemon(number: 1, name: "a", types: ["fire"], hp: 100, speed: 100, attack: 60, defense: 10)
    b = build_pokemon(number: 2, name: "b", types: ["grass"], hp: 100, speed: 10, attack: 20, defense: 40)

    engine = BattleEngine.new(team_a: [a], team_b: [b], effectiveness: type_effectiveness)

    refute engine.finished?
    engine.play_round
    assert_equal 1, engine.rounds
    refute_empty engine.log
    assert_includes [0, 1], engine.winner, "uma rodada só não termina a batalha"
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def testincremental_play_reaches_same_result_as_battle
    team_a = Array.new(3) do |i|
      build_pokemon(number: i + 1, name: "a#{i}", types: [], hp: 200, speed: 100, attack: 100, defense: 10)
    end
    team_b = Array.new(3) do |i|
      build_pokemon(number: i + 10, name: "b#{i}", types: ["electric"], hp: 200, speed: 5, attack: 1, defense: 40)
    end

    batch = BattleEngine.new(team_a: team_a.dup, team_b: team_b.dup, effectiveness: type_effectiveness).battle

    engine = BattleEngine.new(team_a: team_a, team_b: team_b, effectiveness: type_effectiveness)
    engine.play_round until engine.finished?

    assert_equal batch.winner, engine.winner
    assert_equal batch.rounds, engine.rounds
    assert_equal batch.log, engine.log
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize
  def test_play_round_exposes_team_state_with_hp_per_member
    a = build_pokemon(number: 1, name: "a", types: ["fire"], hp: 100, speed: 100, attack: 60, defense: 10)
    b = build_pokemon(number: 2, name: "b", types: ["grass"], hp: 100, speed: 10, attack: 20, defense: 40)

    engine = BattleEngine.new(team_a: [a], team_b: [b], effectiveness: type_effectiveness)

    assert_equal 2, engine.teams.size
    assert_equal 1, engine.teams[0].size
    assert_equal 100, engine.teams[0].first.hp_current

    engine.play_round

    assert_operator engine.teams[1].first.hp_current, :<, 100, "b apanha na primeira rodada"
  end

  def test_play_round_after_finished_is_idempotent
    a = build_pokemon(number: 1, name: "a", types: ["fire"], hp: 100, speed: 100, attack: 60, defense: 10)
    b = build_pokemon(number: 2, name: "b", types: ["grass"], hp: 100, speed: 10, attack: 20, defense: 40)

    engine = BattleEngine.new(team_a: [a], team_b: [b], effectiveness: type_effectiveness)
    engine.play_round until engine.finished?
    log_size = engine.log.size
    rounds = engine.rounds

    engine.play_round

    assert_equal log_size, engine.log.size, "play_round após o fim não gera log novo"
    assert_equal rounds, engine.rounds
    assert_includes [0, 1], engine.winner
  end
  # rubocop:enable Metrics/AbcSize
end
# rubocop:enable Metrics/ClassLength
