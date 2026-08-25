# frozen_string_literal: true

module TeamItemOperations
  private

  def clear_item(user_id, member)
    return nil if member.assigned_item.to_s.empty?

    @inventory.add(user_id, member.assigned_item, 1)
    @team.assign_item(user_id, member.id, nil)
    nil
  end

  def assign_catalog_item(user_id, member, item_name)
    return "Item não disponível para atribuição." unless consumable_item?(item_name)
    return nil if member.assigned_item.to_s == item_name
    return "Item sem estoque para equipar." unless in_stock?(user_id, item_name)

    assign_with_swap(
      user_id, item_name,
      previous: member.assigned_item,
      assigner: ->(name) { @team.assign_item(user_id, member.id, name) }
    )
  end

  def clear_held_item(user_id, member)
    return nil if member.held_item.to_s.empty?

    @inventory.add(user_id, member.held_item, 1)
    @team.assign_held_item(user_id, member.id, nil)
    nil
  end

  def assign_held_catalog_item(user_id, member, item_name)
    return "Item não disponível para equipar." unless held_item?(item_name)
    return nil if member.held_item.to_s == item_name
    return "Item sem estoque para equipar." unless in_stock?(user_id, item_name)

    assign_with_swap(
      user_id, item_name,
      previous: member.held_item,
      assigner: ->(name) { @team.assign_held_item(user_id, member.id, name) }
    )
  end

  def consumable_item?(item_name)
    item = @catalog.find(item_name)
    item && item.heal_amount.to_i.positive?
  end

  def held_item?(item_name)
    item = @catalog.find(item_name)
    item && item.category == "held"
  end

  def in_stock?(user_id, item_name)
    @inventory.count(user_id, item_name).positive?
  end

  def assign_with_swap(user_id, item_name, previous:, assigner:)
    @inventory.add(user_id, previous, 1) unless previous.to_s.empty?
    @inventory.use(user_id, item_name, 1)
    assigner.call(item_name)
    nil
  end
end
