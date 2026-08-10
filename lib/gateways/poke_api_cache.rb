# frozen_string_literal: true

require_relative "poke_api_http"

class PokeApiCache
  DEFAULT_TTL = 600
  DEFAULT_MAX_ENTRIES = 1000

  def initialize(api, ttl: DEFAULT_TTL, max_entries: DEFAULT_MAX_ENTRIES, clock: nil)
    @api = api
    @ttl = ttl
    @max_entries = max_entries
    @clock = clock || -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }
    @entries = {}
  end

  def paginate(offset: 0, limit: 100, query: nil)
    @api.paginate(offset: offset, limit: limit, query: query)
  end

  def find(name)
    fetch([:find, name]) { @api.find(name) }
  end

  def detail(poke_id)
    fetch([:detail, poke_id]) { @api.detail(poke_id) }
  end

  def available_move_names(number)
    fetch([:available_move_names, number]) { @api.available_move_names(number) }
  end

  def move(name)
    fetch([:move, name]) { @api.move(name) }
  end

  def moves_for(number)
    fetch([:moves_for, number]) { @api.moves_for(number) }
  end

  def type_relations
    fetch([:type_relations]) { @api.type_relations }
  end

  def fetch_all_names
    fetch([:fetch_all_names]) { @api.fetch_all_names }
  end

  private

  def fetch(key)
    entry = @entries[key]
    if entry && fresh?(entry)
      touch(key)
      return entry[:value]
    end

    value = yield
    store(key, value)
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
