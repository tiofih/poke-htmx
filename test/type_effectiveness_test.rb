# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/type_effectiveness"

class TypeEffectivenessTest < Minitest::Test
  def relations
    TypeEffectiveness.from_relations(
      "fire" => { "double" => %w[grass bug ice steel], "half" => %w[fire water rock dragon], "no" => [] },
      "electric" => { "double" => %w[water flying], "half" => %w[electric grass dragon], "no" => %w[ground] },
      "normal" => { "double" => [], "half" => %w[rock steel], "no" => %w[ghost] },
      "water" => { "double" => %w[fire ground rock], "half" => %w[water grass dragon], "no" => [] },
      "grass" => { "double" => %w[water ground rock], "half" => %w[fire grass poison flying bug dragon], "no" => [] },
      "ground" => { "double" => %w[fire electric poison rock steel], "half" => %w[grass bug], "no" => %w[flying] },
      "flying" => { "double" => %w[grass fighting bug], "half" => %w[electric rock steel], "no" => %w[ground] },
      "ghost" => { "double" => %w[ghost psychic], "half" => %w[dark], "no" => %w[normal] }
    )
  end

  def test_factor_fraqueza_eh_o_dobro
    assert_in_delta 2.0, relations.factor("fire", "bug")
  end

  def test_factor_resistencia_eh_metade
    assert_in_delta 0.5, relations.factor("fire", "rock")
  end

  def test_factor_imune_eh_zero
    assert_in_delta 0.0, relations.factor("electric", "ground")
  end

  def test_factor_tipo_sem_relacao_e_neutro
    assert_in_delta 1.0, relations.factor("fire", "electric")
  end

  def test_factor_atacante_desconhecido_e_neutro
    assert_in_delta 1.0, relations.factor("fairy", "fire")
  end

  def test_factor_multiplicadores_tipos_reais
    assert_in_delta 2.0, relations.factor("water", "ground")
    assert_in_delta 0.5, relations.factor("grass", "flying")
    assert_in_delta 0.0, relations.factor("ground", "flying")
    assert_in_delta 0.0, relations.factor("ghost", "normal")
    assert_in_delta 2.0, relations.factor("flying", "grass")
  end

  def test_effectiveness_multiplies_factors_for_each_defender_type
    assert_in_delta 0.25, relations.effectiveness("fire", %w[water fire])
    assert_in_delta 1.0, relations.effectiveness("fire", ["electric"])
    assert_in_delta 0.0, relations.effectiveness("electric", ["ground"])
  end

  def test_effectiveness_with_empty_defender_types_is_neutro
    assert_in_delta 1.0, relations.effectiveness("fire", [])
  end

  def test_effectiveness_single_and_multi_dupla
    assert_in_delta 1.0, relations.effectiveness("grass", %w[water flying])
    assert_in_delta 4.0, relations.effectiveness("water", %w[ground fire])
  end

  def test_stab_supera_quando_atacante_tem_o_tipo_do_golpe
    assert_in_delta 1.5, relations.stab(%w[fire], "fire")
    assert_in_delta 1.5, relations.stab(%w[water psychic], "water")
  end

  def test_stab_neutro_quando_atacante_nao_tem_o_tipo_do_golpe
    assert_in_delta 1.0, relations.stab(%w[electric], "fire")
    assert_in_delta 1.0, relations.stab([], "water")
  end

  def test_damage_multiplier_combines_effectiveness_and_stab
    assert_in_delta 0.75, relations.damage_multiplier(
      attacker_types: %w[fire], move_type: "fire", defender_types: ["water"]
    )
  end

  def test_damage_multiplier_without_stab_keeps_effectiveness
    assert_in_delta 1.0, relations.damage_multiplier(
      attacker_types: %w[electric], move_type: "water", defender_types: ["normal"]
    )
  end
end
