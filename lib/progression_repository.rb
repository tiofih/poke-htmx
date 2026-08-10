# frozen_string_literal: true

require "pg"
require_relative "experience_curve"

class ProgressionRepository
  DEFAULT_DATABASE_URL = "postgres://pokedex:pokedex@localhost:5432/pokedex"

  def initialize(db_url: ENV["DATABASE_URL"] || DEFAULT_DATABASE_URL)
    @db_url = db_url
  end

  def get(user_id, team_pokemon_id)
    row = connection.exec_params(
      <<~SQL,
        SELECT p.level, p.xp
        FROM team_pokemon_progress p
        JOIN team_pokemons t ON t.id = p.team_pokemon_id
        WHERE p.team_pokemon_id = $1 AND t.user_id = $2
      SQL
      [team_pokemon_id, user_id]
    ).first
    row && { level: row["level"].to_i, xp: row["xp"].to_i }
  end

  def grant(user_id, team_pokemon_id, amount)
    current = get(user_id, team_pokemon_id)
    return unless current

    total = current[:xp] + amount
    level = ExperienceCurve.level_for_xp(total)
    connection.exec_params(
      "UPDATE team_pokemon_progress SET level = $2, xp = $3, updated_at = now() " \
      "WHERE team_pokemon_id = $1",
      [team_pokemon_id, level, total]
    )
    { level: level, xp: total }
  end

  private

  def connection
    @connection ||= PG.connect(@db_url)
  end
end
