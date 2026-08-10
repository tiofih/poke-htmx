# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/gateways/poke_api_cache"

class CountingApi
  attr_reader :detail_calls, :find_calls, :fetch_all_names_calls

  def initialize
    @detail_calls = 0
    @find_calls = 0
    @fetch_all_names_calls = 0
  end

  def detail(poke_id)
    @detail_calls += 1
    Pokemon.new(name: "pikachu", sprite: "sprite", number: poke_id)
  end

  def find(name)
    @find_calls += 1
    Pokemon.new(name: name, sprite: "sprite", number: 25)
  end

  def fetch_all_names
    @fetch_all_names_calls += 1
    %w[pikachu bulbasaur]
  end

  def paginate(offset: 0, limit: 100, query: nil)
    names = fetch_all_names
    names = names.select { |name| name.downcase.include?(query.downcase) } if query && !query.empty?
    { names: names[offset, limit].to_a, total: names.size }
  end

  def move(name)
    Move.new(name: name, type: "normal", power: 40, accuracy: 100, pp: 35)
  end

  def moves_for(_number)
    [move("thunder-shock")]
  end

  def available_move_names(_number)
    %w[growl thunder-shock]
  end

  def type_relations
    { "normal" => { "double" => [], "half" => [], "no" => ["ghost"] } }
  end
end

class FakeClock
  attr_reader :now

  def initialize(now)
    @now = now
  end

  def tick(seconds)
    @now += seconds
  end

  def call
    @now
  end
end

class PokeApiCacheTest < Minitest::Test
  def setup
    @inner = CountingApi.new
    @clock = FakeClock.new(0)
    @cache = PokeApiCache.new(@inner, ttl: 600, max_entries: 1000, clock: @clock)
  end

  def test_detail_is_delegated_via_interface
    @cache.detail(25)

    assert_equal 1, @inner.detail_calls
  end

  def test_detail_is_cached_within_ttl
    first = @cache.detail(25)
    second = @cache.detail(25)

    assert_same first, second
    assert_equal 1, @inner.detail_calls
  end

  def test_detail_refetches_after_ttl_expires
    @cache.detail(25)
    @clock.tick(601)

    @cache.detail(25)

    assert_equal 2, @inner.detail_calls
  end

  def test_detail_stays_cached_when_ttl_not_reached
    @cache.detail(25)
    @clock.tick(599)

    @cache.detail(25)

    assert_equal 1, @inner.detail_calls
  end

  def test_find_uses_own_cache_entry
    cached = @cache.find("pikachu")
    @cache.find("pikachu")

    assert_same cached, @cache.find("pikachu")
    assert_equal 1, @inner.find_calls
  end
end
