# frozen_string_literal: true

module ServerBattleTestHelpers
  def battle_pokemon_for_test
    Pokemon.new(
      name: "pikachu",
      sprite: "https://example.com/pikachu.png",
      number: 25,
      types: ["electric"],
      stats: [
        { name: "HP", value: 200 },
        { name: "Attack", value: 55 },
        { name: "Defense", value: 40 },
        { name: "Speed", value: 90 }
      ]
    )
  end

  def battle_moves_for_test
    [build_move("thunder-shock", type: "electric", power: 40, pp: 30)]
  end

  def neutral_type_json_table
    PokeApiTypes::TYPE_NAMES.to_h { |type| [type, type_json_for(type)] }
  end

  def type_json_for(type)
    {
      "name" => type,
      "damage_relations" => {
        "double_damage_to" => [],
        "half_damage_to" => [],
        "no_damage_to" => []
      }
    }
  end

  def stub_battle_start(&block)
    PokeApiStub.with_all_names(%w[pikachu bulbasaur charmander squirtle eevee jigglypuff]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_detail(battle_pokemon_for_test) do
          PokeApiStub.with_moves_for(battle_moves_for_test) do
            block.call
          end
        end
      end
    end
  end

  def start_battle_for(user_id)
    add_team(user_id, [["pikachu", 25], ["bulbasaur", 26], ["charmander", 27]]) if @repository.all(user_id).empty?
    stub_battle_start { get "/battle", {}, user_session(user_id) }
  end
end
