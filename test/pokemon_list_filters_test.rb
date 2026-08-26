# frozen_string_literal: true

require_relative "server_test_helpers"

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/HashAlignment
class PokemonListFilterTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def setup
    super
    @default_rating = Server.settings.rating_source
  end

  def teardown
    Server.set :rating_source, @default_rating
    super
  end

  def with_rating(map, &)
    fake = Class.new do
      def initialize(map)
        @map = map
      end

      def rating_for(name)
        (@map[name.to_s] || "F").to_sym
      end
    end.new(map)
    original = Server.settings.rating_source
    Server.set :rating_source, fake
    yield
  ensure
    Server.set :rating_source, original
  end

  def build_record(name, number, types: [])
    Pokemon.new(name: name, sprite: "https://example.com/#{name}.png", number: number, types: types)
  end

  def stub_list(names, find_map: nil, types_map: {}, generation_map: {}, rating_map: {},
                restricted_map: {}, &block)
    forms = names.to_h { |name| [name, true] }
    rating = rating_map
    fmap = find_map || names.to_h do |name|
      [name, build_record(name, 100 + names.index(name), types: types_map[name] || [])]
    end
    generation = generation_map.empty? ? nil : generation_map
    restricted = restricted_map.empty? ? nil : restricted_map
    with_restricted = proc do |inner|
      if restricted
        PokeApiStub.with_gateway(evolution_restricted: restricted) { inner.call }
      else
        inner.call
      end
    end
    with_generation = proc do |inner|
      if generation
        PokeApiStub.with_generation(generation) { inner.call }
      else
        inner.call
      end
    end
    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_find(fmap) do
        PokeApiStub.with_base_forms(forms) do
          with_generation.call(proc do
            with_restricted.call(proc do
              with_rating(rating, &block)
            end)
          end)
        end
      end
    end
  end

  def test_filters_by_type
    names = %w[charmander squirtle bulbasaur pikachu]
    types = {
      "charmander" => %w[fire],
      "squirtle" => %w[water],
      "bulbasaur" => %w[grass poison],
      "pikachu" => %w[electric]
    }
    find_map = names.to_h { |n| [n, build_record(n, 1, types: types[n])] }
    stub_list(names, find_map: find_map, types_map: types) do
      get "/pokemons", type: "fire"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'value="charmander"'
    refute_includes last_response.body, 'value="squirtle"'
    refute_includes last_response.body, 'value="bulbasaur"'
    refute_includes last_response.body, 'value="pikachu"'
  end

  def test_filters_by_type_combined_with_search
    names = %w[charmander charmeleon charizard squirtle]
    types = {
      "charmander" => %w[fire],
      "charmeleon" => %w[fire],
      "charizard" => %w[fire flying],
      "squirtle" => %w[water]
    }
    find_map = names.to_h { |n| [n, build_record(n, 1, types: types[n])] }
    stub_list(names, find_map: find_map, types_map: types) do
      get "/pokemons", type: "fire", q: "char"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'value="charmander"'
    assert_includes last_response.body, 'value="charmeleon"'
    assert_includes last_response.body, 'value="charizard"'
    refute_includes last_response.body, 'value="squirtle"'
  end

  def test_filters_by_generation
    names = %w[bulbasaur chikorita treecko chimchar snivy chespin rowlet grookey sprigatito]
    generation = {
      "bulbasaur" => 1, "chikorita" => 2, "treecko" => 3, "chimchar" => 4,
      "snivy" => 5, "chespin" => 6, "rowlet" => 7, "grookey" => 8, "sprigatito" => 9
    }
    find_map = names.to_h { |n| [n, build_record(n, 1)] }
    stub_list(names, find_map: find_map, generation_map: generation) do
      get "/pokemons", generation: "1"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'value="bulbasaur"'
    refute_includes last_response.body, 'value="chikorita"'
    refute_includes last_response.body, 'value="treecko"'
  end

  def test_filters_combined_type_and_generation_with_search
    names = %w[charizard chimchar charmander]
    types = {
      "charizard" => %w[fire flying],
      "chimchar" => %w[fire],
      "charmander" => %w[fire]
    }
    generation = { "charizard" => 1, "chimchar" => 4, "charmander" => 1 }
    find_map = names.to_h { |n| [n, build_record(n, 1, types: types[n])] }
    stub_list(names, find_map: find_map, types_map: types, generation_map: generation) do
      get "/pokemons", type: "fire", generation: "1", q: "char"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'value="charizard"'
    assert_includes last_response.body, 'value="charmander"'
    refute_includes last_response.body, 'value="chimchar"'
  end

  def test_generation_filter_without_matches_renders_empty
    names = %w[bulbasaur chikorita]
    generation = { "bulbasaur" => 1, "chikorita" => 2 }
    find_map = names.to_h { |n| [n, build_record(n, 1)] }
    stub_list(names, find_map: find_map, generation_map: generation) do
      get "/pokemons", generation: "9"
    end

    assert last_response.ok?
    refute_includes last_response.body, 'value="bulbasaur"'
    refute_includes last_response.body, 'value="chikorita"'
    assert_empty last_response.body.scan('<li class="list-item">')
  end

  def test_filters_by_tier
    names = %w[pikachu bulbasaur charmander]
    rating = { "pikachu" => "S", "bulbasaur" => "A", "charmander" => "F" }
    find_map = names.to_h { |n| [n, build_record(n, 1)] }
    stub_list(names, find_map: find_map, rating_map: rating) do
      get "/pokemons", tier: "S"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'value="pikachu"'
    refute_includes last_response.body, 'value="bulbasaur"'
    refute_includes last_response.body, 'value="charmander"'
  end

  def test_filters_by_cost
    names = %w[pikachu bulbasaur charmander]
    # S 120, A 70, F 20
    rating = { "pikachu" => "S", "bulbasaur" => "A", "charmander" => "F" }
    find_map = names.to_h { |n| [n, build_record(n, 1)] }
    stub_list(names, find_map: find_map, rating_map: rating) do
      get "/pokemons", cost_max: "55"
    end

    assert last_response.ok?
    # F 20 stays, S 120 and A 70 filtered out
    assert_includes last_response.body, 'value="charmander"'
    refute_includes last_response.body, 'value="pikachu"'
    refute_includes last_response.body, 'value="bulbasaur"'
  end

  def test_filter_cost_uses_line_tier_and_restricted_half
    vaporeon = build_record("vaporeon", 134)
    jolteon = build_record("jolteon", 135)
    flareon = build_record("flareon", 136)
    espeon = build_record("espeon", 196)
    eevee_base = build_record("eevee", 133)
    eevee = Pokemon.new(
      name: "eevee", sprite: "https://example.com/eevee.png", number: 133,
      types: [], evolutions: [eevee_base, vaporeon, jolteon, flareon, espeon].freeze
    )
    all_names = %w[eevee vaporeon jolteon flareon espeon]
    rating = { "vaporeon" => "C", "jolteon" => "A", "flareon" => "S", "espeon" => "B", "eevee" => "F" }
    find_map = {
      "eevee" => eevee, "vaporeon" => vaporeon, "jolteon" => jolteon,
      "flareon" => flareon, "espeon" => espeon
    }
    # eevee chain max S = 120, but restricted => 60, so cost_max 60 includes, cost_max 59 excludes
    stub_list(all_names, find_map: find_map, rating_map: rating,
              restricted_map: { "eevee" => true }) do
      get "/pokemons", cost_max: "60"
    end
    assert last_response.ok?
    assert_includes last_response.body, 'value="eevee"'

    stub_list(all_names, find_map: find_map, rating_map: rating,
              restricted_map: { "eevee" => true }) do
      get "/pokemons", cost_max: "59"
    end
    assert last_response.ok?
    refute_includes last_response.body, 'value="eevee"'

    # also tier filter uses line_tier max S even when restricted
    stub_list(all_names, find_map: find_map, rating_map: rating,
              restricted_map: { "eevee" => true }) do
      get "/pokemons", tier: "S"
    end
    assert last_response.ok?
    assert_includes last_response.body, 'value="eevee"'

    stub_list(all_names, find_map: find_map, rating_map: rating,
              restricted_map: { "eevee" => true }) do
      get "/pokemons", tier: "A"
    end
    assert last_response.ok?
    refute_includes last_response.body, 'value="eevee"'
  end

  def test_filters_combined_tier_cost_type_generation
    names = %w[charmander squirtle bulbasaur pikachu]
    types = {
      "charmander" => %w[fire], "squirtle" => %w[water],
      "bulbasaur" => %w[grass poison], "pikachu" => %w[electric]
    }
    generation = { "charmander" => 1, "squirtle" => 1, "bulbasaur" => 1, "pikachu" => 1 }
    rating = { "charmander" => "A", "squirtle" => "A", "bulbasaur" => "B", "pikachu" => "B" }
    # A 70, B 55, so cost_max 60 leaves only B's
    find_map = names.to_h { |n| [n, build_record(n, 1, types: types[n])] }
    stub_list(names, find_map: find_map, types_map: types, generation_map: generation,
              rating_map: rating) do
      get "/pokemons", type: "grass", generation: "1", tier: "B", cost_max: "60", q: "bulba"
    end
    assert last_response.ok?
    assert_includes last_response.body, 'value="bulbasaur"'
    refute_includes last_response.body, 'value="charmander"'
    refute_includes last_response.body, 'value="squirtle"'
    refute_includes last_response.body, 'value="pikachu"'
  end

  def test_clear_filters_button_resets_list
    names = %w[pikachu bulbasaur charmander]
    types = { "pikachu" => %w[electric], "bulbasaur" => %w[grass], "charmander" => %w[fire] }
    generation = { "pikachu" => 1, "bulbasaur" => 1, "charmander" => 1 }
    rating = { "pikachu" => "S", "bulbasaur" => "A", "charmander" => "F" }
    find_map = names.to_h { |n| [n, build_record(n, 1, types: types[n])] }
    stub_list(names, find_map: find_map, types_map: types, generation_map: generation,
              rating_map: rating) do
      get "/pokemons", type: "fire"
    end
    assert last_response.ok?
    assert_includes last_response.body, 'value="charmander"'
    refute_includes last_response.body, 'value="pikachu"'
    # botao limpar existe na pagina /
    stub_list(names, find_map: find_map, types_map: types, generation_map: generation,
              rating_map: rating) do
      get "/"
    end
    assert_includes last_response.body, "Limpar filtros"
    assert_includes last_response.body, 'hx-get="/pokemons?offset=0'
    # limpar -> sem filtros volta todos
    stub_list(names, find_map: find_map, types_map: types, generation_map: generation,
              rating_map: rating) do
      get "/pokemons", type: "", generation: "", tier: "", cost_max: "", q: ""
    end
    assert last_response.ok?
    assert_includes last_response.body, 'value="pikachu"'
    assert_includes last_response.body, 'value="bulbasaur"'
    assert_includes last_response.body, 'value="charmander"'
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/HashAlignment
