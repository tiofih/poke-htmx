# frozen_string_literal: true

require_relative "test_helper"

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
    original = PokeApi.method(:pokemon_data)
    PokeApi.define_singleton_method(:pokemon_data) { |_number| data }
    PokeApi.define_singleton_method(:fetch_move_json) { |name| move_json.merge("name" => name) }
    PokeApi.instance_variable_set(:@pokemon_moves_cache, nil)
    PokeApi.instance_variable_set(:@move_cache, nil)

    moves = PokeApi.moves_for(25)

    assert_equal %w[tail-whip thunder-shock quick-attack thunder-wave], moves.map(&:name)
  ensure
    PokeApi.define_singleton_method(:pokemon_data, original)
  end

  def test_moves_for_memoizes_per_number
    count = 0
    data = pokemon_data_with_moves
    move_json = poke_move_json
    original = PokeApi.method(:pokemon_data)
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
    PokeApi.define_singleton_method(:pokemon_data, original)
  end
end