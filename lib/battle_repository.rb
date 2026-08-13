# frozen_string_literal: true

require "json"
require "pg"

class BattleRepository
  DEFAULT_DATABASE_URL = "postgres://pokedex:pokedex@localhost:5432/pokedex"
  DEFAULT_LIMIT = 10

  def initialize(db_url: ENV["DATABASE_URL"] || DEFAULT_DATABASE_URL)
    @db_url = db_url
  end

  def add(user_id, result, opponent_team)
    connection.exec_params(
      "INSERT INTO battles (user_id, result, opponent_team) VALUES ($1, $2, $3)",
      [user_id, result, opponent_team.to_json]
    )
  end

  def recent(user_id, limit: DEFAULT_LIMIT)
    connection.exec_params(
      "SELECT id, result, opponent_team, created_at FROM battles " \
      "WHERE user_id = $1 ORDER BY created_at DESC, id DESC LIMIT $2",
      [user_id, limit]
    ).map { |row| row_to_record(row) }
  end

  private

  def row_to_record(row)
    {
      id: row["id"].to_i,
      result: row["result"],
      opponent_team: JSON.parse(row["opponent_team"], symbolize_names: true),
      created_at: row["created_at"]
    }
  end

  def connection
    @connection ||= PG.connect(@db_url)
  end
end
