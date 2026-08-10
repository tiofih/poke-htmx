# frozen_string_literal: true

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
end
