# frozen_string_literal: true

require_relative "test_helper"
require_relative "../server"

# rubocop:disable Metrics/ClassLength
class ServerTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Server
  end

  def setup
    TestDatabase.setup!
    TestDatabase.clear_team!
    @repository = TeamRepository.new
  end

  def pikachu_pokemon
    Pokemon.new(name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25)
  end

  def bulbasaur_pokemon
    Pokemon.new(name: "bulbasaur", sprite: "https://example.com/bulbasaur.png", number: 1)
  end

  def rack_test_session
    Rack::Test::Session.new(Rack::MockSession.new(app))
  end

  def user_session(user_id)
    { "rack.session" => { "user_id" => user_id } }
  end

  def test_first_access_generates_session_cookie
    PokeApiStub.with_find(pikachu_pokemon) do
      post "/team", pokeName: "pikachu"
    end

    assert last_response.ok?
    assert_includes last_response.headers["Set-Cookie"], "rack.session"
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
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

    assert_equal 2, distinct_user_ids.size
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
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
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def test_delete_team_removes_pokemon_from_own_session
    @repository.add("user-a", pikachu_pokemon)
    id = @repository.all("user-a").first.id

    delete "/team", { id: id }, user_session("user-a")

    assert last_response.ok?
    assert_empty @repository.all("user-a")
    refute_includes last_response.body, "pikachu"
  end

  # rubocop:disable Metrics/AbcSize
  def test_delete_team_with_unknown_id_keeps_team_intact
    @repository.add("user-a", pikachu_pokemon)
    id = @repository.all("user-a").first.id
    unknown_id = (id.to_i + 999).to_s

    delete "/team", { id: unknown_id }, user_session("user-a")

    assert last_response.ok?
    assert_equal 1, @repository.all("user-a").size
    assert_includes last_response.body, "pikachu"
  end
  # rubocop:enable Metrics/AbcSize

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

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def test_post_team_when_full_returns_warning_and_keeps_six
    six = (1..6).map do |n|
      Pokemon.new(name: "pokemon#{n}", sprite: "https://example.com/#{n}.png", number: n)
    end
    six.each { |poke| @repository.add("user-a", poke) }
    seventh = Pokemon.new(name: "meowth", sprite: "https://example.com/meowth.png", number: 52)

    PokeApiStub.with_find(seventh) do
      post "/team", { pokeName: "meowth" }, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Time cheio"
    assert_equal 6, @repository.all("user-a").size
    refute_includes @repository.all("user-a").map(&:name), "meowth"
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

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

  def test_pokemon_detail_route_returns_sprite_and_name
    PokeApiStub.with_detail(pikachu_pokemon) do
      get "/pokemon/25"
    end

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    assert_includes last_response.body, "https://example.com/pikachu.png"
  end

  # rubocop:disable Metrics/MethodLength
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
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
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
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

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
      charmander: Pokemon.new(name: "charmander", sprite: "https://example.com/charmander.png", number: 4),
      charmeleon: Pokemon.new(name: "charmeleon", sprite: "https://example.com/charmeleon.png", number: 5),
      charizard: Pokemon.new(name: "charizard", sprite: "https://example.com/charizard.png", number: 6)
    }
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
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
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

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

  def two_hundred_fifty_names
    (1..250).map { |index| "pokemon#{index}" }
  end

  # rubocop:disable Metrics/AbcSize
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
  # rubocop:enable Metrics/AbcSize

  def test_pokemons_first_page_has_no_previous_link
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/pokemons"
    end

    assert last_response.ok?
    refute_includes last_response.body, ">Anterior<"
  end

  # rubocop:disable Metrics/AbcSize
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
  # rubocop:enable Metrics/AbcSize

  def test_pokemons_last_page_has_no_next_link
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/pokemons", offset: 200
    end

    assert last_response.ok?
    assert_includes last_response.body, "Página 3 de 3"
    refute_includes last_response.body, ">Próxima<"
    assert_includes last_response.body, ">Anterior<"
  end

  def filtered_names
    %w[pikachu pichu raichu pikachu-alola bulbasaur]
  end

  # rubocop:disable Metrics/AbcSize
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
  # rubocop:enable Metrics/AbcSize

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

  # rubocop:disable Metrics/AbcSize
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
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/AbcSize
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
  # rubocop:enable Metrics/AbcSize

  def test_team_member_links_to_detail
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "hx-get=\"/pokemon/25\""
    assert_includes last_response.body, "hx-target=\"#pokemon\""
  end

  # rubocop:disable Metrics/AbcSize
  def test_team_member_sprite_is_link_not_submit
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, user_session("user-a")

    assert last_response.ok?
    assert_equal 2, last_response.body.scan(%r{hx-get="/pokemon/25"}).size
    refute_includes last_response.body, 'input type="image"'
    assert_includes last_response.body, 'hx-delete="/team"'
  end
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/AbcSize
  def test_post_team_move_reorders_team_fragment
    add_four_pokemon_team("user-a")
    charmander_id = @repository.all("user-a").find { |poke| poke.name == "charmander" }.id

    post "/team/#{charmander_id}/move", { new_slot: 1 }, user_session("user-a")

    assert last_response.ok?
    order = last_response.body.index("charmander") < last_response.body.index("pikachu")
    assert order, "expected charmander (slot 1) before pikachu"
    assert_includes last_response.body, "#1"
  end
  # rubocop:enable Metrics/AbcSize

  def test_team_move_invalid_slot_keeps_team_intact
    add_four_pokemon_team("user-a")
    pikachu_id = @repository.all("user-a").find { |poke| poke.name == "pikachu" }.id

    post "/team/#{pikachu_id}/move", { new_slot: 99 }, user_session("user-a")

    assert last_response.ok?
    assert_equal %w[pikachu bulbasaur charmander squirtle], @repository.all("user-a").map(&:name)
  end

  # rubocop:disable Metrics/AbcSize
  def test_team_move_of_other_users_member_is_noop
    @repository.add("user-a", pikachu_pokemon)
    @repository.add("user-b", bulbasaur_pokemon)
    bulbasaur_id = @repository.all("user-b").first.id

    post "/team/#{bulbasaur_id}/move", { new_slot: 1 }, user_session("user-a")

    assert last_response.ok?
    assert_equal %w[pikachu], @repository.all("user-a").map(&:name)
    assert_equal %w[bulbasaur], @repository.all("user-b").map(&:name)
  end
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/AbcSize
  def test_team_move_does_not_break_delete
    add_four_pokemon_team("user-a")
    pikachu_id = @repository.all("user-a").find { |poke| poke.name == "pikachu" }.id

    post "/team/#{pikachu_id}/move", { new_slot: 1 }, user_session("user-a")
    delete "/team", { id: pikachu_id }, user_session("user-a")

    assert last_response.ok?
    refute_includes @repository.all("user-a").map(&:name), "pikachu"
    assert_includes last_response.body, "Remove from Team"
  end
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/AbcSize
  def test_team_fragment_renders_move_buttons
    add_four_pokemon_team("user-a")

    get "/team", {}, user_session("user-a")

    assert last_response.ok?
    assert_equal 8, last_response.body.scan("hx-post=\"/team/").size
    assert_includes last_response.body, ">▲</button>"
    assert_includes last_response.body, ">▼</button>"
    assert_includes last_response.body, 'name="new_slot"'
    assert_includes last_response.body, 'hx-target="#team"'
  end
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/AbcSize
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
  # rubocop:enable Metrics/AbcSize

  def test_index_has_battle_entry_fragment
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, "hx-get=\"/battle\""
    assert_includes last_response.body, 'id="battle"'
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
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
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize
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
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
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
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def test_battle_close_route_returns_empty_fragment
    get "/battle/close"

    assert last_response.ok?
    assert_empty last_response.body
  end

  def test_nav_links_clear_battle_fragment_when_leaving_battle
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'hx-get="/battle/close"'
    assert_includes last_response.body, 'hx-target="#battle"'
  end

  # rubocop:disable Metrics/MethodLength
  def test_battle_start_loads_into_panel_without_clearing_nav
    @repository.add("user-a", pikachu_pokemon)

    PokeApiStub.with_all_names(%w[pikachu bulbasaur charmander squirtle eevee jigglypuff]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_detail(battle_pokemon_for_test) do
          PokeApiStub.with_moves_for(battle_moves_for_test) do
            get "/battle", {}, user_session("user-a")
          end
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "Seu Time"
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize
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
  # rubocop:enable Metrics/AbcSize

  # rubocop:disable Metrics/MethodLength
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
  # rubocop:enable Metrics/MethodLength

  def battle_moves_for_test
    [Move.new(name: "thunder-shock", type: "electric", power: 40, accuracy: 100, pp: 30)]
  end

  def neutral_type_json_table
    PokeApi::TYPE_NAMES.to_h { |type| [type, type_json_for(type)] }
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

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def test_battle_renders_panels_with_team_and_opponent
    @repository.add("user-a", pikachu_pokemon)

    PokeApiStub.with_all_names(%w[pikachu bulbasaur charmander squirtle eevee jigglypuff]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_detail(battle_pokemon_for_test) do
          PokeApiStub.with_moves_for(battle_moves_for_test) do
            get "/battle", {}, user_session("user-a")
          end
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "Seu Time"
    assert_includes last_response.body, "Oponente"
    assert_includes last_response.body, "pikachu"
    assert_includes last_response.body, "200/200"
    assert_includes last_response.body, "hx-target=\"#battle\""
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def test_battle_fragment_has_play_button
    @repository.add("user-a", pikachu_pokemon)

    PokeApiStub.with_all_names(%w[pikachu bulbasaur charmander squirtle eevee jigglypuff]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_detail(battle_pokemon_for_test) do
          PokeApiStub.with_moves_for(battle_moves_for_test) do
            get "/battle", {}, user_session("user-a")
          end
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "hx-post=\"/battle/play\""
    refute_includes last_response.body, "Vencedor"
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def test_battle_with_empty_team_shows_friendly_message
    get "/battle", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Forme seu time"
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
    add_three_pokemon_team(user_id) if @repository.all(user_id).empty?
    stub_battle_start { get "/battle", {}, user_session(user_id) }
  end

  def add_three_pokemon_team(user_id)
    %w[pikachu bulbasaur charmander].each_with_index do |name, index|
      pokemon = Pokemon.new(
        name: name,
        sprite: "https://example.com/#{name}.png",
        number: 25 + index
      )
      @repository.add(user_id, pokemon)
    end
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

  def test_battle_reset_starts_a_fresh_battle
    start_battle_for("user-a")
    20.times { post "/battle/play", {}, user_session("user-a") }

    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "Rodada 0"
    refute_includes last_response.body, "Vencedor"
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def test_battle_shows_moves_with_pp_per_fighter
    @repository.add("user-a", pikachu_pokemon)

    PokeApiStub.with_all_names(%w[pikachu bulbasaur charmander squirtle eevee jigglypuff]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_detail(battle_pokemon_for_test) do
          PokeApiStub.with_moves_for(battle_moves_for_test) do
            get "/battle", {}, user_session("user-a")
          end
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "thunder-shock"
    assert_includes last_response.body, "PP 30"
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def test_battle_log_shows_used_move_name
    start_battle_for("user-a")

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "thunder-shock"
    assert_includes last_response.body, "usou thunder-shock em"
  end

  # rubocop:disable Metrics/MethodLength
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
  # rubocop:enable Metrics/MethodLength

  private

  def add_four_pokemon_team(user_id)
    [["pikachu", 25], ["bulbasaur", 1], ["charmander", 4], ["squirtle", 7]].each do |name, number|
      pokemon = Pokemon.new(
        name: name,
        sprite: "https://example.com/#{name}.png",
        number: number
      )
      @repository.add(user_id, pokemon)
    end
  end

  def distinct_user_ids
    connection = PG.connect(ENV.fetch("DATABASE_URL"))
    connection.exec("SELECT DISTINCT user_id FROM team_pokemons").map { |row| row["user_id"] }
  ensure
    connection&.close
  end
end
# rubocop:enable Metrics/ClassLength
