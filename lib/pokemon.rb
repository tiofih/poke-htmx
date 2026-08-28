require "dry-struct"

module Types
  include Dry.Types()
end

class Pokemon < Dry::Struct
  attribute :id, Types::Coercible::Integer.optional.default(nil)
  attribute :name, Types::Strict::String
  attribute :sprite, Types::Strict::String
  attribute :number, Types::Coercible::Integer
  attribute :slot, Types::Coercible::Integer.optional.default(nil)
  attribute :moves, Types::Strict::Array.of(Types::Coercible::String).default([].freeze)
  attribute :hp_max, Types::Coercible::Integer.default(0)
  attribute :hp_current, Types::Coercible::Integer.default(0)
  attribute :types, Types::Strict::Array.of(Types::Coercible::String).default([].freeze)
  attribute :stats, Types::Strict::Array.of(Types::Hash.schema(name: Types::Coercible::String, value: Types::Coercible::Integer)).default([].freeze)
  attribute :evolutions, Types::Strict::Array.of(Pokemon).default([].freeze)
  attribute :assigned_item, Types::Coercible::String.optional.default(nil)
  attribute :held_item, Types::Coercible::String.optional.default(nil)

  def usable_hp?
    hp_max.to_i <= 0 || hp_current.to_i.positive?
  end

  # Fainted = vida zerada após já ter lutado (hp_max>0 && hp_current==0).
  # Nunca lutou (hp_max==0) nunca é fainted — coerente com usable_hp? e JourneyService#battle_ready?.
  # Espelha BattlePokemon#fainted? (lib/battle_pokemon.rb:88) mas para Pokemon persistido.
  def fainted?
    hp_max.to_i.positive? && hp_current.to_i.zero?
  end

  def alive?
    !fainted?
  end
end
