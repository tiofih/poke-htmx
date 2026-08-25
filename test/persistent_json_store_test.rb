# frozen_string_literal: true

require "tmpdir"
require_relative "test_helper"
require_relative "../lib/gateways/persistent_json_store"

class FakeTime
  attr_accessor :now

  def initialize(now)
    @now = now
  end

  def call
    @now
  end
end

class PersistentJsonStoreTest < Minitest::Test
  def setup
    @original_faraday = Faraday.method(:get)
  end

  def teardown
    Faraday.define_singleton_method(:get, @original_faraday)
  end

  def stub_faraday(payload:, status: 200)
    Faraday.define_singleton_method(:get) do |_url|
      Struct.new(:status, :body).new(status, JSON.generate(payload))
    end
  end

  def fail_network
    Faraday.define_singleton_method(:get) { |_url| raise Faraday::ConnectionFailed, "no network" }
  end

  def test_returns_parsed_json_and_persists_to_file_on_flush
    Dir.mktmpdir do |dir|
      path = File.join(dir, "cache.json")
      stub_faraday(payload: { "name" => "pikachu", "id" => 25 })

      store = PersistentJsonStore.new(path: path, background: false)
      value = store.get("https://pokeapi.co/api/v2/pokemon/25")
      store.flush!

      assert_equal 25, value["id"]
      assert File.exist?(path)
      assert_equal(
        { "name" => "pikachu", "id" => 25 },
        JSON.parse(File.read(path))["https://pokeapi.co/api/v2/pokemon/25"]["value"]
      )
    end
  end

  def test_store_updates_memory_without_writing_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, "cache.json")
      stub_faraday(payload: { "name" => "pikachu" })

      store = PersistentJsonStore.new(path: path, background: false)
      store.get("https://pokeapi.co/api/v2/pokemon/25")

      refute File.exist?(path), "store so atualiza a memoria; escrita fica para o flush"
    end
  end

  def test_flush_is_idempotent
    Dir.mktmpdir do |dir|
      path = File.join(dir, "cache.json")
      stub_faraday(payload: { "name" => "pikachu" })

      store = PersistentJsonStore.new(path: path, background: false)
      store.get("https://pokeapi.co/api/v2/pokemon/25")
      store.flush!
      store.flush!

      assert_equal "pikachu",
                   JSON.parse(File.read(path))["https://pokeapi.co/api/v2/pokemon/25"]["value"]["name"]
    end
  end

  def test_second_instance_serves_without_network
    Dir.mktmpdir do |dir|
      path = File.join(dir, "cache.json")
      stub_faraday(payload: { "name" => "bulbasaur" })

      first = PersistentJsonStore.new(path: path, background: false)
      first.get("https://pokeapi.co/api/v2/pokemon/1")
      first.flush!

      fail_network
      reloaded = PersistentJsonStore.new(path: path, background: false)
      assert_equal "bulbasaur", reloaded.get("https://pokeapi.co/api/v2/pokemon/1")["name"]
    end
  end

  def test_nil_response_is_not_persisted
    Dir.mktmpdir do |dir|
      path = File.join(dir, "cache.json")
      Faraday.define_singleton_method(:get) { |_url| Struct.new(:status, :body).new(404, "") }

      store = PersistentJsonStore.new(path: path, background: false)
      assert_nil store.get("https://pokeapi.co/api/v2/pokemon/999")
      store.flush!

      refute File.exist?(path), "sem valor para persistir nao cria arquivo"
    end
  end

  def test_expired_entry_is_refetched
    Dir.mktmpdir do |dir|
      path = File.join(dir, "cache.json")
      clock = FakeTime.new(1_000)
      calls = 0
      Faraday.define_singleton_method(:get) do |_url|
        calls += 1
        Struct.new(:status, :body).new(200, JSON.generate("item" => calls))
      end

      store = PersistentJsonStore.new(path: path, ttl: 600, clock: clock, background: false)
      store.get("https://pokeapi.co/api/v2/pokemon/25")
      clock.now = 1_601
      store.get("https://pokeapi.co/api/v2/pokemon/25")

      assert_equal 2, calls
    end
  end

  def test_corrupt_file_is_tolerated
    Dir.mktmpdir do |dir|
      path = File.join(dir, "cache.json")
      File.write(path, "{not valid json")

      stub_faraday(payload: { "name" => "squirtle" })
      store = PersistentJsonStore.new(path: path, background: false)

      assert_equal "squirtle", store.get("https://pokeapi.co/api/v2/pokemon/7")["name"]
    end
  end

  def test_missing_file_is_tolerated
    Dir.mktmpdir do |dir|
      stub_faraday(payload: { "name" => "charmander" })
      store = PersistentJsonStore.new(path: File.join(dir, "cache.json"), background: false)

      assert_equal "charmander", store.get("https://pokeapi.co/api/v2/pokemon/4")["name"]
    end
  end

  def test_background_writer_persists_after_interval
    Dir.mktmpdir do |dir|
      path = File.join(dir, "cache.json")
      stub_faraday(payload: { "name" => "pikachu" })

      store = PersistentJsonStore.new(path: path, write_interval: 0.05)
      store.get("https://pokeapi.co/api/v2/pokemon/25")

      sleep 0.2
      assert File.exist?(path), "writer em background persiste apos o intervalo"
      assert_equal "pikachu",
                   JSON.parse(File.read(path))["https://pokeapi.co/api/v2/pokemon/25"]["value"]["name"]
    end
  end
end
