# frozen_string_literal: true

require "faraday"

module PokeApiTypes
  TYPE_NAMES = %w[normal fire water electric grass ice fighting poison ground flying
                  psychic bug rock ghost dark dragon steel fairy].freeze

  def type_relations
    TYPE_NAMES.each_with_object({}) do |name, acc|
      json = fetch_type_json(name)
      acc.merge!(extract_type_relations(json)) if json
    end
  end

  def extract_type_relations(json)
    relations = json["damage_relations"] || {}
    {
      json["name"] => {
        "double" => relations["double_damage_to"].to_a.map { |type| type["name"] },
        "half" => relations["half_damage_to"].to_a.map { |type| type["name"] },
        "no" => relations["no_damage_to"].to_a.map { |type| type["name"] }
      }
    }
  end

  def fetch_type_json(name)
    response = Faraday.get("https://pokeapi.co/api/v2/type/#{name}")
    return nil unless response.respond_to?(:status) && response.status == 200

    JSON.parse(response.body)
  rescue Faraday::Error, JSON::ParserError
    nil
  end
end
