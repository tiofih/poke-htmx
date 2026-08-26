# frozen_string_literal: true

require_relative "server_test_helpers"

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

  def stub_list(names, find_map: nil, types_map: {}, generation_map: {}, rating_map: {}, &block)
    forms = names.to_h { |name| [name, true] }
    rating = rating_map
    fmap = find_map || names.to_h do |name|
      [name, build_record(name, 100 + names.index(name), types: types_map[name] || [])]
    end
    generation = generation_map.empty? ? nil : generation_map
    if generation
      PokeApiStub.with_all_names(names) do
        PokeApiStub.with_find(fmap) do
          PokeApiStub.with_base_forms(forms) do
            PokeApiStub.with_generation(generation) do
              with_rating(rating, &block)
            end
          end
        end
      end
    else
      PokeApiStub.with_all_names(names) do
        PokeApiStub.with_find(fmap) do
          PokeApiStub.with_base_forms(forms) do
            with_rating(rating, &block)
          end
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
end
