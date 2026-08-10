# frozen_string_literal: true

require_relative "poke_api_http"
require_relative "poke_api_cache"

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
  #   next_evolutions(number)                     -> [{number:, name:, min_level:}]
  #   type_relations                              -> { tipo => { double:, half:, no: } }
  #   fetch_all_names                             -> [String]
  #
  # Ponto de injeção: `PokeApi.instance` resolve o adapter usado por padrão —
  # decorado com `PokeApiCache` (TTL/LRU fixos, E1-B); testes/consumidores podem
  # sobrescrever com `PokeApi.instance = adapter`.
  def self.instance
    @instance ||= PokeApiCache.new(PokeApiHttp.new, ttl: PokeApiCache::DEFAULT_TTL, max_entries: PokeApiCache::DEFAULT_MAX_ENTRIES)
  end

  def self.instance=(adapter)
    @instance = adapter
  end
end
