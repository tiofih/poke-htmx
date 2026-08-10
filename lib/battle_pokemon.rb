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
  attribute :level, Types::Coercible::Integer.default(1)

  def self.from(pokemon, moves: [], level: 1)
    new(**attributes_for(pokemon, moves: moves, level: level))
  end

  class << self
    private

    def attributes_for(pokemon, moves:, level:)
      stats = scale_stats(pokemon.stats, level)
      hp = base_hp(stats)
      { number: pokemon.number, name: pokemon.name, sprite: pokemon.sprite.to_s,
        types: pokemon.types, stats: stats, hp_max: hp, hp_current: hp,
        moves: moves, level: level }
    end

    def scale_stats(stats, level)
      factor = level.to_i - 1
      return stats if factor <= 0

      stats.map { |stat| stat.merge(value: (stat[:value].to_i + (factor * 0.5)).round) }
    end

    def base_hp(stats)
      stats.find { |stat| stat[:name] == "HP" }&.fetch(:value) || 1
    end
  end

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
