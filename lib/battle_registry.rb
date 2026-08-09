# frozen_string_literal: true

class BattleRegistry
  def initialize
    @battles = {}
  end

  def fetch(user_id)
    @battles[user_id]
  end

  def set(user_id, battle)
    @battles[user_id] = battle
  end

  def clear(user_id)
    @battles.delete(user_id)
  end
end
