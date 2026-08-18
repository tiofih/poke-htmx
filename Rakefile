# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.pattern = "test/**/*_test.rb"
  t.warning = false
end

require "rubocop/rake_task"
RuboCop::RakeTask.new(:lint)

namespace :db do # rubocop:disable Metrics/BlockLength
  desc "Create tables from db/schema.sql and apply migrations in order"
  task :setup do
    require "pg"
    db_url = ENV["DATABASE_URL"] || "postgres://pokedex:pokedex@localhost:5432/pokedex"
    connection = PG.connect(db_url)
    connection.exec("SET client_min_messages TO warning")
    connection.exec(File.read("db/schema.sql"))
    Dir["db/migrations/*.sql"].each do |migration|
      connection.exec(File.read(migration))
    end
  ensure
    connection&.close
  end

  desc "Populate database with seed data for manual validation"
  task :seed do
    $LOAD_PATH.unshift(File.expand_path("lib", __dir__))
    seed_name = ENV.fetch("SEED", nil)
    user_id = ENV.fetch("USER_ID", nil)
    db_url = ENV.fetch("DATABASE_URL", nil)
    if seed_name
      seed_file = "db/seeds/#{seed_name}.rb"
      abort "Seed '#{seed_name}' não encontrada em #{seed_file}" unless File.exist?(seed_file)
      load seed_file
      klass = Object.const_get(seed_name.split("_").map(&:capitalize).join)
      kwargs = { user_id: user_id || "seed-custom" }
      kwargs[:db_url] = db_url if db_url
      klass.call(**kwargs)
      puts "Seed '#{seed_name}' aplicada para user_id=#{kwargs[:user_id]}."
    else
      Dir["db/seeds/*.rb"].each { |file| load file }
      kwargs = db_url ? { db_url: db_url } : {}
      TeamBasico.call(user_id: user_id || "seed-basic", **kwargs)
      TeamEvolucao.call(user_id: "seed-evol", **kwargs)
      TeamNiveisMistos.call(user_id: "seed-mixed", **kwargs)
      BatalhasHistorico.call(user_id: "seed-history", **kwargs)
      SaldoInicial.call(user_id: "seed-shop", **kwargs)
      TeamDuelo.call(**kwargs)
      puts "Seeds aplicadas: seed-basic, seed-evol, seed-mixed, seed-history, seed-shop, seed-strong, seed-weak."
    end
  end
end
