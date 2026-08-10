# frozen_string_literal: true

class EvolutionRule
  class << self
    def next_stage(_current_number:, level:, evolutions:)
      candidates = evolutions
                   .select { |evo| evo[:min_level] && evo[:min_level] <= level }
      return nil if candidates.empty?

      candidates.min_by { |evo| [evo[:min_level], evo[:number]] }
                .slice(:number, :name)
    end
  end
end
