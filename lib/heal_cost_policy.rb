# frozen_string_literal: true

class HealCostPolicy
  DEFAULT_COST_PER_HP = 0.5
  BASE_LEVEL = 5

  def initialize(cost_per_hp: DEFAULT_COST_PER_HP)
    @cost_per_hp = cost_per_hp
  end

  def missing_hp(hp_max, hp_current)
    return 0 if hp_max.to_i <= 0

    [hp_max.to_i - hp_current.to_i, 0].max
  end

  def cost(missing_hp, average_level = BASE_LEVEL)
    level = [average_level.to_i, 1].max
    (missing_hp.to_i * @cost_per_hp * level / BASE_LEVEL.to_f).round
  end
end
