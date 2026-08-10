# frozen_string_literal: true

require_relative "test_helper"

class SchemaTest < Minitest::Test
  def test_team_pokemons_has_slot_column_not_null
    column = TestDatabase.column_info("slot")
    refute_nil column, "expected column slot to exist"
    assert_equal "NO", column["is_nullable"]
  end

  def test_team_pokemons_has_unique_indexes_on_user_number_and_user_slot
    assert TestDatabase.index_exists("team_pokemons", "user_id", "number"), "expected UNIQUE (user_id, number)"
    assert TestDatabase.index_exists("team_pokemons", "user_id", "slot"), "expected UNIQUE (user_id, slot)"
  end

  def test_setup_is_idempotent
    TestDatabase.setup!
    TestDatabase.setup!
    assert TestDatabase.index_exists("team_pokemons", "user_id", "slot")
  end
end
