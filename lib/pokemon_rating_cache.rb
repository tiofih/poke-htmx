# frozen_string_literal: true

require "fileutils"
require "json"
require_relative "pokemon_rating"

class PokemonRatingCache
  DEFAULT_TTL = 7 * 24 * 60 * 60

  def initialize(fetcher:, moves_fetcher:, path:, rater: PokemonRating.method(:rate),
                 ttl: DEFAULT_TTL, clock: nil)
    @path = path
    @ttl = ttl
    @clock = clock || -> { Process.clock_gettime(Process::CLOCK_REALTIME) }
    @fetcher = fetcher
    @moves_fetcher = moves_fetcher
    @rater = rater
    @entries = load_file
    @locks = {}
    @keys_mutex = Mutex.new
    @store_mutex = Mutex.new
  end

  def rating_for(name)
    lock_for(name).synchronize do
      cached = peek(name)
      return cached[:tier] if cached && fresh?(cached)

      tier = compute_tier(name)
      store(name, tier) unless tier.nil?
      tier
    end
  end

  private

  def compute_tier(name)
    pokemon = @fetcher.call(name)
    return nil unless pokemon

    moves = @moves_fetcher.call(pokemon.number) || []
    @rater.call(pokemon, moves: moves)[:tier]
  end

  def fresh?(entry)
    @clock.call - entry[:fetched_at] < @ttl
  end

  def peek(name)
    @store_mutex.synchronize { @entries[name] }
  end

  def store(name, tier)
    @store_mutex.synchronize do
      @entries[name] = { fetched_at: @clock.call, tier: tier }
      write_file
    end
  end

  def lock_for(name)
    @keys_mutex.synchronize { @locks[name] ||= Mutex.new }
  end

  def load_file
    return {} unless File.exist?(@path)

    JSON.parse(File.read(@path)).transform_values do |entry|
      { fetched_at: entry["fetched_at"], tier: entry["tier"].to_sym }
    end
  rescue JSON::ParserError
    {}
  end

  def write_file
    FileUtils.mkdir_p(File.dirname(@path))
    temporary = "#{@path}.tmp"
    File.write(temporary, JSON.generate(@entries))
    File.rename(temporary, @path)
  end
end
