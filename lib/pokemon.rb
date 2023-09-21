require 'dry-struct'

module Types
  include Dry.Types()
end

class Pokemon < Dry::Struct
  attribute :name, Types::Strict::String
  attribute :sprite, Types::Strict::String
  attribute :number, Types::Coercible::Integer
end
