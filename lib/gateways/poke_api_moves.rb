# frozen_string_literal: true

require "faraday"
require_relative "../move"

module PokeApiMoves
  def move(name)
    json = fetch_move_json(name)
    json && extract_move(json)
  end

  def moves_for(number)
    data = pokemon_data(number)
    move_entries = data.to_h["moves"].to_a
    last_four = move_entries.last(4).map { |entry| entry.dig("move", "name") }
    last_four.map { |move_name| move(move_name) }.compact
  end

  def available_move_names(number)
    data = pokemon_data(number)
    data.to_h["moves"].to_a.map { |entry| entry.dig("move", "name") }.compact.sort
  end

  def extract_move(json)
    Move.new(
      name: json["name"],
      type: json.dig("type", "name"),
      power: json["power"],
      accuracy: json["accuracy"],
      pp: json["pp"] || 1
    )
  end

  def fetch_move_json(name)
    response = Faraday.get("https://pokeapi.co/api/v2/move/#{name}")
    return nil unless response.respond_to?(:status) && response.status == 200

    JSON.parse(response.body)
  rescue Faraday::Error, JSON::ParserError
    nil
  end
end
