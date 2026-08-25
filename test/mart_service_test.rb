# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/inventory_repository"
require_relative "../lib/wallet_repository"
require_relative "../lib/item_catalog"
require_relative "../lib/mart_service"

module MartServiceTestHelpers
  def setup
    TestDatabase.setup!
    TestDatabase.clear_team!
    @inventory = InventoryRepository.new
    @wallet = WalletRepository.new
    @service = MartService.new(inventory: @inventory, wallet: @wallet)
  end
end

class MartServiceTest < Minitest::Test
  include MartServiceTestHelpers

  def test_buy_item_outside_catalog_is_rejected
    result = @service.buy("user-a", "master-ball")

    assert_equal false, result[:bought]
    assert_match(/não disponível/i, result[:notice])
  end

  def test_buy_with_quantity_zero_is_rejected
    @wallet.grant("user-a", 100)

    result = @service.buy("user-a", "potion", 0)

    assert_equal false, result[:bought]
    assert_match(/quantidade inválida/i, result[:notice])
  end

  def test_buy_with_nil_quantity_is_rejected
    @wallet.grant("user-a", 100)

    result = @service.buy("user-a", "potion", nil)

    assert_equal false, result[:bought]
    assert_match(/quantidade inválida/i, result[:notice])
  end

  def test_buy_debits_wallet_and_adds_inventory
    @wallet.grant("user-a", 100)

    result = @service.buy("user-a", "potion")

    assert_equal true, result[:bought]
    assert_equal 20, result[:cost]
    assert_equal 80, result[:balance]
    assert_match(/comprado/i, result[:notice])
    assert_equal 1, @inventory.count("user-a", "potion")
    assert_equal 80, @wallet.balance("user-a")
  end

  def test_buy_multiple_quantity_sums_cost_and_inventory
    @wallet.grant("user-a", 100)

    result = @service.buy("user-a", "potion", 2)

    assert_equal true, result[:bought]
    assert_equal 40, result[:cost], "2 pocoes a 20"
    assert_equal 60, result[:balance]
    assert_equal 2, @inventory.count("user-a", "potion")
    assert_equal "potion", result[:item].name
    assert_equal 2, result[:quantity]
  end

  def test_buy_with_insufficient_balance_does_not_debit_or_add
    @wallet.grant("user-a", 10)

    result = @service.buy("user-a", "potion")

    assert_equal false, result[:bought]
    assert_equal 20, result[:cost]
    assert_equal 10, result[:balance]
    assert_match(/insuficiente/i, result[:notice])
    assert_equal 0, @inventory.count("user-a", "potion")
    assert_equal 10, @wallet.balance("user-a")
  end

  def test_buy_beyond_catalog_price_scales_balance_check
    @wallet.grant("user-a", 100)

    result = @service.buy("user-a", "hyper-potion")

    assert_equal true, result[:bought]
    assert_equal 100, result[:cost]
    assert_equal 0, result[:balance]
  end
end

class MartServiceSellTest < Minitest::Test
  include MartServiceTestHelpers

  def test_sell_credits_wallet_and_debits_inventory
    @inventory.add("user-a", "potion", 2)

    result = @service.sell("user-a", "potion", 1)

    assert_equal true, result[:sold]
    assert_equal 10, result[:proceeds], "potion (20) vende por metade: 10"
    assert_equal 10, result[:balance]
    assert_match(/vendido/i, result[:notice])
    assert_equal 1, @inventory.count("user-a", "potion")
    assert_equal 10, @wallet.balance("user-a")
  end

  def test_sell_multiple_quantity_sums_proceeds
    @inventory.add("user-a", "choice-band", 2)

    result = @service.sell("user-a", "choice-band", 2)

    assert_equal true, result[:sold]
    assert_equal 80, result[:proceeds], "2 choice-band (80) vendem por 40 cada"
    assert_equal 80, result[:balance]
    assert_equal 0, @inventory.count("user-a", "choice-band")
    assert_equal 80, @wallet.balance("user-a")
  end

  def test_sell_item_outside_catalog_is_rejected
    result = @service.sell("user-a", "master-ball")

    assert_equal false, result[:sold]
    assert_match(/não disponível/i, result[:notice])
  end

  def test_sell_with_quantity_zero_is_rejected
    @inventory.add("user-a", "potion", 2)

    result = @service.sell("user-a", "potion", 0)

    assert_equal false, result[:sold]
    assert_match(/quantidade inválida/i, result[:notice])
    assert_equal 2, @inventory.count("user-a", "potion")
  end

  def test_sell_with_insufficient_stock_does_not_credit_or_debit
    @inventory.add("user-a", "potion", 1)

    result = @service.sell("user-a", "potion", 3)

    assert_equal false, result[:sold]
    assert_match(/estoque/i, result[:notice])
    assert_equal 1, @inventory.count("user-a", "potion")
    assert_equal 0, @wallet.balance("user-a")
  end
end
