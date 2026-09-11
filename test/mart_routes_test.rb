# frozen_string_literal: true

require_relative "server_test_helpers"
require_relative "../lib/item_catalog"
require_relative "../lib/stone_rotation"
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

  def test_mart_buy_opens_from_modal_trigger_with_catalog_inventory_and_balance
    @wallet.grant("user-a", 100)

    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'data-od-id="open-modal-mart"'

    get "/team/mart", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Poke Mart"
    assert_includes last_response.body, "Pocao"
    assert_includes last_response.body, %(hx-post="/mart/buy")
    assert_includes last_response.body, "Saldo: ¥100"
  end

  def test_mart_modal_shows_affordable_quantity
    @wallet.grant("user-a", 100)

    get "/team/mart", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Comprar ×5"
    assert_includes last_response.body, "+20 HP"
    assert_includes last_response.body, "+50 HP"
    assert_includes last_response.body, "+100 HP"
    mart_form = last_response.body[%r{<form[^>]*hx-post="/mart/buy".*?</form>}m]
    refute_nil mart_form
    refute_includes mart_form, "disabled"
  end

  def test_mart_modal_usability_labels_sell_display_name_and_out_of_rotation
    @wallet.grant("user-a", 100)
    @inventory.add("user-a", "potion", 2)

    get "/team/mart", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "+20 HP · ¥20 · 1.0 ¥/HP"
    sell_row = last_response.body[%r{<strong>.*?</strong>.*?<form[^>]*hx-post="/mart/sell".*?</form>}m]
    refute_nil sell_row
    assert_includes sell_row, "<strong>Pocao</strong>"
    assert_includes last_response.body, "Fora da oferta desta rodada:"
  end

  def test_mart_modal_disables_buy_when_insufficient_balance
    @wallet.grant("user-a", 10)

    get "/team/mart", {}, user_session("user-a")

    assert last_response.ok?
    mart_form = last_response.body[%r{<form[^>]*hx-post="/mart/buy".*?</form>}m]
    refute_nil mart_form
    assert_includes mart_form, "disabled"
  end

  def test_mart_buy_adds_row_visible_in_modal_inventory
    @wallet.grant("user-a", 100)

    post "/mart/buy", { item_name: "potion", quantity: "1" }, user_session("user-a")

    assert last_response.ok?
    get "/team/mart", {}, user_session("user-a")

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

  def test_mart_modal_shows_sell_button_per_inventory_item
    @wallet.grant("user-a", 100)
    @inventory.add("user-a", "potion", 2)

    get "/team/mart", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, %(hx-post="/mart/sell")
    sell_form = last_response.body[%r{<form[^>]*hx-post="/mart/sell".*?</form>}m]
    refute_nil sell_form
  end

  def test_mart_modal_hides_zero_quantity_inventory_from_sell
    @wallet.grant("user-a", 100)
    @inventory.add("user-a", "potion", 1)
    @inventory.use("user-a", "potion", 1)
    @inventory.add("user-a", "hyper-potion", 2)

    get "/team/mart", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "hyper-potion"
    refute_includes last_response.body, "potion — 0"
    potion_sell = last_response.body[%r{<strong>potion</strong>.*?</form>}m]
    assert_nil potion_sell
  end

  def test_mart_buy_stone_not_in_rotation_is_rejected_without_debit
    @wallet.grant("user-a", 200)
    stone_names = ItemCatalog.all.select { |item| item.category == "stone" }.map(&:name)
    not_offered = (stone_names - StoneRotation.new("user-a", 0).stones).first

    post "/mart/buy", { item_name: not_offered, quantity: "1" }, user_session("user-a")

    assert last_response.ok?
    assert_match(/oferta/i, last_response.body.strip)
    assert_equal 0, TestDatabase.inventory_quantity("user-a", not_offered)
    assert_equal 200, @wallet.balance("user-a")
  end

  def test_mart_buy_offered_stone_debits_80_and_adds_inventory
    @wallet.grant("user-a", 100)
    offered = StoneRotation.new("user-a", 0).stones.first

    post "/mart/buy", { item_name: offered, quantity: "1" }, user_session("user-a")

    assert last_response.ok?
    assert_match(/comprado/i, last_response.body.strip)
    assert_equal 1, TestDatabase.inventory_quantity("user-a", offered)
    assert_equal 20, @wallet.balance("user-a")
  end

  def test_mart_modal_shows_only_offered_stones
    @wallet.grant("user-a", 100)
    offered = StoneRotation.new("user-a", 0).stones
    not_offered = ItemCatalog.all.select { |item| item.category == "stone" }.map(&:name) - offered

    get "/team/mart", {}, user_session("user-a")

    assert last_response.ok?
    offered.each { |name| assert_includes last_response.body, name }
    not_offered.each { |name| refute_includes last_response.body, name }
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

# Sessao 0065 — C6 venda breaker no spiral
class SellInSpiralTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_sell_when_game_over_succeeds_and_enables_eventual_heal # rubocop:disable Metrics/AbcSize
    # spiral: 6 fainted (hp 10 each, 0/10) -> missing 60 -> cost 30, saldo 5 => game_over true
    fill_team("user-a")
    @repository.all("user-a").each { |m| @progression.update_hp("user-a", m.id, 10, 0) }
    @wallet.grant("user-a", 5)
    @inventory.add("user-a", "choice-band", 2) # price 80 -> sell 40 each
    # sanity: game_over? deve ser true
    assert_equal true, Server.settings.journey.game_over?("user-a")

    post "/mart/sell", { item_name: "choice-band", quantity: "1" }, htmx_session("user-a")

    assert last_response.ok?
    assert_match(/vendido/i, last_response.body)
    assert_includes last_response.body, "notice--success"
    assert_equal 1, TestDatabase.inventory_quantity("user-a", "choice-band"), "estoque decrementado"
    assert_equal 45, @wallet.balance("user-a"), "saldo 5 + 40 = 45"
    # ainda em game_over? mas vendavel; após vender, saldo 45 >=30 => heal liberado
    assert_equal false, Server.settings.journey.game_over?("user-a"),
                 "após venda saldo >= preview_cost => nao mais game_over"

    # heal agora deve curar tudo (bloqueio total liberado)
    post "/team/heal", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_match(/curado por 30/i, last_response.body)
    assert_equal 15, @wallet.balance("user-a"), "45 -30 =15 após cura"
    assert_equal 10, @progression.get("user-a", @repository.all("user-a").first.id)[:hp_current]
  end # rubocop:enable Metrics/AbcSize
end
