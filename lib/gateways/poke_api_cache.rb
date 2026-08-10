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

  private

  def fetch(key, accept: nil)
    entry = @entries[key]
    if entry && fresh?(entry)
      touch(key)
      return entry[:value]
    end

    value = yield
    store(key, value) if accept.nil? || accept.call(value)
    value
  end

  def fresh?(entry)
    @clock.call - entry[:fetched_at] < @ttl
  end

  def store(key, value)
    entry = { fetched_at: @clock.call, value: value }
    @entries.delete(key)
    @entries[key] = entry
    evict_overflow
  end

  def touch(key)
    entry = @entries.delete(key)
    @entries[key] = entry if entry
  end

  def evict_overflow
    @entries.shift while @entries.size > @max_entries
  end
end
