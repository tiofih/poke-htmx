# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/item"
require_relative "../lib/item_catalog"

class ItemCatalogTest < Minitest::Test
  def test_item_has_all_attributes
    item = Item.new(name: "potion", display_name: "Pocao", category: "consumable", price: 20)

    assert_equal "potion", item.name
    assert_equal "Pocao", item.display_name
    assert_equal "consumable", item.category
    assert_equal 20, item.price
    assert_equal 0, item.heal_amount, "heal_amount default zero"
  end

  def test_item_accepts_heal_amount
    item = Item.new(name: "potion", display_name: "Pocao", category: "consumable", price: 20, heal_amount: 20)

    assert_equal 20, item.heal_amount
  end

  def test_item_catalog_has_at_least_three_consumable_items
    assert ItemCatalog.all.size >= 3
    categories = ItemCatalog.all.map(&:category)
    assert(categories.all? { |category| category == "consumable" })
  end

  def test_all_returns_the_catalog
    assert_equal ItemCatalog::ITEM_CATALOG, ItemCatalog.all
  end

  def test_find_returns_item_by_name
    item = ItemCatalog.find("potion")

    refute_nil item
    assert_equal "potion", item.name
    assert_equal 20, item.price
  end

  def test_find_returns_item_with_heal_amount
    assert_equal 20, ItemCatalog.find("potion").heal_amount
    assert_equal 50, ItemCatalog.find("super-potion").heal_amount
    assert_equal 100, ItemCatalog.find("hyper-potion").heal_amount
  end

  def test_find_returns_nil_for_unknown_name
    assert_nil ItemCatalog.find("master-ball")
  end
end
