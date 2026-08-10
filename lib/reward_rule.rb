# frozen_string_literal: true

class RewardRule
  DEFAULT_WIN_XP = 50
  DEFAULT_DRAW_XP = 25
  DEFAULT_LOSE_XP = 20

  def initialize(win_xp: DEFAULT_WIN_XP, draw_xp: DEFAULT_DRAW_XP, lose_xp: DEFAULT_LOSE_XP)
    @win_xp = win_xp
    @draw_xp = draw_xp
    @lose_xp = lose_xp
  end

  def xp_for(result)
    case result
    when :win then @win_xp
    when :draw then @draw_xp
    when :lose then @lose_xp
    else 0
    end
  end
end
