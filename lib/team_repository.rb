# frozen_string_literal: true

require "pg"
require_relative "pokemon"

# rubocop:disable Metrics/ClassLength
class TeamRepository
  DEFAULT_DATABASE_URL = "postgres://pokedex:pokedex@localhost:5432/pokedex"
  MAX_TEAM_SIZE = 6
  MAX_MOVES_PER_POKEMON = 4

  class TeamFullError < StandardError; end
  class DuplicateError < StandardError; end

  def initialize(db_url: ENV["DATABASE_URL"] || DEFAULT_DATABASE_URL)
    @db_url = db_url
  end

  # rubocop:disable Metrics/MethodLength
  def all(user_id)
    connection.exec_params(
      "SELECT * FROM team_pokemons WHERE user_id = $1 ORDER BY slot",
      [user_id]
    ).map do |row|
      Pokemon.new(
        id: row["id"],
        name: row["name"],
        sprite: row["sprite"],
        number: row["number"],
        slot: row["slot"],
        moves: parse_moves(row["moves"])
      )
    end
  end
  # rubocop:enable Metrics/MethodLength

  def add(user_id, pokemon)
    slot = next_free_slot(user_id)
    raise TeamFullError, "Time cheio (máx. #{MAX_TEAM_SIZE})." if slot.nil?
    raise DuplicateError, "#{pokemon.name} já está no time." if duplicate?(user_id, pokemon.number)

    connection.exec_params(
      "INSERT INTO team_pokemons (user_id, name, sprite, number, slot, moves) VALUES ($1, $2, $3, $4, $5, $6)",
      [user_id, pokemon.name, pokemon.sprite, pokemon.number, slot, array_literal(pokemon.moves)]
    )
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

    slot = removed["slot"].to_i
    connection.exec_params(
      "UPDATE team_pokemons SET slot = slot - 1 WHERE user_id = $1 AND slot > $2",
      [user_id, slot]
    )
  end

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
      (new_slot...from).reverse_each do |slot|
        increment_slot(user_id, slot)
      end
    else
      ((from + 1)..new_slot).each do |slot|
        decrement_slot(user_id, slot)
      end
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
    @connection ||= PG.connect(@db_url)
  end

  def parse_moves(value)
    return [] if value.nil? || value.empty?

    value[1..-2].split(",")
  end

  def array_literal(names)
    "{#{names.join(',')}}"
  end
end
# rubocop:enable Metrics/ClassLength
