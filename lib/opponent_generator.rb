# frozen_string_literal: true

require_relative "gateways/poke_api"
require_relative "battle_pokemon"
require_relative "parallelizer"

# rubocop:disable Metrics/ClassLength
class OpponentGenerator
  DEFAULT_TEAM_SIZE = 6
  SCAN_BATCH_SIZE = Parallelizer::DEFAULT_CONCURRENCY

  def initialize(names:, size: DEFAULT_TEAM_SIZE, rng: Random.new,
                 fetcher: PokeApi.instance.method(:detail), level: 1,
                 options: {})
    @names = names
    @size = size
    @rng = rng
    @fetcher = fetcher
    @level = level
    assign_options(options)
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
    @band && !@band.empty? && (@ratings || (@rater && @moves_fetcher))
  end

  def random_names
    @names.sample([@size, @names.size].min, random: @rng)
  end

  def rated_names
    return rated_names_with_ratings if @ratings

    rated_names_with_rater
  end

  def rated_names_with_rater
    collected = []
    evaluated = 0
    @names.shuffle(random: @rng).each_slice(SCAN_BATCH_SIZE) do |batch|
      break if collected.size >= @size || capped?(evaluated)

      collect_rater_batch(collected, batch)
      evaluated += batch.size
    end
    complete_with_fallback(collected)
  end

  def rated_names_with_ratings
    collected = []
    evaluated = 0
    @names.shuffle(random: @rng).each_slice(SCAN_BATCH_SIZE) do |batch|
      break if collected.size >= @size || capped?(evaluated)

      collect_rating_batch(collected, batch)
      evaluated += batch.size
    end
    complete_with_fallback(collected)
  end

  def collect_rater_batch(collected, batch)
    results = @parallelizer.map(batch) do |name|
      base_ok = @base_checker.call(name)
      gen_ok = @generation_checker.call(name)
      band_ok = base_ok && gen_ok && in_band?(name)
      [name, band_ok]
    end
    results.each do |name, ok|
      break if collected.size >= @size

      collected << name if ok
    end
  end

  def collect_rating_batch(collected, batch)
    results = @parallelizer.map(batch) do |name|
      base_ok = @base_checker.call(name)
      gen_ok = @generation_checker.call(name)
      band_ok = base_ok && gen_ok && in_rating_band?(name)
      [name, band_ok]
    end
    results.each do |name, ok|
      break if collected.size >= @size

      collected << name if ok
    end
  end

  def capped?(evaluated)
    @max_candidates && evaluated >= @max_candidates
  end

  def complete_with_fallback(collected)
    return collected if collected.size == @size

    remaining = @names - collected
    filtered = remaining.select { |name| @base_checker.call(name) && @generation_checker.call(name) }
    pool = filtered.empty? ? [] : filtered
    # if filtered empty, do not fallback to non-base/non-gen (preserva pool base)
    collected + pool.sample([@size - collected.size, pool.size].min, random: @rng)
  end

  def assign_options(options)
    @parallelizer = options.fetch(:parallelizer, Parallelizer)
    @rater, @moves_fetcher, @band = options.values_at(:rater, :moves_fetcher, :band)
    @ratings, @max_candidates = options.values_at(:ratings, :max_candidates)
    @base_checker = options.fetch(:base_checker, ->(_name) { true })
    @generation_checker = options.fetch(:generation_checker, ->(_name) { true })
  end

  def in_band?(name)
    pokemon = @fetcher.call(name)
    return false unless pokemon

    moves = @moves_fetcher.call(pokemon.number)
    @band.include?(@rater.call(pokemon, moves))
  end

  def in_rating_band?(name)
    tier = @ratings.call(name)
    tier && @band.include?(tier)
  end
end
# rubocop:enable Metrics/ClassLength
