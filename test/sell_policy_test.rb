# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/item_catalog"
require_relative "../lib/sell_policy"

class SellPolicyTest < Minitest::Test
  def setup
    @policy = SellPolicy.new
  end

  def test_sell_price_is_half_of_buy_price
    assert_equal 10, @policy.sell_price(ItemCatalog.find("potion"))
    assert_equal 25, @policy.sell_price(ItemCatalog.find("super-potion"))
    assert_equal 50, @policy.sell_price(ItemCatalog.find("hyper-potion"))
  end

  def test_sell_price_applies_to_held_items
    assert_equal 40, @policy.sell_price(ItemCatalog.find("choice-band"))
    assert_equal 40, @policy.sell_price(ItemCatalog.find("choice-scarf"))
  end
end
