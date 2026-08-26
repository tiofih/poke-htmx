# frozen_string_literal: true

require_relative "poke_api_http"

class PokeApiCache
  DEFAULT_TTL = 600
  DEFAULT_MAX_ENTRIES = 1000

  attr_reader :inner, :ttl, :max_entries

  def initialize(api, ttl: DEFAULT_TTL, max_entries: DEFAULT_MAX_ENTRIES, clock: nil)
    @inner = api
    @ttl = ttl
    @max_entries = max_entries
    @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    @entries = {}
    @keys = {}
    @keys_mutex = Mutex.new
    @store_mutex = Mutex.new
  end

  def paginate(offset: 0, limit: 100, query: nil)
    @inner.paginate(offset: offset, limit: limit, query: query)
  end

  def find(name)
    fetch([:find, name], accept: ->(value) { !value.nil? }) { @inner.find(name) }
  end

  def detail(poke_id)
    fetch([:detail, poke_id], accept: ->(value) { !value.nil? }) { @inner.detail(poke_id) }
  end

  def available_move_names(number)
    fetch([:available_move_names, number]) { @inner.available_move_names(number) }
  end

  def move(name)
    fetch([:move, name], accept: ->(value) { !value.nil? }) { @inner.move(name) }
  end

  def moves_for(number)
    fetch([:moves_for, number]) { @inner.moves_for(number) }
  end

  def type_relations
    fetch([:type_relations]) { @inner.type_relations }
  end

  def fetch_all_names
    fetch([:fetch_all_names], accept: ->(value) { !value.empty? }) { @inner.fetch_all_names }
  end

  def next_evolutions(number)
    fetch([:next_evolutions, number]) { @inner.next_evolutions(number) }
  end

  def base_form?(name)
    fetch([:base_form, name], accept: ->(value) { value == true }) { @inner.base_form?(name) }
  end

  def learnable_moves(number)
    fetch([:learnable_moves, number]) { @inner.learnable_moves(number) }
  end

  def evolution_restricted?(name)
    fetch([:evolution_restricted, name], accept: ->(value) { value == true }) { @inner.evolution_restricted?(name) }
  end

  def generation_for(name)
    fetch([:generation_for, name], accept: ->(value) { !value.nil? }) { @inner.generation_for(name) }
  end

  def pokemon_names_by_type(type)
    fetch([:pokemon_names_by_type, type.to_s.strip.downcase],
          accept: ->(value) { value.is_a?(Array) && !value.empty? }) { @inner.pokemon_names_by_type(type) }
  end

  private

  def fetch(key, accept: nil)
    lock_for(key).synchronize do
      cached = peek(key)
      if cached && fresh?(cached)
        bump(key)
        return cached[:value]
      end

      value = yield
      store(key, value) if accept.nil? || accept.call(value)
      value
    end
  end

  def fresh?(entry)
    @clock.call - entry[:fetched_at] < @ttl
  end

  def store(key, value)
    @store_mutex.synchronize do
      @entries.delete(key)
      @entries[key] = { fetched_at: @clock.call, value: value }
      @entries.shift while @entries.size > @max_entries
    end
  end

  def peek(key)
    @store_mutex.synchronize { @entries[key] }
  end

  def bump(key)
    @store_mutex.synchronize do
      entry = @entries.delete(key)
      @entries[key] = entry if entry
    end
  end

  def lock_for(key)
    @keys_mutex.synchronize { @keys[key] ||= Mutex.new }
  end
end
