# frozen_string_literal: true

require_relative "server_test_helpers"

class EvolutionRoutesTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def raichu
    Pokemon.new(name: "raichu", sprite: "https://example.com/raichu.png", number: 26)
  end

  def stone_evolutions_for_pikachu
    [{ number: 26, name: "raichu", item: "thunder-stone" }]
  end

  def use_stone_on(user_id, member_id, stone)
    PokeApiStub.with_stone_evolutions(stone_evolutions_for_pikachu) do
      PokeApiStub.with_find(raichu) do
        post "/team/#{member_id}/evolve", { item_name: stone }, user_session(user_id)
      end
    end
  end

  def test_use_stone_evolves_member_and_consumes_one
    fill_team("user-a")
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @inventory.add("user-a", "thunder-stone", 1)

    use_stone_on("user-a", pikachu_id, "thunder-stone")

    assert last_response.ok?
    assert_match(/evoluiu para raichu/i, last_response.body)
    member = @repository.all("user-a").find { |poke| poke.id == pikachu_id.to_i }
    assert_equal "raichu", member.name
    assert_equal 26, member.number
    assert_equal "https://example.com/raichu.png", member.sprite
    assert_equal 0, TestDatabase.inventory_quantity("user-a", "thunder-stone"), "pedra consumida"
  end

  def test_use_stone_without_compatible_stage_notice_without_consuming
    fill_team("user-a")
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @inventory.add("user-a", "fire-stone", 1)

    use_stone_on("user-a", pikachu_id, "fire-stone")

    assert_match(/não evolui/i, last_response.body)
    assert_equal "pikachu", @repository.all("user-a").first.name
    assert_equal 1, TestDatabase.inventory_quantity("user-a", "fire-stone"), "pedra não consumida"
  end

  def test_use_stone_without_inventory_notice_without_consuming
    fill_team("user-a")
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")

    use_stone_on("user-a", pikachu_id, "thunder-stone")

    assert_match(/não tem/i, last_response.body)
    assert_equal "pikachu", @repository.all("user-a").first.name
    assert_equal 0, TestDatabase.inventory_quantity("user-a", "thunder-stone")
  end

  def test_use_stone_target_already_in_team_notice
    fill_team("user-a",
              members: [["pikachu", 25], ["raichu", 26], ["charmander", 4],
                        ["squirtle", 7], ["pidgey", 16], ["rattata", 19]])
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @inventory.add("user-a", "thunder-stone", 1)

    use_stone_on("user-a", pikachu_id, "thunder-stone")

    assert_match(/já está no seu time/i, last_response.body)
    assert_equal "pikachu", @repository.all("user-a").first.name
    assert_equal 1, TestDatabase.inventory_quantity("user-a", "thunder-stone"), "pedra não consumida"
  end

  def test_use_stone_on_fainted_member_blocked_without_consuming
    fill_team("user-a")
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pikachu_id, 10, 0)
    @inventory.add("user-a", "thunder-stone", 1)

    use_stone_on("user-a", pikachu_id, "thunder-stone")

    assert_match(/derrotado/i, last_response.body)
    assert_equal "pikachu", @repository.all("user-a").first.name
    assert_equal 1, TestDatabase.inventory_quantity("user-a", "thunder-stone"), "pedra permanece"
  end

  def test_modal_lists_stone_evolutions_and_inventory_quantity
    fill_team("user-a")
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @inventory.add("user-a", "thunder-stone", 2)

    PokeApiStub.with_stone_evolutions([
                                        { number: 26, name: "raichu", item: "thunder-stone" },
                                        { number: 134, name: "vaporeon", item: "water-stone" }
                                      ]) do
      get "/team/#{pikachu_id}/evolution", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'id="evolution-modal"'
    assert_includes last_response.body, 'role="dialog"'
    assert_includes last_response.body, "raichu"
    assert_includes last_response.body, "vaporeon"
    assert_includes last_response.body, "Inventário: 2"
    assert_includes last_response.body, "water-stone"
    assert_includes last_response.body, %(hx-post="/team/#{pikachu_id}/evolve")
  end

  def test_manage_shows_evolve_button_but_team_fragment_does_not
    fill_team("user-a")
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    evolve_trigger = %(hx-get="/team/#{pikachu_id}/evolution")

    get "/team", {}, htmx_session("user-a")
    refute_includes last_response.body, evolve_trigger

    PokeApiStub.with_learnable_moves([{ level: 1, name: "growl" }]) do
      get "/team/manage", {}, user_session("user-a")
    end
    assert_includes last_response.body, evolve_trigger
  end

  def test_evolve_response_rerenders_the_modal
    fill_team("user-a")
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @inventory.add("user-a", "thunder-stone", 1)

    use_stone_on("user-a", pikachu_id, "thunder-stone")

    assert last_response.ok?
    assert_includes last_response.body, 'id="evolution-modal"', "resposta re-renderiza o mesmo modal"
    assert_match(/evoluiu para raichu/i, last_response.body)
  end
end
