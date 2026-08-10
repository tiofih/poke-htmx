# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/gateways/poke_api_http"

class PokeApiMoveTest < Minitest::Test
  def api
    @api ||= PokeApiHttp.new
  end

  def poke_move_json
    {
      "name" => "thunder-shock",
      "type" => { "name" => "electric" },
      "power" => 40,
      "accuracy" => 100,
      "pp" => 30
    }
  end

  def status_move_json
    {
      "name" => "growl",
      "type" => { "name" => "normal" },
      "power" => nil,
      "accuracy" => 100,
      "pp" => 40
    }
  end

  def test_extract_move_builds_move_with_all_attributes
    move = api.extract_move(poke_move_json)

    assert_instance_of Move, move
    assert_equal "thunder-shock", move.name
    assert_equal "electric", move.type
    assert_equal 40, move.power
    assert_equal 100, move.accuracy
    assert_equal 30, move.pp
  end

  def test_extract_move_allows_status_move_without_power
    move = api.extract_move(status_move_json)

    assert_equal "growl", move.name
    assert_nil move.power
    assert_equal 40, move.pp
  end

  def test_move_fetches_and_memoizes_by_name
    count = 0
    move_json = poke_move_json
    api.define_singleton_method(:fetch_move_json) do |_name|
      count += 1
      move_json
    end
    api.instance_variable_set(:@move_cache, nil)

    first = api.move("thunder-shock")
    second = api.move("thunder-shock")

    assert_instance_of Move, first
    assert_same first, second, "2a chamada usa cache (mesmo objeto)"
    assert_equal 1, count
  end

  def pokemon_data_with_moves
    {
      "moves" => [
        { "move" => { "name" => "growl" } },
        { "move" => { "name" => "tail-whip" } },
        { "move" => { "name" => "thunder-shock" } },
        { "move" => { "name" => "quick-attack" } },
        { "move" => { "name" => "thunder-wave" } }
      ]
    }
  end

  def test_moves_for_returns_last_four_moves_in_api_order
    data = pokemon_data_with_moves
    move_json = poke_move_json
    api.define_singleton_method(:pokemon_data) { |_number| data }
    api.define_singleton_method(:fetch_move_json) { |name| move_json.merge("name" => name) }

    moves = api.moves_for(25)

    assert_equal %w[tail-whip thunder-shock quick-attack thunder-wave], moves.map(&:name)
  end

  def test_moves_for_memoizes_per_number
    count = 0
    data = pokemon_data_with_moves
    move_json = poke_move_json
    api.define_singleton_method(:pokemon_data) do |_number|
      count += 1
      data
    end
    api.define_singleton_method(:fetch_move_json) { |name| move_json.merge("name" => name) }

    api.moves_for(25)
    api.moves_for(25)

    assert_equal 1, count, "2a chamada para o mesmo número usa cache"
  end

  def test_available_move_names_returns_all_move_names_sorted
    data = {
      "moves" => [
        { "move" => { "name" => "thunder-shock" } },
        { "move" => { "name" => "growl" } },
        { "move" => { "name" => "quick-attack" } }
      ]
    }
    api.define_singleton_method(:pokemon_data) { |_number| data }

    assert_equal %w[growl quick-attack thunder-shock], api.available_move_names(25)
  end

  def test_available_move_names_memoizes_per_number
    count = 0
    data = { "moves" => [{ "move" => { "name" => "growl" } }] }
    api.define_singleton_method(:pokemon_data) do |_number|
      count += 1
      data
    end

    api.available_move_names(25)
    api.available_move_names(25)

    assert_equal 1, count, "2a chamada para o mesmo número usa cache"
  end

  def test_fetch_move_json_returns_nil_when_status_has_failure_code
    response = Struct.new(:status).new(404)
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) { |_url| response }

    assert_nil api.fetch_move_json("not-a-move")
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_available_move_names_returns_empty_when_request_fails
    response = Struct.new(:status, :body).new(503, "<html>rate limited</html>")
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) { |_url| response }

    assert_equal [], api.available_move_names(25)
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_move_returns_nil_for_unknown_move
    api.define_singleton_method(:fetch_move_json) { |_name| nil }
    api.instance_variable_set(:@move_cache, nil)

    assert_nil api.move("not-a-move")
  end
end
