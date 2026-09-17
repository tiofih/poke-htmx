# frozen_string_literal: true

class JourneyService
  def initialize(team:, wallet: nil, heal_preview: nil)
    @team = team
    @wallet = wallet
    @heal_preview = heal_preview
  end

  def started?(user_id)
    @team.all(user_id).size >= TeamRepository::MAX_TEAM_SIZE
  end

  def battle_ready?(user_id)
    started?(user_id) && @team.all(user_id).any?(&:usable_hp?)
  end

  def game_over?(user_id)
    started?(user_id) && !battle_ready?(user_id) && !affordable_heal?(user_id)
  end

  private

  def affordable_heal?(user_id)
    return true if @wallet.nil? || @heal_preview.nil?

    @wallet.balance(user_id) >= @heal_preview.call(user_id)
  end
end
