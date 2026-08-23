# frozen_string_literal: true

require_relative "pokemon"
require_relative "move"

class PokemonRating
  STAT_WEIGHTS = {
    "HP" => 0.5,
    "Attack" => 1.0,
    "Defense" => 1.0,
    "Sp.Atk" => 1.0,
    "Sp.Def" => 1.0,
    "Speed" => 1.0
  }.freeze

  TIERS = {
    S: 600,
    A: 500,
    B: 420,
    C: 350,
    D: 280,
    F: 0
  }.freeze

  MOVE_TOP_N = 4
  STAB_MULTIPLIER = 1.5

  def self.rate(pokemon, moves: [])
    score = weighted_stats(pokemon.stats).round + move_bonus(pokemon.types, moves)
    { score: score, tier: tier_for(score) }
  end

  class << self
    private

    def weighted_stats(stats)
      stats.sum do |stat|
        weight = STAT_WEIGHTS[stat[:name]]
        weight ? stat[:value].to_i * weight : 0
      end
    end

    def move_bonus(types, moves)
      effective_powers = moves.filter_map do |move|
        next unless move.power.to_i.positive?

        multiplier = types.include?(move.type) ? STAB_MULTIPLIER : 1.0
        move.power.to_i * multiplier
      end
      return 0 if effective_powers.empty?

      top = effective_powers.max(MOVE_TOP_N)
      (top.sum / top.size).round
    end

    def tier_for(score)
      TIERS.each { |tier, threshold| return tier if score >= threshold }
      :F
    end
  end
end
