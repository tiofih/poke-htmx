# frozen_string_literal: true

# 0098 C3 — locals do fragmento de time montados a partir de dados ja
# resolvidos na rota (sem DB): dado obrigatorio ausente = ArgumentError.
class TeamPresenter
  KEYS = %i[team team_types member_levels notice notice_kind can_battle game_over journey_started].freeze
  REQUIRED = %i[team team_types member_levels can_battle game_over journey_started].freeze

  def initialize(data)
    missing = REQUIRED - data.keys
    raise ArgumentError, "dados faltando: #{missing.join(', ')}" unless missing.empty?

    @data = data
  end

  def to_h
    KEYS.to_h { |key| [key, @data[key]] }
  end
end
