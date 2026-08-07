# frozen_string_literal: true

ENV["RACK_ENV"] = "test"
ENV["DATABASE_URL"] ||= "postgres://pokedex:pokedex@localhost:5432/pokedex"

require "minitest/autorun"
require "rack/test"
require "pg"

require_relative "../lib/pokemon"
require_relative "../lib/team_repository"

module TestDatabase
  def self.setup!
    schema = File.read(File.expand_path("../db/schema.sql", __dir__))
    connection = PG.connect(ENV.fetch("DATABASE_URL"))
    connection.exec(schema)
  ensure
    connection&.close
  end

  def self.clear_team!
    connection = PG.connect(ENV.fetch("DATABASE_URL"))
    connection.exec("TRUNCATE team_pokemons")
  ensure
    connection&.close
  end
end
