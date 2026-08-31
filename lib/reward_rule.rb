# frozen_string_literal: true

class RewardRule
  DEFAULT_REWARDS = {
    win_xp: 50,
    draw_xp: 25,
    lose_xp: 20,
    win_money: 100,
    draw_money: 50,
    lose_money: 40,
    win_levels: 2,
    draw_levels: 1,
    lose_levels: 1
  }.freeze

  def initialize(options = {})
    @rewards = DEFAULT_REWARDS.merge(options)
  end

  def xp_for(result)
    reward_for(result, :win_xp, :draw_xp, :lose_xp)
  end

  def money_for(result)
    reward_for(result, :win_money, :draw_money, :lose_money)
  end

  def levels_for(result)
    reward_for(result, :win_levels, :draw_levels, :lose_levels)
  end

  private

  def reward_for(result, win_key, draw_key, lose_key)
    case result
    when :win then @rewards[win_key]
    when :draw then @rewards[draw_key]
    when :lose then @rewards[lose_key]
    else 0
    end
  end
end
