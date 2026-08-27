# frozen_string_literal: true

# Política de custo para montagem de time (M2).
#
# Custo derivado do tier da linha evolutiva (máximo dos tiers da cadeia).
# Orçamento e teto de S são limites de montagem — não tocam wallet/Eco.
module TeamBudget
  BUDGET = 450
  S_LIMIT = 3

  TIER_COST = {
    "S" => 120,
    "A" => 70,
    "B" => 55,
    "C" => 40,
    "D" => 30,
    "F" => 20
  }.freeze

  # Custo de um Pokémon pelo tier da sua linha evolutiva.
  # Quando restricted=true (evolução por item/pedra/troca), paga metade (floor),
  # exceto linha S que paga 110 quando restrita.
  def self.cost_for(line_tier:, restricted:)
    base = TIER_COST.fetch(line_tier)
    return base unless restricted
    return 110 if line_tier == "S"

    base / 2
  end

  # Checa se o time atual + novo custo cabe no orçamento.
  def self.fits?(current_total:, new_cost:)
    current_total + new_cost <= BUDGET
  end

  # Checa se o time ainda pode aceitar mais Pokémon de linha S.
  def self.s_limit_ok?(current_s_count:)
    current_s_count <= S_LIMIT
  end
end
