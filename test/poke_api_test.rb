# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/type_effectiveness"
require_relative "../lib/gateways/poke_api_http"

class PokeApiTest < Minitest::Test
  def api
    @api ||= PokeApiHttp.new
  end

  def fifteen_names
    %w[bulbasaur ivysaur venusaur charmander charmeleon charizard squirtle wartortle
       blastoise caterpie metapod butterfree pikachu pikachu-raichu raichu]
  end

  def names_json
    {
      "results" => fifteen_names.map { |name| { "name" => name } },
      "count" => fifteen_names.size
    }
  end

  def stub_all_names_response(json)
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) do |_url|
      Struct.new(:status, :body).new(200, JSON.generate(json))
    end
    yield
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_paginate_returns_names_for_offset_with_total
    stub_all_names_response(names_json) do
      page = api.paginate(offset: 0, limit: 10)

      assert_equal 10, page[:names].size
      assert_equal 15, page[:total]
      assert_equal "bulbasaur", page[:names].first
    end
  end

  def test_paginate_slices_by_offset
    stub_all_names_response(names_json) do
      page = api.paginate(offset: 10, limit: 10)

      assert_equal 5, page[:names].size
      assert_equal %w[pikachu pikachu-raichu raichu], page[:names][2..]
      assert_equal 15, page[:total]
    end
  end

  def test_paginate_returns_empty_when_offset_beyond_end
    stub_all_names_response(names_json) do
      page = api.paginate(offset: 100, limit: 10)

      assert_empty page[:names]
      assert_equal 15, page[:total]
    end
  end

  def test_paginate_filters_by_substring_case_insensitive
    stub_all_names_response(names_json) do
      page = api.paginate(offset: 0, limit: 10, query: "PIK")

      assert_equal %w[pikachu pikachu-raichu], page[:names]
      assert_equal 2, page[:total]
    end
  end

  def test_paginate_with_empty_q_returns_all
    stub_all_names_response(names_json) do
      page = api.paginate(offset: 0, limit: 100, query: "")

      assert_equal 15, page[:names].size
      assert_equal 15, page[:total]
    end
  end

  def test_paginate_filters_then_paginates
    stub_all_names_response(names_json) do
      first = api.paginate(offset: 0, limit: 1, query: "char")
      second = api.paginate(offset: 1, limit: 1, query: "char")

      assert_equal %w[charmander], first[:names]
      assert_equal %w[charmeleon], second[:names]
      assert_equal 3, second[:total]
    end
  end

  def fire_type_json
    {
      "name" => "fire",
      "damage_relations" => {
        "double_damage_to" => %w[bug steel grass ice].map { |name| { "name" => name } },
        "half_damage_to" => %w[rock fire water dragon].map { |name| { "name" => name } },
        "no_damage_to" => []
      }
    }
  end

  def test_extract_type_relations_normalizes_damage_relations
    extracted = api.extract_type_relations(fire_type_json)

    assert_equal %w[bug steel grass ice], extracted["fire"]["double"]
    assert_equal %w[rock fire water dragon], extracted["fire"]["half"]
    assert_empty extracted["fire"]["no"]
  end

  def test_extract_type_relations_handles_no_damage_list
    json = { "name" => "electric", "damage_relations" => { "no_damage_to" => [{ "name" => "ground" }] } }
    assert_equal %w[ground], api.extract_type_relations(json)["electric"]["no"]
  end

  def test_type_relations_builds_table_for_all_18_types
    test_self = self
    api.define_singleton_method(:fetch_type_json) { |name| test_self.send(:build_type_json_table)[name] }

    relations = api.type_relations

    assert_equal 18, relations.size
    assert_equal %w[grass bug ice steel], relations["fire"]["double"]
    assert_equal %w[rock fire water dragon], relations["fire"]["half"]
    assert_empty relations["fire"]["no"]
    assert_equal %w[water grass dragon], relations["water"]["half"]
    assert_equal %w[ground], relations["flying"]["no"]
  end

  def test_type_relations_skips_types_that_fail_to_load
    test_self = self
    api.define_singleton_method(:fetch_type_json) do |name|
      return nil if name == "fire"

      test_self.send(:type_json_for, name)
    end

    relations = api.type_relations

    assert_equal 17, relations.size
    refute_includes relations.keys, "fire"
  end

  def test_type_effectiveness_load_integra_fonte_stubbed
    PokeApiStub.with_type(build_type_json_table) do
      effectiveness = TypeEffectiveness.load

      assert_in_delta 2.0, effectiveness.factor("fire", "grass")
      assert_in_delta 0.0, effectiveness.factor("electric", "ground")
      assert_in_delta 0.75, effectiveness.damage_multiplier(
        attacker_types: %w[fire], move_type: "fire", defender_types: %w[water]
      )
    end
  end

  def test_find_returns_nil_when_pokemon_not_found
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) do |_url|
      Struct.new(:status, :body).new(404, "Not Found")
    end

    assert_nil api.find("urshifu")
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_evolution_chain_skips_stages_without_pokemon_endpoint
    api.define_singleton_method(:find) do |name|
      if name == "urshifu"
        nil
      else
        Pokemon.new(name: "kubfu", sprite: "https://example.com/kubfu.png", number: 891)
      end
    end

    stub_responses = {
      "https://pokeapi.co/api/v2/pokemon-species/x" => {
        "evolution_chain" => { "url" => "https://pokeapi.co/api/v2/evolution-chain/1" }
      },
      "https://pokeapi.co/api/v2/evolution-chain/1" => {
        "chain" => {
          "species" => { "name" => "kubfu" },
          "evolves_to" => [{ "species" => { "name" => "urshifu" }, "evolves_to" => [] }]
        }
      }
    }
    original_faraday = Faraday.method(:get)
    Faraday.define_singleton_method(:get) do |url|
      Struct.new(:status, :body).new(200, JSON.generate(stub_responses.fetch(url)))
    end

    evolutions = api.evolution_chain("https://pokeapi.co/api/v2/pokemon-species/x")

    assert_equal %w[kubfu], evolutions.map(&:name)
  ensure
    Faraday.define_singleton_method(:get, original_faraday)
  end

  def test_detail_tolerates_null_sprite
    api.define_singleton_method(:pokemon_data) do |_id|
      {
        "name" => "offender",
        "sprites" => { "front_default" => nil },
        "id" => 999,
        "types" => [],
        "stats" => [],
        "species" => { "url" => "https://pokeapi.co/api/v2/pokemon-species/999" }
      }
    end
    api.define_singleton_method(:evolution_chain) { |_url| [] }

    pokemon = api.detail(999)

    assert_equal "", pokemon.sprite
    assert_equal "offender", pokemon.name
    assert_equal 999, pokemon.number
  end

  def test_find_tolerates_null_sprite
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) do |_url|
      Struct.new(:status, :body).new(
        200,
        JSON.generate("name" => "offender", "sprites" => { "front_default" => nil }, "id" => 999)
      )
    end

    pokemon = api.find("offender")

    assert_equal "", pokemon.sprite
    assert_equal "offender", pokemon.name
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_detail_returns_nil_when_pokemon_data_is_nil
    api.define_singleton_method(:pokemon_data) { |_id| nil }

    assert_nil api.detail(999)
  end

  def test_find_returns_nil_on_network_error
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) { |_url| raise Faraday::ConnectionFailed, "network down" }

    assert_nil api.find("pikachu")
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_fetch_move_json_returns_nil_on_network_error
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) { |_url| raise Faraday::ConnectionFailed, "network down" }

    assert_nil api.fetch_move_json("thunder-shock")
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_evolution_chain_returns_empty_when_status_not_ok
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) do |_url|
      Struct.new(:status, :body).new(404, "Not Found")
    end

    assert_empty api.evolution_chain("https://pokeapi.co/api/v2/pokemon-species/x")
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_evolution_chain_returns_empty_on_network_error
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) { |_url| raise Faraday::ConnectionFailed, "network down" }

    assert_empty api.evolution_chain("https://pokeapi.co/api/v2/pokemon-species/x")
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_evolution_chain_returns_empty_when_body_is_not_json
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) do |_url|
      Struct.new(:status, :body).new(200, "<html>rate limit</html>")
    end

    assert_empty api.evolution_chain("https://pokeapi.co/api/v2/pokemon-species/x")
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_fetch_type_json_returns_nil_when_status_not_ok
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) do |_url|
      Struct.new(:status, :body).new(404, "Not Found")
    end

    assert_nil api.fetch_type_json("fire")
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_fetch_type_json_returns_nil_on_network_error
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) { |_url| raise Faraday::ConnectionFailed, "network down" }

    assert_nil api.fetch_type_json("fire")
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_all_returns_empty_when_status_not_ok
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) do |_url|
      Struct.new(:status, :body).new(404, "Not Found")
    end

    assert_empty api.all
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_all_returns_empty_when_body_is_not_json
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) do |_url|
      Struct.new(:status, :body).new(200, "<html>rate limit</html>")
    end

    assert_empty api.all
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_all_returns_empty_on_network_error
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) { |_url| raise Faraday::ConnectionFailed, "network down" }

    assert_empty api.all
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_fetch_all_names_does_not_memoize_failure
    calls = 0
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) do |_url|
      calls += 1
      raise Faraday::ConnectionFailed, "rate limited" if calls == 1

      Struct.new(:status, :body).new(200, JSON.generate("results" => [{ "name" => "pikachu" }]))
    end

    assert_empty api.fetch_all_names
    assert_equal %w[pikachu], api.fetch_all_names
    assert_equal 2, calls
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  private

  # rubocop:disable Layout/LineLength
  def type_relations_table
    {
      "fire" => { "double" => %w[grass bug ice steel], "half" => %w[rock fire water dragon], "no" => [] },
      "water" => { "double" => %w[fire ground rock], "half" => %w[water grass dragon], "no" => [] },
      "electric" => { "double" => %w[water flying], "half" => %w[grass electric dragon], "no" => %w[ground] },
      "grass" => { "double" => %w[water ground rock], "half" => %w[fire grass poison flying bug dragon steel], "no" => [] },
      "ice" => { "double" => %w[grass ground flying dragon], "half" => %w[fire water ice steel], "no" => [] },
      "fighting" => { "double" => %w[normal ice rock dark steel], "half" => %w[flying poison bug psychic ghost fairy], "no" => [] },
      "poison" => { "double" => %w[grass fairy], "half" => %w[poison ground rock ghost], "no" => %w[steel] },
      "ground" => { "double" => %w[fire electric poison rock steel], "half" => %w[grass bug], "no" => %w[flying] },
      "flying" => { "double" => %w[grass fighting bug], "half" => %w[electric rock steel], "no" => %w[ground] },
      "psychic" => { "double" => %w[fighting poison], "half" => %w[psychic steel], "no" => %w[dark] },
      "bug" => { "double" => %w[grass psychic dark], "half" => %w[fire fighting poison flying ghost steel], "no" => [] },
      "rock" => { "double" => %w[fire ice flying bug], "half" => %w[fighting ground steel], "no" => [] },
      "ghost" => { "double" => %w[ghost psychic], "half" => %w[dark], "no" => %w[normal] },
      "dark" => { "double" => %w[ghost psychic], "half" => %w[fighting dark fairy], "no" => [] },
      "dragon" => { "double" => %w[dragon], "half" => %w[steel], "no" => %w[fairy] },
      "steel" => { "double" => %w[ice rock fairy], "half" => %w[fire water electric steel], "no" => %w[poison] },
      "fairy" => { "double" => %w[fighting dragon dark], "half" => %w[fighting poison steel], "no" => [] },
      "normal" => { "double" => [], "half" => %w[rock steel], "no" => %w[ghost] }
    }
  end
  # rubocop:enable Layout/LineLength

  def build_type_json_table
    type_relations_table.to_h do |name, relations|
      dmg = { "double_damage_to" => relations["double"].map { |t| { "name" => t } },
              "half_damage_to" => relations["half"].map { |t| { "name" => t } },
              "no_damage_to" => relations["no"].map { |t| { "name" => t } } }
      [name, { "name" => name, "damage_relations" => dmg }]
    end
  end

  def type_json_for(name)
    build_type_json_table[name]
  end
end
