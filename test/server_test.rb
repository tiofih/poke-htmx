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

    assert_includes session_a.last_response.body, "pikachu"
    refute_includes session_a.last_response.body, "bulbasaur"
    assert_includes session_b.last_response.body, "bulbasaur"
    refute_includes session_b.last_response.body, "pikachu"

    assert_equal 2, TestDatabase.distinct_user_ids.size
  end

  def test_post_team_persists_pokemon_for_session_user
    PokeApiStub.with_find(pikachu_pokemon) do
      post "/team", { pokeName: "pikachu" }, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    team = @repository.all("user-a")
    assert_equal 1, team.size
    assert_equal "pikachu", team.first.name
    assert_includes last_response.body, %(name="id" value="#{team.first.id}")
    assert_includes last_response.body, "hx-delete=\"/team\""
    assert_empty @repository.all("user-b")
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

    get "/team", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    assert_includes last_response.body, "hx-delete=\"/team\""
  end

  def test_get_team_is_isolated_per_session
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, user_session("user-b")

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
    assert_includes last_response.body, "Remove from Team"
    assert_includes last_response.body, "bulbasaur"
  end

  def test_team_fragment_renders_slot_badge_and_ordered_by_slot
    @repository.add("user-a", bulbasaur_pokemon)
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "#1"
    assert_includes last_response.body, "#2"
    order = last_response.body.index("bulbasaur") < last_response.body.index("pikachu")
    assert order, "expected bulbasaur (slot 1) before pikachu (slot 2)"
  end

  def test_team_member_links_to_detail
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "hx-get=\"/pokemon/25\""
    assert_includes last_response.body, "hx-target=\"#pokemon\""
  end

  def test_team_member_sprite_is_link_not_submit
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, user_session("user-a")

    assert last_response.ok?
    assert_equal 2, last_response.body.scan(%r{hx-get="/pokemon/25"}).size
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
    assert_includes last_response.body, "Remove from Team"
  end

  def test_team_fragment_renders_move_buttons
    add_team("user-a", [["pikachu", 25], ["bulbasaur", 1], ["charmander", 4], ["squirtle", 7]])

    get "/team", {}, user_session("user-a")

    assert last_response.ok?
    assert_equal 8, last_response.body.scan("hx-post=\"/team/").size
    assert_includes last_response.body, ">▲</button>"
    assert_includes last_response.body, ">▼</button>"
    assert_includes last_response.body, 'name="new_slot"'
    assert_includes last_response.body, 'hx-target="#team"'
  end

  def test_team_manage_renders_move_checkboxes_for_each_member
    @repository.add("user-a", pikachu_pokemon)
    PokeApiStub.with_available_move_names(%w[growl quick-attack thunder-shock]) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    assert_includes last_response.body, 'name="moves"'
    assert_includes last_response.body, 'value="growl"'
    assert_includes last_response.body, 'value="quick-attack"'
    assert_includes last_response.body, 'value="thunder-shock"'
    assert_includes last_response.body, 'hx-post="/team/'
    assert_includes last_response.body, 'hx-get="/team"'
  end

  def test_team_manage_checks_currently_selected_moves
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @repository.set_moves("user-a", pikachu_id, %w[thunder-shock])

    PokeApiStub.with_available_move_names(%w[growl thunder-shock]) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'value="thunder-shock" checked'
    refute_includes last_response.body, 'value="growl" checked'
  end

  def test_team_manage_is_isolated_per_session
    @repository.add("user-a", pikachu_pokemon)

    get "/team/manage", {}, user_session("user-b")

    assert last_response.ok?
    refute_includes last_response.body, "pikachu"
  end

  def test_team_manage_renders_slot_controls_and_back_link
    add_team("user-a", [["pikachu", 25], ["bulbasaur", 1], ["charmander", 4], ["squirtle", 7]])

    PokeApiStub.with_available_move_names(%w[growl]) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'name="new_slot"'
    assert_includes last_response.body, ">▲</button>"
    assert_includes last_response.body, ">▼</button>"
    assert_includes last_response.body, 'hx-get="/team"'
    assert_includes last_response.body, "Voltar"
  end

  def test_team_manage_fragment_has_no_html_wrapper
    @repository.add("user-a", pikachu_pokemon)

    PokeApiStub.with_available_move_names(%w[growl]) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    refute_includes last_response.body, "<html"
    refute_includes last_response.body, "<head>"
  end

  def test_post_team_moves_saves_selected_moves
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id

    PokeApiStub.with_available_move_names(%w[growl quick-attack thunder-shock]) do
      post "/team/#{pikachu_id}/moves", { moves: %w[growl thunder-shock] }, user_session("user-a")
    end

    assert last_response.ok?
    assert_equal %w[growl thunder-shock], @repository.all("user-a").first.moves
  end

  def test_post_team_moves_rerenders_manage_fragment
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id

    PokeApiStub.with_available_move_names(%w[growl thunder-shock]) do
      post "/team/#{pikachu_id}/moves", { moves: ["thunder-shock"] }, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'name="moves"'
    assert_includes last_response.body, 'value="thunder-shock" checked'
    refute_includes last_response.body, "<html"
  end

  def test_post_team_moves_with_more_than_four_shows_notice_and_does_not_save
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    PokeApiStub.with_available_move_names(%w[a b c d e f]) do
      post "/team/#{pikachu_id}/moves", { moves: %w[a b c d e f] }, user_session("user-a")
    end

    assert last_response.ok?
    assert_empty @repository.all("user-a").first.moves
    assert_includes last_response.body, "máximo"
  end

  def test_post_team_moves_with_move_outside_available_shows_notice_and_does_not_save
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id

    PokeApiStub.with_available_move_names(%w[growl]) do
      post "/team/#{pikachu_id}/moves", { moves: %w[not-a-real-move] }, user_session("user-a")
    end

    assert last_response.ok?
    assert_empty @repository.all("user-a").first.moves
    assert_includes last_response.body, "dispon"
  end

  def test_post_team_moves_of_other_users_member_is_noop
    @repository.add("user-a", pikachu_pokemon)
    @repository.add("user-b", bulbasaur_pokemon)
    bulbasaur_id = @repository.all("user-b").first.id

    PokeApiStub.with_available_move_names(%w[growl]) do
      post "/team/#{bulbasaur_id}/moves", { moves: ["growl"] }, user_session("user-a")
    end

    assert last_response.ok?
    assert_empty @repository.all("user-b").first.moves
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
      def available_move_names(_number)
        raise "boom inesperado"
      end
    end.new
    previous = Server.settings.api
    Server.set :api, raising_api

    get "/team/manage", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Algo deu errado. Tente novamente."
    refute_includes last_response.body, "<html"
    refute_includes last_response.body, "boom inesperado"
  ensure
    Server.set :api, previous
  end
end

class ServerDetailTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_pokemon_detail_route_returns_sprite_and_name
    PokeApiStub.with_detail(pikachu_pokemon) do
      get "/pokemon/25"
    end

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    assert_includes last_response.body, "https://example.com/pikachu.png"
  end

  def test_pokemon_detail_renders_types
    pikachu = Pokemon.new(
      name: "pikachu",
      sprite: "https://example.com/pikachu.png",
      number: 25,
      types: ["electric"]
    )

    PokeApiStub.with_detail(pikachu) do
      get "/pokemon/25"
    end

    assert last_response.ok?
    assert_includes last_response.body, "electric"
  end

  def test_pokemon_detail_renders_six_base_stats
    pikachu = Pokemon.new(
      name: "pikachu",
      sprite: "https://example.com/pikachu.png",
      number: 25,
      stats: [
        { name: "HP", value: 35 },
        { name: "Attack", value: 55 },
        { name: "Defense", value: 40 },
        { name: "Sp.Atk", value: 50 },
        { name: "Sp.Def", value: 50 },
        { name: "Speed", value: 90 }
      ]
    )

    PokeApiStub.with_detail(pikachu) do
      get "/pokemon/25"
    end

    assert last_response.ok?
    assert_includes last_response.body, "HP"
    assert_includes last_response.body, "35"
    assert_includes last_response.body, "55"
    assert_includes last_response.body, "Speed"
    assert_includes last_response.body, "90"
  end

  def test_pokemon_close_route_returns_empty_fragment
    get "/pokemon/close"

    assert last_response.ok?
    assert_empty last_response.body
  end

  def test_pokemon_detail_has_close_button
    PokeApiStub.with_detail(pikachu_pokemon) do
      get "/pokemon/25"
    end

    assert last_response.ok?
    assert_includes last_response.body, "hx-get=\"/pokemon/close\""
    assert_includes last_response.body, "hx-target=\"#pokemon\""
  end

  def charizard_evolution_pokemons
    {
      charmander: build_pokemon_record("charmander", 4),
      charmeleon: build_pokemon_record("charmeleon", 5),
      charizard: build_pokemon_record("charizard", 6)
    }
  end

  def test_pokemon_detail_renders_evolution_chain
    chain = charizard_evolution_pokemons
    charizard = Pokemon.new(
      name: "charizard",
      sprite: chain[:charizard].sprite,
      number: 6,
      evolutions: [chain[:charmander], chain[:charmeleon], chain[:charizard]]
    )

    PokeApiStub.with_detail(charizard) do
      get "/pokemon/6"
    end

    assert last_response.ok?
    assert_includes last_response.body, "charmander"
    assert_includes last_response.body, "https://example.com/charmander.png"
    assert_includes last_response.body, "charmeleon"
    assert_includes last_response.body, "https://example.com/charmeleon.png"
    assert_includes last_response.body, "charizard"
  end

  def test_pokemon_detail_without_evolutions_does_not_break
    PokeApiStub.with_detail(pikachu_pokemon) do
      get "/pokemon/25"
    end

    assert last_response.ok?
  end

  def test_pokemon_detail_keeps_add_to_team_form
    PokeApiStub.with_detail(pikachu_pokemon) do
      get "/pokemon/25"
    end

    assert last_response.ok?
    assert_includes last_response.body, "hx-post=\"/team\""
    assert_includes last_response.body, "pokeName"
  end

  def test_pokemon_name_fragment_links_to_detail
    PokeApiStub.with_find(pikachu_pokemon) do
      get "/pokemon", name: "pikachu"
    end

    assert last_response.ok?
    assert_includes last_response.body, "hx-get=\"/pokemon/25\""
    assert_includes last_response.body, "hx-target=\"#pokemon\""
  end

  def test_pokemon_name_fragment_sprite_is_link_not_submit
    PokeApiStub.with_find(pikachu_pokemon) do
      get "/pokemon", name: "pikachu"
    end

    assert last_response.ok?
    assert_equal 2, last_response.body.scan(%r{hx-get="/pokemon/25"}).size
    refute_includes last_response.body, 'input type="image"'
    assert_includes last_response.body, 'hx-post="/team"'
  end

  def test_pokemon_name_with_unknown_name_shows_friendly_notice
    PokeApiStub.with_find(nil) do
      get "/pokemon", name: "xyz"
    end

    assert last_response.ok?
    assert_includes last_response.body, "Pokémon não encontrado."
    refute_includes last_response.body, "<html"
  end

  def test_pokemon_detail_with_unknown_id_shows_friendly_notice
    PokeApiStub.with_detail(nil) do
      get "/pokemon/999999"
    end

    assert last_response.ok?
    assert_includes last_response.body, "Pokémon não encontrado."
    refute_includes last_response.body, "<html"
  end
end

class ServerListTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_index_renders_first_page_with_filter_input
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'id="pokemon-list"'
    assert_equal 100, last_response.body.scan("<option value=\"pokemon").size
    assert_includes last_response.body, 'name="q"'
    assert_includes last_response.body, "Página 1 de 3"
    assert_includes last_response.body, 'id="pokemons"'
  end

  def test_index_has_battle_entry_fragment
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, "hx-get=\"/battle\""
    assert_includes last_response.body, 'id="battle"'
  end

  def test_index_has_header_navigation_links
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, "<nav"
    assert_includes last_response.body, "Lista"
    assert_includes last_response.body, "Time"
    assert_includes last_response.body, "Batalha"
    assert_includes last_response.body, 'href="#pokemon-list"'
    assert_includes last_response.body, 'href="#team"'
    assert_includes last_response.body, 'hx-get="/battle"'
    assert_includes last_response.body, 'hx-target="#battle"'
  end

  def test_index_uses_single_layout_with_external_css
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_equal 1, last_response.body.scan("<html").size
    assert_includes last_response.body, "<title>"
    assert_includes last_response.body, 'href="/style.css"'
    assert_includes last_response.body, 'id="pokemon-list"'
    assert_includes last_response.body, 'id="battle"'
  end

  def test_index_nav_time_link_points_to_manage_fragment
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'hx-get="/team/manage"'
    assert_includes last_response.body, 'hx-target="#team"'
    assert_includes last_response.body, 'href="#team"'
  end

  def test_nav_links_clear_battle_fragment_when_leaving_battle
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'hx-get="/battle/close"'
    assert_includes last_response.body, 'hx-target="#battle"'
  end

  def test_fragments_remain_partial_without_html_wrapper
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/pokemons"
    end
    refute_includes last_response.body, "<html"
    refute_includes last_response.body, "<head>"
    assert_includes last_response.body, 'id="pokemons"'

    @repository.add("user-a", pikachu_pokemon)
    get "/team", {}, user_session("user-a")

    refute_includes last_response.body, "<html"
    refute_includes last_response.body, "<head>"
    assert_includes last_response.body, "Remove from Team"
  end

  def test_stylesheet_served_and_styles_fragment_classes
    get "/style.css"

    assert last_response.ok?
    assert_includes last_response.body, ".battle-pane"
    assert_includes last_response.body, ".fighter"
    assert_includes last_response.body, ".battle-log"
    assert_includes last_response.body, ".pagination"
    assert_includes last_response.body, ".notice"
    assert_includes last_response.body, ".slot"
    assert_includes last_response.body, ".type"
  end

  def test_pokemons_fragment_renders_first_page
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/pokemons"
    end

    assert last_response.ok?
    assert_equal 100, last_response.body.scan("<option value=\"pokemon").size
    assert_includes last_response.body, "id=\"pokemons\""
    assert_includes last_response.body, "hx-get=\"/pokemon\""
    assert_includes last_response.body, "Página 1 de 3"
    assert_includes last_response.body, "Próxima"
  end

  def test_pokemons_first_page_has_no_previous_link
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/pokemons"
    end

    assert last_response.ok?
    refute_includes last_response.body, ">Anterior<"
  end

  def test_pokemons_middle_page_has_previous_and_next_links
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/pokemons", offset: 100
    end

    assert last_response.ok?
    assert_includes last_response.body, "offset=0"
    assert_includes last_response.body, "offset=200"
    assert_includes last_response.body, "Página 2 de 3"
    assert_includes last_response.body, ">Anterior<"
    assert_includes last_response.body, ">Próxima<"
  end

  def test_pokemons_last_page_has_no_next_link
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/pokemons", offset: 200
    end

    assert last_response.ok?
    assert_includes last_response.body, "Página 3 de 3"
    refute_includes last_response.body, ">Próxima<"
    assert_includes last_response.body, ">Anterior<"
  end

  def test_pokemons_filters_by_substring_case_insensitive
    PokeApiStub.with_all_names(filtered_names) do
      get "/pokemons", q: "PIK"
    end

    assert last_response.ok?
    assert_equal 2, last_response.body.scan("<option value=\"pikachu").size
    refute_includes last_response.body, "value=\"bulbasaur\""
    assert_includes last_response.body, "Página 1 de 1"
    refute_includes last_response.body, ">Próxima<"
  end

  def test_pokemons_filter_without_matches_renders_empty_select
    PokeApiStub.with_all_names(filtered_names) do
      get "/pokemons", q: "zzzz"
    end

    assert last_response.ok?
    assert_equal 1, last_response.body.scan("<option ").size
    assert_includes last_response.body, 'id="pokemons"'
    refute_includes last_response.body, 'value="pikachu"'
  end

  def test_pokemons_empty_q_returns_full_list
    PokeApiStub.with_all_names(filtered_names) do
      get "/pokemons", q: ""
    end

    assert last_response.ok?
    %w[pikachu pichu raichu pikachu-alola bulbasaur].each do |name|
      assert_includes last_response.body, "value=\"#{name}\""
    end
  end

  def test_pokemons_paginates_filtered_results
    PokeApiStub.with_all_names(filtered_names) do
      get "/pokemons", q: "i"
    end

    assert last_response.ok?
    assert_equal 5, last_response.body.scan("<option value=").size
  end

  def test_pokemons_with_empty_source_and_no_filter_shows_notice
    PokeApiStub.with_all_names([]) do
      get "/pokemons"
    end

    assert last_response.ok?
    assert_includes last_response.body, "Não foi possível carregar a lista de Pokémon."
    refute_includes last_response.body, "<html"
  end

  def test_pokemons_with_empty_source_and_filter_has_no_notice
    PokeApiStub.with_all_names([]) do
      get "/pokemons", q: "pikachu"
    end

    assert last_response.ok?
    refute_includes last_response.body, "Não foi possível carregar a lista de Pokémon."
  end

  def test_index_with_empty_source_and_no_filter_shows_notice
    PokeApiStub.with_all_names([]) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, "Não foi possível carregar a lista de Pokémon."
  end
end

class ServerBattleTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def battle_pokemon_for_test
    Pokemon.new(
      name: "pikachu",
      sprite: "https://example.com/pikachu.png",
      number: 25,
      types: ["electric"],
      stats: [
        { name: "HP", value: 200 },
        { name: "Attack", value: 55 },
        { name: "Defense", value: 40 },
        { name: "Speed", value: 90 }
      ]
    )
  end

  def battle_moves_for_test
    [build_move("thunder-shock", type: "electric", power: 40, pp: 30)]
  end

  def neutral_type_json_table
    PokeApiTypes::TYPE_NAMES.to_h { |type| [type, type_json_for(type)] }
  end

  def type_json_for(type)
    {
      "name" => type,
      "damage_relations" => {
        "double_damage_to" => [],
        "half_damage_to" => [],
        "no_damage_to" => []
      }
    }
  end

  def stub_battle_start(&block)
    PokeApiStub.with_all_names(%w[pikachu bulbasaur charmander squirtle eevee jigglypuff]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_detail(battle_pokemon_for_test) do
          PokeApiStub.with_moves_for(battle_moves_for_test) do
            block.call
          end
        end
      end
    end
  end

  def start_battle_for(user_id)
    add_team(user_id, [["pikachu", 25], ["bulbasaur", 26], ["charmander", 27]]) if @repository.all(user_id).empty?
    stub_battle_start { get "/battle", {}, user_session(user_id) }
  end

  def test_battle_close_route_returns_empty_fragment
    get "/battle/close"

    assert last_response.ok?
    assert_empty last_response.body
  end

  def test_battle_start_loads_into_panel_without_clearing_nav
    @repository.add("user-a", pikachu_pokemon)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Seu Time"
  end

  def test_battle_renders_panels_with_team_and_opponent
    @repository.add("user-a", pikachu_pokemon)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Seu Time"
    assert_includes last_response.body, "Oponente"
    assert_includes last_response.body, "pikachu"
    assert_includes last_response.body, "200/200"
    assert_includes last_response.body, "hx-target=\"#battle\""
  end

  def test_battle_fragment_has_play_button
    @repository.add("user-a", pikachu_pokemon)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "hx-post=\"/battle/play\""
    refute_includes last_response.body, "Vencedor"
  end

  def test_battle_with_empty_team_shows_friendly_message
    get "/battle", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Forme seu time"
  end

  def test_battle_play_advances_one_round_and_refreshes_fragment
    start_battle_for("user-a")

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Rodada 1"
    assert_includes last_response.body, "usou thunder-shock em"
  end

  def test_battle_play_reuses_state_between_requests
    start_battle_for("user-a")

    post "/battle/play", {}, user_session("user-a")
    round_one_hp = last_response.body

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Rodada 2"
    refute_equal round_one_hp, last_response.body, "estado avança (HP/log mudam) a cada play"
  end

  def test_battle_play_without_started_battle_does_not_break
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
  end

  def test_battle_end_shows_winner_and_reset_button
    start_battle_for("user-a")
    20.times { post "/battle/play", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "Vencedor:"
    assert_includes last_response.body, "hx-get=\"/battle\""
  end

  def test_battle_reset_starts_a_fresh_battle_with_persisted_hp
    start_battle_for("user-a")
    20.times { post "/battle/play", {}, user_session("user-a") }
    persisted_hp = @repository.all("user-a").map(&:hp_current)

    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "Rodada 0",
                    "reset recria a batalha do zero"
    persisted_hp.each do |hp|
      assert_includes last_response.body, "HP #{hp}/",
                      "time danificado (HP #{hp}) entra no reset"
    end
  end

  def test_battle_shows_moves_with_pp_per_fighter
    @repository.add("user-a", pikachu_pokemon)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "thunder-shock"
    assert_includes last_response.body, "PP 30"
  end

  def test_battle_log_shows_used_move_name
    start_battle_for("user-a")

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "thunder-shock"
    assert_includes last_response.body, "usou thunder-shock em"
  end

  def test_battle_with_struggle_fallback_does_not_break
    @repository.add("user-a", pikachu_pokemon)

    PokeApiStub.with_all_names(%w[pikachu bulbasaur charmander squirtle eevee jigglypuff]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_detail(battle_pokemon_for_test) do
          PokeApiStub.with_moves_for([]) do
            get "/battle", {}, user_session("user-a")
          end
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "Struggle"
  end

  def test_battle_uses_saved_moves_for_player
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @repository.set_moves("user-a", pikachu_id, %w[quick-attack])

    PokeApiStub.with_all_names(%w[pikachu bulbasaur charmander squirtle eevee jigglypuff]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_detail(battle_pokemon_for_test) do
          PokeApiStub.with_moves_for(battle_moves_for_test) do
            PokeApiStub.with_move("quick-attack" => build_move("quick-attack", type: "normal", power: 40, pp: 30)) do
              get "/battle", {}, user_session("user-a")
            end
          end
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "quick-attack"
  end

  def test_battle_play_log_uses_saved_move_name
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @repository.set_moves("user-a", pikachu_id, %w[quick-attack])

    PokeApiStub.with_all_names(%w[pikachu bulbasaur charmander squirtle eevee jigglypuff]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_detail(battle_pokemon_for_test) do
          PokeApiStub.with_moves_for(battle_moves_for_test) do
            PokeApiStub.with_move("quick-attack" => build_move("quick-attack", type: "normal", power: 40, pp: 30)) do
              get "/battle", {}, user_session("user-a")
            end
          end
        end
      end
    end

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "usou quick-attack em"
  end

  def test_battle_with_unresolvable_saved_moves_falls_back_to_default
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @repository.set_moves("user-a", pikachu_id, %w[obsolete-move])

    PokeApiStub.with_all_names(%w[pikachu bulbasaur charmander squirtle eevee jigglypuff]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_detail(battle_pokemon_for_test) do
          PokeApiStub.with_moves_for(battle_moves_for_test) do
            PokeApiStub.with_move({}) do
              get "/battle", {}, user_session("user-a")
            end
          end
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "thunder-shock"
  end

  def test_battle_with_member_detail_nil_shows_friendly_message
    @repository.add("user-a", pikachu_pokemon)

    PokeApiStub.with_all_names(%w[pikachu bulbasaur charmander squirtle eevee jigglypuff]) do
      PokeApiStub.with_detail(nil) do
        get "/battle", {}, user_session("user-a")
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "Não foi possível preparar a batalha."
    refute_includes last_response.body, "<html"
  end

  def test_battle_with_empty_opponent_shows_friendly_message
    @repository.add("user-a", pikachu_pokemon)

    PokeApiStub.with_all_names([]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_detail(battle_pokemon_for_test) do
          PokeApiStub.with_moves_for(battle_moves_for_test) do
            get "/battle", {}, user_session("user-a")
          end
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "Não foi possível preparar a batalha."
  end

  def test_battle_renders_level_one_per_fighter_by_default
    @repository.add("user-a", pikachu_pokemon)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Nível 1"
    assert_includes last_response.body, "200/200", "nível 1 não escala stats"
  end

  def test_battle_uses_persisted_member_level_for_player_and_opponent
    @repository.add("user-a", pikachu_pokemon)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.grant("user-a", pokemon_id, 600)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Nível 4"
    assert_includes last_response.body, "202/202", "HP 200 escala para 202 no nível 4"
  end

  def test_battle_play_shows_xp_gained_message_at_finish
    start_battle_for("user-a")
    20.times { post "/battle/play", {}, user_session("user-a") }

    assert last_response.ok?
    assert_match(/Seu Time ganhou \d+ XP/, last_response.body)
  end

  def test_battle_play_grants_xp_once_on_transition_to_finished
    @repository.add("user-a", pikachu_pokemon)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    start_battle_for("user-a")

    20.times { post "/battle/play", {}, user_session("user-a") }

    after_finish = TestDatabase.progress_row(pokemon_id)["xp"].to_i
    assert_includes [20, 25, 50], after_finish, "XP concedido uma vez conforme o resultado"

    5.times { post "/battle/play", {}, user_session("user-a") }

    assert_equal after_finish, TestDatabase.progress_row(pokemon_id)["xp"].to_i,
                 "play após o fim não concede XP de novo (guard de transição)"
  end

  def test_battle_reset_reflects_persisted_xp_on_new_confront
    @repository.add("user-a", pikachu_pokemon)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    start_battle_for("user-a")
    20.times { post "/battle/play", {}, user_session("user-a") }

    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "Nível #{TestDatabase.progress_row(pokemon_id)['level'].to_i}"
  end

  def test_battle_play_grants_money_once_on_transition_to_finished
    @repository.add("user-a", pikachu_pokemon)
    start_battle_for("user-a")
    assert_equal 0, @wallet.balance("user-a"), "moeda não concedida antes do fim"

    20.times { post "/battle/play", {}, user_session("user-a") }

    after_finish = @wallet.balance("user-a")
    assert_includes [40, 50, 100], after_finish, "moeda concedida uma vez conforme o resultado"

    5.times { post "/battle/play", {}, user_session("user-a") }

    assert_equal after_finish, @wallet.balance("user-a"),
                 "play após o fim não concede moeda de novo (guard de transição)"
  end

  def test_battle_play_does_not_grant_money_before_finish
    start_battle_for("user-a")
    assert_equal 0, @wallet.balance("user-a"), "moeda não concedida ao abrir a batalha"

    post "/battle/play", {}, user_session("user-a")

    refute_includes last_response.body, "Fim de batalha", "batalha de 3v6 não termina em 1 round"
    assert_equal 0, @wallet.balance("user-a"), "moeda não concedida antes do fim"
  end

  def test_battle_finish_shows_money_gained_message
    start_battle_for("user-a")
    20.times { post "/battle/play", {}, user_session("user-a") }

    assert last_response.ok?
    assert_match(/\d+ de dinheiro/, last_response.body)
    assert_match(/ganhou \d+ XP por Pokémon e \d+ de dinheiro/, last_response.body)
  end

  def test_battle_finish_evolves_member_when_level_reaches_min_level
    @repository.add("user-a", pikachu_pokemon)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.grant("user-a", pokemon_id, 99_999)

    raichu_detail = Pokemon.new(name: "raichu", sprite: "https://example.com/raichu.png", number: 26)
    detail_map = { 25 => battle_pokemon_for_test, 26 => raichu_detail, "pikachu" => battle_pokemon_for_test }
    evolution_data = [{ number: 26, name: "raichu", min_level: 16 }]

    PokeApiStub.with_all_names(%w[pikachu]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_gateway(detail: detail_map, moves_for: battle_moves_for_test,
                                 next_evolutions: evolution_data) do
          get "/battle", {}, user_session("user-a")
          play_until_finish
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "evoluiu para raichu"
    assert_includes last_response.body, 'src="https://example.com/raichu.png"',
                    "painel da batalha deve exibir sprite do pokemon evoluido"
  end

  def test_battle_finish_does_not_evolve_when_target_already_in_team
    @repository.add("user-a", pikachu_pokemon)
    @repository.add("user-a", Pokemon.new(name: "raichu", sprite: "", number: 26))
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.grant("user-a", pikachu_id, 99_999)

    raichu_detail = Pokemon.new(name: "raichu", sprite: "https://example.com/raichu.png", number: 26)
    detail_map = { 25 => battle_pokemon_for_test, 26 => raichu_detail, "pikachu" => battle_pokemon_for_test }
    evolution_data = [{ number: 26, name: "raichu", min_level: 16 }]

    PokeApiStub.with_all_names(%w[pikachu]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_gateway(detail: detail_map, moves_for: battle_moves_for_test,
                                 next_evolutions: evolution_data) do
          get "/battle", {}, user_session("user-a")
          play_until_finish
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "não evoluiu"
  end

  def test_battle_finish_learns_moves_when_level_sufficient
    @repository.add("user-a", pikachu_pokemon)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.grant("user-a", pokemon_id, 99_999)

    learnable = [{ level: 5, name: "quick-attack" }, { level: 30, name: "thunderbolt" }]
    stub_battle_start do
      PokeApiStub.with_learnable_moves(learnable) do
        get "/battle", {}, user_session("user-a")
        play_until_finish(fallback_plays: 50)
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "aprendeu quick-attack"
    assert_includes last_response.body, "aprendeu thunderbolt"
    assert_includes @repository.all("user-a").first.moves, "quick-attack"
    assert_includes @repository.all("user-a").first.moves, "thunderbolt"
  end

  def test_battle_finish_does_not_learn_when_level_insufficient
    @repository.add("user-a", pikachu_pokemon)

    stub_battle_start do
      PokeApiStub.with_learnable_moves([{ level: 50, name: "thunder" }]) do
        get "/battle", {}, user_session("user-a")
        play_until_finish(fallback_plays: 50)
      end
    end

    assert last_response.ok?
    refute_includes last_response.body, "aprendeu"
    assert_empty @repository.all("user-a").first.moves
  end

  def test_battle_finish_persists_one_record_in_battles
    start_battle_for("user-a")
    20.times { post "/battle/play", {}, user_session("user-a") }

    rows = TestDatabase.battle_rows("user-a")
    assert_equal 1, rows.size, "exatamente um registro ao finar a batalha"
    assert_includes %w[win lose draw], rows.first["result"]
    assert_includes rows.first["opponent_team"].to_json, "pikachu"
  end

  def test_battle_play_after_finish_does_not_duplicate_battle_record
    start_battle_for("user-a")
    20.times { post "/battle/play", {}, user_session("user-a") }
    after_finish = TestDatabase.battle_rows("user-a").size

    5.times { post "/battle/play", {}, user_session("user-a") }

    assert_equal after_finish, TestDatabase.battle_rows("user-a").size,
                 "play após o fim não persiste novo registro (guard de transição)"
  end

  def test_battle_in_progress_does_not_persist_record
    start_battle_for("user-a")
    post "/battle/play", {}, user_session("user-a")

    assert_empty TestDatabase.battle_rows("user-a")
  end

  def test_battle_records_are_isolated_per_user
    start_battle_for("user-a")
    20.times { post "/battle/play", {}, user_session("user-a") }

    assert_empty TestDatabase.battle_rows("user-b")
  end

  def play_until_finish(fallback_plays: 20)
    fallback_plays.times do
      post "/battle/play", {}, user_session("user-a")
      return if last_response.body.include?("Fim de batalha")
    end
  end

  def test_battle_finish_persists_hp_per_member
    start_battle_for("user-a")
    play_until_finish(fallback_plays: 50)

    members = @repository.all("user-a")
    assert members.all? { |member| member.hp_max.positive? },
           "hp_max persistido após a batalha"
    assert members.any? { |member| member.hp_current < member.hp_max },
           "algum membro terminou a batalha com dano"
  end

  def test_battle_finish_persists_hp_only_once
    start_battle_for("user-a")
    play_until_finish(fallback_plays: 50)
    first = @repository.all("user-a").map(&:hp_current)

    5.times { post "/battle/play", {}, user_session("user-a") }

    assert_equal first, @repository.all("user-a").map(&:hp_current),
                 "plays após o fim não re-persistem HP (guard de transição)"
  end

  def test_battle_in_progress_does_not_persist_hp
    start_battle_for("user-a")
    post "/battle/play", {}, user_session("user-a")

    members = @repository.all("user-a")
    assert members.all? { |member| member.hp_max.zero? },
           "batalha em andamento não persiste HP"
  end

  def test_new_battle_starts_with_persisted_hp
    @repository.add("user-a", pikachu_pokemon)
    @repository.add("user-a", bulbasaur_pokemon)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 200, 50)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "HP 50/200",
                    "time danificado entra no próximo confronto com o HP persistido"
  end

  def test_new_battle_starts_full_for_member_who_never_battled
    @repository.add("user-a", pikachu_pokemon)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "HP 200/200",
                    "membro que nunca batalhou entra com HP cheio"
  end
end

class ServerHistoryTest < Minitest::Test
  include ServerTestHelpers

  def test_history_renders_fragment_with_rank_and_metrics
    history = BattleRepository.new
    history.add("user-a", "win", [{ number: 25, name: "pikachu" }])
    history.add("user-a", "lose", [{ number: 4, name: "charmander" }])

    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, "<html"
    assert_match(/Ranking global/, last_response.body)
    assert_match(/Vitórias: 1/, last_response.body)
    assert_match(/Derrotas: 1/, last_response.body)
  end

  def test_history_highlights_current_user_in_ranking
    history = BattleRepository.new
    history.add("user-a", "win", [{ number: 25, name: "pikachu" }])

    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    assert_match(/user-a/, last_response.body)
  end

  def test_history_shows_empty_message_without_battles
    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Você ainda não batalhou"
  end

  def test_history_close_route_returns_empty_fragment
    get "/history/close"

    assert last_response.ok?
    assert_empty last_response.body
  end

  def test_index_has_history_target_and_link
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'id="history"'
    assert_includes last_response.body, 'hx-get="/history"'
    assert_includes last_response.body, "Histórico"
  end

  def test_nav_links_clear_history_when_leaving_history
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'hx-get="/battle/close"'
    assert_includes last_response.body, 'href="#history"'
    assert_includes last_response.body, 'hx-get="/history/close"'
    assert_includes last_response.body, 'hx-target="#history"'
  end
end
