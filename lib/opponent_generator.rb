# frozen_string_literal: true

require_relative "gateways/poke_api"
require_relative "battle_pokemon"
require_relative "parallelizer"

class OpponentGenerator
  DEFAULT_TEAM_SIZE = 6

  def initialize(names:, size: DEFAULT_TEAM_SIZE, rng: Random.new,
                 fetcher: PokeApi.instance.method(:detail), level: 1,
                 parallelizer: Parallelizer)
    @names = names
    @size = size
    @rng = rng
    @fetcher = fetcher
    @level = level
    @parallelizer = parallelizer
  end

  def team_names
    return [] if @size <= 0 || @names.empty?

    @names.sample([@size, @names.size].min, random: @rng)
  end

  def team
    @parallelizer.map(team_names) { |name| BattlePokemon.from(@fetcher.call(name), level: @level) }
  end
end
