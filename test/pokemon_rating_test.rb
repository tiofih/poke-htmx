# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/pokemon_rating"

class PokemonRatingTest < Minitest::Test
  WEIGHTS = { "HP" => 0.5, "Attack" => 1.0, "Defense" => 1.0, "Sp.Atk" => 1.0,
              "Sp.Def" => 1.0, "Speed" => 1.0 }.freeze

  def build_pokemon(stats: {}, types: ["normal"])
    Pokemon.new(
      name: "pokemon",
      sprite: "https://example.com/pokemon.png",
      number: 1,
      types: types,
      stats: stats.map { |name, value| { name: name, value: value } }
    )
  end

  def build_move(name, type:, power:)
    Move.new(name: name, type: type, power: power, accuracy: 100, pp: 20)
  end

  def all_stats(value)
    { "HP" => value, "Attack" => value, "Defense" => value,
      "Sp.Atk" => value, "Sp.Def" => value, "Speed" => value }
  end

  def test_rate_sums_weighted_base_stats
    pokemon = build_pokemon(stats: all_stats(100))

    assert_equal 550, PokemonRating.rate(pokemon)[:score]
  end

  def test_rate_missing_stats_count_as_zero
    pokemon = build_pokemon(stats: { "HP" => 100, "Speed" => 50 })

    assert_equal 100, PokemonRating.rate(pokemon)[:score]
  end

  def test_rate_ignores_unknown_stat_names
    pokemon = build_pokemon(stats: all_stats(100).merge("Luck" => 999))

    assert_equal 550, PokemonRating.rate(pokemon)[:score]
  end

  def test_rate_rounds_fractional_weighted_stats
    pokemon = build_pokemon(stats: all_stats(55))

    assert_equal 303, PokemonRating.rate(pokemon)[:score]
  end

  def test_rate_maps_tier_by_score_thresholds
    cases = { 110 => :S, 100 => :A, 80 => :B, 70 => :C, 55 => :D, 40 => :F }

    cases.each do |value, expected_tier|
      pokemon = build_pokemon(stats: all_stats(value))
      assert_equal expected_tier, PokemonRating.rate(pokemon)[:tier], "stats #{value}"
    end
  end

  def test_rate_without_moves_has_no_move_bonus
    pokemon = build_pokemon(stats: all_stats(40))

    assert_equal 220, PokemonRating.rate(pokemon)[:score]
  end

  def test_rate_bonus_zero_when_only_status_moves
    pokemon = build_pokemon(stats: all_stats(40))
    moves = [build_move("growl", type: "normal", power: nil)]

    assert_equal 220, PokemonRating.rate(pokemon, moves: moves)[:score]
  end

  def test_rate_adds_average_of_best_four_moves
    pokemon = build_pokemon(stats: all_stats(40), types: ["rock"])
    moves = [
      build_move("fire", type: "fire", power: 40),
      build_move("water", type: "water", power: 60),
      build_move("tackle", type: "normal", power: 80),
      build_move("electric", type: "electric", power: 100),
      build_move("grass", type: "grass", power: 120)
    ]

    rating = PokemonRating.rate(pokemon, moves: moves)

    assert_equal 90, rating[:score] - 220, "bonus = media dos 4 melhores (120,100,80,60)"
  end

  def test_rate_applies_stab_to_matching_move_type
    pokemon = build_pokemon(stats: all_stats(40), types: ["fire"])
    moves = [
      build_move("ember", type: "fire", power: 60),
      build_move("tackle", type: "normal", power: 40)
    ]

    rating = PokemonRating.rate(pokemon, moves: moves)

    assert_equal 65, rating[:score] - 220, "ember 60*1.5 + tackle 40 -> media 65"
  end

  def test_rate_ignores_status_moves_in_average
    pokemon = build_pokemon(stats: all_stats(40), types: ["normal"])
    moves = [
      build_move("ember", type: "fire", power: 60),
      build_move("growl", type: "normal", power: nil),
      build_move("leer", type: "normal", power: nil)
    ]

    rating = PokemonRating.rate(pokemon, moves: moves)

    assert_equal 60, rating[:score] - 220
  end

  def test_rate_moves_can_raise_tier
    pokemon = build_pokemon(stats: all_stats(40), types: ["fire"])
    moves = [build_move("overheat", type: "fire", power: 100)]

    rating = PokemonRating.rate(pokemon, moves: moves)

    assert_equal :C, rating[:tier], "220 + 150 (overheat 100*1.5) = 370 -> C"
  end

  def test_rate_is_deterministic
    pokemon = build_pokemon(stats: all_stats(100), types: ["fire"])
    moves = [build_move("ember", type: "fire", power: 60)]

    assert_equal PokemonRating.rate(pokemon, moves: moves),
                 PokemonRating.rate(pokemon, moves: moves)
  end
end
