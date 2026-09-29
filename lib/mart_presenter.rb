# frozen_string_literal: true

# 0098 C4 — locals do modal do Mart montados a partir de dados ja
# resolvidos na rota (sem DB): dado obrigatorio ausente = ArgumentError.
class MartPresenter
  KEYS = %i[notice notice_kind balance catalog inventory rotation].freeze
  REQUIRED = %i[balance catalog inventory rotation].freeze

  def initialize(data)
    missing = REQUIRED - data.keys
    raise ArgumentError, "dados faltando: #{missing.join(', ')}" unless missing.empty?

    @data = data
  end

  def to_h
    KEYS.to_h { |key| [key, @data[key]] }
  end
end
