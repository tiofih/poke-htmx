# frozen_string_literal: true

require "faraday"
require_relative "../pokemon"

# rubocop:disable Metrics/ModuleLength
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
    http_get("https://pokeapi.co/api/v2/pokemon/#{poke_id}")
  end

  def evolution_chain(species_url)
    species = http_get(species_url)
    return [] unless species

    chain_url = species.dig("evolution_chain", "url")
    return [] unless chain_url

    chain = http_get(chain_url)
    return [] unless chain

    flatten_chain(chain["chain"]).filter_map { |name| find(name) }
  rescue Faraday::Error, JSON::ParserError
    []
  end

  def next_evolutions(number)
    data = pokemon_data(number)
    return [] unless data

    species_url = data.dig("species", "url")
    return [] unless species_url

    chain = fetch_chain_data(species_url)
    return [] unless chain

    resolve_evolution_entries(find_current_species_next_stages(chain, data["name"]))
  rescue Faraday::Error, JSON::ParserError
    []
  end

  # Estágios seguintes acionados por item (pedra de evolução) — trigger
  # "use-item" — com o nome do item capturado de evolution_details. Falha de
  # rede/parsing -> [] (modal graceful).
  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def stone_evolutions(number)
    data = pokemon_data(number)
    return [] unless data

    species_url = data.dig("species", "url")
    return [] unless species_url

    chain = fetch_chain_data(species_url)
    return [] unless chain

    stages = find_current_species_next_stages(chain, data["name"])
    stages.select { |s| s[:trigger] == "use-item" && s[:item] }
          .filter_map do |s|
      pokemon = find(s[:name])
      pokemon&.number ? { number: pokemon.number, name: s[:name], item: s[:item] } : nil
    end
  rescue Faraday::Error, JSON::ParserError
    []
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def base_form?(name)
    data = pokemon_data(name)
    return false unless data

    chain = fetch_chain_data(data.dig("species", "url"))
    return false unless chain

    chain.dig("species", "name") == data["name"]
  rescue Faraday::Error, JSON::ParserError
    false
  end

  # rubocop:disable Metrics/MethodLength
  def generation_for(name)
    data = pokemon_data(name)
    return nil unless data

    species_url = data.dig("species", "url")
    return nil unless species_url

    species = http_get(species_url)
    return nil unless species

    generation_url = species.dig("generation", "url").to_s
    match = generation_url.match(%r{generation/(\d+)})
    return nil unless match

    match[1].to_i
  rescue Faraday::Error, JSON::ParserError
    nil
  end
  # rubocop:enable Metrics/MethodLength

  # Retorna true se o Pokémon tem pelo menos um estágio seguinte cujo trigger
  # ≠ "level-up" (pedra/item, troca, …); false para evolução só por nível ou
  # sem evolução. Reusa os mesmos fetches de espécie+cadeia já cacheados.
  def evolution_restricted?(name)
    data = pokemon_data(name)
    return false unless data

    species_url = data.dig("species", "url")
    return false unless species_url

    chain = fetch_chain_data(species_url)
    return false unless chain

    next_stages = find_current_species_next_stages(chain, data["name"])
    next_stages.any? { |stage| stage[:trigger] && stage[:trigger] != "level-up" }
  rescue Faraday::Error, JSON::ParserError
    false
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

  def fetch_chain_data(species_url)
    species = http_get(species_url)
    return nil unless species

    chain_url = species.dig("evolution_chain", "url")
    return nil unless chain_url

    chain = http_get(chain_url)
    return nil unless chain

    chain["chain"]
  end

  def resolve_evolution_entries(stages)
    stages.select { |s| s[:trigger] == "level-up" && s[:min_level] }
          .filter_map do |s|
      pokemon = find(s[:name])
      pokemon&.number ? { number: pokemon.number, name: s[:name], min_level: s[:min_level] } : nil
    end
  end

  def find_current_species_next_stages(chain, species_name)
    return chain["evolves_to"].map { |stage| stage_details(stage) } if chain["species"]["name"] == species_name

    chain["evolves_to"].each do |stage|
      result = find_current_species_next_stages(stage, species_name)
      return result unless result.empty?
    end
    []
  end

  def stage_details(stage)
    details = stage["evolution_details"].first || {}
    {
      name: stage["species"]["name"],
      trigger: details.dig("trigger", "name"),
      min_level: details["min_level"],
      item: details.dig("item", "name")
    }
  end
end
# rubocop:enable Metrics/ModuleLength
