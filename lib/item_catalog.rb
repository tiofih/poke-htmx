# frozen_string_literal: true

require_relative "item"

class ItemCatalog
  ITEM_CATALOG = [
    Item.new(name: "potion", display_name: "Pocao", category: "consumable", price: 20, heal_amount: 20),
    Item.new(name: "super-potion", display_name: "Super Pocao", category: "consumable",
             price: 50, heal_amount: 50),
    Item.new(name: "hyper-potion", display_name: "Hiper Pocao", category: "consumable",
             price: 100, heal_amount: 100),
    Item.new(name: "choice-band", display_name: "Choice Band", category: "held", price: 80,
             stat: "Attack", multiplier: 1.5),
    Item.new(name: "choice-scarf", display_name: "Choice Scarf", category: "held", price: 80,
             stat: "Speed", multiplier: 1.5)
  ].freeze

  def self.all
    ITEM_CATALOG
  end

  def self.find(name)
    ITEM_CATALOG.find { |item| item.name == name }
  end

  def self.can_hold
    ITEM_CATALOG.select { |item| item.category == "held" }
  end
end
