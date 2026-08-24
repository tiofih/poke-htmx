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
