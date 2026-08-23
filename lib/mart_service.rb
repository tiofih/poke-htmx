# frozen_string_literal: true

require_relative "item_catalog"

class MartService
  def initialize(inventory:, wallet:, catalog: ItemCatalog)
    @inventory = inventory
    @wallet = wallet
    @catalog = catalog
  end

  def buy(user_id, item_name, quantity = 1)
    return invalid_notice unless @catalog.find(item_name)
    return quantity_invalid_notice if invalid_quantity?(quantity)

    item = @catalog.find(item_name)
    cost = item.price * quantity.to_i
    balance = @wallet.balance(user_id)
    return insufficient_notice(item, quantity, cost, balance) if balance < cost

    purchase_result(user_id, item, quantity, cost)
  end

  private

  def purchase_result(user_id, item, quantity, cost)
    @inventory.add(user_id, item.name, quantity.to_i)
    new_balance = @wallet.spend(user_id, cost)
    {
      bought: true,
      kind: :success,
      **purchase_fields(item, quantity.to_i, cost, new_balance),
      notice: purchase_notice(item, quantity.to_i, cost, new_balance)
    }
  end

  def invalid_notice
    { bought: false, kind: :error, notice: "Item não disponível." }
  end

  def quantity_invalid_notice
    { bought: false, kind: :error, notice: "Quantidade inválida." }
  end

  def insufficient_notice(item, quantity, cost, balance)
    {
      bought: false,
      kind: :error,
      item: item,
      quantity: quantity.to_i,
      cost: cost,
      balance: balance,
      notice: "Dinheiro insuficiente para comprar (custo #{cost}, saldo #{balance})."
    }
  end

  def invalid_quantity?(quantity)
    quantity.nil? || quantity.to_i <= 0
  end

  def purchase_fields(item, qty, cost, balance)
    { item: item, quantity: qty, cost: cost, balance: balance }
  end

  def purchase_notice(item, qty, cost, balance)
    "Comprado #{qty} × #{item.display_name} por #{cost} de dinheiro. Saldo: #{balance}."
  end
end
