# frozen_string_literal: true

require_relative "test_helper"

# rubocop:disable Metrics/ClassLength, Metrics/MethodLength
class PokeApiMoveTest < Minitest::Test
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
    move = PokeApi.extract_move(poke_move_json)

    assert_instance_of Move, move
    assert_equal "thunder-shock", move.name
    assert_equal "electric", move.type
    assert_equal 40, move.power
    assert_equal 100, move.accuracy
    assert_equal 30, move.pp
  end

  def test_extract_move_allows_status_move_without_power
    move = PokeApi.extract_move(status_move_json)

    assert_equal "growl", move.name
    assert_nil move.power
    assert_equal 40, move.pp
  end

  def test_move_fetches_and_memoizes_by_name
    count = 0
    move_json = poke_move_json
    original = PokeApi.method(:fetch_move_json)
    PokeApi.define_singleton_method(:fetch_move_json) do |_name|
      count += 1
      move_json
    end
    PokeApi.instance_variable_set(:@move_cache, nil)

    first = PokeApi.move("thunder-shock")
    second = PokeApi.move("thunder-shock")

    assert_instance_of Move, first
    assert_equal first, second, "2a chamada usa cache (mesmo objeto)"
    assert_equal 1, count
  ensure
    PokeApi.define_singleton_method(:fetch_move_json, original)
    PokeApi.instance_variable_set(:@move_cache, nil)
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
    original_data = PokeApi.method(:pokemon_data)
    original_fetch = PokeApi.method(:fetch_move_json)
    PokeApi.define_singleton_method(:pokemon_data) { |_number| data }
    PokeApi.define_singleton_method(:fetch_move_json) { |name| move_json.merge("name" => name) }
    PokeApi.instance_variable_set(:@pokemon_moves_cache, nil)
    PokeApi.instance_variable_set(:@move_cache, nil)

    moves = PokeApi.moves_for(25)

    assert_equal %w[tail-whip thunder-shock quick-attack thunder-wave], moves.map(&:name)
  ensure
    PokeApi.define_singleton_method(:pokemon_data, original_data)
    PokeApi.define_singleton_method(:fetch_move_json, original_fetch)
  end

  def test_moves_for_memoizes_per_number
    count = 0
    data = pokemon_data_with_moves
    move_json = poke_move_json
    original_data = PokeApi.method(:pokemon_data)
    original_fetch = PokeApi.method(:fetch_move_json)
    PokeApi.define_singleton_method(:pokemon_data) do |_number|
      count += 1
      data
    end
    PokeApi.define_singleton_method(:fetch_move_json) { |name| move_json.merge("name" => name) }
    PokeApi.instance_variable_set(:@pokemon_moves_cache, nil)
    PokeApi.instance_variable_set(:@move_cache, nil)

    PokeApi.moves_for(25)
    PokeApi.moves_for(25)

    assert_equal 1, count, "2a chamada para o mesmo número usa cache"
  ensure
    PokeApi.define_singleton_method(:pokemon_data, original_data)
    PokeApi.define_singleton_method(:fetch_move_json, original_fetch)
  end

  def test_available_move_names_returns_all_move_names_sorted
    data = {
      "moves" => [
        { "move" => { "name" => "thunder-shock" } },
        { "move" => { "name" => "growl" } },
        { "move" => { "name" => "quick-attack" } }
      ]
    }
    original = PokeApi.method(:pokemon_data)
    PokeApi.define_singleton_method(:pokemon_data) { |_number| data }
    PokeApi.instance_variable_set(:@available_moves_cache, nil)

    assert_equal %w[growl quick-attack thunder-shock], PokeApi.available_move_names(25)
  ensure
    PokeApi.define_singleton_method(:pokemon_data, original)
    PokeApi.instance_variable_set(:@available_moves_cache, nil)
  end

  def test_available_move_names_memoizes_per_number
    count = 0
    data = { "moves" => [{ "move" => { "name" => "growl" } }] }
    original = PokeApi.method(:pokemon_data)
    PokeApi.define_singleton_method(:pokemon_data) do |_number|
      count += 1
      data
    end
    PokeApi.instance_variable_set(:@available_moves_cache, nil)

    PokeApi.available_move_names(25)
    PokeApi.available_move_names(25)

    assert_equal 1, count, "2a chamada para o mesmo número usa cache"
  ensure
    PokeApi.define_singleton_method(:pokemon_data, original)
    PokeApi.instance_variable_set(:@available_moves_cache, nil)
  end

  def test_fetch_move_json_returns_nil_when_status_has_failure_code
    response = Struct.new(:status).new(404)
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) { |_url| response }

    assert_nil PokeApi.fetch_move_json("not-a-move")
  ensure
    Faraday.define_singleton_method(:get, original)
  end

  def test_available_move_names_returns_empty_when_request_fails
    response = Struct.new(:status, :body).new(503, "<html>rate limited</html>")
    original = Faraday.method(:get)
    Faraday.define_singleton_method(:get) { |_url| response }
    PokeApi.instance_variable_set(:@available_moves_cache, nil)

    assert_equal [], PokeApi.available_move_names(25)
  ensure
    Faraday.define_singleton_method(:get, original)
    PokeApi.instance_variable_set(:@available_moves_cache, nil)
  end

  def test_move_returns_nil_for_unknown_move
    original = PokeApi.method(:fetch_move_json)
    PokeApi.define_singleton_method(:fetch_move_json) { |_name| nil }
    PokeApi.instance_variable_set(:@move_cache, nil)

    assert_nil PokeApi.move("not-a-move")
  ensure
    PokeApi.define_singleton_method(:fetch_move_json, original)
    PokeApi.instance_variable_set(:@move_cache, nil)
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/MethodLength
