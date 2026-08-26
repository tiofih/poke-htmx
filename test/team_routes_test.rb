# frozen_string_literal: true

require_relative "server_test_helpers"
class ServerTeamTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_first_access_generates_session_cookie
    PokeApiStub.with_find(pikachu_pokemon) do
      post "/team", pokeName: "pikachu"
    end

    assert last_response.ok?
    assert_includes last_response.headers["Set-Cookie"], "rack.session"
  end

  def test_two_sessions_keep_isolated_teams
    session_a = rack_test_session
    session_b = rack_test_session

    PokeApiStub.with_find(pikachu_pokemon) do
      session_a.post "/team", pokeName: "pikachu"
    end
    PokeApiStub.with_find(bulbasaur_pokemon) do
      session_b.post "/team", pokeName: "bulbasaur"
    end

    assert_includes session_a.last_response.body, "Adicionado ao time."
    team_a = session_a.last_response.body[%r{<div id="team-view".*?</div>}m]
    assert_includes team_a, "pikachu"
    refute_includes team_a, "bulbasaur"

    assert_includes session_b.last_response.body, "Adicionado ao time."
    team_b = session_b.last_response.body[%r{<div id="team-view".*?</div>}m]
    assert_includes team_b, "bulbasaur"
    refute_includes team_b, "pikachu"

    assert_equal 2, TestDatabase.distinct_user_ids.size
  end

  def test_post_team_persists_pokemon_for_session_user
    PokeApiStub.with_find(pikachu_pokemon) do
      post "/team", { pokeName: "pikachu" }, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Adicionado ao time."
    team = @repository.all("user-a")
    assert_equal 1, team.size
    assert_equal "pikachu", team.first.name
    assert_empty @repository.all("user-b")
  end

  def test_post_team_includes_team_view_out_of_band_swap
    PokeApiStub.with_find(pikachu_pokemon) do
      post "/team", { pokeName: "pikachu" }, htmx_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Adicionado ao time."
    assert_includes last_response.body, 'id="team-view"'
    assert_includes last_response.body, "hx-swap-oob"
    assert_includes last_response.body, 'hx-delete="/team"'
    assert_includes last_response.body, "pikachu"
  end

  def test_remove_from_full_team_returns_active_add_buttons_oob
    six = (1..6).map { |n| build_pokemon_record("pokemon#{n}", n) }
    six.each { |poke| @repository.add("user-a", poke) }
    pikachu_id = @repository.all("user-a").find { |poke| poke.name == "pokemon1" }.id

    delete "/team", { id: pikachu_id }, htmx_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, 'id="pokemon-list"'
    assert_includes last_response.body, "hx-swap-oob"
    refute_includes last_response.body, 'disabled="disabled"'
  end

  def test_add_sixth_member_disables_add_buttons_oob
    five = (1..5).map { |n| build_pokemon_record("pokemon#{n}", n) }
    five.each { |poke| @repository.add("user-a", poke) }
    sixth = build_pokemon_record("meowth", 52)

    PokeApiStub.with_find(sixth) do
      post "/team", { pokeName: "meowth" }, htmx_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'id="pokemon-list"'
    assert_includes last_response.body, "hx-swap-oob"
    assert_includes last_response.body, 'disabled="disabled"'
  end

  def test_team_fragment_manage_link_is_on_its_own_line
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_match(%r{<p class="team-tools">\s*<a href="#" hx-get="/team/manage"}, last_response.body)
  end

  def test_team_panel_shows_battle_cta_after_journey
    fill_team("user-a")

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_match(%r{<a class="gameloop-cta battle" href="/battle">Batalhar</a>}, last_response.body)
  end

  def test_team_panel_omits_battle_cta_before_journey
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    refute_match(/gameloop-cta battle/, last_response.body)
    refute_includes last_response.body, "Batalhar"
  end

  def test_post_team_starts_with_level_one_moves
    PokeApiStub.with_find(pikachu_pokemon) do
      PokeApiStub.with_learnable_moves(
        [{ level: 1, name: "growl" },
         { level: 1, name: "thunder-shock" },
         { level: 5, name: "quick-attack" }]
      ) do
        post "/team", { pokeName: "pikachu" }, user_session("user-a")
      end
    end

    assert last_response.ok?
    moves = @repository.all("user-a").first.moves
    assert_includes moves, "growl"
    assert_includes moves, "thunder-shock"
    refute_includes moves, "quick-attack", "move de nível 5 não deveria vir na montagem"
  end

  def test_delete_team_removes_pokemon_from_own_session
    @repository.add("user-a", pikachu_pokemon)
    id = @repository.all("user-a").first.id

    delete "/team", { id: id }, user_session("user-a")

    assert last_response.ok?
    assert_empty @repository.all("user-a")
    refute_includes last_response.body, "pikachu"
  end

  def test_delete_team_with_unknown_id_keeps_team_intact
    @repository.add("user-a", pikachu_pokemon)
    id = @repository.all("user-a").first.id
    unknown_id = (id.to_i + 999).to_s

    delete "/team", { id: unknown_id }, user_session("user-a")

    assert last_response.ok?
    assert_equal 1, @repository.all("user-a").size
    assert_includes last_response.body, "pikachu"
  end

  def test_delete_team_without_id_does_not_break
    delete "/team", {}, user_session("user-a")

    assert last_response.ok?
  end

  def test_remove_member_restores_assigned_and_held_items
    fill_team("user-a")
    member = @repository.all("user-a").first
    @inventory.add("user-a", "potion", 1)
    @inventory.add("user-a", "choice-band", 1)
    post "/team/#{member.id}/item", { item_name: "potion" }, user_session("user-a")
    post "/team/#{member.id}/held-item", { item_name: "choice-band" }, user_session("user-a")
    assert_equal 0, TestDatabase.inventory_quantity("user-a", "potion"), "equipar debita do estoque"
    assert_equal 0, TestDatabase.inventory_quantity("user-a", "choice-band"), "segurar debita do estoque"

    delete "/team", { id: member.id }, user_session("user-a")

    assert last_response.ok?
    assert_equal 1, TestDatabase.inventory_quantity("user-a", "potion"), "item equipado devolvido ao remover"
    assert_equal 1, TestDatabase.inventory_quantity("user-a", "choice-band"), "seguravel devolvido ao remover"
    refute_includes @repository.all("user-a").map(&:id), member.id
  end

  def test_remove_member_does_not_restore_item_already_consumed
    fill_team("user-a")
    member = @repository.all("user-a").first
    @inventory.add("user-a", "potion", 1)
    @repository.assign_item("user-a", member.id, "potion")
    @repository.assign_item("user-a", member.id, nil)

    delete "/team", { id: member.id }, user_session("user-a")

    assert last_response.ok?
    assert_equal 1, TestDatabase.inventory_quantity("user-a", "potion"),
                 "item consumido em batalha (assigned_item limpo) nao volta ao estoque"
  end

  def test_delete_team_only_removes_own_session_member
    @repository.add("user-a", pikachu_pokemon)
    id = @repository.all("user-a").first.id

    delete "/team", { id: id }, user_session("user-b")

    assert last_response.ok?
    assert_equal 1, @repository.all("user-a").size
    assert_empty @repository.all("user-b")
  end

  def test_post_team_when_full_returns_warning_and_keeps_six
    six = (1..6).map do |n|
      build_pokemon_record("pokemon#{n}", n)
    end
    six.each { |poke| @repository.add("user-a", poke) }
    seventh = build_pokemon_record("meowth", 52)

    PokeApiStub.with_find(seventh) do
      post "/team", { pokeName: "meowth" }, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Time cheio"
    assert_equal 6, @repository.all("user-a").size
    refute_includes @repository.all("user-a").map(&:name), "meowth"
  end

  def test_post_team_with_duplicate_returns_warning_and_does_not_insert
    @repository.add("user-a", pikachu_pokemon)

    PokeApiStub.with_find(pikachu_pokemon) do
      post "/team", { pokeName: "pikachu" }, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "pikachu já está no time."
    assert_equal 1, @repository.all("user-a").size
  end

  def test_get_team_returns_own_session_team
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    assert_includes last_response.body, "hx-delete=\"/team\""
  end

  def test_get_team_is_isolated_per_session
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, htmx_session("user-b")

    assert last_response.ok?
    refute_includes last_response.body, "pikachu"
  end

  def test_team_remove_button_still_deletes_after_sprite_link
    @repository.add("user-a", pikachu_pokemon)
    @repository.add("user-a", bulbasaur_pokemon)
    pikachu_id = @repository.all("user-a").find { |poke| poke.name == "pikachu" }.id

    delete "/team", { id: pikachu_id }, user_session("user-a")

    assert last_response.ok?
    assert_equal 1, @repository.all("user-a").size
    refute_includes @repository.all("user-a").map(&:name), "pikachu"
    assert_includes @repository.all("user-a").map(&:name), "bulbasaur"
    assert_includes last_response.body, "Remover do time"
    assert_includes last_response.body, "bulbasaur"
  end

  def test_team_page_is_removed_and_returns_404_without_htmx
    start_journey("user-a")
    add_team("user-a", [["pikachu", 25]])

    env = user_session("user-a")
    get "/team", {}, env

    assert_equal 404, last_response.status
    refute_includes last_response.body, 'id="team-view"'
  end

  def test_team_fragment_renders_slot_badge_and_ordered_by_slot
    @repository.add("user-a", bulbasaur_pokemon)
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "#1"
    assert_includes last_response.body, "#2"
    order = last_response.body.index("bulbasaur") < last_response.body.index("pikachu")
    assert order, "expected bulbasaur (slot 1) before pikachu (slot 2)"
  end

  def test_team_member_sprite_and_name_are_plain_on_team_screen
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, 'hx-get="/pokemon/25"'
    assert_includes last_response.body, 'alt="pikachu"'
  end

  def test_team_member_sprite_is_plain_image_not_link
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, 'hx-get="/pokemon/25"'
    refute_includes last_response.body, 'input type="image"'
    assert_includes last_response.body, 'hx-delete="/team"'
  end

  def test_post_team_move_reorders_team_fragment
    add_team("user-a", [["pikachu", 25], ["bulbasaur", 1], ["charmander", 4], ["squirtle", 7]])
    charmander_id = @repository.all("user-a").find { |poke| poke.name == "charmander" }.id

    post "/team/#{charmander_id}/move", { new_slot: 1 }, user_session("user-a")

    assert last_response.ok?
    order = last_response.body.index("charmander") < last_response.body.index("pikachu")
    assert order, "expected charmander (slot 1) before pikachu"
    assert_includes last_response.body, "#1"
  end

  def test_team_move_invalid_slot_keeps_team_intact
    add_team("user-a", [["pikachu", 25], ["bulbasaur", 1], ["charmander", 4], ["squirtle", 7]])
    pikachu_id = @repository.all("user-a").find { |poke| poke.name == "pikachu" }.id

    post "/team/#{pikachu_id}/move", { new_slot: 99 }, user_session("user-a")

    assert last_response.ok?
    assert_equal %w[pikachu bulbasaur charmander squirtle], @repository.all("user-a").map(&:name)
  end

  def test_team_move_of_other_users_member_is_noop
    @repository.add("user-a", pikachu_pokemon)
    @repository.add("user-b", bulbasaur_pokemon)
    bulbasaur_id = @repository.all("user-b").first.id

    post "/team/#{bulbasaur_id}/move", { new_slot: 1 }, user_session("user-a")

    assert last_response.ok?
    assert_equal %w[pikachu], @repository.all("user-a").map(&:name)
    assert_equal %w[bulbasaur], @repository.all("user-b").map(&:name)
  end

  def test_team_move_does_not_break_delete
    add_team("user-a", [["pikachu", 25], ["bulbasaur", 1], ["charmander", 4], ["squirtle", 7]])
    pikachu_id = @repository.all("user-a").find { |poke| poke.name == "pikachu" }.id

    post "/team/#{pikachu_id}/move", { new_slot: 1 }, user_session("user-a")
    delete "/team", { id: pikachu_id }, user_session("user-a")

    assert last_response.ok?
    refute_includes @repository.all("user-a").map(&:name), "pikachu"
    assert_includes last_response.body, "Remover do time"
  end

  def test_team_fragment_renders_move_buttons
    fill_team("user-a")

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_equal 13, last_response.body.scan("hx-post=\"/team/").size
    assert_includes last_response.body, ">▲</button>"
    assert_includes last_response.body, ">▼</button>"
    assert_includes last_response.body, 'name="new_slot"'
    assert_includes last_response.body, 'hx-target="#team-view"'
  end

  def test_team_member_sprite_has_alt_text
    start_journey("user-a")
    add_team("user-a", [["pikachu", 25]])

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_match(/<img[^>]+alt="pikachu"/, last_response.body)
  end

  def test_team_slot_controls_have_aria_labels
    start_journey("user-a")
    add_team("user-a", [["pikachu", 25]])

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, 'aria-label="Mover para cima"'
    assert_includes last_response.body, 'aria-label="Mover para baixo"'
  end

  def test_post_team_with_unknown_name_shows_notice_and_does_not_insert
    PokeApiStub.with_find(nil) do
      post "/team", { pokeName: "xyz" }, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Pokémon não encontrado."
    refute_includes last_response.body, "<html"
    assert_empty @repository.all("user-a")
  end

  def test_unexpected_error_renders_friendly_fragment_without_stack
    @repository.add("user-a", pikachu_pokemon)

    raising_api = Class.new do
      def learnable_moves(_number)
        raise "boom inesperado"
      end
    end.new
    previous = Server.settings.api
    Server.set :api, raising_api

    get "/team/manage", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Algo deu errado. Tente novamente."
    refute_includes last_response.body, "<html"
    refute_includes last_response.body, "boom inesperado"
  ensure
    Server.set :api, previous
  end

  def test_unexpected_error_returns_500_status_for_full_page_request
    @repository.add("user-a", pikachu_pokemon)

    raising_api = Class.new do
      def learnable_moves(_number)
        raise "boom inesperado"
      end
    end.new
    previous = Server.settings.api
    Server.set :api, raising_api

    get "/team/manage", {}, user_session("user-a")

    assert_equal 500, last_response.status
    assert_includes last_response.body, "Algo deu errado. Tente novamente."
    refute_includes last_response.body, "<html"
    refute_includes last_response.body, "boom inesperado"
  ensure
    Server.set :api, previous
  end

  def test_team_heal_cures_team_and_charges_wallet
    fill_team("user-a")
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 200, 100)
    @wallet.grant("user-a", 200)

    post "/team/heal", {}, user_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, "<html"
    assert_match(/curado por 50/i, last_response.body.strip)
    assert_equal 150, @wallet.balance("user-a")
    assert_equal 200, @progression.get("user-a", pokemon_id)[:hp_current]
    assert_includes last_response.body, "Poke Center"
  end

  def test_team_heal_with_insufficient_balance_shows_notice_without_debiting
    fill_team("user-a")
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 200, 100)
    @wallet.grant("user-a", 10)

    post "/team/heal", {}, user_session("user-a")

    assert last_response.ok?
    assert_match(/insuficiente/i, last_response.body.strip)
    assert_equal 10, @wallet.balance("user-a")
    assert_equal 100, @progression.get("user-a", pokemon_id)[:hp_current]
  end

  def test_team_heal_already_cured_shows_notice_without_debiting
    fill_team("user-a")
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 200, 200)
    @wallet.grant("user-a", 100)

    post "/team/heal", {}, user_session("user-a")

    assert last_response.ok?
    assert_match(/já está curado/i, last_response.body.strip)
    assert_equal 100, @wallet.balance("user-a")
  end

  def test_team_heal_with_empty_team_does_not_break
    start_journey("user-a")

    post "/team/heal", {}, user_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, "<html"
  end

  def test_team_fragment_shows_poke_center_with_hp_and_heal_button
    fill_team("user-a")
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 200, 100)

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Poke Center"
    assert_includes last_response.body, "HP 100/200"
    assert_includes last_response.body, %(hx-post="/team/heal")
  end

  def test_team_fragment_omits_heal_button_for_empty_team
    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, "Poke Center"
  end

  def test_center_fragment_shows_heal_cost_upfront
    fill_team("user-a")
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 200, 100)
    @wallet.grant("user-a", 200)

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Poke Center"
    assert_includes last_response.body, "HP 100/200"
    assert_match(/Custo[^:]*:\s*50/, last_response.body)
    heal_form = last_response.body[%r{<form[^>]*hx-post="/team/heal".*?</form>}m]
    refute_nil heal_form
    refute_includes heal_form, "disabled"
  end

  def test_center_fragment_disables_heal_when_cured
    fill_team("user-a")
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 200, 200)
    @wallet.grant("user-a", 100)

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    heal_form = last_response.body[%r{<form[^>]*hx-post="/team/heal".*?</form>}m]
    refute_nil heal_form
    assert_includes heal_form, "disabled"
  end

  def test_center_fragment_disables_heal_when_insufficient_balance
    fill_team("user-a")
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 200, 100)
    @wallet.grant("user-a", 10)

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    heal_form = last_response.body[%r{<form[^>]*hx-post="/team/heal".*?</form>}m]
    refute_nil heal_form
    assert_includes heal_form, "disabled"
  end
end

class ServerHealJourneyGateTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_heal_blocked_before_journey
    @repository.add("user-novo", pikachu_pokemon)
    pokemon_id = TestDatabase.team_id("pikachu", "user-novo")
    @progression.update_hp("user-novo", pokemon_id, 200, 100)
    @wallet.grant("user-novo", 200)

    post "/team/heal", {}, user_session("user-novo")

    assert last_response.ok?
    refute_includes last_response.body, "<html"
    assert_match(/jornada/i, last_response.body)
    assert_equal 100, @progression.get("user-novo", pokemon_id)[:hp_current]
    assert_equal 200, @wallet.balance("user-novo")
  end

  def test_heal_released_after_journey_started
    fill_team("user-a")
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 200, 100)
    @wallet.grant("user-a", 200)

    post "/team/heal", {}, user_session("user-a")

    assert_match(/curado por 50/i, last_response.body.strip)
    assert_equal 150, @wallet.balance("user-a")
  end
end

class ServerTeamJourneyMarkTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_post_team_marks_journey_on_sixth_member
    5.times { |n| @repository.add("user-a", build_pokemon_record("pokemon#{n}", n + 1)) }
    state = UserStateRepository.new

    refute state.started?("user-a")

    PokeApiStub.with_find(pikachu_pokemon) do
      PokeApiStub.with_learnable_moves([{ level: 1, name: "growl" }]) do
        post "/team", { pokeName: "pikachu" }, user_session("user-a")
      end
    end

    assert last_response.ok?
    assert_equal 6, @repository.all("user-a").size
    assert_equal true, state.started?("user-a")
  end

  def test_post_team_below_six_does_not_mark_journey
    PokeApiStub.with_find(pikachu_pokemon) do
      PokeApiStub.with_learnable_moves([{ level: 1, name: "growl" }]) do
        post "/team", { pokeName: "pikachu" }, user_session("user-a")
      end
    end

    assert last_response.ok?
    assert_equal false, UserStateRepository.new.started?("user-a")
  end
end

class ServerTeamHpGateTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_team_panel_hides_battle_cta_when_all_hp_zero
    fill_team("user-a")
    @repository.all("user-a").each { |member| @progression.update_hp("user-a", member.id, 200, 0) }

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    refute_match(/gameloop-cta battle/, last_response.body)
    assert_includes last_response.body, "Poke Center"
    assert_includes last_response.body, "Poke Mart"
  end
end

class ServerTeamJourneyFragmentTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_team_fragment_hides_center_and_mart_before_journey
    @repository.add("user-novo", pikachu_pokemon)

    get "/team", {}, htmx_session("user-novo")

    assert last_response.ok?
    refute_includes last_response.body, "Poke Center"
    refute_includes last_response.body, "Poke Mart"
    refute_includes last_response.body, %(hx-post="/team/heal")
    assert_match(/jornada/i, last_response.body)
    assert_includes last_response.body, "notice--info"
  end

  def test_team_fragment_shows_center_and_mart_after_journey_started
    fill_team("user-a")
    @wallet.grant("user-a", 100)

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Poke Center"
    assert_includes last_response.body, "Poke Mart"
    refute_match(/Monte seu time inicial/, last_response.body)
  end

  def test_team_panel_reblocks_center_and_mart_when_team_shrinks_below_six
    fill_team("user-a")
    delete "/team", { id: @repository.all("user-a").first.id }, user_session("user-a")
    delete "/team", { id: @repository.all("user-a").first.id }, user_session("user-a")

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, "Poke Center"
    refute_includes last_response.body, "Poke Mart"
    assert_match(/Monte seu time inicial/, last_response.body)
  end

  def test_team_panel_shows_game_over_banner_when_stuck
    TestDatabase.clear_team!
    fill_team("user-a")
    @repository.all("user-a").each { |member| @progression.update_hp("user-a", member.id, 200, 0) }

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_match(/game over/i, last_response.body)
    assert_match(/Recome\S* jornada/, last_response.body)
  end
end

class ServerTeamRemoveHtmxTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def setup
    super
    fill_team("user-a")
  end

  def test_htmx_delete_team_removes_and_swaps_both_fragments
    id = @repository.all("user-a").first.id

    delete "/team", { id: id, offset: "0", q: "" }, htmx_session("user-a")

    assert last_response.ok?
    assert_equal 5, @repository.all("user-a").size
    refute_includes last_response.body, "pikachu"
    assert_includes last_response.body, "bulbasaur"
    assert_includes last_response.body, %(hx-swap-oob="innerHTML")
    assert_includes last_response.body, 'id="pokemon-list"'
  end

  def test_delete_team_is_idempotent_on_second_request
    id = @repository.all("user-a").first.id
    delete "/team", { id: id, offset: "0", q: "" }, htmx_session("user-a")
    assert_equal 5, @repository.all("user-a").size

    delete "/team", { id: id, offset: "0", q: "" }, htmx_session("user-a")

    assert last_response.ok?
    assert_equal 5, @repository.all("user-a").size
    refute_includes last_response.body, "Algo deu errado"
  end

  def test_remove_form_prevents_double_submit
    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    remove_form = last_response.body[%r{<form[^>]*hx-delete="/team".*?</form>}m]
    refute_nil remove_form
    assert_match(/hx-disabled-elt/, remove_form)
  end
end
