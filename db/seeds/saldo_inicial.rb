# frozen_string_literal: true

require "pg"
require_relative "../../lib/wallet_repository"

class SaldoInicial
  INITIAL_BALANCE = 200

  def self.call(user_id: "seed-shop", db_url: ENV.fetch("DATABASE_URL", nil))
    database = db_url || WalletRepository::DEFAULT_DATABASE_URL
    connection = PG.connect(database)
    connection.exec_params(
      "INSERT INTO wallet (user_id, balance) VALUES ($1, $2) " \
      "ON CONFLICT (user_id) DO UPDATE SET balance = EXCLUDED.balance, updated_at = now()",
      [user_id, INITIAL_BALANCE]
    )
  ensure
    connection&.close
  end
end
