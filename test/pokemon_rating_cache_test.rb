# frozen_string_literal: true

require "tmpdir"
require_relative "test_helper"
require_relative "../lib/pokemon_rating"
require_relative "../lib/pokemon_rating_cache"

class FakeClock
  attr_accessor :now

  def initialize(now)
    @now = now
  end

  def call
    @now
  end
end

class PokemonRatingCacheTest < Minitest::Test
  def build_pokemon(name)
    Pokemon.new(
      name: name, sprite: "s", number: 1, types: ["normal"],
      stats: [{ name: "HP", value: 1300 }]
    )
  end

  def rater
    ->(_pokemon, moves:) { { score: 100, tier: moves.empty? ? :S : :A } }
  end

  def cache_for(path, fetcher: nil, moves_fetcher: nil, ttl: 7 * 24 * 60 * 60, clock: nil)
    PokemonRatingCache.new(
      path: path, ttl: ttl, clock: clock,
      fetcher: fetcher || ->(name) { build_pokemon(name) },
      moves_fetcher: moves_fetcher || ->(_number) { [] },
      rater: rater
    )
  end

  def test_rating_for_computes_and_returns_tier
    Dir.mktmpdir do |dir|
      cache = cache_for(File.join(dir, "ratings.json"))

      assert_equal :S, cache.rating_for("mewtwo")
    end
  end

  def test_hit_does_not_refetch
    Dir.mktmpdir do |dir|
      calls = 0
      fetcher = lambda do |name|
        calls += 1
        build_pokemon(name)
      end
      cache = cache_for(File.join(dir, "ratings.json"), fetcher: fetcher)

      2.times { cache.rating_for("mewtwo") }

      assert_equal 1, calls, "hit devolve o tier sem re-fetch do detail"
    end
  end

  def test_unknown_species_returns_nil_without_caching
    Dir.mktmpdir do |dir|
      calls = 0
      fetcher = lambda do |_name|
        calls += 1
        nil
      end
      cache = cache_for(File.join(dir, "ratings.json"), fetcher: fetcher)

      assert_nil cache.rating_for("missing")
      assert_nil cache.rating_for("missing")
      assert_equal 2, calls, "detail nulo nao e cacheado — consulta seguinte re-tenta"
    end
  end

  def test_expired_entry_is_refetched
    Dir.mktmpdir do |dir|
      clock = FakeClock.new(1_000)
      calls = 0
      fetcher = lambda do |name|
        calls += 1
        build_pokemon(name)
      end
      cache = cache_for(File.join(dir, "ratings.json"), fetcher: fetcher, ttl: 100, clock: clock)

      cache.rating_for("mewtwo")
      clock.now = 1_101
      cache.rating_for("mewtwo")

      assert_equal 2, calls, "entrada expirada e re-computada"
    end
  end

  def test_persists_between_instances
    Dir.mktmpdir do |dir|
      path = File.join(dir, "ratings.json")
      calls = 0
      fetcher = lambda do |name|
        calls += 1
        build_pokemon(name)
      end

      PokemonRatingCache.new(
        path: path, fetcher: fetcher, moves_fetcher: ->(_number) { [] }, rater: rater
      ).rating_for("mewtwo")

      reloaded = cache_for(path, fetcher: fetcher)
      assert_equal :S, reloaded.rating_for("mewtwo")
      assert_equal 1, calls, "segunda instancia le o arquivo sem re-fetch"
    end
  end

  def test_missing_file_is_tolerated
    Dir.mktmpdir do |dir|
      cache = cache_for(File.join(dir, "ratings.json"))

      assert_equal :S, cache.rating_for("mewtwo")
    end
  end
end
