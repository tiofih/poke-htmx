# frozen_string_literal: true

require_relative "../lib/gateways/poke_api_http"

class PokeApiFake
  # rubocop:disable Metrics/ParameterLists
  def initialize(find: nil, detail: nil, fetch_all_names: nil,
                 moves_for: nil, move: nil, available_move_names: nil, type_relations: nil,
                 next_evolutions: nil, stone_evolutions: nil, learnable_moves: nil, base_form: nil,
                 evolution_restricted: nil, generation_for: nil, pokemon_names_by_type: nil)
    # rubocop:enable Metrics/ParameterLists
    @config = {
      find: find, detail: detail, fetch_all_names: fetch_all_names,
      moves_for: moves_for, move: move,
      available_move_names: available_move_names, type_relations: type_relations,
      next_evolutions: next_evolutions, stone_evolutions: stone_evolutions,
      learnable_moves: learnable_moves,
      base_form: base_form, evolution_restricted: evolution_restricted,
      generation_for: generation_for, pokemon_names_by_type: pokemon_names_by_type
    }.freeze
    @find = find
    @detail = detail
    @fetch_all_names = fetch_all_names
    @moves_for = moves_for
    @move = move
    @available_move_names = available_move_names
    @type_relations = type_relations
    @next_evolutions = next_evolutions
    @stone_evolutions = stone_evolutions
    @learnable_moves = learnable_moves
    @base_form = base_form
    @evolution_restricted = evolution_restricted
    @generation_for = generation_for
    @pokemon_names_by_type = pokemon_names_by_type
  end

  attr_reader :config, :fetch_all_names, :type_relations

  def find(name)
    resolve(@find, name)
  end

  def detail(poke_id)
    resolve(@detail, poke_id)
  end

  def paginate(offset: 0, limit: 100, query: nil)
    names = fetch_all_names.to_a
    names = names.select { |name| name.downcase.include?(query.downcase) } if query && !query.empty?
    { names: names[offset, limit].to_a, total: names.size }
  end

  def move(name)
    resolve(@move, name)
  end

  def moves_for(_number)
    @moves_for
  end

  def available_move_names(_number)
    @available_move_names
  end

  def next_evolutions(_number)
    @next_evolutions
  end

  def stone_evolutions(_number)
    @stone_evolutions
  end

  def learnable_moves(_number)
    @learnable_moves
  end

  def base_form?(name)
    return true if @base_form.nil?

    resolve(@base_form, name) == true
  end

  def evolution_restricted?(name)
    resolve(@evolution_restricted, name) == true
  end

  def generation_for(name)
    resolve(@generation_for, name)
  end

  def pokemon_names_by_type(type)
    resolve(@pokemon_names_by_type, type.to_s.strip.downcase) || []
  end

  private

  def resolve(config, key)
    return nil if config.nil?

    config.is_a?(Hash) ? config[key] : config
  end
end
