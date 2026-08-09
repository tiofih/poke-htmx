# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/move"
require_relative "../lib/battle_pokemon"

class MoveTest < Minitest::Test
  def test_move_has_all_attributes
    move = Move.new(name: "tacle", type: "normal", power: 40, accuracy: 100, pp: 35)

    assert_equal "tacle", move.name
    assert_equal "normal", move.type
    assert_equal 40, move.power
    assert_equal 100, move.accuracy
    assert_equal 35, move.pp
  end

  def test_move_allows_nil_power_and_accuracy_for_status_moves
    move = Move.new(name: "growl", type: "normal", power: nil, accuracy: nil, pp: 40)

    assert_nil move.power
    assert_nil move.accuracy
  end

  def test_battle_pokemon_defaults_to_no_moves
    pokemon = BattlePokemon.new(
      number: 25,
      name: "pikachu",
      types: ["electric"],
      stats: [{ name: "HP", value: 100 }],
      hp_max: 100,
      hp_current: 100
    )

    assert_empty pokemon.moves
  end

  def test_from_without_moves_keeps_empty_list
    pokemon = Pokemon.new(name: "pikachu", sprite: "s", number: 25, stats: [{ name: "HP", value: 100 }])

    assert_empty BattlePokemon.from(pokemon).moves
  end

  def test_from_accepts_moves
    move = Move.new(name: "tacle", type: "normal", power: 40, accuracy: 100, pp: 35)
    pokemon = Pokemon.new(name: "pikachu", sprite: "s", number: 25, stats: [{ name: "HP", value: 100 }])

    battle_pokemon = BattlePokemon.from(pokemon, moves: [move])

    assert_equal [move], battle_pokemon.moves
  end

  # rubocop:disable Metrics/MethodLength
  def test_use_move_decrements_pp_functionally
    move = Move.new(name: "tacle", type: "normal", power: 40, accuracy: 100, pp: 35)
    pokemon = BattlePokemon.new(
      number: 25,
      name: "pikachu",
      types: ["electric"],
      stats: [{ name: "HP", value: 100 }],
      hp_max: 100,
      hp_current: 100,
      moves: [move]
    )

    used = pokemon.use_move(0)

    assert_equal 34, used.moves.first.pp
    assert_equal 35, pokemon.moves.first.pp, "original permanece intacto"
  end

  def test_use_move_does_not_go_below_zero
    move = Move.new(name: "tacle", type: "normal", power: 40, accuracy: 100, pp: 0)
    pokemon = BattlePokemon.new(
      number: 25,
      name: "pikachu",
      types: ["electric"],
      stats: [{ name: "HP", value: 100 }],
      hp_max: 100,
      hp_current: 100,
      moves: [move]
    )

    assert_equal 0, pokemon.use_move(0).moves.first.pp
  end
  # rubocop:enable Metrics/MethodLength
end
