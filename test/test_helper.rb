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
    connection = PG.connect(ENV.fetch("DATABASE_URL"))
    connection.exec("SET client_min_messages TO warning")
    connection.exec(File.read(File.expand_path("../db/schema.sql", __dir__)))
    Dir[File.expand_path("../db/migrations/*.sql", __dir__)].sort.each do |migration|
      connection.exec(File.read(migration))
    end
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

module PokeApiStub
  def self.with_find(pokemon)
    original = PokeApi.method(:find)
    PokeApi.define_singleton_method(:find) { |_name| pokemon }
    yield
  ensure
    PokeApi.define_singleton_method(:find, original)
  end
end
