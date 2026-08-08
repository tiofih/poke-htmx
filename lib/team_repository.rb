# frozen_string_literal: true

require "pg"
require_relative "pokemon"

class TeamRepository
  DEFAULT_DATABASE_URL = "postgres://pokedex:pokedex@localhost:5432/pokedex"

  def initialize(db_url: ENV["DATABASE_URL"] || DEFAULT_DATABASE_URL)
    @db_url = db_url
  end

  def all(user_id)
    connection.exec_params(
      "SELECT * FROM team_pokemons WHERE user_id = $1 ORDER BY id",
      [user_id]
    ).map do |row|
      Pokemon.new(id: row["id"], name: row["name"], sprite: row["sprite"], number: row["number"])
    end
  end

  def add(user_id, pokemon)
    connection.exec_params(
      "INSERT INTO team_pokemons (user_id, name, sprite, number) VALUES ($1, $2, $3, $4)",
      [user_id, pokemon.name, pokemon.sprite, pokemon.number]
    )
  end

  def remove(user_id, id)
    connection.exec_params("DELETE FROM team_pokemons WHERE id = $1", [id])
  end

  private

  def connection
    @connection ||= PG.connect(@db_url)
  end
end
