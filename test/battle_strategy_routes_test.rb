# frozen_string_literal: true

require_relative "server_test_helpers"
require_relative "battle_test_helpers"
class ServerBattleItemTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport
  include ServerBattleTestHelpers

  def setup
    super
    fill_team("user-a")
  end

  def test_battle_panel_shows_assigned_item_on_player_member
    member_id = @repository.all("user-a").first.id
    @repository.assign_item("user-a", member_id, "potion")

    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "carrega: Pocao"
  end

  def test_battle_consumes_assigned_item_and_clears_member_without_debit
    member_id = @repository.all("user-a").first.id
    @inventory.add("user-a", "potion", 1)
    post "/team/#{member_id}/item", { item_name: "potion" }, user_session("user-a")
    assert_equal 0, TestDatabase.inventory_quantity("user-a", "potion"), "equipar debita"

    @progression.update_hp("user-a", member_id, 200, 90)
    stub_battle_start { get "/battle", {}, user_session("user-a") }
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "usou 1 Pocao", "copy C3: uso conta a unidade consumida"
    assert_includes last_response.body, "restam 0", "copy C3: uso informa o estoque restante"
    assert_equal 0, TestDatabase.inventory_quantity("user-a", "potion"),
                 "item atribuido consumido nao debita de novo (ja saiu na equipacao)"
    assert_nil @repository.all("user-a").first.assigned_item, "poke fica sem item apos consumir em batalha"
  end
end

class ServerBattleHeldItemTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport
  include ServerBattleTestHelpers

  def setup
    super
    fill_team("user-a")
  end

  def shield_opponent
    Pokemon.new(
      name: "shuckle",
      sprite: "https://example.com/shuckle.png",
      number: 213,
      types: [],
      stats: [
        { name: "HP", value: 200 },
        { name: "Attack", value: 1 },
        { name: "Defense", value: 100 },
        { name: "Speed", value: 1 }
      ]
    )
  end

  def test_battle_panel_shows_held_item_on_player_member
    member_id = @repository.all("user-a").first.id
    @repository.assign_held_item("user-a", member_id, "choice-band")

    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "segura: Choice Band"
  end

  def test_battle_play_does_not_debit_held_item_inventory
    member_id = @repository.all("user-a").first.id
    @repository.assign_held_item("user-a", member_id, "choice-band")
    @inventory.add("user-a", "choice-band", 3)

    stub_battle_start { get "/battle", {}, user_session("user-a") }
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_equal 3, TestDatabase.inventory_quantity("user-a", "choice-band"),
                 "held item nao é debitado em rodada"
    refute_includes last_response.body, "<html"
  end

  def test_battle_play_with_held_item_does_not_consume_on_finish
    member_id = @repository.all("user-a").first.id
    @repository.assign_held_item("user-a", member_id, "choice-band")
    @inventory.add("user-a", "choice-band", 2)

    stub_battle_start do
      60.times do
        post "/battle/play", {}, user_session("user-a")
        break if last_response.body.include?("Fim de batalha")
      end
    end

    assert_equal 2, TestDatabase.inventory_quantity("user-a", "choice-band"),
                 "held item nao é debitado no fim da batalha"
  end
end
