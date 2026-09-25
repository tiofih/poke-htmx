# frozen_string_literal: true

ENV["RACK_ENV"] = "test"
# Isola o cache persistente da PokéAPI em teste para não carregar o arquivo de
# 322M/4324 chaves de dev/prod (PersistentJsonStore faz JSON.parse síncrono no boot).
# Sem isso cada `docker compose run` paga ~3.26s de parse (medido em 2026-08-26).
ENV["POKEAPI_CACHE_PATH"] ||= "tmp/test_pokeapi_cache.json"
ENV["POKERATING_CACHE_PATH"] ||= "tmp/test_pokemon_rating_cache.json"

# Suíte roda num banco SEPARADO do app (pokedex_test), para não disputar locks/
# dados com o Puma ativo (flakiness/hang). Deriva do DATABASE_URL do ambiente
# (container `web`, host `db`) trocando só o nome do banco.
ENV["DATABASE_URL"] = (ENV["DATABASE_URL"] || "postgres://pokedex:pokedex@db:5432/pokedex")
                      .sub(%r{/[^/]*$}, "/pokedex_test")

require "minitest/autorun"
require "rack/test"
require "pg"

require_relative "../lib/connection_registry"
require_relative "../lib/pokemon"
require_relative "../lib/gateways/poke_api"
require_relative "../lib/team_repository"
require_relative "test_support"
require_relative "poke_api_fake"
require_relative "vcr_setup"

module Minitest
  class Test
    # Garante banco+schema antes de QUALQUER teste (idempotente, paga 1x por
    # processo). Sem isso a ordem aleatoria do Minitest derruba o primeiro
    # teste a tocar o banco — ex.: SeedTeamTest caindo antes de todo
    # TestDatabase.setup! ("database pokedex_test does not exist", CI 0093).
    def before_setup
      super
      TestDatabase.setup!
    end

    def after_teardown
      super
      ConnectionRegistry.close_all!
    end
  end
end

module TestDatabase # rubocop:disable Metrics/ModuleLength
  @setup_done = false
  @setup_mutex = Mutex.new

  def self.setup!
    @setup_mutex.synchronize do
      return if @setup_done

      ensure_database!
      with_db do |connection|
        connection.exec("SET client_min_messages TO warning")
        connection.exec(File.read(File.expand_path("../db/schema.sql", __dir__)))
        Dir[File.expand_path("../db/migrations/*.sql", __dir__)].each do |migration|
          connection.exec(File.read(migration))
        end
      end
      @setup_done = true
    end
  end

  def self.reset_setup!
    @setup_mutex.synchronize { @setup_done = false }
  end

  def self.ensure_database!
    connection = PG.connect(maintenance_url)
    exists = connection.exec_params(
      "SELECT 1 FROM pg_database WHERE datname = $1", [test_database_name]
    ).ntuples.positive?
    connection.exec("CREATE DATABASE #{test_database_name}") unless exists
  ensure
    connection&.close
  end

  def self.test_database_name
    ENV.fetch("DATABASE_URL").split("/").last
  end

  def self.maintenance_url
    ENV.fetch("DATABASE_URL").sub(%r{/[^/]*$}, "/postgres")
  end

  def self.clear_team!
    tables = "team_pokemons, team_pokemon_progress, battles, wallet, inventory"
    with_db { |connection| connection.exec("TRUNCATE #{tables}") }
  end

  def self.inventory_quantity(user_id, item_name)
    with_db do |connection|
      row = connection.exec_params(
        "SELECT quantity FROM inventory WHERE user_id = $1 AND item_name = $2", [user_id, item_name]
      ).first
      row ? row["quantity"].to_i : 0
    end
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

  def self.team_row(name, user_id)
    with_db do |connection|
      connection.exec_params(
        "SELECT * FROM team_pokemons WHERE name = $1 AND user_id = $2",
        [name, user_id]
      ).first
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

  def self.with_base_forms(map, &)
    with_gateway(base_form: map, &)
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

  def self.with_stone_evolutions(data, &)
    with_gateway(stone_evolutions: data, &)
  end

  def self.with_learnable_moves(data, &)
    with_gateway(learnable_moves: data, &)
  end

  def self.with_generation(map, &)
    with_gateway(generation_for: map, &)
  end

  def self.with_pokemon_names_by_type(map, &)
    normalized = map.transform_keys { |k| k.to_s.strip.downcase }
    with_gateway(pokemon_names_by_type: normalized, &)
  end

  def self.with_type_names(map, &)
    with_pokemon_names_by_type(map, &)
  end
end
