# frozen_string_literal: true

require "pg"
require_relative "../../lib/battle_repository"

class BatalhasHistorico
  def self.call(user_id: "seed-history", db_url: ENV.fetch("DATABASE_URL", nil))
    repository = BattleRepository.new(db_url: db_url)
    clear_history!(user_id, db_url)

    records.each { |result, team| repository.add(user_id, result, team) }
  end

  def self.records
    [
      ["win", team([["pikachu", 25], ["bulbasaur", 1], ["charmander", 4]])],
      ["win", team([["squirtle", 7], ["eevee", 133], ["jigglypuff", 39]])],
      ["lose", team([["charizard", 6], ["blastoise", 9], ["venusaur", 3]])],
      ["draw", team([["gengar", 94], ["alakazam", 65], ["machamp", 68]])],
      ["win", team([["dratini", 147], ["snorlax", 143], ["lapras", 131]])],
      ["lose", team([["mewtwo", 150], ["mew", 151]])]
    ]
  end

  def self.team(members)
    members.map { |name, number| { number: number, name: name } }
  end

  def self.clear_history!(user_id, db_url)
    database = db_url || BattleRepository::DEFAULT_DATABASE_URL
    connection = PG.connect(database)
    connection.exec_params("DELETE FROM battles WHERE user_id = $1", [user_id])
  ensure
    connection&.close
  end
end
