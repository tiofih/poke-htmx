# frozen_string_literal: true

require_relative "server_test_helpers"
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

  def test_pokemon_detail_sprite_has_alt_text
    PokeApiStub.with_detail(pikachu_pokemon) do
      get "/pokemon/25"
    end

    assert last_response.ok?
    assert_match(/<img[^>]+alt="pikachu"/, last_response.body)
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
    assert_includes last_response.body, "hx-target=\"#pokemon-detail\""
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

  def test_pokemon_detail_evolutions_are_links_to_detail
    chain = charizard_evolution_pokemons
    charizard = Pokemon.new(
      name: "charizard",
      sprite: chain[:charizard].sprite,
      number: 6,
      evolutions: [chain[:charmander], chain[:charmeleon]]
    )

    PokeApiStub.with_detail(charizard) do
      get "/pokemon/6"
    end

    assert last_response.ok?
    assert_match(%r{hx-get="/pokemon/4"[^>]*hx-target="#pokemon-detail"}, last_response.body)
    assert_match(%r{hx-get="/pokemon/5"[^>]*hx-target="#pokemon-detail"}, last_response.body)
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
    assert_includes last_response.body, "Adicionar ao time"
  end

  def test_pokemon_name_fragment_links_to_detail
    PokeApiStub.with_find(pikachu_pokemon) do
      get "/pokemon", name: "pikachu"
    end

    assert last_response.ok?
    assert_includes last_response.body, "hx-get=\"/pokemon/25\""
    assert_includes last_response.body, "hx-target=\"#pokemon-detail\""
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

  def test_pokemon_detail_evolution_sprites_have_alt_text
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
    assert_match(/alt="charmander"/, last_response.body)
    assert_match(/alt="charmeleon"/, last_response.body)
    assert_match(/alt="charizard"/, last_response.body)
  end
end

class ServerListTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def records_for(names)
    names.to_h { |name| [name, build_pokemon_record(name, number_for(name))] }
  end

  def number_for(name)
    digits = name.scan(/\d+/).first
    digits ? digits.to_i : 25
  end

  def stub_list(names, evolved: [], &)
    forms = names.to_h { |name| [name, !evolved.include?(name)] }
    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_find(records_for(names)) do
        PokeApiStub.with_base_forms(forms, &)
      end
    end
  end

  def refute_dropdown_markup(body)
    refute_includes body, "<select"
    refute_includes body, "<option"
  end

  ALL_STARTERS = %w[
    bulbasaur charmander squirtle
    chikorita cyndaquil totodile
    treecko torchic mudkip
    turtwig chimchar piplup
    snivy tepig oshawott
    chespin fennekin froakie
    rowlet litten popplio
    grookey scorbunny sobble
    sprigatito fuecoco quaxly
  ].freeze

  def test_index_renders_clickable_list
    stub_list(two_hundred_fifty_names) { get "/" }

    assert last_response.ok?
    assert_includes last_response.body, 'id="pokemon-list"'
    assert_equal 27, last_response.body.scan('<li class="starter-item">').size
    assert_equal 9, last_response.body.scan('<li class="list-item">').size
    assert_includes last_response.body, 'name="q"'
    assert_includes last_response.body, "Página 1"
    assert_includes last_response.body, 'name="type"'
    assert_includes last_response.body, "<select"
  end

  def test_index_is_list_only_screen
    stub_list(two_hundred_fifty_names) { get "/" }

    assert last_response.ok?
    assert_includes last_response.body, 'id="pokemon-list"'
    assert_includes last_response.body, 'id="pokemon-detail"'
    assert_includes last_response.body, 'id="add-status"'
    refute_includes last_response.body, 'id="team"'
    refute_includes last_response.body, 'id="battle"'
    refute_includes last_response.body, 'id="history"'
  end

  def test_index_has_battle_entry_fragment
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'href="/battle"'
  end

  def test_index_has_header_navigation_links
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, "<nav"
    assert_includes last_response.body, "Time"
    assert_includes last_response.body, "Batalha"
    assert_includes last_response.body, 'href="/"'
    refute_includes last_response.body, 'href="/team"'
    assert_includes last_response.body, 'href="/battle"'
    assert_includes last_response.body, 'href="/history"'
    refute_includes last_response.body, "hx-trigger=\"click from:#nav-lista\""
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
    assert_includes last_response.body, 'id="pokemon-detail"'
  end

  def test_index_page_uses_full_width_list_body_class
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'class=" page-list"'
    assert_includes last_response.body, 'class="grid-2-1"'
    assert_match(/class="catalog-pane[^"]*"/, last_response.body)
  end

  def test_index_renders_team_panel_with_counter_when_not_started
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'id="team-view"'
    assert_includes last_response.body, "0/6"
    assert_includes last_response.body, "jornada"
  end

  def test_index_team_panel_shows_members
    add_team("user-a", [["pikachu", 25], ["bulbasaur", 1]])

    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    assert_includes last_response.body, "bulbasaur"
    assert_includes last_response.body, 'id="team-view"'
  end

  def test_nav_has_no_time_link_after_unification
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    refute_includes last_response.body, 'href="/team"'
    assert_includes last_response.body, 'href="/" class="active"'
  end

  def test_layout_marks_active_nav_link_on_list_page
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'href="/" class="active"'
    refute_includes last_response.body, 'href="/team" class="active"'
    refute_includes last_response.body, 'href="/battle" class="active"'
    refute_includes last_response.body, 'href="/history" class="active"'
  end

  def test_pokemons_fragment_has_no_html_wrapper
    stub_list(two_hundred_fifty_names) { get "/pokemons" }

    refute_includes last_response.body, "<html"
    refute_includes last_response.body, "<head>"
    assert_includes last_response.body, 'class="pokemon-list"'
  end

  def test_pokemons_list_images_are_lazy
    stub_list(two_hundred_fifty_names) do
      get "/pokemons", q: "pokemon"
    end

    assert last_response.ok?
    assert_equal 36, last_response.body.scan('loading="lazy"').size
  end

  def test_index_has_global_loading_indicator
    stub_list(two_hundred_fifty_names) { get "/" }

    assert last_response.ok?
    assert_includes last_response.body, 'id="global-loading"'
    assert_includes last_response.body, "htmx:beforeRequest"
    assert_includes last_response.body, "htmx:afterRequest"
  end

  def test_stylesheet_served_and_styles_fragment_classes
    get "/style.css"

    assert last_response.ok?
    assert_includes last_response.body, ".battle-pane"
    assert_includes last_response.body, ".fighter"
    assert_includes last_response.body, ".battle-log"
    assert_includes last_response.body, ".pagination"
    assert_includes last_response.body, ".notice"
    assert_includes last_response.body, "#global-loading"
    assert_includes last_response.body, ".slot"
    assert_includes last_response.body, ".type"
  end

  def test_pokemons_renders_clickable_list # rubocop:disable Metrics/AbcSize
    stub_list(two_hundred_fifty_names) do
      get "/pokemons", q: "pokemon"
    end

    assert last_response.ok?
    assert_equal 36, last_response.body.scan('<li class="list-item">').size
    assert_equal 36, last_response.body.scan("hx-get=\"/pokemon/").size
    assert_equal 36, last_response.body.scan("<img src=").size
    assert_equal 36, last_response.body.scan('name="pokeName"').size
    assert_includes last_response.body, 'hx-post="/team"'
    assert_includes last_response.body, "Página 1"
    refute_includes last_response.body, 'id="filter-controls"'
    refute_includes last_response.body, 'hx-swap-oob="innerHTML"'
    refute_includes last_response.body, "<html"
  end # rubocop:enable Metrics/AbcSize

  def test_pokemons_add_buttons_use_pt_br_copy
    stub_list(two_hundred_fifty_names) do
      get "/pokemons", q: "pokemon"
    end

    assert last_response.ok?
    assert_equal 36, last_response.body.scan("Adicionar ao time").size
  end

  def test_pokemons_add_button_shows_in_team_when_pokemon_in_team
    add_team("user-a", [["pikachu", 25]])

    stub_list(filtered_names) do
      get "/pokemons", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "No time ✓"
    assert_match(/disabled="disabled"[^>]*>\s*No time ✓/, last_response.body)
    assert_includes last_response.body, "Adicionar ao time"
  end

  def test_pokemons_add_buttons_disabled_when_team_full
    add_team("user-a", [["pikachu", 25], ["bulbasaur", 1], ["charmander", 4],
                        ["squirtle", 7], ["caterpie", 10], ["weedle", 13]])

    stub_list(two_hundred_fifty_names) do
      get "/pokemons", {}, user_session("user-a")
    end

    assert last_response.ok?
    total_buttons = last_response.body.scan("<button").size
    disabled_buttons = last_response.body.scan('disabled="disabled"').size
    assert_equal total_buttons, disabled_buttons
  end

  def test_pokemons_omits_evolved_forms_from_list
    stub_list(filtered_names, evolved: ["raichu"]) do
      get "/pokemons"
    end

    assert last_response.ok?
    refute_includes last_response.body, 'value="raichu"'
    assert_includes last_response.body, 'value="pikachu"'
    assert_equal 3, last_response.body.scan('<li class="list-item">').size
  end

  def test_pokemons_excludes_starters_from_pool_list
    stub_list(filtered_names) { get "/pokemons" }

    assert last_response.ok?
    assert_equal 27, last_response.body.scan('<li class="starter-item">').size
    assert_equal 4, last_response.body.scan('<li class="list-item">').size
    assert_equal 1, last_response.body.scan('value="bulbasaur"').size
  end

  def test_pokemons_highlights_starters_block_when_q_empty
    stub_list(filtered_names) { get "/pokemons" }

    assert last_response.ok?
    assert_equal 27, last_response.body.scan('<li class="starter-item">').size
    ALL_STARTERS.each do |slug|
      assert_includes last_response.body, "value=\"#{slug}\""
    end
  end

  def test_starters_block_hidden_when_filtering
    stub_list(filtered_names) do
      get "/pokemons", q: "pik"
    end

    assert last_response.ok?
    refute_includes last_response.body, '<li class="starter-item">'
  end

  def test_pokemons_first_page_has_no_previous_link
    stub_list(two_hundred_fifty_names) { get "/pokemons" }

    assert last_response.ok?
    refute_includes last_response.body, ">Anterior<"
  end

  def test_pokemons_starters_only_on_first_page
    stub_list(two_hundred_fifty_names) do
      get "/pokemons", offset: 9
    end

    assert last_response.ok?
    refute_includes last_response.body, "Iniciais"
    assert_empty last_response.body.scan('<li class="starter-item">')
    assert_equal 36, last_response.body.scan('<li class="list-item">').size
    assert_includes last_response.body, "Página 2"
  end

  def test_pokemons_middle_page_has_previous_and_next_links
    stub_list(two_hundred_fifty_names) do
      get "/pokemons", offset: 9
    end

    assert last_response.ok?
    assert_includes last_response.body, "offset=0"
    assert_includes last_response.body, "offset=45"
    assert_includes last_response.body, "Página 2"
    assert_includes last_response.body, ">Anterior<"
    assert_includes last_response.body, ">Próxima<"
  end

  def test_pokemons_last_page_has_no_next_link
    stub_list(two_hundred_fifty_names) do
      get "/pokemons", offset: 225
    end

    assert last_response.ok?
    assert_includes last_response.body, "Página 8"
    refute_includes last_response.body, ">Próxima<"
    assert_includes last_response.body, ">Anterior<"
  end

  def test_pokemons_filters_by_substring_case_insensitive
    stub_list(filtered_names) do
      get "/pokemons", q: "PIK"
    end

    assert last_response.ok?
    assert_equal 2, last_response.body.scan('<li class="list-item">').size
    refute_includes last_response.body, 'value="bulbasaur"'
    assert_includes last_response.body, "Página 1"
    refute_includes last_response.body, ">Próxima<"
  end

  def test_pokemons_filter_without_matches_renders_empty_list
    stub_list(filtered_names) do
      get "/pokemons", q: "zzzz"
    end

    assert last_response.ok?
    assert_empty last_response.body.scan('<li class="list-item">')
    refute_includes last_response.body, 'id="filter-controls"'
    refute_includes last_response.body, 'hx-swap-oob="innerHTML"'
    refute_includes last_response.body, 'value="pikachu"'
  end

  def test_pokemons_empty_q_returns_full_list
    stub_list(filtered_names) do
      get "/pokemons", q: ""
    end

    assert last_response.ok?
    %w[pikachu pichu raichu pikachu-alola bulbasaur].each do |name|
      assert_includes last_response.body, "value=\"#{name}\""
    end
  end

  def test_pokemons_paginates_filtered_results
    stub_list(filtered_names) do
      get "/pokemons", q: "i"
    end

    assert last_response.ok?
    assert_equal 4, last_response.body.scan('<li class="list-item">').size
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

class ServerPokemonSearchHintTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_search_non_base_shows_evolution_hint
    names = %w[pikachu pichu raichu bulbasaur]
    forms = { "pikachu" => false, "pichu" => true, "raichu" => false, "bulbasaur" => true }
    pikachu = Pokemon.new(
      name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25,
      evolutions: [build_pokemon_record("pichu", 172), build_pokemon_record("pikachu", 25)]
    )
    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_base_forms(forms) do
        PokeApiStub.with_detail({ "pikachu" => pikachu }) do
          get "/pokemons", { q: "pika" }, user_session("user-a")
        end
      end
    end

    assert last_response.ok?
    assert_match(/evolução de "pichu"/i, last_response.body)
    assert_match(/monte/i, last_response.body)
  end

  def test_search_starter_shows_starter_hint
    names = %w[charmander charmeleon charizard]
    forms = { "charmander" => true, "charmeleon" => false, "charizard" => false }
    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_base_forms(forms) do
        get "/pokemons", { q: "char" }, user_session("user-a")
      end
    end

    assert last_response.ok?
    assert_match(/charmander/i, last_response.body)
    assert_match(/inicial/i, last_response.body)
  end

  def test_search_base_form_lists_without_hint
    names = %w[pikachu pichu raichu]
    forms = { "pikachu" => false, "pichu" => true, "raichu" => false }
    records = { "pichu" => build_pokemon_record("pichu", 172) }
    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_find(records) do
        PokeApiStub.with_base_forms(forms) do
          get "/pokemons", { q: "pich" }, user_session("user-a")
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "pichu"
    refute_match(/evolução de/i, last_response.body)
  end
end
