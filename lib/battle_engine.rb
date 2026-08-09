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
      play_round(rounds)
    end
    BattleResult.new(winner: winner, log: @log, rounds: rounds)
  end

  private

  def play_round(round)
    alive_and_actionable.each do |team_index, index|
      break if finished?

      act(team_index, index, round)
    end
  end

  def alive_and_actionable
    @teams.each_with_index.flat_map do |team, team_index|
      team.each_with_index.filter_map { |pokemon, index| [team_index, index] if pokemon.alive? }
    end.sort_by do |team_index, index|
      [-@teams[team_index][index].stat("Speed"), team_index, index]
    end
  end

  def act(attacker_team_index, attacker_index, round)
    target_team_index = 1 - attacker_team_index
    target_index = @target_strategy.call(@teams[target_team_index])

    attacker = @teams[attacker_team_index][attacker_index]
    target = @teams[target_team_index][target_index]
    damage = damage_for(attacker, target)
    damaged = target.take_damage(damage)
    @teams[target_team_index][target_index] = damaged
    @log << {
      round: round,
      attacker: attacker_team_index,
      move_type: move_type_for(attacker),
      damage: damage,
      ko: damaged.fainted?
    }
  end

  def damage_for(attacker, target)
    [attacker.stat("Attack") - target.stat("Defense"), 1].max
  end

  def move_type_for(attacker)
    attacker.types.first
  end

  def alive_count(team_index)
    @teams[team_index].count(&:alive?)
  end

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
end