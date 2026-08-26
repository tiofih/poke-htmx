# frozen_string_literal: true

require_relative "item_catalog"
require_relative "team_item_operations"
require_relative "team_repository"
require_relative "inventory_repository"
require_relative "wallet_repository"

class TeamService
  include TeamItemOperations

  def initialize(api:, team:, progression:, inventory:, wallet:, catalog: ItemCatalog)
    @api_provider = api
    @team = team
    @progression = progression
    @inventory = inventory
    @wallet = wallet
    @catalog = catalog
  end

  def manage_data(user_id)
    members = @team.all(user_id)
    {
      members: members,
      available_moves: moves_for(user_id, members),
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

  def preview_move(member, selected, toggle, available_moves)
    current = Array(selected)
    return [current, nil] unless member && available_name?(member, toggle, available_moves)

    return [current - [toggle], nil] if current.include?(toggle)

    limit = TeamRepository::MAX_MOVES_PER_POKEMON
    return [current, "Selecione no máximo #{limit} golpes."] if current.size >= limit

    [current + [toggle], nil]
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

  def remove_member(user_id, id)
    member = @team.all(user_id).find { |poke| poke.id.to_s == id.to_s }
    return false unless member

    restore_items(user_id, member)
    @team.remove(user_id, id)
  end

  def reset(user_id)
    @team.all(user_id).each { |member| restore_items(user_id, member) }
    @team.clear(user_id)
  end

  private

  def restore_items(user_id, member)
    @inventory.add(user_id, member.assigned_item, 1) unless member.assigned_item.to_s.empty?
    @inventory.add(user_id, member.held_item, 1) unless member.held_item.to_s.empty?
  end

  def available_name?(member, name, available_moves)
    available_moves[member.id].to_a.any? { |move| move[:name] == name }
  end

  def api
    @api_provider.call
  end

  def moves_for(user_id, members)
    members.to_h { |member| [member.id, gated_moves(user_id, member)] }
  end

  def gated_moves(user_id, member)
    learnable = api.learnable_moves(member.number).to_a
    gated = learnable.select { |move| move[:level] <= member_level(user_id, member) }
    gated + saved_moves_outside_gated(member, learnable, gated)
  end

  def saved_moves_outside_gated(member, learnable, gated)
    by_name = learnable.to_h { |move| [move[:name], move] }
    member.moves.to_a.reject { |name| gated.any? { |move| move[:name] == name } }.map do |name|
      known = by_name[name]
      known ? { level: known[:level], name: name } : { name: name }
    end
  end

  def member_level(user_id, member)
    @progression.get(user_id, member.id)&.fetch(:level) || 1
  end

  def move_choice_error(member, selected, available_moves)
    limit = TeamRepository::MAX_MOVES_PER_POKEMON
    return "Selecione no máximo #{limit} golpes." if selected.size > limit

    available = member ? available_moves[member.id].to_a.map { |move| move[:name] } : []
    return "Golpe não disponível para este Pokémon." if selected.any? { |move| !available.include?(move) }

    nil
  end
end
