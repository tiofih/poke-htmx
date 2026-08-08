# frozen_string_literal: true

class TypeEffectiveness
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

    if relation["double"].include?(defender_type)
      2.0
    elsif relation["half"].include?(defender_type)
      0.5
    elsif relation["no"].include?(defender_type)
      0.0
    else
      1.0
    end
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