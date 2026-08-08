# frozen_string_literal: true

ENV["RACK_ENV"] = "test"
ENV["DATABASE_URL"] ||= "postgres://pokedex:pokedex@localhost:5432/pokedex"

require "minitest/autorun"
require "rack/test"
require "pg"

require_relative "../lib/pokemon"
require_relative "../lib/poke_api"
require_relative "../lib/team_repository"

module TestDatabase
  def self.setup!
    connection = PG.connect(ENV.fetch("DATABASE_URL"))
    connection.exec("SET client_min_messages TO warning")
    connection.exec(File.read(File.expand_path("../db/schema.sql", __dir__)))
    Dir[File.expand_path("../db/migrations/*.sql", __dir__)].each do |migration|
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

  def self.with_detail(pokemon)
    existed = PokeApi.respond_to?(:detail)
    original = existed ? PokeApi.method(:detail) : nil
    PokeApi.define_singleton_method(:detail) { |_poke_id| pokemon }
    yield
  ensure
    if existed
      PokeApi.define_singleton_method(:detail, original)
    else
      PokeApi.singleton_class.send(:remove_method, :detail)
    end
  end

  def self.with_all_names(names)
    existed = PokeApi.respond_to?(:fetch_all_names)
    original = existed ? PokeApi.method(:fetch_all_names) : nil
    PokeApi.define_singleton_method(:fetch_all_names) { names }
    yield
  ensure
    if existed
      PokeApi.define_singleton_method(:fetch_all_names, original)
    else
      PokeApi.singleton_class.send(:remove_method, :fetch_all_names)
    end
  end

  def self.with_type(table)
    existed = PokeApi.respond_to?(:fetch_type_json)
    original = existed ? PokeApi.method(:fetch_type_json) : nil
    PokeApi.define_singleton_method(:fetch_type_json) { |name| table[name] }
    PokeApi.instance_variable_set(:@type_relations, nil)
    yield
  ensure
    if existed
      PokeApi.define_singleton_method(:fetch_type_json, original)
    else
      PokeApi.singleton_class.send(:remove_method, :fetch_type_json)
    end
    PokeApi.instance_variable_set(:@type_relations, nil)
  end
end
