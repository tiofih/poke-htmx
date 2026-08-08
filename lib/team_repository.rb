# frozen_string_literal: true

require "pg"
require_relative "pokemon"

class TeamRepository
  DEFAULT_DATABASE_URL = "postgres://pokedex:pokedex@localhost:5432/pokedex"

  def initialize(db_url: ENV["DATABASE_URL"] || DEFAULT_DATABASE_URL)
    @db_url = db_url
  end

  def all
    connection.exec("SELECT * FROM team_pokemons ORDER BY id").map do |row|
      Pokemon.new(name: row["name"], sprite: row["sprite"], number: row["number"])
    end
  end

  def add(pokemon)
    connection.exec_params(
      "INSERT INTO team_pokemons (name, sprite, number) VALUES ($1, $2, $3)",
      [pokemon.name, pokemon.sprite, pokemon.number]
    )
  end

  def remove(id)
    connection.exec_params("DELETE FROM team_pokemons WHERE id = $1", [id])
  end

  private

  def connection
    @connection ||= PG.connect(@db_url)
  end
end
