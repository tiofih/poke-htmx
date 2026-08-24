# frozen_string_literal: true

require "pg"
require_relative "connection_registry"

class SeedTeam
  DEFAULT_DATABASE_URL = "postgres://pokedex:pokedex@localhost:5432/pokedex"

  def initialize(user_id:, db_url: ENV["DATABASE_URL"] || DEFAULT_DATABASE_URL)
    @user_id = user_id
    @db_url = db_url
  end

  def add_member(name:, sprite:, number:, slot:, moves: [], level: 1, experience: 0) # rubocop:disable Metrics/MethodLength, Metrics/ParameterLists
    connection.transaction do
      id = connection.exec_params(
        "INSERT INTO team_pokemons (user_id, name, sprite, number, slot, moves) " \
        "VALUES ($1, $2, $3, $4, $5, $6) RETURNING id",
        [@user_id, name, sprite, number, slot, array_literal(moves)]
      ).first["id"]
      connection.exec_params(
        "INSERT INTO team_pokemon_progress (team_pokemon_id, level, xp) VALUES ($1, $2, $3)",
        [id, level, experience]
      )
    end
  end

  def clear!
    connection.exec_params(
      "DELETE FROM team_pokemon_progress WHERE team_pokemon_id IN " \
      "(SELECT id FROM team_pokemons WHERE user_id = $1)",
      [@user_id]
    )
    connection.exec_params(
      "DELETE FROM team_pokemons WHERE user_id = $1",
      [@user_id]
    )
  end

  private

  def connection
    ConnectionRegistry.connection_for(self, Thread.current.object_id, @db_url)
  end

  def array_literal(names)
    return "{}" if names.empty?

    "{#{names.join(',')}}"
  end
end
