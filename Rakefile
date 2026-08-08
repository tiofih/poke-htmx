# frozen_string_literal: true

require "rake/testtask"

Rake::TestTask.new(:test) do |t|
  t.libs << "test" << "lib"
  t.pattern = "test/**/*_test.rb"
  t.warning = false
end

require "rubocop/rake_task"
RuboCop::RakeTask.new(:lint)

namespace :db do
  desc "Create tables from db/schema.sql"
  task :setup do
    require "pg"
    db_url = ENV["DATABASE_URL"] || "postgres://pokedex:pokedex@localhost:5432/pokedex"
    connection = PG.connect(db_url)
    connection.exec("SET client_min_messages TO warning")
    connection.exec(File.read("db/schema.sql"))
  ensure
    connection&.close
  end
end
