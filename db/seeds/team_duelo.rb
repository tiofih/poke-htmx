# frozen_string_literal: true

require "pg"
require_relative "../../lib/seed_team"
require_relative "../../lib/wallet_repository"

# Seed: time forte x time fraco (Eco-4-C — validação de seguráveis).
# Uso: `./scripts/seed team_duelo` (ou `rake db:seed` completo).
#
# Cria dois usuários:
#   - `seed-strong` — time forte (níveis 15/20/25/30/35/40): batalha contra o
#     oponente nível 1 ceifa em poucas jogadas, deixando uso de choice-band/scarf
#     visível (vitória rápida).
#   - `seed-weak`  — time fraco (nível 1): equilibra contra o oponente nível 1 e
#     deixa ver o efeito dos seguráveis sem superar o oponente por muito.
# Ambos ganham saldo suficiente no Mart (400) para comprar os seguráveis
# (choice-band 80 + choice-scarf 80 = 160) e sobrar para poções de validação.
#
# Tabelas que toca: `team_pokemons` + `team_pokemon_progress` (via SeedTeam) e
# `wallet` (upsert).
#
# Em teste, o seed é rodado via script de teste dedicado (`test/seed_scripts_test.rb`)
# conectando no banco de teste; em dev, via `./scripts/seed` (banco de dev).

class TeamDuelo
  STRONG_USER = "seed-strong"
  WEAK_USER = "seed-weak"
  BALANCE = 400

  STRONG_TEAM = [
    { name: "dragonite", number: 149, moves: %w[dragon-claw wing-attack aqua-tail],
      level: 40, experience: 78_000 },
    { name: "tyranitar", number: 248, moves: %w[crunch stone-edge earthquake],
      level: 35, experience: 59_500 },
    { name: "garchomp", number: 445, moves: %w[dragon-claw earthquake crunch],
      level: 30, experience: 45_000 },
    { name: "salamence", number: 373, moves: %w[fly dragon-claw fire-fang],
      level: 25, experience: 29_500 },
    { name: "metagross", number: 376, moves: %w[metal-claw earthquake bullet-punch],
      level: 20, experience: 18_000 },
    { name: "charizard", number: 6, moves: %w[flamethrower wing-attack slash],
      level: 15, experience: 9_500 }
  ].freeze

  WEAK_TEAM = [
    { name: "rattata", number: 19, moves: %w[tackle tail-whip], level: 1, experience: 0 },
    { name: "pidgey", number: 16, moves: %w[tackle gust], level: 1, experience: 0 },
    { name: "caterpie", number: 10, moves: %w[bug-bite string-shot], level: 1, experience: 0 },
    { name: "magikarp", number: 129, moves: %w[splash], level: 1, experience: 0 },
    { name: "zubat", number: 41, moves: %w[leech-life], level: 1, experience: 0 },
    { name: "oddish", number: 43, moves: %w[absorb], level: 1, experience: 0 }
  ].freeze

  def self.call(db_url: ENV.fetch("DATABASE_URL", nil)) # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    strong = SeedTeam.new(user_id: STRONG_USER, db_url: db_url)
    weak = SeedTeam.new(user_id: WEAK_USER, db_url: db_url)
    strong.clear!
    weak.clear!

    STRONG_TEAM.each_with_index do |member, i|
      strong.add_member(sprite: sprite_for(member[:number]), **member, slot: i + 1)
    end
    WEAK_TEAM.each_with_index do |member, i|
      weak.add_member(sprite: sprite_for(member[:number]), **member, slot: i + 1)
    end

    seed_balance(STRONG_USER, db_url)
    seed_balance(WEAK_USER, db_url)
  end

  def self.seed_balance(user_id, db_url)
    database = db_url || WalletRepository::DEFAULT_DATABASE_URL
    connection = PG.connect(database)
    connection.exec_params(
      "INSERT INTO wallet (user_id, balance) VALUES ($1, $2) " \
      "ON CONFLICT (user_id) DO UPDATE SET balance = EXCLUDED.balance, updated_at = now()",
      [user_id, BALANCE]
    )
  ensure
    connection&.close
  end

  def self.sprite_for(number)
    "https://raw.githubusercontent.com/PokeAPI/sprites/master/sprites/pokemon/#{number}.png"
  end
end
