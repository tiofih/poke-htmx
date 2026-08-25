# frozen_string_literal: true

require_relative "server_test_helpers"

class JourneyRestartTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def setup
    super
    fill_team("user-a")
    @wallet.grant("user-a", 500)
    @inventory.add("user-a", "potion", 3)
  end

  def test_restart_journey_clears_team_and_resets_balance
    post "/journey/restart", {}, user_session("user-a")

    assert last_response.ok?
    assert_empty @repository.all("user-a")
    assert_equal 200, TestDatabase.wallet_balance("user-a")
    refute_includes last_response.body, "pikachu"
  end

  def test_restart_journey_returns_equipped_items_to_inventory
    member = @repository.all("user-a").first
    post "/team/#{member.id}/item", { item_name: "potion" }, user_session("user-a")
    assert_equal 2, TestDatabase.inventory_quantity("user-a", "potion"), "equipar debita (3 -> 2)"

    post "/journey/restart", {}, user_session("user-a")

    assert_equal 3, TestDatabase.inventory_quantity("user-a", "potion"), "item equipado devolvido ao estoque"
    assert_empty @repository.all("user-a")
  end

  def test_restart_journey_reblocks_battle_gate
    post "/journey/restart", {}, user_session("user-a")

    get "/battle", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_match(/Monte seu time inicial/i, last_response.body)
  end
end
