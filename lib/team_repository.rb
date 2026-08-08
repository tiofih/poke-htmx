# frozen_string_literal: true

require "pg"
require_relative "pokemon"

class TeamRepository
  DEFAULT_DATABASE_URL = "postgres://pokedex:pokedex@localhost:5432/pokedex"
  MAX_TEAM_SIZE = 6

  class TeamFullError < StandardError; end
  class DuplicateError < StandardError; end

  def initialize(db_url: ENV["DATABASE_URL"] || DEFAULT_DATABASE_URL)
    @db_url = db_url
  end

  def all(user_id)
    connection.exec_params(
      "SELECT * FROM team_pokemons WHERE user_id = $1 ORDER BY slot",
      [user_id]
    ).map do |row|
      Pokemon.new(id: row["id"], name: row["name"], sprite: row["sprite"], number: row["number"], slot: row["slot"])
    end
  end

  def add(user_id, pokemon)
    slot = next_free_slot(user_id)
    raise TeamFullError, "Time cheio (máx. #{MAX_TEAM_SIZE})." if slot.nil?

    connection.exec_params(
      "INSERT INTO team_pokemons (user_id, name, sprite, number, slot) VALUES ($1, $2, $3, $4, $5)",
      [user_id, pokemon.name, pokemon.sprite, pokemon.number, slot]
    )
  end

  def remove(user_id, id)
    connection.exec_params("DELETE FROM team_pokemons WHERE id = $1 AND user_id = $2", [id, user_id])
  end

  private

  def next_free_slot(user_id)
    taken = connection.exec_params(
      "SELECT slot FROM team_pokemons WHERE user_id = $1 ORDER BY slot",
      [user_id]
    ).map { |row| row["slot"].to_i }
    (1..MAX_TEAM_SIZE).find { |slot| !taken.include?(slot) }
  end

  def connection
    @connection ||= PG.connect(@db_url)
  end
end
