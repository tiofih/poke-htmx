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
  attribute :types, Types::Strict::Array.of(Types::Coercible::String).default([].freeze)
  attribute :stats, Types::Strict::Array.of(Types::Hash.schema(name: Types::Coercible::String, value: Types::Coercible::Integer)).default([].freeze)
  attribute :evolutions, Types::Strict::Array.of(Pokemon).default([].freeze)
end
