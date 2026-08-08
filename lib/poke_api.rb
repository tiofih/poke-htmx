require "faraday"
require "pry"
require_relative "pokemon"

class PokeApi
  STAT_LABELS = {
    "hp" => "HP",
    "attack" => "Attack",
    "defense" => "Defense",
    "special-attack" => "Sp.Atk",
    "special-defense" => "Sp.Def",
    "speed" => "Speed"
  }.freeze

  def self.all
    response = Faraday.get("https://pokeapi.co/api/v2/pokemon?limit=100000&offset=0").body
    JSON.parse(response)["results"]
  end

  def self.fetch_all_names
    @fetch_all_names ||= all.map { |pokemon| pokemon["name"] }
  end

  def self.paginate(offset: 0, limit: 100, query: nil)
    names = fetch_all_names
    names = names.select { |name| name.downcase.include?(query.downcase) } if query && !query.empty?
    { names: names[offset, limit].to_a, total: names.size }
  end

  def self.find(name)
    response = Faraday.get("https://pokeapi.co/api/v2/pokemon/#{name}").body
    resp = JSON.parse(response)
    Pokemon.new(name: resp["name"], sprite: resp["sprites"]["front_default"], number: resp["id"])
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def self.detail(poke_id)
    data = pokemon_data(poke_id)
    Pokemon.new(
      name: data["name"],
      sprite: data["sprites"]["front_default"],
      number: data["id"],
      types: data["types"].map { |type| type["type"]["name"] },
      stats: data["stats"].map do |stat|
        { name: STAT_LABELS.fetch(stat["stat"]["name"], stat["stat"]["name"]), value: stat["base_stat"] }
      end,
      evolutions: evolution_chain(data["species"]["url"])
    )
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def self.pokemon_data(poke_id)
    JSON.parse(Faraday.get("https://pokeapi.co/api/v2/pokemon/#{poke_id}").body)
  end

  def self.evolution_chain(species_url)
    species = JSON.parse(Faraday.get(species_url).body)
    chain_url = species.dig("evolution_chain", "url")
    return [] unless chain_url

    chain = JSON.parse(Faraday.get(chain_url).body)["chain"]
    flatten_chain(chain).map { |name| find(name) }
  end

  def self.flatten_chain(chain)
    names = [chain["species"]["name"]]
    chain["evolves_to"].each { |stage| names.concat(flatten_chain(stage)) }
    names
  end
end
