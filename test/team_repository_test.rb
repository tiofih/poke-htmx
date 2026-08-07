# frozen_string_literal: true

require_relative "test_helper"

class TeamRepositoryTest < Minitest::Test
  def setup
    TestDatabase.setup!
    TestDatabase.clear_team!
    @repository = TeamRepository.new
  end

  def test_all_returns_empty_array_for_empty_database
    assert_equal [], @repository.all
  end

  def test_add_persists_pokemon_and_all_returns_it
    pokemon = Pokemon.new(name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25)

    @repository.add(pokemon)
    rows = @repository.all

    assert_equal 1, rows.size
    assert_instance_of Pokemon, rows.first
    assert_equal "pikachu", rows.first.name
    assert_equal "https://example.com/pikachu.png", rows.first.sprite
    assert_equal 25, rows.first.number
  end
end
