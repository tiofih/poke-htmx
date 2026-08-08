# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/type_effectiveness"

class TypeEffectivenessTest < Minitest::Test
  def relations
    TypeEffectiveness.from_relations(
      "fire" => { "double" => %w[grass bug ice steel], "half" => %w[fire water rock dragon], "no" => [] },
      "electric" => { "double" => %w[water flying], "half" => %w[electric grass dragon], "no" => %w[ground] },
      "normal" => { "double" => [], "half" => %w[rock steel], "no" => %w[ghost] }
    )
  end

  def test_factor_fraqueza_eh_2
    assert_in_delta 2.0, relations.factor("fire", "grass")
    assert_in_delta 2.0, relations.factor("electric", "water")
  end

  def test_factor_resistencia_eh_0_5
    assert_in_delta 0.5, relations.factor("fire", "water")
    assert_in_delta 0.5, relations.factor("fire", "rock")
  end

  def test_factor_imune_eh_0
    assert_in_delta 0.0, relations.factor("electric", "ground")
    assert_in_delta 0.0, relations.factor("normal", "ghost")
  end

  def test_factor_tipo_sem_relacao_e_1
    assert_in_delta 1.0, relations.factor("fire", "electric")
    assert_in_delta 1.0, relations.factor("fire", "normal")
  end

  def test_factor_atacante_desconhecido_e_1
    assert_in_delta 1.0, relations.factor("fairy", "fire")
  end
end