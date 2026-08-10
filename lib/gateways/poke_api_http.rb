# frozen_string_literal: true

require "faraday"
require_relative "poke_api_parsing"
require_relative "poke_api_moves"
require_relative "poke_api_types"

class PokeApiHttp
  include PokeApiParsing
  include PokeApiMoves
  include PokeApiTypes

  def all
    response = Faraday.get("https://pokeapi.co/api/v2/pokemon?limit=100000&offset=0")
    return [] unless response.respond_to?(:status) && response.status == 200

    JSON.parse(response.body)["results"]
  rescue Faraday::Error, JSON::ParserError
    []
  end

  def fetch_all_names
    cached = @fetch_all_names
    return cached if cached

    names = all.map { |pokemon| pokemon["name"] }
    @fetch_all_names = names unless names.empty?
    names
  end

  def paginate(offset: 0, limit: 100, query: nil)
    names = fetch_all_names
    names = names.select { |name| name.downcase.include?(query.downcase) } if query && !query.empty?
    { names: names[offset, limit].to_a, total: names.size }
  end

  def find(name)
    response = Faraday.get("https://pokeapi.co/api/v2/pokemon/#{name}")
    return nil unless response.respond_to?(:status) && response.status == 200

    resp = JSON.parse(response.body)
    Pokemon.new(
      name: resp["name"],
      sprite: resp.dig("sprites", "front_default").to_s,
      number: resp["id"]
    )
  rescue Faraday::Error, JSON::ParserError
    nil
  end

  private

  def ok?(response)
    response.respond_to?(:status) && response.status == 200
  end
end
