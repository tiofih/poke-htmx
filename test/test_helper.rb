# frozen_string_literal: true

ENV["RACK_ENV"] = "test"
ENV["DATABASE_URL"] ||= "postgres://pokedex:pokedex@localhost:5432/pokedex"

require "minitest/autorun"
require "rack/test"
require "pg"

require_relative "../lib/pokemon"
require_relative "../lib/gateways/poke_api"
require_relative "../lib/team_repository"
require_relative "test_support"
require_relative "poke_api_fake"

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
    with_db { |connection| connection.exec("TRUNCATE team_pokemons, team_pokemon_progress, battles, wallet") }
  end

  def self.clear_wallet!
    with_db { |connection| connection.exec("TRUNCATE wallet") }
  end

  def self.wallet_balance(user_id)
    with_db do |connection|
      row = connection.exec_params("SELECT balance FROM wallet WHERE user_id = $1", [user_id]).first
      row ? row["balance"].to_i : 0
    end
  end

  def self.clear_battles!
    with_db { |connection| connection.exec("TRUNCATE battles") }
  end

  def self.battle_rows(user_id)
    with_db do |connection|
      connection.exec_params(
        "SELECT * FROM battles WHERE user_id = $1 ORDER BY id",
        [user_id]
      ).to_a
    end
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

  def self.progress_row(team_pokemon_id)
    with_db do |connection|
      connection.exec_params(
        "SELECT * FROM team_pokemon_progress WHERE team_pokemon_id = $1",
        [team_pokemon_id]
      ).first
    end
  end

  def self.progress_count
    with_db do |connection|
      connection.exec("SELECT COUNT(*) FROM team_pokemon_progress").first["count"].to_i
    end
  end

  def self.distinct_user_ids
    with_db do |connection|
      connection.exec("SELECT DISTINCT user_id FROM team_pokemons").map { |row| row["user_id"] }
    end
  end

  def self.column_info(column)
    table_column_info("team_pokemons", column)
  end

  def self.table_exists?(table)
    with_db do |connection|
      connection.exec_params(
        "SELECT 1 FROM information_schema.tables WHERE table_name = $1",
        [table]
      ).ntuples.positive?
    end
  end

  def self.table_column_info(table, column)
    with_db do |connection|
      connection.exec_params(
        "SELECT is_nullable FROM information_schema.columns WHERE table_name = $1 AND column_name = $2",
        [table, column]
      ).first
    end
  end

  def self.primary_key(table, column)
    with_db do |connection|
      connection.exec_params(
        <<~SQL,
          SELECT 1 FROM information_schema.table_constraints tc
          JOIN information_schema.key_column_usage kcu ON tc.constraint_name = kcu.constraint_name
          WHERE tc.table_name = $1 AND tc.constraint_type = 'PRIMARY KEY' AND kcu.column_name = $2
        SQL
        [table, column]
      ).ntuples.positive?
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

  def self.index_with_columns(table, column_a, column_b)
    with_db do |connection|
      connection.exec_params(
        <<~SQL,
          SELECT 1 FROM pg_indexes
          WHERE tablename = $1
            AND indexdef ILIKE '%#{column_a}%'
            AND indexdef ILIKE '%#{column_b}%'
        SQL
        [table]
      ).ntuples.positive?
    end
  end
end

module PokeApiStub
  def self.with_gateway(**configs, &)
    merged = if defined?(Server) && Server.settings.api.is_a?(PokeApiFake)
               Server.settings.api.config.merge(configs)
             else
               configs
             end
    original_server = Server.settings.api if defined?(Server)
    original_instance = PokeApi.instance
    Server.set :api, PokeApiFake.new(**merged) if defined?(Server)
    PokeApi.instance = PokeApiFake.new(**merged)
    yield
  ensure
    Server.set :api, original_server if defined?(Server)
    PokeApi.instance = original_instance
  end

  def self.with_find(pokemon, &)
    with_gateway(find: pokemon, &)
  end

  def self.with_detail(pokemon, &)
    with_gateway(detail: pokemon, &)
  end

  def self.with_all_names(names, &)
    with_gateway(fetch_all_names: names, &)
  end

  def self.with_moves_for(moves, &)
    with_gateway(moves_for: moves, &)
  end

  def self.with_move(move_map, &)
    with_gateway(move: move_map, &)
  end

  def self.with_available_move_names(names, &)
    with_gateway(available_move_names: names, &)
  end

  def self.with_type(table, &)
    relations = table.each_with_object({}) do |(_name, json), acc|
      acc.merge!(PokeApiHttp.new.extract_type_relations(json)) if json
    end
    with_gateway(type_relations: relations, &)
  end

  def self.with_next_evolutions(data, &)
    with_gateway(next_evolutions: data, &)
  end

  def self.with_learnable_moves(data, &)
    with_gateway(learnable_moves: data, &)
  end
end
