# frozen_string_literal: true

require_relative "poke_api"
require_relative "battle_pokemon"

class OpponentGenerator
  DEFAULT_TEAM_SIZE = 6

  def initialize(names:, size: DEFAULT_TEAM_SIZE, rng: Random.new, fetcher: PokeApi.method(:detail))
    @names = names
    @size = size
    @rng = rng
    @fetcher = fetcher
  end

  def team_names
    return [] if @size <= 0 || @names.empty?

    @names.sample([@size, @names.size].min, random: @rng)
  end

  def team
    team_names.map { |name| BattlePokemon.from(@fetcher.call(name)) }
  end
end
