# frozen_string_literal: true

require_relative "gateways/poke_api"
require_relative "battle_pokemon"
require_relative "parallelizer"

class OpponentGenerator
  DEFAULT_TEAM_SIZE = 6

  def initialize(names:, size: DEFAULT_TEAM_SIZE, rng: Random.new,
                 fetcher: PokeApi.instance.method(:detail), level: 1,
                 options: {})
    @names = names
    @size = size
    @rng = rng
    @fetcher = fetcher
    @level = level
    @parallelizer = options.fetch(:parallelizer, Parallelizer)
    @rater = options[:rater]
    @moves_fetcher = options[:moves_fetcher]
    @band = options[:band]
  end

  def team_names
    return [] if @size <= 0 || @names.empty?
    return random_names unless rated?

    rated_names
  end

  def team
    @parallelizer.map(team_names) { |name| BattlePokemon.from(@fetcher.call(name), level: @level) }
  end

  private

  def rated?
    @rater && @moves_fetcher && @band && !@band.empty?
  end

  def random_names
    @names.sample([@size, @names.size].min, random: @rng)
  end

  def rated_names
    collected = []
    @names.shuffle(random: @rng).each do |name|
      break if collected.size >= @size

      collected << name if in_band?(name)
    end
    return collected if collected.size == @size

    remaining = @names - collected
    collected + remaining.sample([@size - collected.size, remaining.size].min, random: @rng)
  end

  def in_band?(name)
    pokemon = @fetcher.call(name)
    return false unless pokemon

    moves = @moves_fetcher.call(pokemon.number)
    @band.include?(@rater.call(pokemon, moves))
  end
end
