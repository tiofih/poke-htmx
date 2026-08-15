# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/inventory_repository"
require_relative "../lib/item_catalog"

module InventoryRepositoryTestHelpers
  def setup
    TestDatabase.setup!
    TestDatabase.clear_team!
    @repository = InventoryRepository.new
  end
end

class InventoryAllTest < Minitest::Test
  include InventoryRepositoryTestHelpers

  def test_all_returns_empty_list_without_rows
    assert_equal [], @repository.all("user-a")
  end

  def test_all_returns_entries_ordered_by_name
    @repository.add("user-a", "hyper-potion", 2)
    @repository.add("user-a", "potion", 3)

    entries = @repository.all("user-a")
    names = entries.map { |entry| entry[:name] }

    assert_equal %w[hyper-potion potion], names
    assert_equal 2, entries.first[:quantity]
    assert_equal 3, entries.last[:quantity]
  end
end

class InventoryAddTest < Minitest::Test
  include InventoryRepositoryTestHelpers

  def test_add_creates_row_with_quantity
    assert_equal 3, @repository.add("user-a", "potion", 3)
    assert_equal 3, @repository.count("user-a", "potion")
  end

  def test_add_accumulates_via_upsert
    @repository.add("user-a", "potion", 3)
    assert_equal 5, @repository.add("user-a", "potion", 2)
    assert_equal 5, @repository.count("user-a", "potion")
  end

  def test_add_with_zero_is_noop
    @repository.add("user-a", "potion", 3)
    assert_equal 3, @repository.add("user-a", "potion", 0)
    assert_equal 3, @repository.count("user-a", "potion")
  end

  def test_add_with_nil_is_noop
    @repository.add("user-a", "potion", 3)
    assert_equal 3, @repository.add("user-a", "potion", nil)
    assert_equal 3, @repository.count("user-a", "potion")
  end

  def test_add_with_negative_is_noop
    @repository.add("user-a", "potion", 3)
    assert_equal 3, @repository.add("user-a", "potion", -2)
    assert_equal 3, @repository.count("user-a", "potion")
  end

  def test_add_item_outside_catalog_is_noop
    assert_equal 0, @repository.add("user-a", "master-ball", 2)
    assert_equal 0, @repository.count("user-a", "master-ball")
  end
end

class InventoryCountTest < Minitest::Test
  include InventoryRepositoryTestHelpers

  def test_count_returns_zero_without_row
    assert_equal 0, @repository.count("user-a", "potion")
  end
end

class InventoryIsolationTest < Minitest::Test
  include InventoryRepositoryTestHelpers

  def test_inventories_are_isolated_per_user
    @repository.add("user-a", "potion", 3)
    @repository.add("user-b", "potion", 5)

    assert_equal 3, @repository.count("user-a", "potion")
    assert_equal 5, @repository.count("user-b", "potion")
    user_b_potion = @repository.all("user-b").find { |entry| entry[:name] == "potion" }
    assert_equal 5, user_b_potion[:quantity]
  end
end
