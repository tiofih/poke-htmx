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

  def test_preview_cost_returns_total_cost_without_mutating
    add_pokemon("user-a", "pikachu", 25, hp_max: 45, hp_current: 35)
    add_pokemon("user-a", "bulbasaur", 1, hp_max: 50, hp_current: 40)
    @wallet.grant("user-a", 100)

    cost = @service.preview_cost("user-a")

    assert_equal 10, cost, "(10 + 10) * 0.5 = 10"
    assert_equal 100, @wallet.balance("user-a"), "preview não debita"
    assert_equal 35, @progression.get("user-a", TestDatabase.team_id("pikachu", "user-a"))[:hp_current],
                 "preview não cura"
  end
end

# Sessao 0065 — C1 heal suficiente cura tudo (bloqueio total, sem parcial)
class HealingWhenAffordableTest < Minitest::Test
  include HealServiceTestHelpers

  def test_heal_when_balance_sufficient_heals_all_and_charges
    # 2 membros com dano: 10 + 10 = 20 missing -> cost 10 (0.5)
    add_pokemon("user-a", "pikachu", 25, hp_max: 45, hp_current: 35)
    add_pokemon("user-a", "bulbasaur", 1, hp_max: 50, hp_current: 40)
    @wallet.grant("user-a", 100)

    result = @service.heal("user-a")

    assert_equal true, result[:healed]
    assert_equal :success, result[:kind]
    assert_equal 10, result[:cost]
    assert_equal 90, result[:balance]
    assert_match(/curado por 10/i, result[:notice])
    assert_match(/Saldo: 90/, result[:notice])
    assert_equal 45, @progression.get("user-a", TestDatabase.team_id("pikachu", "user-a"))[:hp_current]
    assert_equal 50, @progression.get("user-a", TestDatabase.team_id("bulbasaur", "user-a"))[:hp_current]
    assert_equal 90, @wallet.balance("user-a")
  end
end

# Sessao 0065 — C2 heal bloqueado (bloqueio total D3 A)
class HealingWhenUnaffordableTest < Minitest::Test
  include HealServiceTestHelpers

  def test_heal_when_balance_insufficient_does_not_heal
    add_pokemon("user-a", "pikachu", 25, hp_max: 45, hp_current: 35)
    add_pokemon("user-a", "bulbasaur", 1, hp_max: 50, hp_current: 40)
    @wallet.grant("user-a", 5)

    result = @service.heal("user-a")

    assert_equal false, result[:healed]
    assert_equal :error, result[:kind]
    assert_equal 10, result[:cost]
    assert_equal 5, result[:balance]
    assert_match(/Dinheiro insuficiente para curar \(custo 10, saldo 5\)/, result[:notice])
    assert_equal 35, @progression.get("user-a", TestDatabase.team_id("pikachu", "user-a"))[:hp_current],
                 "nada curado quando saldo insuficiente"
    assert_equal 40, @progression.get("user-a", TestDatabase.team_id("bulbasaur", "user-a"))[:hp_current],
                 "nada curado quando saldo insuficiente"
    assert_equal 5, @wallet.balance("user-a"), "wallet intacto"
  end
end

# Sessao 0065 — C5 preview_cost sem mutacao, ignora hp_max 0, arredonda 0.5
class HealPreviewCostTest < Minitest::Test
  include HealServiceTestHelpers

  def test_preview_cost_returns_total_cost_without_mutating
    add_pokemon("user-a", "pikachu", 25, hp_max: 45, hp_current: 35)
    add_pokemon("user-a", "bulbasaur", 1, hp_max: 50, hp_current: 40)
    add_pokemon("user-a", "charmander", 4) # hp_max 0 -> ignorado
    @wallet.grant("user-a", 7)

    cost = @service.preview_cost("user-a")

    assert_equal 10, cost, "(10 + 10) * 0.5 = 10, hp_max 0 ignorado"
    assert_equal 7, @wallet.balance("user-a"), "preview nao debita"
    assert_equal 35, @progression.get("user-a", TestDatabase.team_id("pikachu", "user-a"))[:hp_current],
                 "preview nao cura"
    assert_equal 40, @progression.get("user-a", TestDatabase.team_id("bulbasaur", "user-a"))[:hp_current]
  end

  def test_preview_cost_rounds_half
    add_pokemon("user-a", "pikachu", 25, hp_max: 10, hp_current: 9) # missing 1 -> cost 1 (0.5 round)
    assert_equal 1, @service.preview_cost("user-a")
  end
end
