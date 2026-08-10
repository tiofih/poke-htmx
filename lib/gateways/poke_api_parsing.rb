# frozen_string_literal: true

require "faraday"
require_relative "../pokemon"

module PokeApiParsing
  STAT_LABELS = {
    "hp" => "HP",
    "attack" => "Attack",
    "defense" => "Defense",
    "special-attack" => "Sp.Atk",
    "special-defense" => "Sp.Def",
    "speed" => "Speed"
  }.freeze

  def detail(poke_id)
    data = pokemon_data(poke_id)
    return nil unless data

    Pokemon.new(**pokemon_attributes(data))
  end

  def pokemon_data(poke_id)
    response = Faraday.get("https://pokeapi.co/api/v2/pokemon/#{poke_id}")
    return nil unless response.respond_to?(:status) && response.status == 200

    JSON.parse(response.body)
  rescue Faraday::Error, JSON::ParserError
    nil
  end

  def evolution_chain(species_url)
    species_response = Faraday.get(species_url)
    return [] unless ok?(species_response)

    chain_url = JSON.parse(species_response.body).dig("evolution_chain", "url")
    return [] unless chain_url

    chain_response = Faraday.get(chain_url)
    return [] unless ok?(chain_response)

    chain = JSON.parse(chain_response.body)["chain"]
    flatten_chain(chain).filter_map { |name| find(name) }
  rescue Faraday::Error, JSON::ParserError
    []
  end

  def flatten_chain(chain)
    names = [chain["species"]["name"]]
    chain["evolves_to"].each { |stage| names.concat(flatten_chain(stage)) }
    names
  end

  private

  def pokemon_attributes(data)
    {
      name: data["name"],
      sprite: data.dig("sprites", "front_default").to_s,
      number: data["id"],
      types: data["types"].map { |type| type["type"]["name"] },
      stats: stats_from(data),
      evolutions: evolution_chain(data["species"]["url"])
    }
  end

  def stats_from(data)
    data["stats"].map do |stat|
      { name: STAT_LABELS.fetch(stat["stat"]["name"], stat["stat"]["name"]), value: stat["base_stat"] }
    end
  end
end
