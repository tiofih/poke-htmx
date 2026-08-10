# frozen_string_literal: true

ENV["RACK_ENV"] = "test"
ENV["DATABASE_URL"] ||= "postgres://pokedex:pokedex@localhost:5432/pokedex"

require "minitest/autorun"
require "rack/test"
require "pg"

require_relative "../lib/pokemon"
require_relative "../lib/poke_api"
require_relative "../lib/team_repository"
require_relative "test_support"

module TestDatabase
  def self.setup!
    with_db do |connection|
      connection.exec("SET client_min_messages TO warning")
      connection.exec(File.read(File.expand_path("../db/schema.sql", __dir__)))
      Dir[File.expand_path("../db/migrations/*.sql", __dir__)].each do |migration|
        connection.exec(File.read(migration))
      end
    end
  end

  def self.clear_team!
    with_db { |connection| connection.exec("TRUNCATE team_pokemons") }
  end

  def self.with_db
    connection = PG.connect(ENV.fetch("DATABASE_URL"))
    yield connection
  ensure
    connection&.close
  end

  def self.team_row(name)
    with_db do |connection|
      connection.exec_params("SELECT * FROM team_pokemons WHERE name = $1", [name]).first
    end
  end

  def self.team_id(name, user_id)
    with_db do |connection|
      connection.exec_params(
        "SELECT id FROM team_pokemons WHERE name = $1 AND user_id = $2",
        [name, user_id]
      ).first["id"]
    end
  end

  def self.distinct_user_ids
    with_db do |connection|
      connection.exec("SELECT DISTINCT user_id FROM team_pokemons").map { |row| row["user_id"] }
    end
  end

  def self.column_info(column)
    with_db do |connection|
      connection.exec_params(
        "SELECT is_nullable FROM information_schema.columns WHERE table_name = $1 AND column_name = $2",
        %w[team_pokemons] + [column]
      ).first
    end
  end

  def self.index_exists(table, column_a, column_b)
    with_db do |connection|
      connection.exec_params(
        <<~SQL,
          SELECT 1 FROM pg_indexes
          WHERE tablename = $1 AND indexdef ILIKE '%UNIQUE%'
            AND indexdef ILIKE '%(#{%(#{column_a}, #{column_b})})%'
        SQL
        [table]
      ).ntuples.positive?
    end
  end
end

module PokeApiStub
  def self.stub_singleton(method_name, implementation, cache: nil)
    existed = PokeApi.respond_to?(method_name)
    original = existed ? PokeApi.method(method_name) : nil
    PokeApi.instance_variable_set(cache, nil) if cache
    PokeApi.define_singleton_method(method_name, &implementation)
    yield
  ensure
    if existed
      PokeApi.define_singleton_method(method_name, original)
    else
      PokeApi.singleton_class.send(:remove_method, method_name)
    end
    PokeApi.instance_variable_set(cache, nil) if cache
  end

  def self.with_find(pokemon, &)
    stub_singleton(:find, proc { |_name| pokemon }, &)
  end

  def self.with_detail(pokemon, &)
    stub_singleton(:detail, proc { |_poke_id| pokemon }, &)
  end

  def self.with_all_names(names, &)
    stub_singleton(:fetch_all_names, proc { names }, &)
  end

  def self.with_moves_for(moves, &)
    stub_singleton(:moves_for, proc { |_number| moves }, cache: :@pokemon_moves_cache, &)
  end

  def self.with_move(move_map, &)
    stub_singleton(:move, proc { |name| move_map[name] }, cache: :@move_cache, &)
  end

  def self.with_available_move_names(names, &)
    stub_singleton(:available_move_names, proc { |_number| names }, cache: :@available_moves_cache, &)
  end

  def self.with_type(table, &)
    stub_singleton(:fetch_type_json, proc { |name| table[name] }, cache: :@type_relations, &)
  end
end
