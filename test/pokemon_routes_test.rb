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
    assert_equal 20, last_response.body.scan('<li class="list-item">').size
    assert_includes last_response.body, 'name="q"'
    assert_includes last_response.body, "Página 1 de 13"
    refute_dropdown_markup(last_response.body)
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
    stub_list(two_hundred_fifty_names) { get "/pokemons" }

    refute_includes last_response.body, "<html"
    refute_includes last_response.body, "<head>"
    assert_includes last_response.body, 'class="pokemon-list"'

    @repository.add("user-a", pikachu_pokemon)
    get "/team", {}, user_session("user-a")

    refute_includes last_response.body, "<html"
    refute_includes last_response.body, "<head>"
    assert_includes last_response.body, "Remove from Team"
  end

  def test_pokemons_list_images_are_lazy
    stub_list(two_hundred_fifty_names) do
      get "/pokemons", q: "pokemon"
    end

    assert last_response.ok?
    assert_equal 20, last_response.body.scan('loading="lazy"').size
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

  def test_pokemons_renders_clickable_list
    stub_list(two_hundred_fifty_names) do
      get "/pokemons", q: "pokemon"
    end

    assert last_response.ok?
    assert_equal 20, last_response.body.scan('<li class="list-item">').size
    assert_equal 20, last_response.body.scan("hx-get=\"/pokemon/").size
    assert_equal 20, last_response.body.scan("<img src=").size
    assert_equal 20, last_response.body.scan('name="pokeName"').size
    assert_includes last_response.body, 'hx-post="/team"'
    assert_includes last_response.body, "Página 1 de 13"
    refute_dropdown_markup(last_response.body)
    refute_includes last_response.body, "<html"
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
    assert_includes last_response.body, "Iniciais"
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
    refute_includes last_response.body, "Iniciais"
    refute_includes last_response.body, '<li class="starter-item">'
  end

  def test_pokemons_first_page_has_no_previous_link
    stub_list(two_hundred_fifty_names) { get "/pokemons" }

    assert last_response.ok?
    refute_includes last_response.body, ">Anterior<"
  end

  def test_pokemons_middle_page_has_previous_and_next_links
    stub_list(two_hundred_fifty_names) do
      get "/pokemons", offset: 20
    end

    assert last_response.ok?
    assert_includes last_response.body, "offset=0"
    assert_includes last_response.body, "offset=40"
    assert_includes last_response.body, "Página 2 de 13"
    assert_includes last_response.body, ">Anterior<"
    assert_includes last_response.body, ">Próxima<"
  end

  def test_pokemons_last_page_has_no_next_link
    stub_list(two_hundred_fifty_names) do
      get "/pokemons", offset: 240
    end

    assert last_response.ok?
    assert_includes last_response.body, "Página 13 de 13"
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
    assert_includes last_response.body, "Página 1 de 1"
    refute_includes last_response.body, ">Próxima<"
  end

  def test_pokemons_filter_without_matches_renders_empty_list
    stub_list(filtered_names) do
      get "/pokemons", q: "zzzz"
    end

    assert last_response.ok?
    assert_empty last_response.body.scan('<li class="list-item">')
    refute_includes last_response.body, "<select"
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
