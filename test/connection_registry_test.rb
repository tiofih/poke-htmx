# frozen_string_literal: true

require_relative "test_helper"

class ConnectionRegistryTest < Minitest::Test
  def setup
    TestDatabase.setup!
  end

  def teardown
    ConnectionRegistry.close_all!
  end

  def test_registers_connection_on_first_use
    repo = TeamRepository.new
    repo.all("user-a")
    assert_equal 1, ConnectionRegistry.size
  end

  def test_close_all_releases_connections_and_allows_reuse
    repo = TeamRepository.new
    repo.all("user-a")
    ConnectionRegistry.close_all!
    assert_equal 0, ConnectionRegistry.size
    assert_empty repo.all("user-b")
    assert_equal 1, ConnectionRegistry.size
  end

  def test_close_all_releases_connections_created_during_test
    ConnectionRegistry.close_all!
    baseline = open_connection_count
    20.times { |i| TeamRepository.new.all("user-#{i}") }
    assert_operator open_connection_count, :>, baseline
    ConnectionRegistry.close_all!
    assert_operator open_connection_count, :<=, baseline + 1
  end

  def test_release_current_thread_closes_and_removes_entries
    ConnectionRegistry.close_all!
    TeamRepository.new.all("user-a")
    TeamRepository.new.all("user-b")
    assert_equal 2, ConnectionRegistry.size

    ConnectionRegistry.release_current_thread!

    assert_equal 0, ConnectionRegistry.size, "release da thread remove as entradas da thread atual"
  end

  def test_caps_total_connections_with_lru_eviction
    ConnectionRegistry.close_all!
    db = ENV.fetch("DATABASE_URL")
    first = ConnectionRegistry.connection_for(:owner, 3000, db)
    (ConnectionRegistry::MAX_CONNECTIONS - 1).times do |i|
      ConnectionRegistry.connection_for(:owner, 3001 + i, db)
    end
    assert_equal ConnectionRegistry::MAX_CONNECTIONS, ConnectionRegistry.size

    ConnectionRegistry.connection_for(:owner, 3999, db)

    assert_operator ConnectionRegistry.size, :<=, ConnectionRegistry::MAX_CONNECTIONS
    assert first.finished?, "LRU evictada quando o teto estoura"
  end

  def test_eviction_prefers_dead_threads
    ConnectionRegistry.close_all!
    db = ENV.fetch("DATABASE_URL")
    dead_conn = Thread.new do
      ConnectionRegistry.connection_for(:dead_owner, Thread.current.object_id, db)
    end.value
    refute dead_conn.finished?, "sanity: conexao viva antes da eviccao"

    ConnectionRegistry::MAX_CONNECTIONS.times do |i|
      ConnectionRegistry.connection_for(:live_owner, 5000 + i, db)
    end

    assert dead_conn.finished?, "eviccao fecha a conexao de thread morta antes das LRU vivas"
    assert_operator ConnectionRegistry.size, :<=, ConnectionRegistry::MAX_CONNECTIONS
  end

  private

  def open_connection_count
    TestDatabase.with_db do |connection|
      connection.exec_params(
        "SELECT count(*) FROM pg_stat_activity WHERE datname = current_database()",
        []
      ).first["count"].to_i
    end
  end
end
