# frozen_string_literal: true

require_relative "../../lib/seed_team"

# Seed: time pronto para evoluir em 1 vitória (validação de evolução/aprendizado).
# Uso: `./scripts/seed team_evolucao`.
#
# Níveis 15/35/15/15/31/30 (média 24 → **banda A–S** do J3): batalha gera oponentes
# da **banda A–S** (espécies fortes, nível 1).

class TeamEvolucao
  def self.call(user_id: "seed-evol", db_url: ENV.fetch("DATABASE_URL", nil)) # rubocop:disable Metrics/MethodLength
    seed = SeedTeam.new(user_id: user_id, db_url: db_url)
    seed.clear!

    members = [
      { name: "charmander", number: 4, moves: %w[ember scratch growl leer],
        level: 15, experience: 11_999 },
      { name: "charmeleon", number: 5, moves: %w[ember scratch dragon-rage leer],
        level: 35, experience: 62_999 },
      { name: "squirtle", number: 7,
        moves: %w[water-gun tackle tail-whip withdraw], level: 15, experience: 11_999 },
      { name: "bulbasaur", number: 1,
        moves: %w[vine-whip tackle growl leech-seed], level: 15, experience: 11_999 },
      { name: "ivysaur", number: 2, moves: %w[razor-leaf tackle vine-whip leech-seed],
        level: 31, experience: 49_599 },
      { name: "pikachu", number: 25,
        moves: %w[thunder-shock quick-attack thunderbolt slam], level: 30, experience: 46_499 }
    ]

    members.each_with_index { |m, i| seed.add_member(sprite: sprite_for(m[:number]), **m, slot: i + 1) }
  end

  def self.sprite_for(number)
    "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/#{number}.png"
  end
end
