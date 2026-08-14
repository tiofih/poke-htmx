# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/progression_repository"
require_relative "../lib/wallet_repository"
require_relative "../lib/heal_service"

module HealServiceTestHelpers
  include TestSupport

  def setup
    TestDatabase.setup!
    TestDatabase.clear_team!
    @team = TeamRepository.new
    @progression = ProgressionRepository.new
    @wallet = WalletRepository.new
    @service = HealService.new(team: @team, progression: @progression, wallet: @wallet)
  end

  def add_pokemon(user_id, name, number, hp_max: nil, hp_current: nil)
    @team.add(user_id, build_pokemon_record(name, number))
    pokemon_id = TestDatabase.team_id(name, user_id)
    @progression.update_hp(user_id, pokemon_id, hp_max, hp_current || hp_max) if hp_max
    pokemon_id
  end
end

class HealServiceTest < Minitest::Test
  include HealServiceTestHelpers

  def test_heal_returns_cured_false_when_team_already_full
    add_pokemon("user-a", "pikachu", 25, hp_max: 45, hp_current: 45)
    @wallet.grant("user-a", 100)

    result = @service.heal("user-a")

    assert_equal false, result[:healed]
    assert_match(/já está curado/i, result[:notice])
    assert_equal 100, @wallet.balance("user-a"), "não debita quando já curado"
  end

  def test_heal_returns_cured_false_for_member_who_never_battled
    add_pokemon("user-a", "pikachu", 25)
    @wallet.grant("user-a", 100)

    result = @service.heal("user-a")

    assert_equal false, result[:healed]
    assert_match(/já está curado/i, result[:notice])
  end

  def test_heal_cures_team_and_charges_cost
    add_pokemon("user-a", "pikachu", 25, hp_max: 45, hp_current: 35)
    @wallet.grant("user-a", 100)

    result = @service.heal("user-a")

    assert_equal true, result[:healed]
    assert_equal 5, result[:cost], "10 HP faltante * 0.5 = 5"
    assert_equal 95, result[:balance]
    assert_match(/curado por 5/i, result[:notice])
    assert_equal 45, @progression.get("user-a", TestDatabase.team_id("pikachu", "user-a"))[:hp_current]
    assert_equal 95, @wallet.balance("user-a")
  end

  def test_heal_sums_missing_hp_across_team
    add_pokemon("user-a", "pikachu", 25, hp_max: 45, hp_current: 35)
    add_pokemon("user-a", "bulbasaur", 1, hp_max: 50, hp_current: 40)
    @wallet.grant("user-a", 100)

    result = @service.heal("user-a")

    assert_equal 10, result[:cost], "(10 + 10) * 0.5 = 10"
    assert_equal 90, result[:balance]
  end

  def test_heal_ignores_members_who_never_battled_in_cost
    add_pokemon("user-a", "pikachu", 25, hp_max: 45, hp_current: 35)
    add_pokemon("user-a", "bulbasaur", 1)
    @wallet.grant("user-a", 100)

    result = @service.heal("user-a")

    assert_equal 5, result[:cost], "apenas pikachu com HP faltante conta"
  end

  def test_heal_with_insufficient_balance_does_not_heal_or_debit
    add_pokemon("user-a", "pikachu", 25, hp_max: 45, hp_current: 35)
    @wallet.grant("user-a", 3)

    result = @service.heal("user-a")

    assert_equal false, result[:healed]
    assert_equal 5, result[:cost]
    assert_equal 3, result[:balance]
    assert_match(/insuficiente/i, result[:notice])
    assert_equal 35, @progression.get("user-a", TestDatabase.team_id("pikachu", "user-a"))[:hp_current]
    assert_equal 3, @wallet.balance("user-a")
  end

  def test_heal_with_empty_team_returns_cured_false_without_error
    result = @service.heal("user-a")

    assert_equal false, result[:healed]
    assert_match(/curado/i, result[:notice])
  end

  def test_heal_uses_injectable_policy_rate
    policy = HealCostPolicy.new(cost_per_hp: 2)
    service = HealService.new(team: @team, progression: @progression, wallet: @wallet, policy: policy)
    add_pokemon("user-a", "pikachu", 25, hp_max: 45, hp_current: 35)
    @wallet.grant("user-a", 100)

    result = service.heal("user-a")

    assert_equal 20, result[:cost], "10 HP faltante * 2 = 20"
    assert_equal 80, result[:balance]
  end
end
