# frozen_string_literal: true

require "faraday"
require_relative "persistent_json_store"
require_relative "poke_api_parsing"
require_relative "poke_api_moves"
require_relative "poke_api_types"

class PokeApiHttp
  include PokeApiParsing
  include PokeApiMoves
  include PokeApiTypes

  def initialize(cache_path: nil, ttl: PersistentJsonStore::DEFAULT_TTL)
    @store = cache_path ? PersistentJsonStore.new(path: cache_path, ttl: ttl) : nil
  end

  def all
    data = http_get("https://pokeapi.co/api/v2/pokemon?limit=100000&offset=0")
    data ? data["results"] : []
  end

  def fetch_all_names
    all.map { |pokemon| pokemon["name"] }
  end

  def paginate(offset: 0, limit: 100, query: nil)
    names = fetch_all_names
    names = names.select { |name| name.downcase.include?(query.downcase) } if query && !query.empty?
    { names: names[offset, limit].to_a, total: names.size }
  end

  def find(name)
    data = http_get("https://pokeapi.co/api/v2/pokemon/#{name}")
    return nil unless data

    Pokemon.new(
      name: data["name"],
      sprite: data.dig("sprites", "front_default").to_s,
      number: data["id"]
    )
  end

  def http_get(url)
    @store ? @store.get(url) : transport_get(url)
  end

  private

  def transport_get(url)
    response = Faraday.get(url)
    return nil unless ok?(response)

    JSON.parse(response.body)
  rescue Faraday::Error, JSON::ParserError
    nil
  end

  def ok?(response)
    response.respond_to?(:status) && response.status == 200
  end
end
