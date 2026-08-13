# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/battle_repository"

module BattleRepositoryTestHelpers
  include TestSupport

  def setup
    TestDatabase.setup!
    TestDatabase.clear_battles!
    @repository = BattleRepository.new
  end

  def opponent(team)
    team.map { |name, number| { number: number, name: name } }
  end
end

class BattleAddTest < Minitest::Test
  include BattleRepositoryTestHelpers

  def test_add_persists_result_and_serialized_opponent
    @repository.add("user-a", "win", opponent([["pikachu", 25], ["bulbasaur", 1]]))
    @repository.add("user-a", "lose", opponent([["charmander", 4]]))

    rows = TestDatabase.battle_rows("user-a")
    assert_equal 2, rows.size
    assert_equal %w[lose win], rows.map { |row| row["result"] }.sort
    assert_includes rows.first["opponent_team"].to_json, "pikachu"
  end

  def test_recent_round_trips_opponent_team_identically
    team = opponent([["pikachu", 25], ["bulbasaur", 1]])
    @repository.add("user-a", "win", team)

    recent = @repository.recent("user-a")
    assert_equal team, recent.first[:opponent_team]
  end

  def test_recent_includes_created_at_from_database
    @repository.add("user-a", "win", opponent([["pikachu", 25]]))

    recent = @repository.recent("user-a")
    refute_nil recent.first[:created_at], "created_at deveria ser preenchido pelo banco"
  end

  def test_recent_returns_most_recent_first
    @repository.add("user-a", "win", opponent([["pikachu", 25]]))
    sleep 0.01
    @repository.add("user-a", "lose", opponent([["charmander", 4]]))

    recent = @repository.recent("user-a")
    recent_results = recent.map { |record| record[:result] }
    assert_equal %w[lose win], recent_results
  end

  def test_recent_respects_limit
    3.times { |index| @repository.add("user-a", "win", opponent([["pikachu", index]])) }

    assert_equal 2, @repository.recent("user-a", limit: 2).size
    assert_equal 3, @repository.recent("user-a").size
  end

  def test_recent_only_returns_own_user_records
    @repository.add("user-a", "win", opponent([["pikachu", 25]]))

    assert_empty @repository.recent("user-b")
  end

  def test_recent_empty_without_battles
    assert_empty @repository.recent("user-a")
  end
end

class BattleIsolationTest < Minitest::Test
  include BattleRepositoryTestHelpers

  def test_added_battles_are_isolated_per_user
    @repository.add("user-a", "win", opponent([["pikachu", 25]]))
    @repository.add("user-b", "lose", opponent([["charmander", 4]]))

    user_a = @repository.recent("user-a")
    user_b = @repository.recent("user-b")

    assert_equal 1, user_a.size
    assert_equal 1, user_b.size
    assert_equal "win", user_a.first[:result]
    assert_equal "lose", user_b.first[:result]
  end
end
