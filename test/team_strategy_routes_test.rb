# frozen_string_literal: true

require_relative "server_test_helpers"
class ServerTeamItemTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_post_team_item_assigns_item_to_member
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id

    post "/team/#{pikachu_id}/item", { item_name: "potion" }, user_session("user-a")

    assert last_response.ok?
    assert_equal "potion", @repository.all("user-a").first.assigned_item
    refute_includes last_response.body, "<html"
  end

  def test_post_team_item_rerenders_manage_fragment
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @inventory.add("user-a", "potion", 2)

    post "/team/#{pikachu_id}/item", { item_name: "potion" }, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, 'name="item_name"'
    assert_includes last_response.body, 'value="potion" selected'
  end

  def test_post_team_item_with_empty_name_clears_assignment
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @repository.assign_item("user-a", pikachu_id, "potion")

    post "/team/#{pikachu_id}/item", { item_name: "" }, user_session("user-a")

    assert last_response.ok?
    assert_nil @repository.all("user-a").first.assigned_item
    assert_includes last_response.body, 'value="" selected', '"Nenhum" volta a ser o selecionado'
  end

  def test_post_team_item_with_unknown_item_shows_notice_and_does_not_assign
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id

    post "/team/#{pikachu_id}/item", { item_name: "master-ball" }, user_session("user-a")

    assert last_response.ok?
    assert_nil @repository.all("user-a").first.assigned_item
    assert_includes last_response.body, "Item não disponível"
  end

  def test_post_team_item_of_other_users_member_is_noop
    @repository.add("user-a", pikachu_pokemon)
    @repository.add("user-b", bulbasaur_pokemon)
    bulbasaur_id = @repository.all("user-b").first.id

    post "/team/#{bulbasaur_id}/item", { item_name: "potion" }, user_session("user-a")

    assert last_response.ok?
    assert_nil @repository.all("user-b").first.assigned_item
    assert_nil @repository.all("user-a").first.assigned_item, "membro do proprio usuario nao muda"
  end

  def test_team_manage_renders_item_select_with_inventory_and_current_selection
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @repository.assign_item("user-a", pikachu_id, "potion")
    @inventory.add("user-a", "potion", 2)

    PokeApiStub.with_available_move_names(%w[growl]) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'name="item_name"'
    assert_includes last_response.body, "Salvar item"
    assert_includes last_response.body, "Nenhum"
    assert_includes last_response.body, 'value="potion"'
    assert_includes last_response.body, "×2"
    assert_includes last_response.body, 'value="potion" selected'
  end
end

class ServerTeamHeldItemTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_post_team_held_item_assigns_held_item_to_member
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @inventory.add("user-a", "choice-band", 1)

    post "/team/#{pikachu_id}/held-item", { item_name: "choice-band" }, user_session("user-a")

    assert last_response.ok?
    assert_equal "choice-band", @repository.all("user-a").first.held_item
    refute_includes last_response.body, "<html"
  end

  def test_post_team_held_item_rerenders_manage_fragment_with_selection
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @inventory.add("user-a", "choice-band", 1)

    post "/team/#{pikachu_id}/held-item", { item_name: "choice-band" }, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Salvar segurável"
    assert_includes last_response.body, 'value="choice-band" selected'
  end

  def test_post_team_held_item_with_empty_name_clears_assignment
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @repository.assign_held_item("user-a", pikachu_id, "choice-band")

    post "/team/#{pikachu_id}/held-item", { item_name: "" }, user_session("user-a")

    assert last_response.ok?
    assert_nil @repository.all("user-a").first.held_item
    assert_includes last_response.body, 'value="" selected'
  end

  def test_post_team_held_item_without_inventory_shows_notice_and_does_not_assign
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id

    post "/team/#{pikachu_id}/held-item", { item_name: "choice-band" }, user_session("user-a")

    assert last_response.ok?
    assert_nil @repository.all("user-a").first.held_item
    assert_includes last_response.body, "Item não disponível para equipar."
  end

  def test_post_team_held_item_with_consumable_rejected
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @inventory.add("user-a", "potion", 1)

    post "/team/#{pikachu_id}/held-item", { item_name: "potion" }, user_session("user-a")

    assert last_response.ok?
    assert_nil @repository.all("user-a").first.held_item
    assert_includes last_response.body, "Item não disponível para equipar."
  end

  def test_post_team_held_item_of_other_users_member_is_noop
    @repository.add("user-b", bulbasaur_pokemon)
    @inventory.add("user-b", "choice-band", 1)
    bulbasaur_id = @repository.all("user-b").first.id

    post "/team/#{bulbasaur_id}/held-item", { item_name: "choice-band" }, user_session("user-a")

    assert last_response.ok?
    assert_nil @repository.all("user-b").first.held_item
  end

  def test_team_manage_renders_held_item_select_with_inventory_and_current_selection
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @repository.assign_held_item("user-a", pikachu_id, "choice-scarf")
    @inventory.add("user-a", "choice-band", 2)
    @inventory.add("user-a", "choice-scarf", 1)

    PokeApiStub.with_available_move_names(%w[growl]) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Segurável:"
    assert_includes last_response.body, "Salvar segurável"
    assert_includes last_response.body, 'value="choice-band"'
    assert_includes last_response.body, 'value="choice-scarf" selected'
    refute_includes last_response.body, 'name="held_item"', "select de seguravel usa item_name"
  end

  def test_team_manage_consumable_select_does_not_show_held_items
    @repository.add("user-a", pikachu_pokemon)
    @inventory.add("user-a", "choice-band", 1)
    @inventory.add("user-a", "potion", 2)

    PokeApiStub.with_available_move_names(%w[growl]) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'name="item_name"'
    assert_includes last_response.body, "Pocao"
    assert_equal 1, last_response.body.scan("Choice Band").size,
                 "held aparece apenas no select de seguravel, nao no de consumivel"
  end
end
