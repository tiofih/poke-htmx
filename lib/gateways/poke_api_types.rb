# frozen_string_literal: true

require_relative "../parallelizer"

module PokeApiTypes
  TYPE_NAMES = %w[normal fire water electric grass ice fighting poison ground flying
                  psychic bug rock ghost dark dragon steel fairy].freeze

  def type_relations
    Parallelizer.map(TYPE_NAMES, concurrency: Parallelizer::DEFAULT_CONCURRENCY) { |name| fetch_type_json(name) }
                .each_with_object({}) do |json, acc|
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
    http_get("https://pokeapi.co/api/v2/type/#{name}")
  end
end
