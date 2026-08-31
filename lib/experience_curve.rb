# frozen_string_literal: true

class ExperienceCurve
  class << self
    def xp_needed(level)
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

    private # rubocop:disable Lint/UselessAccessModifier
  end
end
