# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/team_repository"
require_relative "../lib/progression_repository"
require_relative "../lib/wallet_repository"
require_relative "../lib/journey_service"

module JourneyServiceTestHelpers
  include TestSupport

  def setup
    TestDatabase.setup!
    TestDatabase.clear_team!
    @team = TeamRepository.new
    @progression = ProgressionRepository.new
    @journey = JourneyService.new(team: @team)
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

class JourneyBattleReadyTest < Minitest::Test
  include JourneyServiceTestHelpers

  def test_not_battle_ready_when_team_empty
    assert_equal false, @journey.battle_ready?("user-a")
  end

  def test_battle_ready_with_fresh_team_that_never_fought
    fill_team("user-a")

    assert_equal true, @journey.battle_ready?("user-a")
  end

  def test_not_battle_ready_when_all_hp_zero
    fill_team("user-a")
    @team.all("user-a").each do |member|
      @progression.update_hp("user-a", member.id, 200, 0)
    end

    assert_equal false, @journey.battle_ready?("user-a")
  end

  def test_battle_ready_when_partial_team_has_hp
    fill_team("user-a")
    zeroed = @team.all("user-a")
    zeroed[1..].each { |member| @progression.update_hp("user-a", member.id, 200, 0) }

    assert_equal true, @journey.battle_ready?("user-a")
  end
end

class JourneyGameOverTest < Minitest::Test
  include JourneyServiceTestHelpers

  def setup
    super
    @wallet = WalletRepository.new
    @heal_cost = 100
    @journey = JourneyService.new(
      team: @team,
      wallet: @wallet, heal_preview: ->(_user_id) { @heal_cost }
    )
  end

  def zero_all_hp(user_id)
    @team.all(user_id).each do |member|
      @progression.update_hp(user_id, member.id, 200, 0)
    end
  end

  def test_game_over_when_all_hp_zero_and_unaffordable
    fill_team("user-a")
    zero_all_hp("user-a")
    @wallet.grant("user-a", 50)

    assert_equal true, @journey.game_over?("user-a")
  end

  def test_not_game_over_when_heal_affordable
    fill_team("user-a")
    zero_all_hp("user-a")
    @wallet.grant("user-a", 200)

    assert_equal false, @journey.game_over?("user-a")
  end

  def test_not_game_over_when_partial_hp
    fill_team("user-a")
    zeroed = @team.all("user-a")
    zeroed[1..].each { |member| @progression.update_hp("user-a", member.id, 200, 0) }

    assert_equal false, @journey.game_over?("user-a")
  end

  def test_not_game_over_below_team_of_six
    @team.add("user-a", build_pokemon_record("pikachu", 25))

    assert_equal false, @journey.game_over?("user-a")
  end
end

# Sessao 0065 — C3 game_over true no spiral (visivel)
class JourneyGameOverSpiralTest < Minitest::Test
  include JourneyServiceTestHelpers

  def setup
    super
    @wallet = WalletRepository.new
    @heal_cost = 100
    @journey = JourneyService.new(
      team: @team,
      wallet: @wallet, heal_preview: ->(_user_id) { @heal_cost }
    )
  end

  def zero_all_hp(user_id)
    @team.all(user_id).each do |member|
      @progression.update_hp(user_id, member.id, 200, 0)
    end
  end

  def test_game_over_when_all_fainted_and_unaffordable_is_true
    fill_team("user-a")
    zero_all_hp("user-a")
    @wallet.grant("user-a", 50) # < 100

    assert_equal true, @journey.game_over?("user-a"),
                 "started + todos fainted + saldo < preview_cost => game_over"
  end

  def test_game_over_false_when_all_fainted_but_affordable
    fill_team("user-a")
    zero_all_hp("user-a")
    @wallet.grant("user-a", 150) # >=100

    assert_equal false, @journey.game_over?("user-a"),
                 "ainda derrotado mas curavel => nao game_over"
  end

  def test_game_over_false_when_not_started
    # sem time cheio, mesmo com HP zero e sem saldo, nao eh game over
    @team.add("user-a", build_pokemon_record("pikachu", 25))
    @progression.update_hp("user-a", TestDatabase.team_id("pikachu", "user-a"), 200, 0)

    assert_equal false, @journey.game_over?("user-a")
  end

  def test_game_over_false_when_partial_hp
    fill_team("user-a")
    zeroed = @team.all("user-a")
    zeroed[1..].each { |member| @progression.update_hp("user-a", member.id, 200, 0) }
    @wallet.grant("user-a", 10) # pouco saldo, mas ainda tem 1 vivo

    assert_equal false, @journey.game_over?("user-a")
  end
end
