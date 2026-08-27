# frozen_string_literal: true

require_relative "server_test_helpers"

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/HashAlignment, Metrics/ClassLength
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

  # rubocop:disable Metrics/MethodLength
  def stub_list(names, find_map: nil, detail_map: nil, types_map: {}, generation_map: {}, rating_map: {},
                restricted_map: {}, &block)
    forms = names.to_h { |name| [name, true] }
    rating = rating_map
    fmap = find_map || names.to_h do |name|
      [name, build_record(name, 100 + names.index(name), types: types_map[name] || [])]
    end
    dmap = detail_map || fmap
    # derive type -> names index for pokemon_names_by_type endpoint (simula /type/:name)
    type_names_map = {}
    types_map.each do |name, tys|
      Array(tys).each do |t|
        key = t.to_s.strip.downcase
        (type_names_map[key] ||= []) << name
      end
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
    with_detail = proc do |inner|
      PokeApiStub.with_detail(dmap) { inner.call }
    end
    with_type_names = proc do |inner|
      PokeApiStub.with_pokemon_names_by_type(type_names_map) { inner.call }
    end
    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_find(fmap) do
        PokeApiStub.with_base_forms(forms) do
          with_detail.call(proc do
            with_type_names.call(proc do
              with_generation.call(proc do
                with_restricted.call(proc do
                  with_rating(rating, &block)
                end)
              end)
            end)
          end)
        end
      end
    end
  end
  # rubocop:enable Metrics/MethodLength

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

  def test_ordering_by_cost_and_tier_sorts_before_pagination
    names = %w[charmander squirtle bulbasaur pikachu]
    # tier costs: F 20, A 70, B 55, S 120
    rating = { "charmander" => "F", "squirtle" => "C", "bulbasaur" => "B", "pikachu" => "S" }
    find_map = names.to_h { |n| [n, build_record(n, 1)] }
    # cost_asc: F(20) < C(40) < B(55) < S(120)
    stub_list(names, find_map: find_map, rating_map: rating) do
      get "/pokemons", sort: "cost_asc"
    end
    assert last_response.ok?
    body = last_response.body
    idx_charm = body.index('value="charmander"')
    idx_squirt = body.index('value="squirtle"')
    idx_bulba = body.index('value="bulbasaur"')
    idx_pika = body.index('value="pikachu"')
    assert idx_charm < idx_squirt
    assert idx_squirt < idx_bulba
    assert idx_bulba < idx_pika

    # tier_desc S->F : S, B, C, F
    stub_list(names, find_map: find_map, rating_map: rating) do
      get "/pokemons", sort: "tier_desc"
    end
    assert last_response.ok?
    body = last_response.body
    assert body.index('value="pikachu"') < body.index('value="bulbasaur"')
    assert body.index('value="bulbasaur"') < body.index('value="squirtle"')
    assert body.index('value="squirtle"') < body.index('value="charmander"')
  end

  def test_filters_persisted_in_session
    names = %w[charmander squirtle bulbasaur]
    types = { "charmander" => %w[fire], "squirtle" => %w[water], "bulbasaur" => %w[grass] }
    generation = { "charmander" => 1, "squirtle" => 1, "bulbasaur" => 1 }
    rating = { "charmander" => "F", "squirtle" => "A", "bulbasaur" => "B" }
    find_map = names.to_h { |n| [n, build_record(n, 1, types: types[n])] }
    stub_list(names, find_map: find_map, types_map: types, generation_map: generation,
              rating_map: rating) do
      get "/pokemons", type: "fire", sort: "cost_desc"
      assert last_response.ok?
      assert_includes last_response.body, 'value="charmander"'
      # second request without params should restore via session
      get "/pokemons"
      assert last_response.ok?
      assert_includes last_response.body, 'value="charmander"'
      refute_includes last_response.body, 'value="squirtle"'
      # limpar zera
      get "/pokemons", type: "", generation: "", tier: "", cost_max: "", cost: "", sort: "", q: "", offset: "0"
      assert last_response.ok?
      assert_includes last_response.body, 'value="squirtle"'
      # after clear, second request without params should NOT restore
      get "/pokemons"
      assert last_response.ok?
      assert_includes last_response.body, 'value="squirtle"'
      assert_includes last_response.body, 'value="charmander"'
    end
  end

  def test_pagination_preserves_sort
    many = (1..50).map { |i| "pokemon#{i}" }
    # assign tiers to create predictable cost order
    rating = many.to_h { |n| [n, "F"] }
    rating["pokemon1"] = "S"
    rating["pokemon2"] = "A"
    find_map = many.to_h { |n| [n, build_record(n, n.scan(/\d+/).first.to_i)] }
    stub_list(many, find_map: find_map, rating_map: rating) do
      get "/pokemons", sort: "cost_desc", offset: "0"
      assert last_response.ok?
      assert_includes last_response.body, "Página 1"
      # next page link should preserve sort
      assert_includes last_response.body, "sort=cost_desc"
      get "/pokemons", sort: "cost_desc", offset: "36"
      assert last_response.ok?
      assert_includes last_response.body, "Página 2"
    end
  end

  def test_pagination_with_filters_and_search_preserved
    names = (1..50).map { |i| "pokemon#{i}" } + %w[charmander charmeleon]
    types = { "charmander" => %w[fire], "charmeleon" => %w[fire] }
    names.each { |n| types[n] ||= %w[normal] }
    rating = {}
    find_map = names.to_h { |n| [n, build_record(n, 1, types: types[n] || %w[normal])] }
    stub_list(names, find_map: find_map, types_map: types, rating_map: rating) do
      get "/pokemons", type: "fire", q: "char", offset: "0"
      assert last_response.ok?
      assert_includes last_response.body, 'value="charmander"'
      assert_includes last_response.body, 'value="charmeleon"'
      assert_includes last_response.body, "Página 1"
    end
  end

  def test_oob_after_add_preserves_filters_and_sort
    names = %w[charmander squirtle bulbasaur pikachu]
    types = {
      "charmander" => %w[fire], "squirtle" => %w[water],
      "bulbasaur" => %w[grass], "pikachu" => %w[electric]
    }
    find_map = names.to_h { |n| [n, build_record(n, 1, types: types[n])] }
    rating = { "charmander" => "F", "squirtle" => "C", "bulbasaur" => "B", "pikachu" => "S" }
    # first set filter via session
    stub_list(names, find_map: find_map, types_map: types, rating_map: rating) do
      get "/pokemons", type: "fire", sort: "cost_desc"
      assert_includes last_response.body, 'value="charmander"'
      # POST add should OOB preserve filter (via session + params)
      post "/team",
           { pokeName: "charmander", offset: "0", q: "", type: "fire", sort: "cost_desc" },
           { "HTTP_HX_REQUEST" => "true", "rack.session" => { "user_id" => "user-a" } }
      # response includes oob pokemon-list
      assert last_response.ok?
      assert_includes last_response.body, 'id="pokemon-list"'
      # after add, filtered list still only fire
      assert_includes last_response.body, 'value="charmander"'
      refute_includes last_response.body, 'value="squirtle"'
    end
  end

  def test_pagination_follows_next_offset_with_filter_and_sort
    many = (1..80).map { |i| "pokemon#{i}" }
    types = many.to_h { |n| [n, %w[fire]] }
    rating = many.to_h { |n| [n, "F"] }
    rating["pokemon1"] = "S"
    rating["pokemon2"] = "A"
    find_map = many.to_h { |n| [n, build_record(n, n.scan(/\d+/).first.to_i, types: %w[fire])] }
    stub_list(many, find_map: find_map, types_map: types, rating_map: rating) do
      get "/pokemons", type: "fire", offset: "0"
      assert last_response.ok?
      assert_includes last_response.body, "Página 1"
      # next_offset must be PAGE_SIZE (36) not FIRST_PAGE_COMMONS (9) when filter active
      refute_includes last_response.body, 'offset=9"'
      assert_includes last_response.body, "offset=36"
      next_offset = last_response.body[%r{hx-get="/pokemons\?offset=(\d+)}, 1]
      assert_equal "36", next_offset
      get "/pokemons", type: "fire", offset: next_offset
      assert last_response.ok?
      assert_includes last_response.body, "Página 2"
      assert_includes last_response.body, "offset=0"
      assert_includes last_response.body, "offset=72"

      # sort active also uses PAGE_SIZE
      get "/pokemons", sort: "cost_desc", offset: "0"
      assert last_response.ok?
      assert_includes last_response.body, "Página 1"
      next_sorted = last_response.body[%r{hx-get="/pokemons\?offset=(\d+)}, 1]
      assert_equal "36", next_sorted
      get "/pokemons", sort: "cost_desc", offset: next_sorted
      assert last_response.ok?
      assert_includes last_response.body, "Página 2"

      # without filter/sort, first page still uses FIRST_PAGE_COMMONS (clear session first)
      get "/pokemons", type: "", generation: "", tier: "", cost_max: "", cost: "", sort: "", q: "", offset: "0"
      get "/pokemons", offset: "0"
      assert last_response.ok?
      first_next = last_response.body[%r{hx-get="/pokemons\?offset=(\d+)}, 1]
      assert_equal "9", first_next
    end
  end

  def test_oob_after_remove_preserves_filters_and_sort
    names = %w[charmander squirtle bulbasaur pikachu]
    types = {
      "charmander" => %w[fire], "squirtle" => %w[water],
      "bulbasaur" => %w[grass], "pikachu" => %w[electric]
    }
    find_map = names.to_h { |n| [n, build_record(n, 1, types: types[n])] }
    rating = { "charmander" => "F", "squirtle" => "C", "bulbasaur" => "B", "pikachu" => "S" }
    stub_list(names, find_map: find_map, types_map: types, rating_map: rating) do
      get "/pokemons", type: "fire", sort: "cost_desc"
      assert_includes last_response.body, 'value="charmander"'
      poke = build_pokemon_record("pikachu", 25)
      @repository.add("user-a", poke)
      id = @repository.all("user-a").first.id
      delete "/team",
             { id: id, offset: "0", q: "", type: "fire", sort: "cost_desc" },
             { "HTTP_HX_REQUEST" => "true", "rack.session" => { "user_id" => "user-a" } }
      assert last_response.ok?
      assert_includes last_response.body, 'id="pokemon-list"'
      assert_includes last_response.body, "hx-swap-oob"
      assert_includes last_response.body, 'value="charmander"'
      refute_includes last_response.body, 'value="squirtle"'
      # sort and type preserved in OOB hidden inputs (pagination link absent when single page)
      assert_includes last_response.body, 'name="type" value="fire"'
      assert_includes last_response.body, 'name="sort" value="cost_desc"'
    end
  end

  def test_without_network
    names = %w[eevee vaporeon jolteon]
    eevee_base = build_record("eevee", 133)
    vaporeon = build_record("vaporeon", 134)
    jolteon = build_record("jolteon", 135)
    eevee = Pokemon.new(
      name: "eevee", sprite: "s", number: 133,
      evolutions: [eevee_base, vaporeon, jolteon].freeze
    )
    rating = { "eevee" => "F", "vaporeon" => "A", "jolteon" => "S" }
    find_map = { "eevee" => eevee, "vaporeon" => vaporeon, "jolteon" => jolteon }
    forms = { "eevee" => true, "vaporeon" => false, "jolteon" => false }
    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_find(find_map) do
        PokeApiStub.with_base_forms(forms) do
          with_rating(rating) do
            get "/pokemons", tier: "S"
          end
        end
      end
    end
    assert last_response.ok?
    assert_includes last_response.body, 'value="eevee"'
  end

  def test_filters_by_type_via_endpoint_when_find_has_no_types
    # Simula PokeApiHttp real: find retorna Pokemon minimal sem types (vazio)
    names = %w[geodude onix pikachu]
    # find minimal (sem types) — reproduz bug de find sem types
    find_minimal = names.to_h { |n| [n, build_record(n, 1, types: [])] }
    # endpoint /type/rock lista apenas geodude e onix
    type_names = { "rock" => %w[geodude onix] }
    detail_map = names.to_h { |n| [n, build_record(n, 1, types: n == "pikachu" ? %w[electric] : %w[rock ground])] }
    forms = names.to_h { |n| [n, true] }
    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_find(find_minimal) do
        PokeApiStub.with_detail(detail_map) do
          PokeApiStub.with_base_forms(forms) do
            PokeApiStub.with_pokemon_names_by_type(type_names) do
              get "/pokemons", type: "rock"
              assert last_response.ok?
              assert_includes last_response.body, 'value="geodude"'
              assert_includes last_response.body, 'value="onix"'
              refute_includes last_response.body, 'value="pikachu"'
              # prova que find minimal sozinho falharia, mas endpoint corrige
            end
          end
        end
      end
    end
  end

  def test_tier_filter_uses_detail_for_evolutions_when_find_minimal
    # find minimal tem evolutions vazio, detail tem cadeia ramificada (eevee-like)
    names = %w[eevee]
    vaporeon = build_record("vaporeon", 134)
    jolteon = build_record("jolteon", 135)
    flareon = build_record("flareon", 136)
    eevee_base = build_record("eevee", 133)
    eevee_with_chain = Pokemon.new(
      name: "eevee", sprite: "s", number: 133,
      evolutions: [eevee_base, vaporeon, jolteon, flareon].freeze
    )
    eevee_minimal = build_record("eevee", 133, types: [])
    rating = { "eevee" => "F", "vaporeon" => "C", "jolteon" => "A", "flareon" => "S" }
    forms = { "eevee" => true }
    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_find("eevee" => eevee_minimal) do
        PokeApiStub.with_detail("eevee" => eevee_with_chain) do
          PokeApiStub.with_base_forms(forms) do
            PokeApiStub.with_pokemon_names_by_type({}) do
              with_rating(rating) do
                get "/pokemons", tier: "S"
                assert last_response.ok?
                assert_includes last_response.body, 'value="eevee"'
                get "/pokemons", tier: "F"
                assert last_response.ok?
                refute_includes last_response.body, 'value="eevee"'
              end
            end
          end
        end
      end
    end
  end

  def test_rock_type_with_large_pool_completes_quickly_via_endpoint
    # 1300 nomes stubados, apenas 3 rocks; sem endpoint levaria N finds, com endpoint faz interseção
    many = (1..1_300).map { |i| "pokemon#{i}" }
    rocks = %w[rock1 rock2 rock3]
    all_names = many + rocks
    find_minimal = all_names.to_h { |n| [n, build_record(n, 1, types: [])] }
    detail_map = find_minimal.dup
    type_names = { "rock" => rocks }
    forms = all_names.to_h { |n| [n, true] }
    start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    PokeApiStub.with_all_names(all_names) do
      PokeApiStub.with_find(find_minimal) do
        PokeApiStub.with_detail(detail_map) do
          PokeApiStub.with_base_forms(forms) do
            PokeApiStub.with_pokemon_names_by_type(type_names) do
              get "/pokemons", type: "rock"
              assert last_response.ok?
              rocks.each { |r| assert_includes last_response.body, "value=\"#{r}\"" }
              refute_includes last_response.body, 'value="pokemon1"'
            end
          end
        end
      end
    end
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
    assert_operator elapsed, :<, 1.0, "filtro rock com 1300 nomes deve resolver em <1s via endpoint (#{elapsed}s)"
  end

  def test_clear_filters_resets_dropdowns
    names = %w[geodude onix pikachu]
    types = {
      "geodude" => %w[rock ground],
      "onix" => %w[rock ground],
      "pikachu" => %w[electric]
    }
    generation = { "geodude" => 1, "onix" => 1, "pikachu" => 1 }
    rating = { "geodude" => "F", "onix" => "F", "pikachu" => "F" }
    find_map = names.to_h { |n| [n, build_record(n, 1, types: types[n])] }
    stub_list(names, find_map: find_map, types_map: types, generation_map: generation,
                   rating_map: rating) do
      get "/pokemons", type: "rock", generation: "1"
      assert last_response.ok?
      assert_includes last_response.body, 'id="filter-controls"'
      assert_includes last_response.body, 'hx-swap-oob="innerHTML"'
      assert_includes last_response.body, 'value="rock" selected'
      assert_match(/value="1" selected.*Gera..o 1/m, last_response.body)

      get "/pokemons", offset: "0", q: "", type: "", generation: "", tier: "", cost: "", cost_max: "", sort: ""
      assert last_response.ok?
      assert_includes last_response.body, 'id="filter-controls"'
      assert_includes last_response.body, 'hx-swap-oob="innerHTML"'
      assert_match(%r{<option value="" selected>Todos os tipos</option>}, last_response.body)
      assert_match(%r{<option value="" selected>Todas as gera..es</option>}, last_response.body)
      assert_match(%r{<option value="" selected>Todos os tiers</option>}, last_response.body)
      assert_match(%r{<option value="" selected>Qualquer custo</option>}, last_response.body)
      assert_match(%r{<option value="" selected>Padr.o</option>}, last_response.body)
      refute_includes last_response.body, 'value="rock" selected'
      refute_match(/value="1" selected.*Gera..o 1/m, last_response.body)
    end
  end

  def test_typing_q_does_not_swap_filter_controls
    names = %w[pikachu pichu bulbasaur]
    find_map = names.to_h { |n| [n, build_record(n, 1)] }
    stub_list(names, find_map: find_map) do
      get "/pokemons", q: "pi"
      assert last_response.ok?
      refute_includes last_response.body, 'id="filter-controls"'
      refute_includes last_response.body, 'hx-swap-oob="innerHTML"'
      assert_includes last_response.body, 'value="pikachu"'
    end
  end

  def test_clear_still_resets_filter_controls
    names = %w[geodude onix pikachu]
    types = {
      "geodude" => %w[rock ground],
      "onix" => %w[rock ground],
      "pikachu" => %w[electric]
    }
    generation = { "geodude" => 1, "onix" => 1, "pikachu" => 1 }
    rating = { "geodude" => "F", "onix" => "F", "pikachu" => "F" }
    find_map = names.to_h { |n| [n, build_record(n, 1, types: types[n])] }
    stub_list(names, find_map: find_map, types_map: types, generation_map: generation,
                   rating_map: rating) do
      get "/pokemons", offset: "0", q: "", type: "", generation: "", tier: "", cost: "", cost_max: "", sort: ""
      assert last_response.ok?
      assert_includes last_response.body, 'id="filter-controls"'
      assert_includes last_response.body, 'hx-swap-oob="innerHTML"'
      assert_match(%r{<option value="" selected>Todos os tipos</option>}, last_response.body)
    end
  end

  def test_pagination_does_not_swap_filter_controls
    names = %w[pikachu bulbasaur charmander squirtle]
    find_map = names.to_h { |n| [n, build_record(n, 1)] }
    stub_list(names, find_map: find_map) do
      get "/pokemons", offset: "36"
      assert last_response.ok?
      refute_includes last_response.body, 'id="filter-controls"'
      refute_includes last_response.body, 'hx-swap-oob="innerHTML"'
    end
  end
end
# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Layout/HashAlignment, Metrics/ClassLength
