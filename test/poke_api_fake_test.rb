# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/gateways/poke_api_http"
require_relative "poke_api_fake"

class PokeApiFakeTest < Minitest::Test
  def pikachu
    Pokemon.new(name: "pikachu", sprite: "s", number: 25)
  end

  def test_implements_the_gateway_contract_on_both_adapters
    [PokeApiHttp.new, PokeApiFake.new].each do |adapter|
      assert_respond_to adapter, :find
      assert_respond_to adapter, :detail
      assert_respond_to adapter, :fetch_all_names
      assert_respond_to adapter, :paginate
      assert_respond_to adapter, :move
      assert_respond_to adapter, :moves_for
      assert_respond_to adapter, :available_move_names
      assert_respond_to adapter, :type_relations
      assert_respond_to adapter, :next_evolutions
      assert_respond_to adapter, :learnable_moves
    end
  end

  def test_find_returns_per_name_when_configured_with_a_hash
    fake = PokeApiFake.new(find: { "pikachu" => pikachu })

    assert_equal pikachu, fake.find("pikachu")
    assert_nil fake.find("bulbasaur")
  end

  def test_find_returns_same_value_for_any_name_when_fixed
    fake = PokeApiFake.new(find: pikachu)

    assert_equal pikachu, fake.find("anything")
  end

  def test_detail_defaults_to_nil
    assert_nil PokeApiFake.new.detail(25)
  end

  def test_fetch_all_names_returns_configured_list
    fake = PokeApiFake.new(fetch_all_names: %w[pikachu bulbasaur])

    assert_equal %w[pikachu bulbasaur], fake.fetch_all_names
  end

  def test_move_returns_per_name_when_configured_with_a_hash
    move = Move.new(name: "thunder-shock", type: "electric", power: 40, accuracy: 100, pp: 30)
    fake = PokeApiFake.new(move: { "thunder-shock" => move })

    assert_same move, fake.move("thunder-shock")
    assert_nil fake.move("tackle")
  end

  def test_moves_for_returns_configured_list
    move = Move.new(name: "tackle", type: "normal", power: 40, accuracy: 100, pp: 35)
    fake = PokeApiFake.new(moves_for: [move])

    assert_equal [move], fake.moves_for(25)
  end

  def test_available_move_names_returns_configured_list
    fake = PokeApiFake.new(available_move_names: %w[growl quick-attack])

    assert_equal %w[growl quick-attack], fake.available_move_names(25)
  end

  def test_type_relations_returns_configured_table
    table = { "fire" => { "double" => %w[grass], "half" => %w[fire], "no" => [] } }
    fake = PokeApiFake.new(type_relations: table)

    assert_same table, fake.type_relations
  end

  def test_next_evolutions_returns_configured_data
    data = [{ number: 5, name: "charmeleon", min_level: 16 }]
    fake = PokeApiFake.new(next_evolutions: data)

    assert_equal data, fake.next_evolutions(4)
  end

  def test_learnable_moves_returns_configured_data
    data = [{ level: 1, name: "thunder-shock" }]
    fake = PokeApiFake.new(learnable_moves: data)

    assert_equal data, fake.learnable_moves(25)
  end
end
