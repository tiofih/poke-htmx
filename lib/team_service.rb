# frozen_string_literal: true

require_relative "item_catalog"
require_relative "team_repository"
require_relative "inventory_repository"
require_relative "wallet_repository"

class TeamService
  def initialize(api:, team:, inventory:, wallet:, catalog: ItemCatalog)
    @api_provider = api
    @team = team
    @inventory = inventory
    @wallet = wallet
    @catalog = catalog
  end

  def manage_data(user_id)
    members = @team.all(user_id)
    {
      members: members,
      available_moves: moves_for(members),
      inventory: @inventory.all(user_id),
      balance: @wallet.balance(user_id)
    }
  end

  def save_moves(user_id, member, selected, available_moves)
    error = move_choice_error(member, selected, available_moves)
    return error if error
    return nil unless member

    @team.set_moves(user_id, member.id, selected)
    nil
  end

  def assign_item(user_id, member, item_name)
    return nil unless member
    return clear_item(user_id, member) if item_name.empty?

    assign_catalog_item(user_id, member, item_name)
  end

  def assign_held_item(user_id, member, item_name)
    return nil unless member
    return clear_held_item(user_id, member) if item_name.empty?

    assign_held_catalog_item(user_id, member, item_name)
  end

  private

  def api
    @api_provider.call
  end

  def moves_for(members)
    members.to_h { |member| [member.id, api.available_move_names(member.number)] }
  end

  def move_choice_error(member, selected, available_moves)
    limit = TeamRepository::MAX_MOVES_PER_POKEMON
    return "Selecione no máximo #{limit} golpes." if selected.size > limit

    available = member ? available_moves[member.id] : []
    return "Golpe não disponível para este Pokémon." if selected.any? { |move| !available.include?(move) }

    nil
  end

  def clear_item(user_id, member)
    @team.assign_item(user_id, member.id, nil)
    nil
  end

  def assign_catalog_item(user_id, member, item_name)
    item = @catalog.find(item_name)
    return "Item não disponível para atribuição." unless item && item.heal_amount.to_i.positive?

    @team.assign_item(user_id, member.id, item_name)
    nil
  end

  def clear_held_item(user_id, member)
    @team.assign_held_item(user_id, member.id, nil)
    nil
  end

  def assign_held_catalog_item(user_id, member, item_name)
    item = @catalog.find(item_name)
    unless item && item.category == "held" && @inventory.count(user_id, item_name).positive?
      return "Item não disponível para equipar."
    end

    @team.assign_held_item(user_id, member.id, item_name)
    nil
  end
end
