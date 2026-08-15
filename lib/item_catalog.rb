# frozen_string_literal: true

require_relative "item"

class ItemCatalog
  ITEM_CATALOG = [
    Item.new(name: "potion", display_name: "Pocao", category: "consumable", price: 20),
    Item.new(name: "super-potion", display_name: "Super Pocao", category: "consumable", price: 50),
    Item.new(name: "hyper-potion", display_name: "Hiper Pocao", category: "consumable", price: 100)
  ].freeze

  def self.all
    ITEM_CATALOG
  end

  def self.find(name)
    ITEM_CATALOG.find { |item| item.name == name }
  end
end
