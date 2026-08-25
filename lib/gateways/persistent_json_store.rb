# frozen_string_literal: true

require "faraday"
require "fileutils"
require "json"

class PersistentJsonStore
  DEFAULT_TTL = 7 * 24 * 60 * 60
  DEFAULT_WRITE_INTERVAL = 30

  def initialize(path:, ttl: DEFAULT_TTL, clock: nil, background: true,
                 write_interval: DEFAULT_WRITE_INTERVAL)
    @path = path
    @ttl = ttl
    @clock = clock || -> { Process.clock_gettime(Process::CLOCK_REALTIME) }
    @write_interval = write_interval
    setup_state
    setup_background if background
  end

  def get(url)
    lock_for(url).synchronize do
      cached = peek(url)
      return cached[:value] if cached && fresh?(cached)

      value = transport_get(url)
      store(url, value) unless value.nil?
      value
    end
  end

  def flush!
    snapshot = nil
    @store_mutex.synchronize do
      if @dirty
        snapshot = @entries.dup
        @dirty = false
      end
    end
    write_snapshot(snapshot) if snapshot
  end

  private

  def setup_state
    @entries = load_file
    @locks = {}
    @keys_mutex = Mutex.new
    @store_mutex = Mutex.new
    @write_mutex = Mutex.new
    @dirty = false
  end

  def setup_background
    start_writer
    at_exit { flush! }
  end

  def store(url, value)
    @store_mutex.synchronize do
      @entries[url] = { fetched_at: @clock.call, value: value }
      @dirty = true
    end
  end

  def start_writer
    Thread.new do
      loop do
        sleep(@write_interval)
        flush!
      end
    end
  end

  def write_snapshot(entries)
    @write_mutex.synchronize { write_file(entries) }
  end

  def transport_get(url)
    response = Faraday.get(url)
    return nil unless response.respond_to?(:status) && response.status == 200

    JSON.parse(response.body)
  rescue Faraday::Error, JSON::ParserError
    nil
  end

  def fresh?(entry)
    @clock.call - entry[:fetched_at] < @ttl
  end

  def peek(url)
    @store_mutex.synchronize { @entries[url] }
  end

  def lock_for(url)
    @keys_mutex.synchronize { @locks[url] ||= Mutex.new }
  end

  def load_file
    return {} unless File.exist?(@path)

    parsed = JSON.parse(File.read(@path))
    parsed.each_with_object({}) do |(url, entry), acc|
      acc[url] = { fetched_at: entry["fetched_at"], value: entry["value"] }
    end
  rescue JSON::ParserError
    {}
  end

  def write_file(entries)
    FileUtils.mkdir_p(File.dirname(@path))
    temporary = "#{@path}.tmp"
    File.write(temporary, JSON.generate(entries))
    File.rename(temporary, @path)
  end
end
