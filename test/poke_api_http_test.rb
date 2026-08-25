# frozen_string_literal: true

require "tmpdir"
require_relative "test_helper"
require_relative "../lib/gateways/poke_api_http"

class PokeApiHttpTest < Minitest::Test
  def setup
    @api = PokeApiHttp.new
  end

  def test_find_builds_pokemon_from_api_response
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) do |_url|
      Struct.new(:status, :body).new(
        200,
        JSON.generate("name" => "pikachu", "sprites" => { "front_default" => "sprite" }, "id" => 25)
      )
    end

    pokemon = @api.find("pikachu")

    assert_equal 25, pokemon.number
    assert_equal "pikachu", pokemon.name
    assert_equal "sprite", pokemon.sprite
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_detail_tolerates_null_sprite
    @api.define_singleton_method(:pokemon_data) do |_id|
      { "name" => "offender", "sprites" => { "front_default" => nil }, "id" => 999,
        "types" => [], "stats" => [], "species" => { "url" => "https://pokeapi.co/999" } }
    end
    @api.define_singleton_method(:evolution_chain) { |_url| [] }

    pokemon = @api.detail(999)

    assert_equal "", pokemon.sprite
    assert_equal "offender", pokemon.name
    assert_equal 999, pokemon.number
  end

  def test_moves_for_returns_last_four_moves
    @api.define_singleton_method(:pokemon_data) do |_number|
      { "moves" => %w[m1 m2 m3 m4 m5 m6].map { |name| { "move" => { "name" => name } } } }
    end
    @api.define_singleton_method(:move) do |name|
      Move.new(name: name, type: "normal", power: 40, accuracy: 100, pp: 35)
    end

    moves = @api.moves_for(25)

    assert_equal %w[m3 m4 m5 m6], moves.map(&:name)
  end

  def setup_next_evolutions_stubs(pokemon_data:, chain_json:, find_map: {})
    @api.define_singleton_method(:pokemon_data) { |_number| pokemon_data }
    @api.define_singleton_method(:find) do |name|
      map = find_map[name]
      map ? Pokemon.new(name: name, sprite: "", number: map) : nil
    end
    @original_faraday = Faraday.method(:get)
    Faraday.define_singleton_method(:get) do |url|
      if url.include?("pokemon-species") || url.include?("evolution-chain")
        Struct.new(:status, :body).new(200, JSON.generate(chain_json))
      else
        Struct.new(:status, :body).new(404, "")
      end
    end
  end

  def teardown
    Faraday.define_singleton_method(:get, @original_faraday) if defined?(@original_faraday) && @original_faraday
  end

  def test_next_evolutions_returns_level_up_stages_only
    setup_next_evolutions_stubs(
      pokemon_data: {
        "species" => { "url" => "https://pokeapi.co/api/v2/pokemon-species/4/" },
        "name" => "charmander"
      },
      chain_json: {
        "evolution_chain" => { "url" => "https://pokeapi.co/api/v2/evolution-chain/2/" },
        "chain" => {
          "species" => { "name" => "charmander" },
          "evolves_to" => [{
            "species" => { "name" => "charmeleon" },
            "evolution_details" => [{ "trigger" => { "name" => "level-up" }, "min_level" => 16 }],
            "evolves_to" => [{
              "species" => { "name" => "charizard" },
              "evolution_details" => [{ "trigger" => { "name" => "level-up" }, "min_level" => 36 }],
              "evolves_to" => []
            }]
          }]
        }
      },
      find_map: { "charmeleon" => 5, "charizard" => 6 }
    )

    result = @api.next_evolutions(4)

    assert_equal 1, result.size
    assert_equal 5, result.first[:number]
    assert_equal "charmeleon", result.first[:name]
    assert_equal 16, result.first[:min_level]
  end

  def test_next_evolutions_returns_empty_for_non_level_up_triggers
    setup_next_evolutions_stubs(
      pokemon_data: { "species" => { "url" => "https://pokeapi.co/api/v2/pokemon-species/133/" }, "name" => "eevee" },
      chain_json: {
        "evolution_chain" => { "url" => "https://pokeapi.co/api/v2/evolution-chain/67/" },
        "chain" => {
          "species" => { "name" => "eevee" },
          "evolves_to" => [
            { "species" => { "name" => "vaporeon" },
              "evolution_details" => [{ "trigger" => { "name" => "use-item" } }], "evolves_to" => [] },
            { "species" => { "name" => "jolteon" },
              "evolution_details" => [{ "trigger" => { "name" => "use-item" } }], "evolves_to" => [] }
          ]
        }
      },
      find_map: { "vaporeon" => 134, "jolteon" => 135 }
    )

    result = @api.next_evolutions(133)

    assert_equal [], result
  end

  def test_next_evolutions_returns_empty_when_no_evolution
    setup_next_evolutions_stubs(
      pokemon_data: { "species" => { "url" => "https://pokeapi.co/api/v2/pokemon-species/150/" }, "name" => "mewtwo" },
      chain_json: {
        "evolution_chain" => { "url" => "https://pokeapi.co/api/v2/evolution-chain/77/" },
        "chain" => {
          "species" => { "name" => "mewtwo" },
          "evolves_to" => []
        }
      },
      find_map: {}
    )

    result = @api.next_evolutions(150)

    assert_equal [], result
  end

  def test_next_evolutions_returns_empty_when_pokemon_data_nil
    @api.define_singleton_method(:pokemon_data) { |_number| nil }

    result = @api.next_evolutions(999)

    assert_equal [], result
  end

  def test_next_evolutions_returns_empty_on_faraday_error
    @api.define_singleton_method(:pokemon_data) do |_number|
      { "species" => { "url" => "https://pokeapi.co/api/v2/pokemon-species/4/" }, "name" => "charmander" }
    end
    @original_faraday = Faraday.method(:get)
    Faraday.define_singleton_method(:get) { |_url| raise Faraday::ConnectionFailed, "timeout" }

    result = @api.next_evolutions(4)

    assert_equal [], result
  ensure
    Faraday.define_singleton_method(:get, @original_faraday)
  end

  def test_learnable_moves_returns_level_up_moves_with_min_level_per_move
    @api.define_singleton_method(:pokemon_data) do |_number|
      {
        "moves" => [
          {
            "move" => { "name" => "thunder-shock" },
            "version_group_details" => [
              { "level_learned_at" => 1, "move_learn_method" => { "name" => "level-up" } },
              { "level_learned_at" => 0, "move_learn_method" => { "name" => "egg" } }
            ]
          },
          {
            "move" => { "name" => "quick-attack" },
            "version_group_details" => [
              { "level_learned_at" => 0, "move_learn_method" => { "name" => "tutor" } }
            ]
          },
          {
            "move" => { "name" => "thunderbolt" },
            "version_group_details" => [
              { "level_learned_at" => 26, "move_learn_method" => { "name" => "level-up" } },
              { "level_learned_at" => 30, "move_learn_method" => { "name" => "level-up" } }
            ]
          }
        ]
      }
    end

    result = @api.learnable_moves(25)

    assert_equal 2, result.size
    assert_equal({ level: 1, name: "thunder-shock" }, result.first)
    assert_equal({ level: 26, name: "thunderbolt" }, result.last)
  end

  def test_learnable_moves_returns_empty_when_pokemon_data_nil
    @api.define_singleton_method(:pokemon_data) { |_number| nil }

    result = @api.learnable_moves(999)

    assert_equal [], result
  end

  def test_learnable_moves_excludes_machine_and_tutor_methods
    @api.define_singleton_method(:pokemon_data) do |_number|
      {
        "moves" => [
          {
            "move" => { "name" => "water-gun" },
            "version_group_details" => [
              { "level_learned_at" => 0, "move_learn_method" => { "name" => "machine" } }
            ]
          }
        ]
      }
    end

    result = @api.learnable_moves(7)

    assert_equal [], result
  end

  def test_with_cache_path_serves_find_without_network
    Dir.mktmpdir do |dir|
      path = File.join(dir, "cache.json")
      api = PokeApiHttp.new(cache_path: path)
      Faraday.define_singleton_method(:get) do |_url|
        Struct.new(:status, :body).new(
          200,
          JSON.generate("name" => "pikachu", "sprites" => { "front_default" => "s" }, "id" => 25)
        )
      end

      assert_equal 25, api.find("pikachu").number
      api.flush!

      Faraday.define_singleton_method(:get) { |_url| raise Faraday::ConnectionFailed }
      reloaded = PokeApiHttp.new(cache_path: path)

      assert_equal 25, reloaded.find("pikachu").number
    end
  ensure
    Faraday.define_singleton_method(:get, @original_faraday) if defined?(@original_faraday) && @original_faraday
  end

  def test_type_relations_fetches_types_in_parallel
    @original_faraday = Faraday.method(:get)
    mutex = Mutex.new
    active = 0
    max_active = 0
    Faraday.define_singleton_method(:get) do |_url|
      mutex.synchronize do
        active += 1
        max_active = active if active > max_active
      end
      sleep 0.02
      mutex.synchronize { active -= 1 }
      Struct.new(:status, :body).new(
        200,
        JSON.generate("name" => "normal", "damage_relations" => {
                        "double_damage_to" => [], "half_damage_to" => [], "no_damage_to" => []
                      })
      )
    end

    relations = @api.type_relations

    assert relations.key?("normal")
    assert_operator max_active, :>, 1, "18 tipos deveriam ser buscados em paralelo"
  ensure
    Faraday.define_singleton_method(:get, @original_faraday)
  end
end
