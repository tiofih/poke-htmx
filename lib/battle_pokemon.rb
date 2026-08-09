# frozen_string_literal: true

require "dry-struct"
require_relative "pokemon"
require_relative "move"

class BattlePokemon < Dry::Struct
  BC_HP = Types::Coercible::Integer

  attribute :number, Types::Coercible::Integer
  attribute :name, Types::Strict::String
  attribute :sprite, Types::Coercible::String.default("")
  attribute :types, Types::Strict::Array.of(Types::Coercible::String).default([].freeze)
  attribute :stats, Types::Strict::Array.of(Types::Hash.schema(name: Types::Coercible::String, value: Types::Coercible::Integer)).default([].freeze)
  attribute :hp_max, BC_HP
  attribute :hp_current, BC_HP
  attribute :moves, Types::Strict::Array.of(Move).default([].freeze)

  # rubocop:disable Metrics/MethodLength
  def self.from(pokemon, moves: [])
    hp = pokemon.stats.find { |stat| stat[:name] == "HP" }&.fetch(:value)
    new(
      number: pokemon.number,
      name: pokemon.name,
      sprite: pokemon.sprite.to_s,
      types: pokemon.types,
      stats: pokemon.stats,
      hp_max: hp || 1,
      hp_current: hp || 1,
      moves: moves
    )
  end
  # rubocop:enable Metrics/MethodLength

  def use_move(index)
    updated = moves.map.with_index do |move, i|
      i == index ? move.new(pp: [move.pp - 1, 0].max) : move
    end
    new(moves: updated)
  end

  def take_damage(amount)
    return self if amount <= 0

    new_hp = [hp_current - amount, 0].max
    new(hp_current: new_hp)
  end

  def stat(name)
    stats.find { |stat| stat[:name] == name }&.fetch(:value) || 1
  end

  def alive?
    hp_current.positive?
  end

  def fainted?
    !alive?
  end
end
