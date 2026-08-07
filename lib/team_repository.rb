# frozen_string_literal: true

require "pg"

class TeamRepository
  DEFAULT_DATABASE_URL = "postgres://pokedex:pokedex@localhost:5432/pokedex"

  def initialize(db_url: ENV["DATABASE_URL"] || DEFAULT_DATABASE_URL)
    @db_url = db_url
  end

  def all
    connection.exec("SELECT * FROM team_pokemons ORDER BY id").to_a
  end

  private

  def connection
    @connection ||= PG.connect(@db_url)
  end
end
