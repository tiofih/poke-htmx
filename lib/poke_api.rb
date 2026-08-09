require "faraday"
require "pry"
require_relative "pokemon"
require_relative "move"

# rubocop:disable Metrics/ClassLength
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
    response = Faraday.get("https://pokeapi.co/api/v2/pokemon/#{name}")
    return nil unless response.status == 200

    resp = JSON.parse(response.body)
    Pokemon.new(
      name: resp["name"],
      sprite: resp.dig("sprites", "front_default").to_s,
      number: resp["id"]
    )
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def self.detail(poke_id)
    data = pokemon_data(poke_id)
    Pokemon.new(
      name: data["name"],
      sprite: data.dig("sprites", "front_default").to_s,
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
    flatten_chain(chain).filter_map { |name| find(name) }
  end

  def self.flatten_chain(chain)
    names = [chain["species"]["name"]]
    chain["evolves_to"].each { |stage| names.concat(flatten_chain(stage)) }
    names
  end

  def self.move(name)
    @move_cache ||= {}
    @move_cache[name] ||= extract_move(fetch_move_json(name))
  end

  def self.moves_for(number)
    @pokemon_moves_cache ||= {}
    @pokemon_moves_cache[number] ||= begin
      data = pokemon_data(number)
      move_entries = data["moves"].to_a
      last_four = move_entries.last(4).map { |entry| entry.dig("move", "name") }
      last_four.map { |move_name| move(move_name) }
    end
  end

  def self.extract_move(json)
    Move.new(
      name: json["name"],
      type: json.dig("type", "name"),
      power: json["power"],
      accuracy: json["accuracy"],
      pp: json["pp"] || 1
    )
  end

  def self.fetch_move_json(name)
    JSON.parse(Faraday.get("https://pokeapi.co/api/v2/move/#{name}").body)
  end

  def self.extract_type_relations(json)
    relations = json["damage_relations"] || {}
    {
      json["name"] => {
        "double" => relations["double_damage_to"].to_a.map { |type| type["name"] },
        "half" => relations["half_damage_to"].to_a.map { |type| type["name"] },
        "no" => relations["no_damage_to"].to_a.map { |type| type["name"] }
      }
    }
  end

  TYPE_NAMES = %w[normal fire water electric grass ice fighting poison ground flying
                  psychic bug rock ghost dark dragon steel fairy].freeze

  def self.fetch_type_json(name)
    JSON.parse(Faraday.get("https://pokeapi.co/api/v2/type/#{name}").body)
  end

  def self.type_relations
    @type_relations ||= TYPE_NAMES.each_with_object({}) do |name, acc|
      acc.merge!(extract_type_json(name))
    end
  end

  def self.extract_type_json(name)
    extract_type_relations(fetch_type_json(name))
  end
end
# rubocop:enable Metrics/ClassLength
