# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/opponent_generator"

class OpponentGeneratorTest < Minitest::Test
  NAMES = %w[pikachu bulbasaur squirtle charmander eevee snorlax meowth psyduck].freeze

  def build_pokemon(name)
    Pokemon.new(
      name: name,
      sprite: "https://example.com/#{name}.png",
      number: NAMES.index(name) + 1,
      types: ["normal"],
      stats: [{ name: "HP", value: 50 }, { name: "Speed", value: 20 }]
    )
  end

  def generator(names: NAMES, size: 6, seed: 42, fetcher: nil)
    fetcher ||= ->(name) { build_pokemon(name) }
    OpponentGenerator.new(names: names, size: size, rng: Random.new(seed), fetcher: fetcher)
  end

  def test_team_returns_battle_pokemon_built_from_fetched_details
    team = generator.team

    assert_equal 6, team.size
    assert team.all?(BattlePokemon)
    assert_equal [["normal"]], team.map(&:types).uniq
  end

  def test_team_names_does_not_repeat_slugs
    names = generator.team_names

    assert_equal 6, names.size
    assert_equal names.uniq, names, "sorteio não repete slugs"
  end

  def test_team_respects_custom_size
    names = generator(size: 3).team_names

    assert_equal 3, names.size
  end

  def test_team_names_with_fewer_names_than_size_uses_all
    names = generator(names: %w[a b c], size: 6).team_names

    assert_equal 3, names.size
    assert_equal names.uniq, names
  end

  def test_same_seed_generates_same_team_order
    first = generator(seed: 42).team_names
    second = generator(seed: 42).team_names

    assert_equal first, second
  end

  def test_different_seed_generates_different_order
    first = generator(seed: 42).team_names
    second = generator(seed: 7).team_names

    refute_equal first, second, "seeds diferentes tendem a gerar ordens diferentes"
  end

  def test_team_names_with_empty_names_returns_empty
    assert_empty generator(names: []).team_names
    assert_empty generator(names: []).team
  end

  def test_team_with_non_positive_size_returns_empty
    assert_empty generator(size: 0).team
    assert_empty generator(size: -1).team
  end
end
