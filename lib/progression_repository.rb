# frozen_string_literal: true

require "pg"
require_relative "connection_registry"
require_relative "experience_curve"

class ProgressionRepository
  DEFAULT_DATABASE_URL = "postgres://pokedex:pokedex@localhost:5432/pokedex"

  def initialize(db_url: ENV["DATABASE_URL"] || DEFAULT_DATABASE_URL)
    @db_url = db_url
  end

  def get(user_id, team_pokemon_id)
    row = progress_row(user_id, team_pokemon_id)
    row && { level: row["level"].to_i, xp: row["xp"].to_i,
             hp_max: row["hp_max"].to_i, hp_current: row["hp_current"].to_i }
  end

  def update_hp(user_id, team_pokemon_id, hp_max, hp_current)
    return unless progress_row(user_id, team_pokemon_id)

    connection.exec_params(
      "UPDATE team_pokemon_progress SET hp_max = $1, hp_current = $2, updated_at = now() " \
      "WHERE team_pokemon_id = $3",
      [hp_max.to_i, hp_current.to_i, team_pokemon_id]
    )
    get(user_id, team_pokemon_id)
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

  def progress_row(user_id, team_pokemon_id)
    connection.exec_params(
      <<~SQL,
        SELECT p.level, p.xp, p.hp_max, p.hp_current
        FROM team_pokemon_progress p
        JOIN team_pokemons t ON t.id = p.team_pokemon_id
        WHERE p.team_pokemon_id = $1 AND t.user_id = $2
      SQL
      [team_pokemon_id, user_id]
    ).first
  end

  def connection
    ConnectionRegistry.connection_for(self, Thread.current.object_id, @db_url)
  end
end
