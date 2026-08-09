# frozen_string_literal: true

require "dry-struct"
require_relative "pokemon"

class Move < Dry::Struct
  attribute :name, Types::Strict::String
  attribute :type, Types::Strict::String
  attribute :power, Types::Coercible::Integer.optional
  attribute :accuracy, Types::Coercible::Integer.optional
  attribute :pp, Types::Coercible::Integer.default(1)
end
