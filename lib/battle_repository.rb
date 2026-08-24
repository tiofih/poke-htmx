# frozen_string_literal: true

require "json"
require "pg"
require_relative "connection_registry"

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

  def stats(user_id)
    rows = connection.exec_params(
      "SELECT result, COUNT(*) FROM battles WHERE user_id = $1 GROUP BY result",
      [user_id]
    ).to_h { |row| [row["result"], row["count"].to_i] }
    {
      wins: rows["win"].to_i,
      losses: rows["lose"].to_i,
      draws: rows["draw"].to_i,
      total: rows.values.sum
    }
  end

  def ranking(limit: DEFAULT_LIMIT)
    connection.exec_params(
      "SELECT user_id, COUNT(*) FILTER (WHERE result = 'win') AS wins, COUNT(*) AS total " \
      "FROM battles GROUP BY user_id ORDER BY wins DESC, total DESC, user_id ASC LIMIT $1",
      [limit]
    ).map { |row| row_to_ranking(row) }
  end

  def rank_position(user_id)
    return unless ranked_user?(user_id)

    wins = user_wins(user_id)
    position_rows(wins)["position"].to_i
  end

  private

  def ranked_user?(user_id)
    connection.exec_params(
      "SELECT 1 FROM battles WHERE user_id = $1",
      [user_id]
    ).ntuples.positive?
  end

  def user_wins(user_id)
    connection.exec_params(
      "SELECT COUNT(*) FILTER (WHERE result = 'win') AS wins " \
      "FROM battles WHERE user_id = $1",
      [user_id]
    ).first["wins"].to_i
  end

  def position_rows(wins)
    connection.exec_params(
      "SELECT COUNT(*) + 1 AS position FROM (" \
      "SELECT user_id, COUNT(*) FILTER (WHERE result = 'win')::int AS wins " \
      "FROM battles GROUP BY user_id) ranked WHERE ranked.wins > $1::int",
      [wins]
    ).first
  end

  def row_to_record(row)
    {
      id: row["id"].to_i,
      result: row["result"],
      opponent_team: JSON.parse(row["opponent_team"], symbolize_names: true),
      created_at: row["created_at"]
    }
  end

  def row_to_ranking(row)
    { user_id: row["user_id"], wins: row["wins"].to_i, total: row["total"].to_i }
  end

  def connection
    @connection ||= ConnectionRegistry.register(self, PG.connect(@db_url))
  end
end
