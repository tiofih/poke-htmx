# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/team_repository"
require_relative "../lib/user_state_repository"
require_relative "../lib/journey_service"

module JourneyServiceTestHelpers
  include TestSupport

  def setup
    TestDatabase.setup!
    TestDatabase.clear_team!
    TestDatabase.clear_user_state!
    @team = TeamRepository.new
    @journey = JourneyService.new(user_state: UserStateRepository.new, team: @team)
  end

  def fill_team(user_id)
    (1..TeamRepository::MAX_TEAM_SIZE).each do |number|
      @team.add(user_id, build_pokemon_record("pokemon#{number}", number))
    end
  end
end

class JourneyStartedTest < Minitest::Test
  include JourneyServiceTestHelpers

  def test_not_started_with_empty_team_and_no_flag
    assert_equal false, @journey.started?("user-a")
  end

  def test_team_of_six_derives_started_without_flag
    fill_team("user-a")

    assert_equal true, @journey.started?("user-a")
  end

  def test_flag_alone_does_not_liberate_with_empty_team
    @journey.mark_started("user-a")

    assert_equal false, @journey.started?("user-a")
  end

  def test_flag_alone_does_not_liberate_below_six
    @journey.mark_started("user-a")
    5.times { |n| @team.add("user-a", build_pokemon_record("pokemon#{n}", n + 1)) }

    assert_equal false, @journey.started?("user-a")
  end

  def test_team_size_liberates_even_without_flag
    fill_team("user-b")

    assert_equal true, @journey.started?("user-b")
  end

  def test_isolation_between_users
    fill_team("user-a")

    assert_equal true, @journey.started?("user-a")
    assert_equal false, @journey.started?("user-b")
  end
end

class JourneyMarkWhenFullTest < Minitest::Test
  include JourneyServiceTestHelpers

  def test_mark_when_full_persists_flag_at_six_members
    fill_team("user-a")
    user_state = UserStateRepository.new

    refute user_state.started?("user-a")
    @journey.mark_started_when_full("user-a")

    assert_equal true, user_state.started?("user-a")
  end

  def test_mark_when_full_does_not_persist_below_six
    @team.add("user-a", build_pokemon_record("pikachu", 25))
    @journey.mark_started_when_full("user-a")

    assert_equal false, UserStateRepository.new.started?("user-a")
  end
end
