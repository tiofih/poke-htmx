# frozen_string_literal: true

require_relative "item_catalog"

class ItemUsePolicy
  DEFAULT_THRESHOLD = 0.5

  def initialize(threshold: DEFAULT_THRESHOLD, catalog: ItemCatalog)
    @threshold = threshold
    @catalog = catalog
  end

  def decide(member:, stock:)
    missing = missing_hp(member)
    return nil unless urgent?(member, missing)

    pick_item(available_healing_items(stock), missing)&.name
  end

  def heal_amount(item_name)
    @catalog.find(item_name)&.heal_amount.to_i
  end

  private

  def missing_hp(member)
    member.hp_max.to_i - member.hp_current.to_i
  end

  def urgent?(member, missing)
    return false if missing <= 0 || member.hp_max.to_i <= 0

    member.hp_current / member.hp_max.to_f <= @threshold
  end

  def available_healing_items(stock)
    stock.filter_map do |name, quantity|
      item = @catalog.find(name)
      item if item && quantity.to_i.positive? && item.heal_amount.to_i.positive?
    end
  end

  def pick_item(options, missing)
    return nil if options.empty?

    covering = options.select { |item| item.heal_amount >= missing }
    if covering.empty?
      options.max_by(&:heal_amount)
    else
      covering.min_by(&:heal_amount)
    end
  end
end
