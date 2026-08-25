# frozen_string_literal: true

require_relative "server_test_helpers"
class ServerMartTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def setup
    super
    fill_team("user-a")
  end

  def test_mart_buy_debits_wallet_and_adds_to_inventory
    @wallet.grant("user-a", 100)

    post "/mart/buy", { item_name: "potion", quantity: "2" }, user_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, "<html"
    assert_match(/comprado/i, last_response.body.strip)
    assert_includes last_response.body, "notice--success"
    assert_equal 2, TestDatabase.inventory_quantity("user-a", "potion")
    assert_equal 60, @wallet.balance("user-a")
  end

  def test_mart_buy_with_insufficient_balance_shows_notice_without_charging
    @wallet.grant("user-a", 10)

    post "/mart/buy", { item_name: "potion", quantity: "1" }, user_session("user-a")

    assert last_response.ok?
    assert_match(/insuficiente/i, last_response.body.strip)
    assert_equal 0, TestDatabase.inventory_quantity("user-a", "potion")
    assert_equal 10, @wallet.balance("user-a")
  end

  def test_mart_buy_with_unknown_item_shows_notice_without_charging
    @wallet.grant("user-a", 100)

    post "/mart/buy", { item_name: "master-ball", quantity: "1" }, user_session("user-a")

    assert last_response.ok?
    assert_match(/não disponível/i, last_response.body.strip)
    assert_equal 0, TestDatabase.inventory_quantity("user-a", "master-ball")
    assert_equal 100, @wallet.balance("user-a")
  end

  def test_mart_fragment_shows_catalog_inventory_and_balance
    @wallet.grant("user-a", 100)

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Poke Mart"
    assert_includes last_response.body, "Pocao"
    assert_includes last_response.body, %(hx-post="/mart/buy")
    assert_includes last_response.body, "Saldo: 100"
  end

  def test_mart_fragment_shows_affordable_quantity
    @wallet.grant("user-a", 100)

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Pocao — 20 ×5"
    assert_includes last_response.body, "Super Pocao — 50 ×2"
    assert_includes last_response.body, "Hiper Pocao — 100 ×1"
    mart_form = last_response.body[%r{<form[^>]*hx-post="/mart/buy".*?</form>}m]
    refute_nil mart_form
    refute_includes mart_form, "disabled"
  end

  def test_mart_fragment_disables_buy_when_insufficient_balance
    @wallet.grant("user-a", 10)

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    mart_form = last_response.body[%r{<form[^>]*hx-post="/mart/buy".*?</form>}m]
    refute_nil mart_form
    assert_includes mart_form, "disabled"
  end

  def test_mart_buy_adds_row_visible_in_fragment_inventory
    @wallet.grant("user-a", 100)

    post "/mart/buy", { item_name: "potion", quantity: "1" }, user_session("user-a")

    assert_includes last_response.body, "potion"
  end

  def test_mart_sell_credits_wallet_and_debits_inventory
    @wallet.grant("user-a", 100)
    @inventory.add("user-a", "potion", 2)

    post "/mart/sell", { item_name: "potion", quantity: "1" }, user_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, "<html"
    assert_match(/vendido/i, last_response.body.strip)
    assert_includes last_response.body, "notice--success"
    assert_equal 1, TestDatabase.inventory_quantity("user-a", "potion")
    assert_equal 110, @wallet.balance("user-a")
  end

  def test_mart_sell_with_insufficient_stock_does_not_credit
    @wallet.grant("user-a", 100)
    @inventory.add("user-a", "potion", 1)

    post "/mart/sell", { item_name: "potion", quantity: "3" }, user_session("user-a")

    assert last_response.ok?
    assert_match(/estoque/i, last_response.body.strip)
    assert_equal 1, TestDatabase.inventory_quantity("user-a", "potion")
    assert_equal 100, @wallet.balance("user-a")
  end

  def test_mart_fragment_shows_sell_button_per_inventory_item
    @wallet.grant("user-a", 100)
    @inventory.add("user-a", "potion", 2)

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, %(hx-post="/mart/sell")
    sell_form = last_response.body[%r{<form[^>]*hx-post="/mart/sell".*?</form>}m]
    refute_nil sell_form
  end
end

class ServerMartJourneyGateTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_mart_buy_blocked_before_journey
    @repository.add("user-novo", pikachu_pokemon)
    @wallet.grant("user-novo", 100)

    post "/mart/buy", { item_name: "potion", quantity: "2" }, user_session("user-novo")

    assert last_response.ok?
    refute_includes last_response.body, "<html"
    assert_match(/jornada/i, last_response.body)
    assert_equal 0, TestDatabase.inventory_quantity("user-novo", "potion")
    assert_equal 100, @wallet.balance("user-novo")
  end

  def test_mart_buy_released_after_journey_started
    fill_team("user-a")
    @wallet.grant("user-a", 100)

    post "/mart/buy", { item_name: "potion", quantity: "1" }, user_session("user-a")

    assert_match(/comprado/i, last_response.body.strip)
    assert_equal 1, TestDatabase.inventory_quantity("user-a", "potion")
  end

  def test_mart_sell_blocked_before_journey
    @repository.add("user-novo", pikachu_pokemon)
    @inventory.add("user-novo", "potion", 1)

    post "/mart/sell", { item_name: "potion", quantity: "1" }, user_session("user-novo")

    assert last_response.ok?
    assert_match(/jornada/i, last_response.body)
    assert_equal 1, TestDatabase.inventory_quantity("user-novo", "potion")
    assert_equal 0, @wallet.balance("user-novo")
  end
end
