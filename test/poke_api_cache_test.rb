# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/gateways/poke_api_cache"

class CountingApi
  attr_reader :detail_calls, :find_calls, :fetch_all_names_calls,
              :move_calls, :moves_for_calls, :type_relations_calls

  def initialize
    @detail_calls = 0
    @find_calls = 0
    @fetch_all_names_calls = 0
    @move_calls = 0
    @moves_for_calls = 0
    @type_relations_calls = 0
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
    @move_calls += 1
    Move.new(name: name, type: "normal", power: 40, accuracy: 100, pp: 35)
  end

  def moves_for(_number)
    @moves_for_calls += 1
    [move("thunder-shock")]
  end

  def available_move_names(_number)
    %w[growl thunder-shock]
  end

  def type_relations
    @type_relations_calls += 1
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

  def test_evicts_least_recently_used_when_over_max_entries
    cache = PokeApiCache.new(@inner, ttl: 600, max_entries: 2, clock: @clock)

    cache.find("a")
    cache.find("b")
    cache.find("a")
    cache.find("c")

    assert_equal 3, @inner.find_calls
  end

  def test_evicted_entry_is_refetched
    cache = PokeApiCache.new(@inner, ttl: 600, max_entries: 2, clock: @clock)

    cache.find("a")
    cache.find("b")
    cache.find("a")
    cache.find("c")
    cache.find("b")

    assert_equal 4, @inner.find_calls
  end

  def test_most_recently_used_survives_eviction
    cache = PokeApiCache.new(@inner, ttl: 600, max_entries: 2, clock: @clock)

    cache.find("a")
    cache.find("b")
    cache.find("a")
    cache.find("c")
    cache.find("a")

    assert_equal 3, @inner.find_calls
  end

  def test_nil_from_find_is_not_cached
    @inner.define_singleton_method(:find) do |name|
      @find_calls += 1
      name == "missing" ? nil : Pokemon.new(name: name, sprite: "s", number: 1)
    end

    assert_nil @cache.find("missing")
    assert_nil @cache.find("missing")
    assert_equal 2, @inner.find_calls
  end

  def test_nil_from_detail_is_not_cached
    @inner.define_singleton_method(:detail) do |poke_id|
      @detail_calls += 1
      poke_id == 999 ? nil : Pokemon.new(name: "pikachu", sprite: "s", number: poke_id)
    end

    assert_nil @cache.detail(999)
    assert_nil @cache.detail(999)
    assert_equal 2, @inner.detail_calls
  end

  def test_nil_from_move_is_not_cached
    @inner.define_singleton_method(:move) do |name|
      @move_calls += 1
      name == "missing" ? nil : Move.new(name: name, type: "normal", power: 10, accuracy: 100, pp: 20)
    end

    assert_nil @cache.move("missing")
    assert_nil @cache.move("missing")
    assert_equal 2, @inner.move_calls
  end

  def test_empty_fetch_all_names_is_not_cached
    @inner.define_singleton_method(:fetch_all_names) do
      @fetch_all_names_calls += 1
      @fetch_all_names_calls == 1 ? [] : %w[pikachu]
    end

    assert_empty @cache.fetch_all_names
    assert_equal %w[pikachu], @cache.fetch_all_names
    assert_equal 2, @inner.fetch_all_names_calls
  end

  def test_moves_for_caches_its_value
    first = @cache.moves_for(25)
    @cache.moves_for(25)

    assert_equal first, @cache.moves_for(25)
    assert_equal 1, @inner.moves_for_calls
  end

  def test_type_relations_caches_its_value
    first = @cache.type_relations
    @cache.type_relations

    assert_equal first, @cache.type_relations
    assert_equal 1, @inner.type_relations_calls
  end

  def test_cache_entries_are_isolated_by_method
    @cache.find("pikachu")
    @cache.detail(25)

    assert_equal 1, @inner.find_calls
    assert_equal 1, @inner.detail_calls
  end

  def test_cache_entries_are_isolated_by_argument
    @cache.find("pikachu")
    @cache.find("bulbasaur")

    assert_equal 2, @inner.find_calls
  end
end
