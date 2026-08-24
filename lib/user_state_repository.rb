# frozen_string_literal: true

require "pg"
require_relative "connection_registry"

class UserStateRepository
  DEFAULT_DATABASE_URL = "postgres://pokedex:pokedex@localhost:5432/pokedex"

  def initialize(db_url: ENV["DATABASE_URL"] || DEFAULT_DATABASE_URL)
    @db_url = db_url
  end

  def started?(user_id)
    row = connection.exec_params(
      "SELECT journey_started FROM user_state WHERE user_id = $1",
      [user_id]
    ).first
    row ? row["journey_started"] == "t" : false
  end

  def mark_started(user_id)
    connection.exec_params(
      "INSERT INTO user_state (user_id, journey_started) VALUES ($1, TRUE) " \
      "ON CONFLICT (user_id) DO UPDATE SET journey_started = TRUE",
      [user_id]
    )
  end

  private

  def connection
    ConnectionRegistry.connection_for(self, Thread.current.object_id, @db_url)
  end
end
