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
             stat: "Speed", multiplier: 1.5),
    Item.new(name: "fire-stone", display_name: "Pedra de Fogo", category: "stone", price: 80),
    Item.new(name: "water-stone", display_name: "Pedra de Agua", category: "stone", price: 80),
    Item.new(name: "thunder-stone", display_name: "Pedra de Trovao", category: "stone", price: 80),
    Item.new(name: "leaf-stone", display_name: "Pedra de Folha", category: "stone", price: 80),
    Item.new(name: "moon-stone", display_name: "Pedra Lunar", category: "stone", price: 80),
    Item.new(name: "sun-stone", display_name: "Pedra Solar", category: "stone", price: 80)
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
