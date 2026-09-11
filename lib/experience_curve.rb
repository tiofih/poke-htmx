# frozen_string_literal: true

class ExperienceCurve
  # Flat early-game cost so L1-3 level at a steady, friendly pace.
  EARLY_XP = 60

  class << self
    def xp_needed(level)
      return EARLY_XP if level <= 3

      level * 100
    end

    def level_for_xp(total_xp)
      level = 1
      level += 1 while total_xp >= cumulative_xp_for(level)
      level
    end

    def cumulative_xp_for(level)
      level * (level + 1) * 100 / 2
    end
  end
end
