# frozen_string_literal: true

require_relative "../../lib/seed_team"

class TeamBasico
  def self.call(user_id: "seed-basic", db_url: ENV.fetch("DATABASE_URL", nil))
    seed = SeedTeam.new(user_id: user_id, db_url: db_url)
    seed.clear!

    [
      { name: "charmander", sprite: "", number: 4, moves: %w[ember scratch growl leer] },
      { name: "squirtle", sprite: "", number: 7, moves: %w[water-gun tackle tail-whip withdraw] },
      { name: "bulbasaur", sprite: "", number: 1, moves: %w[vine-whip tackle growl leech-seed] },
      { name: "pikachu", sprite: "", number: 25, moves: %w[thunder-shock quick-attack tail-whip growl] },
      { name: "eevee", sprite: "", number: 133, moves: %w[tackle tail-whip sand-attack growl] },
      { name: "dratini", sprite: "", number: 147, moves: %w[wrap leer thunder-wave twister] }
    ].each_with_index { |m, i| seed.add_member(**m, slot: i + 1) }
  end
end
