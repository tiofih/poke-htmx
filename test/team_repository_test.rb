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

  def test_remove_deletes_pokemon_by_id
    pikachu = Pokemon.new(name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25)
    bulbasaur = Pokemon.new(name: "bulbasaur", sprite: "https://example.com/bulbasaur.png", number: 1)
    @repository.add(pikachu)
    @repository.add(bulbasaur)

    first_id = team_id("pikachu")
    @repository.remove(first_id)

    remaining = @repository.all
    assert_equal %w[bulbasaur], remaining.map(&:name)
  end

  private

  def team_id(name)
    connection = PG.connect(ENV.fetch("DATABASE_URL"))
    connection.exec_params("SELECT id FROM team_pokemons WHERE name = $1", [name]).first["id"]
  ensure
    connection&.close
  end
end
