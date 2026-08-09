# frozen_string_literal: true

require_relative "battle_pokemon"
require_relative "type_effectiveness"

class BattleResult
  attr_reader :winner, :log, :rounds

  def initialize(winner:, log:, rounds:)
    @winner = winner
    @log = log
    @rounds = rounds
  end
end

class BattleEngine
  def initialize(team_a:, team_b:, effectiveness: TypeEffectiveness.load, target_strategy: nil)
    @teams = [team_a.dup, team_b.dup]
    @effectiveness = effectiveness
    @target_strategy = target_strategy || ->(team) { team.index(&:alive?) }
    @log = []
  end

  def battle
    rounds = 0
    until finished?
      rounds += 1
      play_round!(rounds)
    end
    BattleResult.new(winner: winner, log: @log, rounds: rounds)
  end

  def play_round
    @rounds ||= 0
    return @rounds if finished?

    @rounds += 1
    play_round!(@rounds)
  end

  def rounds
    @rounds ||= 0
  end

  attr_reader :log, :teams

  def finished?
    alive_count(0).zero? || alive_count(1).zero?
  end

  def winner
    a_alive = alive_count(0)
    b_alive = alive_count(1)
    return nil if a_alive.zero? && b_alive.zero?
    return 1 if a_alive.zero?

    0
  end

  private

  def play_round!(round)
    alive_and_actionable.each do |team_index, index|
      break if finished?

      act(team_index, index, round)
    end
  end

  def alive_and_actionable
    entries = @teams.each_with_index.flat_map do |team, team_index|
      team.each_with_index.filter_map { |pokemon, index| [team_index, index] if pokemon.alive? }
    end
    entries.sort_by do |team_index, index|
      [-@teams[team_index][index].stat("Speed"), team_index, index]
    end
  end

  def act(attacker_team_index, attacker_index, round)
    target_team_index = 1 - attacker_team_index
    target_index = @target_strategy.call(@teams[target_team_index])
    attacker = @teams[attacker_team_index][attacker_index]
    target = @teams[target_team_index][target_index]

    if attacker.moves.empty?
      move = nil
      move_type = move_type_for(attacker, target)
      damage = damage_for(attacker, target)
    else
      move = choose_move(attacker, target)
      move_type = move.type
      damage = move_damage_for(attacker, target, move)
      used_index = attacker.moves.find_index { |m| m.name == move.name }
      @teams[attacker_team_index][attacker_index] = attacker.use_move(used_index) if used_index
    end

    damaged = apply_damage(target_team_index, target_index, target, damage)
    @log << action_entry(round, attacker_team_index, move_type, damage, damaged, move&.name)
  end

  def choose_move(attacker, target)
    usable = attacker.moves.select { |m| m.power.to_i.positive? && m.pp.positive? }
    return struggle_move(attacker) if usable.empty?

    usable.sort_by { |m| [-expected_damage(attacker, target, m), -m.power.to_i] }.first
  end

  def struggle_move(attacker)
    Move.new(name: "Struggle", type: attacker.types.first || "normal", power: 10, accuracy: nil, pp: 100)
  end

  def expected_damage(attacker, target, move)
    move.power.to_f * damage_multiplier_for(attacker, target, move.type)
  end

  def apply_damage(target_team_index, target_index, target, damage)
    damaged = target.take_damage(damage)
    @teams[target_team_index][target_index] = damaged
    damaged
  end

  def action_entry(round, attacker_team_index, move_type, damage, damaged, move_name = nil)
    entry = {
      round: round,
      attacker: attacker_team_index,
      move_type: move_type,
      damage: damage,
      ko: damaged.fainted?
    }
    entry[:move] = move_name if move_name
    entry
  end

  def damage_for(attacker, target)
    base = [attacker.stat("Attack") - target.stat("Defense"), 1].max
    move_type = move_type_for(attacker, target)
    multiplier = damage_multiplier_for(attacker, target, move_type)
    [(base * multiplier).round, 1].max
  end

  def move_damage_for(attacker, target, move)
    base = [attacker.stat("Attack") - target.stat("Defense"), 1].max
    power_factor = move.power.to_i / 50.0
    multiplier = damage_multiplier_for(attacker, target, move.type)
    multiplier = 1.0 if multiplier.zero?
    [(base * power_factor * multiplier).round, 1].max
  end

  def damage_multiplier_for(attacker, target, move_type)
    return 1.0 unless move_type

    @effectiveness.damage_multiplier(
      attacker_types: attacker.types,
      move_type: move_type,
      defender_types: target.types
    )
  end

  def move_type_for(attacker, target)
    type_options = attacker.types.map { |type| [type, damage_multiplier_for(attacker, target, type)] }
    return nil if type_options.empty?

    type, multiplier = type_options.max_by(&:last)
    return nil if multiplier.zero?

    type
  end

  def alive_count(team_index)
    @teams[team_index].count(&:alive?)
  end
end
