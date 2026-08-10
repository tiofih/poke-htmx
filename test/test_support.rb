# frozen_string_literal: true

require_relative "../lib/pokemon"
require_relative "../lib/battle_engine"
require_relative "../lib/move"

module TestSupport
  def type_effectiveness
    TypeEffectiveness.from_relations(
      "fire" => { "double" => %w[grass bug ice steel], "half" => %w[fire water rock dragon], "no" => [] },
      "grass" => { "double" => %w[water ground rock], "half" => %w[fire grass poison flying bug dragon], "no" => [] },
      "electric" => { "double" => %w[water flying], "half" => %w[electric grass dragon], "no" => %w[ground] },
      "normal" => { "double" => [], "half" => %w[rock steel], "no" => %w[ghost] }
    )
  end

  def build_pokemon(number:, name:, types: [], hp: 100, speed: 100, attack: 1, defense: 1, moves: [])
    BattlePokemon.new(
      number: number,
      name: name,
      types: types,
      stats: [
        { name: "HP", value: hp },
        { name: "Attack", value: attack },
        { name: "Defense", value: defense },
        { name: "Speed", value: speed }
      ],
      hp_max: hp,
      hp_current: hp,
      moves: moves
    )
  end

  def build_move(name, type:, power:, pp:)
    Move.new(name: name, type: type, power: power, accuracy: 100, pp: pp)
  end

  def build_pokemon_record(name, number)
    Pokemon.new(name: name, sprite: "https://example.com/#{name}.png", number: number)
  end

  def add_team(user_id, specs)
    specs.each do |name, number|
      @repository.add(user_id, build_pokemon_record(name, number))
    end
  end
end
