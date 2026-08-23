# frozen_string_literal: true

require "dry-struct"
require_relative "pokemon"

class Move < Dry::Struct
  attribute :name, Types::Strict::String
  attribute :type, Types::Strict::String
  attribute :power, Types::Coercible::Integer.optional
  attribute :accuracy, Types::Coercible::Integer.optional
  attribute :pp, Types::Coercible::Integer.default(1)
  attribute :pp_max, Types::Coercible::Integer.optional.default(nil)

  def initialize(attributes = {})
    attrs = attributes.to_h
    attrs[:pp_max] = attrs[:pp] if attrs[:pp_max].nil? && attrs.key?(:pp)
    super(attrs)
  end

  def pp_max
    attributes[:pp_max] || pp
  end
end
