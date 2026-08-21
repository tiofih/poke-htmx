# frozen_string_literal: true

class JourneyService
  def initialize(user_state:, team:)
    @user_state = user_state
    @team = team
  end

  def started?(user_id)
    @user_state.started?(user_id) || @team.all(user_id).size >= TeamRepository::MAX_TEAM_SIZE
  end

  def mark_started(user_id)
    @user_state.mark_started(user_id)
  end

  def mark_started_when_full(user_id)
    mark_started(user_id) if @team.all(user_id).size >= TeamRepository::MAX_TEAM_SIZE
  end
end
