# frozen_string_literal: true

require_relative "item_catalog"
require_relative "sell_policy"

class MartService
  def initialize(inventory:, wallet:, catalog: ItemCatalog, policy: SellPolicy.new)
    @inventory = inventory
    @wallet = wallet
    @catalog = catalog
    @policy = policy
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

  def sell(user_id, item_name, quantity = 1)
    item = @catalog.find(item_name)
    return sell_invalid_notice unless item
    return sell_quantity_invalid_notice if invalid_quantity?(quantity)

    available = @inventory.count(user_id, item_name)
    return insufficient_stock_notice(item, quantity) if available < quantity.to_i

    sell_result(user_id, item, quantity.to_i)
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

  def sell_invalid_notice
    { sold: false, kind: :error, notice: "Item não disponível." }
  end

  def sell_quantity_invalid_notice
    { sold: false, kind: :error, notice: "Quantidade inválida." }
  end

  def insufficient_stock_notice(item, quantity)
    {
      sold: false, kind: :error, item: item, quantity: quantity.to_i,
      notice: "Estoque insuficiente para vender (#{quantity.to_i} × #{item.display_name})."
    }
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

  def sell_result(user_id, item, quantity)
    proceeds = @policy.sell_price(item) * quantity
    @inventory.use(user_id, item.name, quantity)
    new_balance = @wallet.grant(user_id, proceeds)
    {
      sold: true, kind: :success,
      item: item, quantity: quantity, proceeds: proceeds, balance: new_balance,
      notice: "Vendido #{quantity} × #{item.display_name} por #{proceeds} de dinheiro. Saldo: #{new_balance}."
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
