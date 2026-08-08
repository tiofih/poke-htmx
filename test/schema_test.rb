# frozen_string_literal: true

require_relative "test_helper"

class SchemaTest < Minitest::Test
  def test_team_pokemons_has_slot_column_not_null
    column = column_info("slot")
    refute_nil column, "expected column slot to exist"
    assert_equal "NO", column["is_nullable"]
  end

  def test_team_pokemons_has_unique_indexes_on_user_number_and_user_slot
    assert index_exists("team_pokemons", "user_id", "number"), "expected UNIQUE (user_id, number)"
    assert index_exists("team_pokemons", "user_id", "slot"), "expected UNIQUE (user_id, slot)"
  end

  def test_setup_is_idempotent
    TestDatabase.setup!
    TestDatabase.setup!
    assert index_exists("team_pokemons", "user_id", "slot")
  end

  private

  def column_info(column)
    connection = PG.connect(ENV.fetch("DATABASE_URL"))
    connection.exec_params(
      "SELECT is_nullable FROM information_schema.columns WHERE table_name = $1 AND column_name = $2",
      %w[team_pokemons] + [column]
    ).first
  ensure
    connection&.close
  end

  # rubocop:disable Metrics/MethodLength
  def index_exists(table, column_a, column_b)
    connection = PG.connect(ENV.fetch("DATABASE_URL"))
    connection.exec_params(
      <<~SQL,
        SELECT 1 FROM pg_indexes
        WHERE tablename = $1 AND indexdef ILIKE '%UNIQUE%'
          AND indexdef ILIKE '%(#{%(#{column_a}, #{column_b})})%'
      SQL
      [table]
    ).ntuples.positive?
  ensure
    connection&.close
  end
  # rubocop:enable Metrics/MethodLength
end
