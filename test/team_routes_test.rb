# frozen_string_literal: true

require_relative "server_test_helpers"

# Rating fake padrão: todos os Pokémon tier F (custo mínimo 20)
class DefaultFakeRating
  def rating_for(_name)
    :F
  end
end

class ServerTeamTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def setup
    super
    @default_rating = Server.settings.rating_source
    Server.set :rating_source, DefaultFakeRating.new
  end

  def teardown
    Server.set :rating_source, @default_rating
    super
  end

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
    # o roster agora é <ul class="roster"> aninhado em .card; extrai até fechar o roster
    team_a = session_a.last_response.body[%r{<div id="team-view".*?<ul class="roster"[^>]*>.*?</ul>}m]
    assert_includes team_a, "pikachu"
    refute_includes team_a, "bulbasaur"

    assert_includes session_b.last_response.body, "Adicionado ao time."
    team_b = session_b.last_response.body[%r{<div id="team-view".*?<ul class="roster"[^>]*>.*?</ul>}m]
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

  # C7/ITEM 3 — "Gerenciar time" migra para o budget-summary do index (GET /),
  # sem duplicar no fragmento do team
  def test_team_fragment_manage_link_is_on_its_own_line
    @repository.add("user-a", pikachu_pokemon)

    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end

    assert last_response.ok?
    before_team_view = last_response.body.split('id="team-view"').first
    assert_match(%r{<div class="budget-summary">.*?hx-get="/team/manage"}m, before_team_view)

    get "/team", {}, htmx_session("user-a")
    refute_includes last_response.body, "Gerenciar time"
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

  def test_post_team_full_returns_error_notice
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
    assert_includes last_response.body, "notice--error"
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

  def test_concurrent_post_team_no_500 # rubocop:disable Naming/VariableNumber
    specs = [["pikachu", 25], ["bulbasaur", 1], ["charmander", 4]]
    pokemon_by_name = specs.to_h { |name, number| [name, build_pokemon_record(name, number)] }

    PokeApiStub.with_gateway(find: pokemon_by_name) do
      errors = Queue.new
      responses = Queue.new
      threads = specs.map do |name, _number|
        Thread.new do
          session = Rack::Test::Session.new(Rack::MockSession.new(app))
          session.post "/team", { pokeName: name }, user_session("user-a")
          responses << session.last_response
        rescue StandardError => e
          errors << e
        end
      end
      threads.each(&:join)

      assert errors.empty?, "erros concorrentes: #{Array.new(errors.size) { errors.pop }.inspect}"
      until responses.empty?
        response = responses.pop
        assert response.ok?, "resposta nao-ok (#{response.status}) sob corrida"
      end
    end

    assert_equal 3, @repository.all("user-a").size
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
    assert_equal 12, last_response.body.scan("hx-post=\"/team/").size
    assert_includes last_response.body, ">▲</button>"
    assert_includes last_response.body, ">▼</button>"
    assert_includes last_response.body, 'name="new_slot"'
    assert_includes last_response.body, 'hx-target="#team-view"'
    # heal form mudou para a home (full page), fora do fragmento
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, %(hx-post="/team/heal")
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
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end

    assert last_response.ok?
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

    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Poke Center"
    assert_includes last_response.body, "100/200"
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

    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Poke Center"
    assert_includes last_response.body, "100/200"
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

    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end

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

    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end

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

    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end

    assert last_response.ok?
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

    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end

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
    # C3: banner + CTAs Vender/Venda | Recomeçar visíveis
    assert_match(/Venda itens no Poke Mart/i, last_response.body)
    assert_match(/Recome\S* jornada/, last_response.body)
    assert_includes last_response.body, "notice--error"
    assert_includes last_response.body, 'hx-post="/journey/restart"'
    assert_includes last_response.body, '<button type="submit" class="btn btn-secondary">Recomeçar jornada</button>'
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

# Sessao 0059 — Q5 remover em 1 clique (hardening htmx + OOB condicional)
class ServerTeamRemoveQ5Test < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def setup
    super
    fill_team("user-a")
    @default_rating = Server.settings.rating_source
    Server.set :rating_source, DefaultFakeRating.new
  end

  def teardown
    Server.set :rating_source, @default_rating
    super
  end

  # C1 — DELETE htmx remove em 1 request e devolve OOB valido
  def test_htmx_delete_removes_in_one_request_with_both_fragments
    id = @repository.all("user-a").find { |poke| poke.name == "pikachu" }.id
    assert_includes @repository.all("user-a").map(&:name), "pikachu"

    delete "/team", { id: id, offset: "0", q: "" }, htmx_session("user-a")

    assert last_response.ok?
    assert_equal 5, @repository.all("user-a").size
    refute_includes @repository.all("user-a").map { |poke| poke.id.to_s }, id.to_s
    # #team-view (main target innerHTML) sem o membro removido
    refute_includes last_response.body, "team-pokemon-#{id}"
    refute_includes last_response.body, ">pikachu<"
    assert_includes last_response.body, "bulbasaur"
    # OOB #pokemon-list válido quando starters_visible? (q.empty? && offset.zero?)
    assert_includes last_response.body, 'id="pokemon-list"'
    assert_includes last_response.body, 'hx-swap-oob="innerHTML"'
    # garante que veio lista (não erro)
    refute_includes last_response.body, "Algo deu errado"
  end

  # C2 — 2º DELETE mesmo id idempotente (200, time intacto)
  def test_delete_is_idempotent_on_second_request
    id = @repository.all("user-a").first.id
    delete "/team", { id: id, offset: "0", q: "" }, htmx_session("user-a")
    assert last_response.ok?
    assert_equal 5, @repository.all("user-a").size

    delete "/team", { id: id, offset: "0", q: "" }, htmx_session("user-a")

    assert last_response.ok?
    assert_equal 5, @repository.all("user-a").size
    refute_includes last_response.body, "Algo deu errado"
    # ainda devolve fragmento do time (innerHTML, sem wrapper id)
    assert_includes last_response.body, "bulbasaur"
  end

  # C3 — form tem hardening hx-disabled-elt="this" + hx-sync="closest form:replace" + hx-indicator="#team-view"
  def test_remove_form_has_hardening_attrs
    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    remove_form = last_response.body[%r{<form[^>]*hx-delete="/team".*?</form>}m]
    refute_nil remove_form, "form hx-delete nao encontrado"
    assert_match(/hx-disabled-elt="this"/, remove_form)
    assert_match(/hx-sync="closest form:replace"/, remove_form)
    assert_match(/hx-indicator="#team-view"/, remove_form)
  end

  # C4 — OOB condicional: quando filtrado/paginado/busca não varre starters (sem bloco starters)
  # mas ainda devolve OOB filtrado; quando visível, inclui starters
  # rubocop:disable Metrics/AbcSize
  def test_oob_conditional_skips_starters_when_filtered_or_paginated
    id = @repository.all("user-a").first.id

    # q não vazio → OOB presente mas sem starters
    delete "/team", { id: id, offset: "0", q: "pika" }, htmx_session("user-a")
    assert last_response.ok?
    assert_includes last_response.body, 'id="pokemon-list" hx-swap-oob'
    refute_includes last_response.body, '<ul class="pokemon-list starters">',
                    "starters nao deveriam aparecer quando q nao vazio"
    assert_includes last_response.body, "bulbasaur"

    # restaura time para próximo caso
    @repository.add("user-a", build_pokemon_record("pikachu", 25)) if @repository.all("user-a").size == 5
    id2 = @repository.all("user-a").last.id

    # offset >0 → sem starters
    delete "/team", { id: id2, offset: "36", q: "" }, htmx_session("user-a")
    assert last_response.ok?
    assert_includes last_response.body, 'id="pokemon-list" hx-swap-oob'
    refute_includes last_response.body, '<ul class="pokemon-list starters">',
                    "starters nao deveriam aparecer quando offset>0"

    # type filter → sem starters
    @repository.add("user-a", build_pokemon_record("pikachu", 25)) if @repository.all("user-a").size == 5
    id3 = @repository.all("user-a").last.id
    delete "/team", { id: id3, type: "fire", offset: "0", q: "" }, htmx_session("user-a")
    assert last_response.ok?
    assert_includes last_response.body, 'id="pokemon-list" hx-swap-oob'
    refute_includes last_response.body, '<ul class="pokemon-list starters">',
                    "starters nao deveriam aparecer quando type filtrado"

    # sort ativo → sem starters
    @repository.add("user-a", build_pokemon_record("pikachu", 25)) if @repository.all("user-a").size == 5
    id4 = @repository.all("user-a").last.id
    delete "/team", { id: id4, sort: "cost_desc", offset: "0", q: "" }, htmx_session("user-a")
    assert last_response.ok?
    assert_includes last_response.body, 'id="pokemon-list" hx-swap-oob'
    refute_includes last_response.body, '<ul class="pokemon-list starters">',
                    "starters nao deveriam aparecer quando sort ativo"
  end
  # rubocop:enable Metrics/AbcSize

  def test_oob_includes_starters_when_visible
    id = @repository.all("user-a").first.id

    delete "/team", { id: id, offset: "0", q: "" }, htmx_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, 'id="pokemon-list" hx-swap-oob'
    assert_includes last_response.body, '<ul class="pokemon-list starters">'
  end
end

# C6, C8 — custo de montagem: tier da linha, teto de S, orçamento
class TeamBudgetRoutesTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  class FakeRatingSource
    def initialize(map)
      @map = map
    end

    def rating_for(name)
      (@map[name.to_s] || "F").to_sym
    end
  end

  def setup
    super
    @default_rating = Server.settings.rating_source
    Server.set :rating_source, DefaultFakeRating.new
  end

  def teardown
    Server.set :rating_source, @default_rating
    super
  end

  def with_budget_rating(rating_map, &)
    fake = FakeRatingSource.new(rating_map)
    original = Server.settings.rating_source
    Server.set :rating_source, fake
    yield
  ensure
    Server.set :rating_source, original
  end

  def pikachu_chain
    pichu = build_pokemon_record("pichu", 172)
    pikachu = build_pokemon_record("pikachu", 25)
    raichu = build_pokemon_record("raichu", 26)
    Pokemon.new(
      name: "pikachu", sprite: "s", number: 25,
      evolutions: [pichu, pikachu, raichu].freeze
    )
  end

  # C6 — tier da linha = máximo da cadeia
  def test_cost_uses_highest_chain_tier
    # pikachu (próprio F) mas linha tem raichu S → conta como S
    rating = { "raichu" => "S", "pichu" => "F", "pikachu" => "F" }
    PokeApiStub.with_find(pikachu_chain) do
      with_budget_rating(rating) do
        post "/team", { pokeName: "pikachu" }, user_session("user-a")
      end
    end

    assert last_response.ok?
    team = @repository.all("user-a")
    assert_equal 1, team.size
    assert_equal "pikachu", team.first.name
  end

  # C8 — bloqueio por orçamento (único limitador; trava S removida)
  def test_add_blocked_by_budget
    # Time com custo = 435: 2S(240) + 1B(55) + 2A(140)
    rating = {
      "heavy-1" => "S", "heavy-2" => "S", "heavy-3" => "B",
      "heavy-4" => "A", "heavy-5" => "A", "over-budget" => "C"
    }
    heavy1 = Pokemon.new(name: "heavy-1", sprite: "s", number: 101,
                         evolutions: [build_pokemon_record("heavy-1", 101)])
    heavy2 = Pokemon.new(name: "heavy-2", sprite: "s", number: 102,
                         evolutions: [build_pokemon_record("heavy-2", 102)])
    heavy3 = Pokemon.new(name: "heavy-3", sprite: "s", number: 103,
                         evolutions: [build_pokemon_record("heavy-3", 103)])
    heavy4 = Pokemon.new(name: "heavy-4", sprite: "s", number: 104,
                         evolutions: [build_pokemon_record("heavy-4", 104)])
    heavy5 = Pokemon.new(name: "heavy-5", sprite: "s", number: 105,
                         evolutions: [build_pokemon_record("heavy-5", 105)])
    @repository.add("user-a", heavy1)
    @repository.add("user-a", heavy2)
    @repository.add("user-a", heavy3)
    @repository.add("user-a", heavy4)
    @repository.add("user-a", heavy5)

    candidate = Pokemon.new(name: "over-budget", sprite: "s", number: 200,
                            evolutions: [build_pokemon_record("over-budget", 200)])

    find_map = {
      "heavy-1" => heavy1, "heavy-2" => heavy2, "heavy-3" => heavy3,
      "heavy-4" => heavy4, "heavy-5" => heavy5, "over-budget" => candidate
    }
    PokeApiStub.with_find(find_map) do
      with_budget_rating(rating) do
        post "/team", { pokeName: "over-budget" }, user_session("user-a")
      end
    end

    assert last_response.ok?
    assert_match(/or[cç]amento/i, last_response.body)
    assert_equal 5, @repository.all("user-a").size
    refute_includes @repository.all("user-a").map(&:name), "over-budget"
  end

  # C7 — add dentro dos limites atualiza painel
  def test_add_within_limits_updates_panel
    rating = { "pikachu" => "F", "pichu" => "F", "raichu" => "F" }
    PokeApiStub.with_find(pikachu_chain) do
      with_budget_rating(rating) do
        post "/team", { pokeName: "pikachu" }, user_session("user-a")
      end
    end

    assert last_response.ok?
    team = @repository.all("user-a")
    assert_equal 1, team.size
    assert_match(%r{Custo do time: 20/450}, last_response.body)
    refute_match(/S no time:/, last_response.body)
  end

  # C9 — remoção libera orçamento e teto de S
  # rubocop:disable Metrics/AbcSize
  def test_remove_frees_budget_and_s_limit
    # Adiciona 3 Pokémon de linha S
    s_mons = {}
    3.times do |i|
      name = "s-free-#{i}"
      poke = Pokemon.new(name: name, sprite: "s", number: 400 + i,
                         evolutions: [build_pokemon_record(name, 400 + i)])
      s_mons[name] = poke
      @repository.add("user-a", poke)
    end

    rating = s_mons.keys.to_h { |n| [n, "S"] }
    # Remove o primeiro S
    removed = @repository.all("user-a").first
    PokeApiStub.with_find(s_mons) do
      with_budget_rating(rating) do
        delete "/team", { id: removed.id }, user_session("user-a")
      end
    end

    assert last_response.ok?
    assert_equal 2, @repository.all("user-a").size
    # Agora pode adicionar outro S
    new_s = Pokemon.new(name: "s-new", sprite: "s", number: 500,
                        evolutions: [build_pokemon_record("s-new", 500)])
    rating["s-new"] = "S"
    s_mons["s-new"] = new_s
    PokeApiStub.with_find(s_mons) do
      with_budget_rating(rating) do
        post "/team", { pokeName: "s-new" }, user_session("user-a")
      end
    end

    assert last_response.ok?
    assert_equal 3, @repository.all("user-a").size
    assert_includes @repository.all("user-a").map(&:name), "s-new"
  end
  # rubocop:enable Metrics/AbcSize

  # C3 — 4º S puro bloqueado só por orçamento (sem trava hard)
  def test_fourth_pure_s_blocked_by_budget_only
    s_mons = {}
    3.times do |i|
      name = "s-pure-#{i}"
      poke = Pokemon.new(name: name, sprite: "s", number: 610 + i,
                         evolutions: [build_pokemon_record(name, 610 + i)])
      s_mons[name] = poke
      @repository.add("user-a", poke)
    end
    rating = s_mons.keys.to_h { |n| [n, "S"] }
    rating["candidate-pure"] = "S"
    candidate = Pokemon.new(name: "candidate-pure", sprite: "s", number: 620,
                            evolutions: [build_pokemon_record("candidate-pure", 620)])
    find_map = s_mons.merge("candidate-pure" => candidate)
    # garante que nenhum é restrito (custo 120)
    PokeApiStub.with_find(find_map) do
      with_budget_rating(rating) do
        PokeApiStub.with_gateway(evolution_restricted: {}) do
          post "/team", { pokeName: "candidate-pure" }, user_session("user-a")
        end
      end
    end

    assert last_response.ok?
    assert_match(/or[cç]amento/i, last_response.body)
    refute_match(/m[aá]ximo.*3.*S/i, last_response.body)
    assert_equal 3, @repository.all("user-a").size
    refute_includes @repository.all("user-a").map(&:name), "candidate-pure"
    # jornada não marcada e batalha não invalidada (time segue <6)
    refute UserStateRepository.new.started?("user-a")
  end

  # C4 — 4º S restrito (110) também bloqueado só por orçamento
  def test_fourth_restricted_s_blocked_by_budget_only
    s_mons = {}
    3.times do |i|
      name = "s-pure-#{i}"
      poke = Pokemon.new(name: name, sprite: "s", number: 630 + i,
                         evolutions: [build_pokemon_record(name, 630 + i)])
      s_mons[name] = poke
      @repository.add("user-a", poke)
    end
    rating = s_mons.keys.to_h { |n| [n, "S"] }
    rating["candidate-rest"] = "S"
    candidate = Pokemon.new(name: "candidate-rest", sprite: "s", number: 640,
                            evolutions: [build_pokemon_record("candidate-rest", 640)])
    find_map = s_mons.merge("candidate-rest" => candidate)
    PokeApiStub.with_find(find_map) do
      with_budget_rating(rating) do
        PokeApiStub.with_gateway(evolution_restricted: { "candidate-rest" => true }) do
          post "/team", { pokeName: "candidate-rest" }, user_session("user-a")
        end
      end
    end

    assert last_response.ok?
    assert_match(/or[cç]amento/i, last_response.body)
    refute_match(/m[aá]ximo.*3.*S/i, last_response.body)
    assert_equal 3, @repository.all("user-a").size
    refute_includes @repository.all("user-a").map(&:name), "candidate-rest"
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def test_restricted_s_not_hard_capped
    # 2S puro (240) + 1 S_rest (110) = 350; + S_rest 110 = 460 bloqueia
    s_mons = {}
    %w[s-pure-a s-pure-b].each_with_index do |name, idx|
      poke = Pokemon.new(name: name, sprite: "s", number: 650 + idx,
                         evolutions: [build_pokemon_record(name, 650 + idx)])
      s_mons[name] = poke
      @repository.add("user-a", poke)
    end
    s_rest = Pokemon.new(name: "s-rest-1", sprite: "s", number: 652,
                         evolutions: [build_pokemon_record("s-rest-1", 652)])
    s_mons["s-rest-1"] = s_rest
    @repository.add("user-a", s_rest)
    rating = { "s-pure-a" => "S", "s-pure-b" => "S", "s-rest-1" => "S",
               "s-rest-2" => "S", "a-rest" => "A" }
    candidate2 = Pokemon.new(name: "s-rest-2", sprite: "s", number: 653,
                             evolutions: [build_pokemon_record("s-rest-2", 653)])
    find_map = s_mons.merge("s-rest-2" => candidate2)
    PokeApiStub.with_find(find_map) do
      with_budget_rating(rating) do
        PokeApiStub.with_gateway(evolution_restricted: { "s-rest-1" => true, "s-rest-2" => true }) do
          post "/team", { pokeName: "s-rest-2" }, user_session("user-a")
        end
      end
    end
    assert_match(/or[cç]amento/i, last_response.body)
    assert_equal 3, @repository.all("user-a").size

    # prova que não é trava hard: 1S puro + 1S_rest (230) + A_rest 35 cabe (265 ≤450)
    TestDatabase.clear_team!
    one_s = Pokemon.new(name: "solo-s", sprite: "s", number: 654,
                        evolutions: [build_pokemon_record("solo-s", 654)])
    solo_rest = Pokemon.new(name: "solo-rest", sprite: "s", number: 655,
                            evolutions: [build_pokemon_record("solo-rest", 655)])
    @repository.add("user-b", one_s)
    @repository.add("user-b", solo_rest)
    a_rest = Pokemon.new(name: "a-rest", sprite: "s", number: 656,
                         evolutions: [build_pokemon_record("a-rest", 656)])
    find_map2 = { "solo-s" => one_s, "solo-rest" => solo_rest, "a-rest" => a_rest }
    PokeApiStub.with_find(find_map2) do
      with_budget_rating(rating) do
        PokeApiStub.with_gateway(evolution_restricted: { "solo-rest" => true, "a-rest" => true }) do
          post "/team", { pokeName: "a-rest" }, user_session("user-b")
        end
      end
    end
    assert_match(/Adicionado ao time/, last_response.body)
    assert_equal 3, @repository.all("user-b").size
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def test_remove_frees_budget_for_restricted_s
    s_mons = {}
    3.times do |i|
      name = "s-free-rest-#{i}"
      poke = Pokemon.new(name: name, sprite: "s", number: 660 + i,
                         evolutions: [build_pokemon_record(name, 660 + i)])
      s_mons[name] = poke
      @repository.add("user-a", poke)
    end
    rating = s_mons.keys.to_h { |n| [n, "S"] }
    rating["s-rest-new"] = "S"
    # remove um S puro (custo 120) → total 240, agora S_rest 110 cabe (350)
    removed = @repository.all("user-a").first
    delete "/team", { id: removed.id }, user_session("user-a")
    assert_equal 2, @repository.all("user-a").size
    new_rest = Pokemon.new(name: "s-rest-new", sprite: "s", number: 670,
                           evolutions: [build_pokemon_record("s-rest-new", 670)])
    find_map = s_mons.merge("s-rest-new" => new_rest)
    PokeApiStub.with_find(find_map) do
      with_budget_rating(rating) do
        PokeApiStub.with_gateway(evolution_restricted: { "s-rest-new" => true }) do
          post "/team", { pokeName: "s-rest-new" }, user_session("user-a")
        end
      end
    end
    assert last_response.ok?
    assert_match(/Adicionado ao time/, last_response.body)
    assert_equal 3, @repository.all("user-a").size
    assert_includes @repository.all("user-a").map(&:name), "s-rest-new"
  end

  # C10 — painel mostra custo/orçamento sem contador S
  def test_team_panel_shows_cost_budget_and_s_count
    # Time vazio — apenas custo, sem S no time
    get "/team", {}, htmx_session("user-c")
    assert last_response.ok?
    assert_match(%r{Custo do time: 0/450}, last_response.body)
    refute_match(/S no time:/, last_response.body)

    # Adiciona um Pokémon F barato
    poke = Pokemon.new(name: "cheap", sprite: "s", number: 600,
                       evolutions: [build_pokemon_record("cheap", 600)])
    PokeApiStub.with_find(poke) do
      with_budget_rating({ "cheap" => "F" }) do
        post "/team", { pokeName: "cheap" }, user_session("user-c")
      end
    end

    assert last_response.ok?
    assert_match(%r{Custo do time: 20/450}, last_response.body)
    refute_match(/S no time:/, last_response.body)
  end

  # C5 — painel sem contador S, só custo (S removido do front)
  def test_team_panel_shows_s_count_without_limit
    s_poke = Pokemon.new(name: "solo-s", sprite: "s", number: 700,
                         evolutions: [build_pokemon_record("solo-s", 700)])
    PokeApiStub.with_find(s_poke) do
      with_budget_rating({ "solo-s" => "S" }) do
        post "/team", { pokeName: "solo-s" }, user_session("user-c")
        assert last_response.ok?
        assert_match(%r{Custo do time: 120/450}, last_response.body)
        refute_match(/S no time:/, last_response.body)
        # GET dentro do mesmo stub para rating consistente
        get "/team", {}, htmx_session("user-c")
        assert_match(%r{Custo do time: 120/450}, last_response.body)
        refute_match(/S no time:/, last_response.body)
      end
    end
  end

  def test_team_panel_cost_reflects_restricted_s_one_ten
    s_rest = Pokemon.new(name: "s-rest-panel", sprite: "s", number: 701,
                         evolutions: [build_pokemon_record("s-rest-panel", 701)])
    PokeApiStub.with_find(s_rest) do
      with_budget_rating({ "s-rest-panel" => "S" }) do
        PokeApiStub.with_gateway(evolution_restricted: { "s-rest-panel" => true }) do
          post "/team", { pokeName: "s-rest-panel" }, user_session("user-d")
        end
      end
    end
    assert last_response.ok?
    assert_match(%r{Custo do time: 110/450}, last_response.body)
    refute_match(/S no time:/, last_response.body)
    # OOB #pokemon-list preservado com badge? verificado em pokemon_list_cost_test
  end
end

# Sessao 0065 — C2 heal bloqueado (rota) + C5 preview disabled
class TeamHealRoutesTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_heal_blocked_when_insufficient_balance
    fill_team("user-a")
    target = @repository.all("user-a").first
    @progression.update_hp("user-a", target.id, 200, 0)
    # missing 200 -> cost 100, saldo 10 insuficiente
    @wallet.grant("user-a", 10)

    post "/team/heal", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_match(/Dinheiro insuficiente para curar \(custo 100, saldo 10\)/, last_response.body)
    assert_includes last_response.body, "notice--error"
    assert_equal 0, @progression.get("user-a", target.id)[:hp_current], "nada curado"
    assert_equal 10, @wallet.balance("user-a")
    # strips agora na home (full page), nao no fragmento
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_match(%r{>0/200<}, last_response.body)
    assert_match(/Custo total: 100/, last_response.body)
  end

  def test_center_shows_preview_cost_and_disables_heal_when_unaffordable
    fill_team("user-a")
    target = @repository.all("user-a").first
    @progression.update_hp("user-a", target.id, 200, 100)
    @wallet.grant("user-a", 10) # cost 50 > 10

    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Poke Center"
    assert_match(/Custo total: 50/, last_response.body)
    heal_form = last_response.body[%r{<form[^>]*hx-post="/team/heal".*?</form>}m]
    refute_nil heal_form
    assert_includes heal_form, "disabled"
  end
end

# Sessao 0065 — C7 reset limpa mesmo no spiral (bypass)
class JourneyRestartSpiralTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_restart_clears_fainted_team_in_spiral_and_resets_balance # rubocop:disable Metrics/AbcSize
    fill_team("user-a")
    @repository.all("user-a").each { |m| @progression.update_hp("user-a", m.id, 10, 0) }
    first = @repository.all("user-a").first
    @inventory.add("user-a", "potion", 1)
    @repository.assign_item("user-a", first.id, "potion")
    @inventory.add("user-a", "choice-band", 1)
    @repository.assign_held_item("user-a", first.id, "choice-band")
    @wallet.grant("user-a", 5) # saldo insuficiente -> game_over
    assert_equal true, Server.settings.journey.game_over?("user-a")

    post "/journey/restart", { offset: "0", q: "" }, htmx_session("user-a")

    assert last_response.ok?
    assert_empty @repository.all("user-a"), "reset deve limpar mesmo com todos fainted (6->0)"
    assert_equal 2, TestDatabase.inventory_quantity("user-a", "potion"), "potion devolvido (1+1)"
    assert_equal 2, TestDatabase.inventory_quantity("user-a", "choice-band"), "choice-band devolvido (1+1)"
    assert_equal 200, TestDatabase.wallet_balance("user-a"), "saldo reset 200"
    assert_includes last_response.body, "Jornada recomeçada"
    assert_includes last_response.body, 'id="pokemon-list"'
    assert_includes last_response.body, 'id="nav-badge"'
    assert_includes last_response.body, "notice--info"
    assert_equal false, Server.settings.journey.game_over?("user-a"),
                 "após reset time vazio + saldo 200 => nao game_over"
  end # rubocop:enable Metrics/AbcSize
end
