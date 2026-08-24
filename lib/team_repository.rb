# frozen_string_literal: true

require "pg"
require_relative "connection_registry"
require_relative "pokemon"

module SlotOperations
  def move(user_id, id, new_slot)
    from = current_slot(user_id, id)
    return unless from && movable?(user_id, from, new_slot)

    connection.transaction do
      park_member(user_id, id)
      shift_slots(user_id, from, new_slot)
      assign_slot(user_id, id, new_slot)
    end
  end

  private

  def current_slot(user_id, id)
    row = connection.exec_params(
      "SELECT slot FROM team_pokemons WHERE id = $1 AND user_id = $2",
      [id, user_id]
    ).first
    row && row["slot"].to_i
  end

  def team_size(user_id)
    connection.exec_params(
      "SELECT COUNT(*) FROM team_pokemons WHERE user_id = $1",
      [user_id]
    ).first["count"].to_i
  end

  def movable?(user_id, from, new_slot)
    new_slot.between?(1, team_size(user_id)) && new_slot != from
  end

  def park_member(user_id, id)
    connection.exec_params(
      "UPDATE team_pokemons SET slot = -1 WHERE id = $1 AND user_id = $2",
      [id, user_id]
    )
  end

  def assign_slot(user_id, id, new_slot)
    connection.exec_params(
      "UPDATE team_pokemons SET slot = $1 WHERE id = $2 AND user_id = $3",
      [new_slot, id, user_id]
    )
  end

  def shift_slots(user_id, from, new_slot)
    if new_slot < from
      (new_slot...from).reverse_each { |slot| increment_slot(user_id, slot) }
    else
      ((from + 1)..new_slot).each { |slot| decrement_slot(user_id, slot) }
    end
  end

  def increment_slot(user_id, slot)
    connection.exec_params(
      "UPDATE team_pokemons SET slot = $1 WHERE user_id = $2 AND slot = $3",
      [slot + 1, user_id, slot]
    )
  end

  def decrement_slot(user_id, slot)
    connection.exec_params(
      "UPDATE team_pokemons SET slot = $1 WHERE user_id = $2 AND slot = $3",
      [slot - 1, user_id, slot]
    )
  end

  def reindex_after_removal(user_id, slot)
    connection.exec_params(
      "UPDATE team_pokemons SET slot = slot - 1 WHERE user_id = $1 AND slot > $2",
      [user_id, slot]
    )
  end
end

module EvolutionOperations
  def evolve(user_id, id, pokemon)
    updated = connection.exec_params(
      "UPDATE team_pokemons SET number = $3, name = $4, sprite = $5 " \
      "WHERE id = $1 AND user_id = $2 RETURNING id",
      [id, user_id, pokemon.number, pokemon.name, pokemon.sprite]
    ).first
    !updated.nil?
  rescue PG::UniqueViolation
    false
  end

  def learn_move(user_id, id, move_name)
    moves = saved_moves(user_id, id)
    return false unless moves
    return false unless learnable?(moves, move_name)

    persist_moves(user_id, id, moves + [move_name])
    true
  end

  private

  def saved_moves(user_id, id)
    row = connection.exec_params(
      "SELECT moves FROM team_pokemons WHERE id = $1 AND user_id = $2",
      [id, user_id]
    ).first
    row && parse_moves(row["moves"])
  end

  def learnable?(moves, move_name)
    !moves.include?(move_name) && moves.size < TeamRepository::MAX_MOVES_PER_POKEMON
  end

  def persist_moves(user_id, id, moves)
    connection.exec_params(
      "UPDATE team_pokemons SET moves = $3 WHERE id = $1 AND user_id = $2",
      [id, user_id, array_literal(moves)]
    )
  end
end

module ItemAssignmentOperations
  def assign_item(user_id, id, item_name)
    item = item_name.to_s.empty? ? nil : item_name
    connection.exec_params(
      "UPDATE team_pokemons SET assigned_item = $3 WHERE id = $1 AND user_id = $2",
      [id, user_id, item]
    )
  end

  def assign_held_item(user_id, id, item_name)
    item = item_name.to_s.empty? ? nil : item_name
    connection.exec_params(
      "UPDATE team_pokemons SET held_item = $3 WHERE id = $1 AND user_id = $2",
      [id, user_id, item]
    )
  end
end

class TeamRepository
  DEFAULT_DATABASE_URL = "postgres://pokedex:pokedex@localhost:5432/pokedex"
  MAX_TEAM_SIZE = 6
  MAX_MOVES_PER_POKEMON = 4

  class TeamFullError < StandardError; end
  class DuplicateError < StandardError; end

  include SlotOperations
  include EvolutionOperations
  include ItemAssignmentOperations

  def initialize(db_url: ENV["DATABASE_URL"] || DEFAULT_DATABASE_URL)
    @db_url = db_url
  end

  def all(user_id)
    connection.exec_params(
      "SELECT t.*, p.hp_max, p.hp_current " \
      "FROM team_pokemons t " \
      "LEFT JOIN team_pokemon_progress p ON p.team_pokemon_id = t.id " \
      "WHERE t.user_id = $1 ORDER BY t.slot",
      [user_id]
    ).map { |row| row_to_pokemon(row) }
  end

  def add(user_id, pokemon)
    slot = next_free_slot(user_id)
    raise TeamFullError, "Time cheio (máx. #{MAX_TEAM_SIZE})." if slot.nil?
    raise DuplicateError, "#{pokemon.name} já está no time." if duplicate?(user_id, pokemon.number)

    connection.transaction do
      create_progress(insert_team_member(user_id, pokemon, slot))
    end
  end

  def set_moves(user_id, id, moves)
    connection.exec_params(
      "UPDATE team_pokemons SET moves = $3 WHERE id = $1 AND user_id = $2",
      [id, user_id, array_literal(moves.first(MAX_MOVES_PER_POKEMON))]
    )
  end

  def remove(user_id, id)
    removed = connection.exec_params(
      "DELETE FROM team_pokemons WHERE id = $1 AND user_id = $2 RETURNING slot",
      [id, user_id]
    ).first
    return unless removed

    reindex_after_removal(user_id, removed["slot"].to_i)
  end

  private

  def insert_team_member(user_id, pokemon, slot)
    connection.exec_params(
      "INSERT INTO team_pokemons (user_id, name, sprite, number, slot, moves) VALUES " \
      "($1, $2, $3, $4, $5, $6) RETURNING id",
      [user_id, pokemon.name, pokemon.sprite, pokemon.number, slot, array_literal(pokemon.moves)]
    ).first["id"]
  end

  def create_progress(team_pokemon_id)
    connection.exec_params(
      "INSERT INTO team_pokemon_progress (team_pokemon_id, level, xp) VALUES ($1, 1, 0)",
      [team_pokemon_id]
    )
  end

  def row_to_pokemon(row)
    Pokemon.new(**team_member_attributes(row), hp_max: row["hp_max"], hp_current: row["hp_current"])
  end

  def team_member_attributes(row)
    {
      id: row["id"],
      name: row["name"],
      sprite: row["sprite"],
      number: row["number"],
      slot: row["slot"],
      assigned_item: row["assigned_item"],
      held_item: row["held_item"],
      moves: parse_moves(row["moves"])
    }
  end

  def next_free_slot(user_id)
    taken = connection.exec_params(
      "SELECT slot FROM team_pokemons WHERE user_id = $1 ORDER BY slot",
      [user_id]
    ).map { |row| row["slot"].to_i }
    (1..MAX_TEAM_SIZE).find { |slot| !taken.include?(slot) }
  end

  def duplicate?(user_id, number)
    connection.exec_params(
      "SELECT 1 FROM team_pokemons WHERE user_id = $1 AND number = $2",
      [user_id, number]
    ).ntuples.positive?
  end

  def connection
    ConnectionRegistry.connection_for(self, Thread.current.object_id, @db_url)
  end

  def parse_moves(value)
    return [] if value.nil? || value.empty?

    value[1..-2].split(",")
  end

  def array_literal(names)
    "{#{names.join(',')}}"
  end
end
