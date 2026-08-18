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
    consumables = ItemCatalog.all.select { |item| item.category == "consumable" }
    assert consumables.size >= 3
    assert(consumables.all? { |item| item.category == "consumable" })
  end

  def test_item_accepts_stat_and_multiplier
    item = Item.new(
      name: "choice-band", display_name: "Choice Band", category: "held",
      price: 80, stat: "Attack", multiplier: 1.5
    )

    assert_equal "Attack", item.stat
    assert_equal 1.5, item.multiplier
  end

  def test_item_stat_and_multiplier_default_to_nil_and_one
    item = Item.new(name: "potion", display_name: "Pocao", category: "consumable", price: 20)

    assert_nil item.stat
    assert_equal 1.0, item.multiplier
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

  def test_catalog_has_held_items_with_stat_multiplier_and_category
    choice_band = ItemCatalog.find("choice-band")
    choice_scarf = ItemCatalog.find("choice-scarf")

    refute_nil choice_band
    assert_equal "held", choice_band.category
    assert_equal "Attack", choice_band.stat
    assert_equal 1.5, choice_band.multiplier

    refute_nil choice_scarf
    assert_equal "held", choice_scarf.category
    assert_equal "Speed", choice_scarf.stat
    assert_equal 1.5, choice_scarf.multiplier
  end

  def test_can_hold_returns_only_held_category_items
    held_names = ItemCatalog.can_hold.map(&:name)

    assert_includes held_names, "choice-band"
    assert_includes held_names, "choice-scarf"
    refute_includes held_names, "potion"
    assert(ItemCatalog.can_hold.all? { |item| item.category == "held" })
  end
end
