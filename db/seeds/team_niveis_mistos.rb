# frozen_string_literal: true

require_relative "../../lib/seed_team"

class TeamNiveisMistos
  def self.call(user_id: "seed-mixed", db_url: ENV.fetch("DATABASE_URL", nil)) # rubocop:disable Metrics/MethodLength
    seed = SeedTeam.new(user_id: user_id, db_url: db_url)
    seed.clear!

    members = [
      { name: "charmander", number: 4,  moves: %w[ember scratch],
        level: 1,  experience: 0        },
      { name: "squirtle",   number: 7,  moves: %w[water-gun tackle],
        level: 5,  experience: 1_000    },
      { name: "bulbasaur",  number: 1,  moves: %w[vine-whip tackle],
        level: 10, experience: 4_500    },
      { name: "pikachu",    number: 25, moves: %w[thunder-shock quick-attack],
        level: 20, experience: 19_000   },
      { name: "eevee",      number: 133, moves: %w[tackle sand-attack],
        level: 35, experience: 59_500   },
      { name: "dratini",    number: 147, moves: %w[wrap thunder-wave],
        level: 50, experience: 122_500  }
    ]

    members.each_with_index { |m, i| seed.add_member(sprite: sprite_for(m[:number]), **m, slot: i + 1) }
  end

  def self.sprite_for(number)
    "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/other/official-artwork/#{number}.png"
  end
end
