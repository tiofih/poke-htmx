# frozen_string_literal: true

require_relative "poke_api_http"

module PokeApi
  # Interface do gateway de dados da PokéAPI.
  #
  # Contrato (implementado por qualquer adapter):
  #   paginate(offset:, limit:, query:)          -> { names:, total: }
  #   find(name)                                  -> Pokemon | nil
  #   detail(poke_id)                             -> Pokemon | nil
  #   available_move_names(number)                -> [String]
  #   move(name)                                  -> Move | nil
  #   moves_for(number)                           -> [Move]
  #   type_relations                              -> { tipo => { double:, half:, no: } }
  #   fetch_all_names                             -> [String]
  #
  # Ponto de injeção: `PokeApi.instance` resolve o adapter usado por padrão;
  # testes/consumidores podem sobrescrever com `PokeApi.instance = adapter`.
  def self.instance
    @instance ||= PokeApiHttp.new
  end

  def self.instance=(adapter)
    @instance = adapter
  end
end
