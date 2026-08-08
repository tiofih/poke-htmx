# frozen_string_literal: true

class TypeEffectiveness
  FACTORS = { "double" => 2.0, "half" => 0.5, "no" => 0.0 }.freeze

  def self.from_relations(relations)
    new(relations)
  end

  def self.load
    from_relations(PokeApi.type_relations)
  end

  def initialize(relations)
    @relations = relations
  end

  def factor(attack_type, defender_type)
    relation = @relations[attack_type]
    return 1.0 unless relation

    FACTORS.each do |kind, multiplier|
      return multiplier if relation[kind].include?(defender_type)
    end
    1.0
  end

  def effectiveness(attack_type, defender_types)
    return 1.0 if defender_types.empty?

    defender_types.reduce(1.0) { |acc, type| acc * factor(attack_type, type) }
  end

  def stab(attack_types, move_type)
    attack_types.include?(move_type) ? 1.5 : 1.0
  end

  def damage_multiplier(attacker_types:, move_type:, defender_types:)
    effectiveness(move_type, defender_types) * stab(attacker_types, move_type)
  end
end
