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
    response = Faraday.get("https://pokeapi.co/api/v2/pokemon?limit=100000&offset=0")
    return [] unless response.respond_to?(:status) && response.status == 200

    JSON.parse(response.body)["results"]
  rescue Faraday::Error, JSON::ParserError
    []
  end

  def self.fetch_all_names
    cached = @fetch_all_names
    return cached if cached

    names = all.map { |pokemon| pokemon["name"] }
    @fetch_all_names = names unless names.empty?
    names
  end

  def self.paginate(offset: 0, limit: 100, query: nil)
    names = fetch_all_names
    names = names.select { |name| name.downcase.include?(query.downcase) } if query && !query.empty?
    { names: names[offset, limit].to_a, total: names.size }
  end

  def self.find(name)
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

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def self.detail(poke_id)
    data = pokemon_data(poke_id)
    return nil unless data

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
    response = Faraday.get("https://pokeapi.co/api/v2/pokemon/#{poke_id}")
    return nil unless response.respond_to?(:status) && response.status == 200

    JSON.parse(response.body)
  rescue Faraday::Error, JSON::ParserError
    nil
  end

  def self.evolution_chain(species_url)
    species_response = Faraday.get(species_url)
    return [] unless species_response.respond_to?(:status) && species_response.status == 200

    species = JSON.parse(species_response.body)
    chain_url = species.dig("evolution_chain", "url")
    return [] unless chain_url

    chain_response = Faraday.get(chain_url)
    return [] unless chain_response.respond_to?(:status) && chain_response.status == 200

    chain = JSON.parse(chain_response.body)["chain"]
    flatten_chain(chain).filter_map { |name| find(name) }
  rescue Faraday::Error, JSON::ParserError
    []
  end

  def self.flatten_chain(chain)
    names = [chain["species"]["name"]]
    chain["evolves_to"].each { |stage| names.concat(flatten_chain(stage)) }
    names
  end

  def self.move(name)
    @move_cache ||= {}
    @move_cache[name] ||= begin
      json = fetch_move_json(name)
      json && extract_move(json)
    end
  end

  def self.moves_for(number)
    @pokemon_moves_cache ||= {}
    @pokemon_moves_cache[number] ||= begin
      data = pokemon_data(number)
      move_entries = data.to_h["moves"].to_a
      last_four = move_entries.last(4).map { |entry| entry.dig("move", "name") }
      last_four.map { |move_name| move(move_name) }.compact
    end
  end

  def self.available_move_names(number)
    @available_moves_cache ||= {}
    @available_moves_cache[number] ||= begin
      data = pokemon_data(number)
      data.to_h["moves"].to_a.map { |entry| entry.dig("move", "name") }.compact.sort
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
    response = Faraday.get("https://pokeapi.co/api/v2/move/#{name}")
    return nil unless response.respond_to?(:status) && response.status == 200

    JSON.parse(response.body)
  rescue Faraday::Error, JSON::ParserError
    nil
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
    response = Faraday.get("https://pokeapi.co/api/v2/type/#{name}")
    return nil unless response.respond_to?(:status) && response.status == 200

    JSON.parse(response.body)
  rescue Faraday::Error, JSON::ParserError
    nil
  end

  def self.type_relations
    @type_relations ||= TYPE_NAMES.each_with_object({}) do |name, acc|
      json = fetch_type_json(name)
      acc.merge!(extract_type_relations(json)) if json
    end
  end
end
# rubocop:enable Metrics/ClassLength
