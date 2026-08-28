# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/team_service"
require_relative "../lib/team_repository"
require_relative "../lib/progression_repository"
require_relative "../lib/inventory_repository"
require_relative "../lib/wallet_repository"

class PokemonFaintedTest < Minitest::Test
  def test_fainted_when_hp_max_positive_and_current_zero
    poke = Pokemon.new(name: "pikachu", sprite: "s", number: 25, hp_max: 10, hp_current: 0)

    assert_equal true, poke.fainted?
    assert_equal false, poke.alive?
  end

  def test_not_fainted_when_hp_positive
    poke = Pokemon.new(name: "pikachu", sprite: "s", number: 25, hp_max: 10, hp_current: 5)

    assert_equal false, poke.fainted?
    assert_equal true, poke.alive?
  end

  def test_not_fainted_when_never_fought_hp_max_zero
    poke = Pokemon.new(name: "pikachu", sprite: "s", number: 25, hp_max: 0, hp_current: 0)

    assert_equal false, poke.fainted?
    assert_equal true, poke.alive?
  end

  def test_not_fainted_when_hp_max_nil_treated_as_zero
    poke = Pokemon.new(name: "pikachu", sprite: "s", number: 25, hp_max: 0, hp_current: 0)

    assert_equal false, poke.fainted?
  end

  def test_fainted_consistent_with_usable_hp
    # usable_hp? false => fainted? true, usable_hp? true => not necessarily fainted (hp_max==0)
    fainted = Pokemon.new(name: "p", sprite: "s", number: 1, hp_max: 10, hp_current: 0)
    usable_fresh = Pokemon.new(name: "p", sprite: "s", number: 1, hp_max: 0, hp_current: 0)
    usable_alive = Pokemon.new(name: "p", sprite: "s", number: 1, hp_max: 10, hp_current: 5)

    assert_equal false, fainted.usable_hp?
    assert_equal true, fainted.fainted?

    assert_equal true, usable_fresh.usable_hp?
    assert_equal false, usable_fresh.fainted?

    assert_equal true, usable_alive.usable_hp?
    assert_equal false, usable_alive.fainted?
  end
end

class FaintedRemoveTest < Minitest::Test
  include TestSupport

  def setup
    TestDatabase.setup!
    TestDatabase.clear_team!
    @team = TeamRepository.new
    @progression = ProgressionRepository.new
    @inventory = InventoryRepository.new
    @wallet = WalletRepository.new
    @service = TeamService.new(
      api: -> { PokeApiFake.new },
      team: @team,
      progression: @progression,
      inventory: @inventory,
      wallet: @wallet
    )
  end

  def fill_team(user_id)
    (1..6).each { |n| @team.add(user_id, build_pokemon_record("pokemon#{n}", n)) }
  end

  def test_remove_fainted_returns_false
    fill_team("user-a")
    target = @team.all("user-a").first
    @progression.update_hp("user-a", target.id, 10, 0)
    @inventory.add("user-a", "potion", 1)
    @team.assign_item("user-a", target.id, "potion")
    @inventory.add("user-a", "choice-band", 1)
    @team.assign_held_item("user-a", target.id, "choice-band")

    result = @service.remove_member("user-a", target.id)

    assert_equal false, result
    assert_equal 6, @team.all("user-a").size, "fainted nao deve ser removido (6->6)"
    # assign via repository nao debita estoque, entao inventario permanece 1; bloqueado nao restaura
    assert_equal 1, TestDatabase.inventory_quantity("user-a", "potion"),
                 "item nao deve ser devolvido quando bloqueado"
    assert_equal 1, TestDatabase.inventory_quantity("user-a", "choice-band"),
                 "held nao deve ser devolvido quando bloqueado"
    assert_includes @team.all("user-a").map(&:id), target.id
  end

  def test_remove_with_usable_hp_succeeds
    fill_team("user-a")
    target = @team.all("user-a").first
    @progression.update_hp("user-a", target.id, 10, 5)
    @inventory.add("user-a", "potion", 1)
    @team.assign_item("user-a", target.id, "potion")

    result = @service.remove_member("user-a", target.id)

    assert result
    assert_equal 5, @team.all("user-a").size
    # repository assign nao debita, entao 1 + restore 1 => 2
    assert_equal 2, TestDatabase.inventory_quantity("user-a", "potion")
    refute_includes @team.all("user-a").map(&:id), target.id
  end

  def test_remove_never_fought_hp_max_zero_succeeds
    fill_team("user-a")
    target = @team.all("user-a").first
    # hp_max==0 hp_current==0 => never fought, alive?
    # No progression => hp_max 0 - nothing to update
    result = @service.remove_member("user-a", target.id)

    assert result
    assert_equal 5, @team.all("user-a").size
  end

  def test_remove_unknown_id_returns_false
    fill_team("user-a")

    result = @service.remove_member("user-a", "999999")

    assert_equal false, result
    assert_equal 6, @team.all("user-a").size
  end

  def test_reset_clears_even_when_all_fainted
    fill_team("user-a")
    @team.all("user-a").each { |m| @progression.update_hp("user-a", m.id, 10, 0) }
    first = @team.all("user-a").first
    @inventory.add("user-a", "potion", 1)
    @team.assign_item("user-a", first.id, "potion")

    @service.reset("user-a")

    assert_empty @team.all("user-a"), "reset deve limpar mesmo com todos fainted"
    assert_equal 2, TestDatabase.inventory_quantity("user-a", "potion"), "reset devolve itens (1+1)"
  end
end
