# frozen_string_literal: true

require_relative "test_helper"

class SchemaTest < Minitest::Test
  def setup
    TestDatabase.setup!
  end

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

  def test_progress_table_exists_with_level_and_xp_columns_not_null
    assert TestDatabase.table_exists?("team_pokemon_progress"),
           "expected table team_pokemon_progress to exist"
    assert_equal "NO", TestDatabase.table_column_info("team_pokemon_progress", "level")["is_nullable"]
    assert_equal "NO", TestDatabase.table_column_info("team_pokemon_progress", "xp")["is_nullable"]
  end

  def test_battles_table_exists_with_required_columns_not_null
    assert TestDatabase.table_exists?("battles"), "expected table battles to exist"
    assert_equal "NO", TestDatabase.table_column_info("battles", "user_id")["is_nullable"]
    assert_equal "NO", TestDatabase.table_column_info("battles", "result")["is_nullable"]
    assert_equal "NO", TestDatabase.table_column_info("battles", "opponent_team")["is_nullable"]
  end

  def test_battles_table_has_index_on_user_and_created_at
    assert TestDatabase.index_with_columns("battles", "user_id", "created_at"),
           "expected index (user_id, created_at DESC)"
  end

  def test_wallet_table_exists_with_required_columns_not_null
    assert TestDatabase.table_exists?("wallet"), "expected table wallet to exist"
    assert_equal "NO", TestDatabase.table_column_info("wallet", "user_id")["is_nullable"]
    assert_equal "NO", TestDatabase.table_column_info("wallet", "balance")["is_nullable"]
    assert_equal "NO", TestDatabase.table_column_info("wallet", "updated_at")["is_nullable"]
  end

  def test_wallet_has_user_id_as_primary_key
    assert TestDatabase.primary_key("wallet", "user_id"), "expected user_id to be PK of wallet"
  end

  def test_progress_table_has_hp_columns_not_null
    assert_equal "NO", TestDatabase.table_column_info("team_pokemon_progress", "hp_max")["is_nullable"]
    assert_equal "NO", TestDatabase.table_column_info("team_pokemon_progress", "hp_current")["is_nullable"]
  end

  def test_inventory_table_exists_with_required_columns_not_null
    assert TestDatabase.table_exists?("inventory"), "expected table inventory to exist"
    assert_equal "NO", TestDatabase.table_column_info("inventory", "user_id")["is_nullable"]
    assert_equal "NO", TestDatabase.table_column_info("inventory", "item_name")["is_nullable"]
    assert_equal "NO", TestDatabase.table_column_info("inventory", "quantity")["is_nullable"]
  end

  def test_inventory_has_composite_primary_key
    assert TestDatabase.primary_key("inventory", "user_id"), "expected user_id in PK of inventory"
    assert TestDatabase.primary_key("inventory", "item_name"), "expected item_name in PK of inventory"
  end

  def test_clear_team_truncates_wallet
    TestDatabase.clear_team!
    with_wallet_row do
      TestDatabase.clear_team!
    end
    assert_equal 0, TestDatabase.wallet_balance("user-a")
  end

  def test_clear_team_truncates_supporting_progress_table
    TestDatabase.clear_team!
    with_progress_row do
      TestDatabase.clear_team!
    end
    assert_empty TestDatabase.distinct_user_ids
  end

  private

  def with_wallet_row
    TestDatabase.with_db do |connection|
      connection.exec_params(
        "INSERT INTO wallet (user_id, balance) VALUES ($1, $2)",
        ["user-a", 150]
      )
    end
    yield
  end

  def with_progress_row
    TestDatabase.with_db do |connection|
      row = connection.exec_params(
        "INSERT INTO team_pokemons (user_id, name, sprite, number, slot) VALUES ($1, $2, $3, $4, $5) RETURNING id",
        ["user-a", "pikachu", "", 25, 1]
      ).first
      connection.exec_params(
        "INSERT INTO team_pokemon_progress (team_pokemon_id) VALUES ($1)", [row["id"]]
      )
    end
    yield
  end
end
