# frozen_string_literal: true

require "pg"
require_relative "connection_registry"
require_relative "item_catalog"

class InventoryRepository
  DEFAULT_DATABASE_URL = "postgres://pokedex:pokedex@localhost:5432/pokedex"

  def initialize(db_url: ENV["DATABASE_URL"] || DEFAULT_DATABASE_URL)
    @db_url = db_url
  end

  def all(user_id)
    connection.exec_params(
      "SELECT item_name, quantity FROM inventory WHERE user_id = $1 ORDER BY item_name",
      [user_id]
    ).map { |row| { name: row["item_name"], quantity: row["quantity"].to_i } }
  end

  def add(user_id, item_name, quantity)
    return count(user_id, item_name) if invalid_quantity?(quantity)
    return count(user_id, item_name) unless ItemCatalog.find(item_name)

    connection.exec_params(
      "INSERT INTO inventory (user_id, item_name, quantity) VALUES ($1, $2, $3) " \
      "ON CONFLICT (user_id, item_name) DO UPDATE SET " \
      "quantity = inventory.quantity + EXCLUDED.quantity, updated_at = now()",
      [user_id, item_name, quantity]
    )
    count(user_id, item_name)
  end

  def count(user_id, item_name)
    row = connection.exec_params(
      "SELECT quantity FROM inventory WHERE user_id = $1 AND item_name = $2",
      [user_id, item_name]
    ).first
    row ? row["quantity"].to_i : 0
  end

  def use(user_id, item_name, quantity = 1)
    current = count(user_id, item_name)
    return current if invalid_quantity?(quantity) || current <= 0
    return current unless ItemCatalog.find(item_name)

    new_quantity = [current - quantity.to_i, 0].max
    connection.exec_params(
      "UPDATE inventory SET quantity = $3, updated_at = now() " \
      "WHERE user_id = $1 AND item_name = $2",
      [user_id, item_name, new_quantity]
    )
    new_quantity
  end

  private

  def invalid_quantity?(quantity)
    quantity.nil? || quantity <= 0
  end

  def connection
    ConnectionRegistry.connection_for(self, Thread.current.object_id, @db_url)
  end
end
