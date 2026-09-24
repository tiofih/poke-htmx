# frozen_string_literal: true

require_relative "gateways/poke_api"
require_relative "battle_pokemon"
require_relative "parallelizer"
require_relative "team_budget"

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
    total_cost = 0
    evaluated = 0
    @names.shuffle(random: @rng).each_slice(SCAN_BATCH_SIZE) do |batch|
      break if collected.size >= @size || capped?(evaluated)

      total_cost = collect_rater_batch(collected, batch, total_cost)
      evaluated += batch.size
    end
    complete_with_fallback(collected, total_cost)
  end

  def rated_names_with_ratings
    collected = []
    total_cost = 0
    evaluated = 0
    @names.shuffle(random: @rng).each_slice(SCAN_BATCH_SIZE) do |batch|
      break if collected.size >= @size || capped?(evaluated)

      total_cost = collect_rating_batch(collected, batch, total_cost)
      evaluated += batch.size
    end
    complete_with_fallback(collected, total_cost)
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def collect_rater_batch(collected, batch, total_cost)
    results = @parallelizer.map(batch) do |name|
      base_ok = @base_checker.call(name)
      gen_ok = @generation_checker.call(name)
      if base_ok && gen_ok
        pokemon = @fetcher.call(name)
        if pokemon
          moves = @moves_fetcher.call(pokemon.number)
          tier = @rater.call(pokemon, moves)
          band_ok = @band.include?(tier)
          restricted = @restricted_checker.call(name)
          [name, tier, band_ok, restricted]
        else
          [name, nil, false, false]
        end
      else
        [name, nil, false, false]
      end
    end
    results.each do |name, tier, band_ok, restricted|
      break if collected.size >= @size
      next unless band_ok

      cost = TeamBudget.cost_for(line_tier: tier.to_s, restricted: restricted)
      next if total_cost + cost > @budget_limit

      collected << name
      total_cost += cost
    end
    total_cost
  end

  def collect_rating_batch(collected, batch, total_cost)
    results = @parallelizer.map(batch) do |name|
      base_ok = @base_checker.call(name)
      gen_ok = @generation_checker.call(name)
      tier = @ratings.call(name)
      band_ok = base_ok && gen_ok && tier && @band.include?(tier)
      restricted = @restricted_checker.call(name)
      [name, tier, band_ok, restricted]
    end
    results.each do |name, tier, band_ok, restricted|
      break if collected.size >= @size
      next unless band_ok

      cost = TeamBudget.cost_for(line_tier: tier.to_s, restricted: restricted)
      next if total_cost + cost > @budget_limit

      collected << name
      total_cost += cost
    end
    total_cost
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def capped?(evaluated)
    @max_candidates && evaluated >= @max_candidates
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def complete_with_fallback(collected, total_cost = 0)
    return collected if collected.size == @size

    remaining = @names - collected
    filtered = remaining.select { |name| @base_checker.call(name) && @generation_checker.call(name) }
    # fallback precisa respeitar orçamento também
    fallback = []
    filtered.shuffle(random: @rng).each do |name|
      break if collected.size + fallback.size >= @size

      tier = tier_for_fallback(name)
      restricted = @restricted_checker.call(name)
      cost = TeamBudget.cost_for(line_tier: tier.to_s, restricted: restricted)
      next if total_cost + cost > @budget_limit

      fallback << name
      total_cost += cost
    end
    collected + fallback
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  def tier_for_fallback(name)
    if @ratings
      @ratings.call(name) || :F
    elsif @rater && @moves_fetcher
      pokemon = @fetcher.call(name)
      return :F unless pokemon

      moves = @moves_fetcher.call(pokemon.number)
      @rater.call(pokemon, moves) || :F
    else
      :F
    end
  end

  def assign_options(options)
    @parallelizer = options.fetch(:parallelizer, Parallelizer)
    @rater, @moves_fetcher, @band = options.values_at(:rater, :moves_fetcher, :band)
    @ratings, @max_candidates = options.values_at(:ratings, :max_candidates)
    @base_checker = options.fetch(:base_checker, ->(_name) { true })
    @generation_checker = options.fetch(:generation_checker, ->(_name) { true })
    @restricted_checker = options.fetch(:restricted_checker, ->(_name) { false })
    @budget_limit = options.fetch(:budget_limit, TeamBudget::BUDGET)
  end
end
# rubocop:enable Metrics/ClassLength
