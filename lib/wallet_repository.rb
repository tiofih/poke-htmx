# frozen_string_literal: true

require "pg"
require_relative "connection_registry"

class WalletRepository
  DEFAULT_DATABASE_URL = "postgres://pokedex:pokedex@localhost:5432/pokedex"

  def initialize(db_url: ENV["DATABASE_URL"] || DEFAULT_DATABASE_URL)
    @db_url = db_url
  end

  def balance(user_id)
    row = connection.exec_params("SELECT balance FROM wallet WHERE user_id = $1", [user_id]).first
    row ? row["balance"].to_i : 0
  end

  def grant(user_id, amount)
    return balance(user_id) if amount.nil? || amount <= 0

    connection.exec_params(
      "INSERT INTO wallet (user_id, balance) VALUES ($1, $2) " \
      "ON CONFLICT (user_id) DO UPDATE SET balance = wallet.balance + EXCLUDED.balance, " \
      "updated_at = now()",
      [user_id, amount]
    )
    balance(user_id)
  end

  def spend(user_id, amount)
    current = balance(user_id)
    return current if amount.nil? || amount <= 0 || current < amount

    connection.exec_params(
      "UPDATE wallet SET balance = balance - $2, updated_at = now() " \
      "WHERE user_id = $1",
      [user_id, amount]
    )
    balance(user_id)
  end

  private

  def connection
    @connection ||= ConnectionRegistry.register(self, PG.connect(@db_url))
  end
end
