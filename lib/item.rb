# frozen_string_literal: true

require "dry-struct"
require_relative "pokemon"

class Item < Dry::Struct
  attribute :name, Types::Strict::String
  attribute :display_name, Types::Strict::String
  attribute :category, Types::Strict::String
  attribute :price, Types::Coercible::Integer
  attribute :heal_amount, Types::Coercible::Integer.default(0)
  attribute :stat, Types::Coercible::String.optional.default(nil)
  attribute :multiplier, Types::Coercible::Float.default(1.0)
end
