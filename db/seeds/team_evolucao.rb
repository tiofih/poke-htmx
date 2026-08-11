# frozen_string_literal: true

require_relative "../../lib/seed_team"

class TeamEvolucao
  def self.call(user_id: "seed-evol", db_url: ENV.fetch("DATABASE_URL", nil)) # rubocop:disable Metrics/MethodLength
    seed = SeedTeam.new(user_id: user_id, db_url: db_url)
    seed.clear!

    members = [
      { name: "charmander", sprite: "", number: 4, moves: %w[ember scratch growl leer],
        level: 15, experience: 11_999 },
      { name: "charmeleon", sprite: "", number: 5, moves: %w[ember scratch dragon-rage leer],
        level: 35, experience: 62_999 },
      { name: "squirtle", sprite: "", number: 7,
        moves: %w[water-gun tackle tail-whip withdraw], level: 15, experience: 11_999 },
      { name: "bulbasaur", sprite: "", number: 1,
        moves: %w[vine-whip tackle growl leech-seed], level: 15, experience: 11_999 },
      { name: "ivysaur", sprite: "", number: 2, moves: %w[razor-leaf tackle vine-whip leech-seed],
        level: 31, experience: 49_599 },
      { name: "pikachu", sprite: "", number: 25,
        moves: %w[thunder-shock quick-attack thunderbolt slam], level: 30, experience: 46_499 }
    ]

    members.each_with_index { |m, i| seed.add_member(**m, slot: i + 1) }
  end
end
