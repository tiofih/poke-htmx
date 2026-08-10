# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/progression_repository"

module ProgressionRepositoryTestHelpers
  include TestSupport

  def setup
    TestDatabase.setup!
    TestDatabase.clear_team!
    @repository = TeamRepository.new
    @progression = ProgressionRepository.new
  end

  def add_pokemon(user_id, name, number)
    @repository.add(user_id, build_pokemon_record(name, number))
  end
end

class ProgressionGetTest < Minitest::Test
  include ProgressionRepositoryTestHelpers

  def test_get_returns_level_one_and_zero_xp_after_mounting
    add_pokemon("user-a", "pikachu", 25)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")

    assert_equal({ level: 1, xp: 0 }, @progression.get("user-a", pokemon_id))
  end

  def test_get_returns_nil_for_unknown_id
    assert_nil @progression.get("user-a", "999999")
  end

  def test_get_returns_nil_for_member_of_another_user
    add_pokemon("user-a", "pikachu", 25)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")

    assert_nil @progression.get("user-b", pokemon_id)
  end

  def test_get_requires_an_owner
    add_pokemon("user-a", "pikachu", 25)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")

    assert_nil @progression.get(nil, pokemon_id)
  end
end

class ProgressionGrantTest < Minitest::Test
  include ProgressionRepositoryTestHelpers

  def test_grant_sums_xp_and_returns_new_level_and_xp
    add_pokemon("user-a", "pikachu", 25)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")

    assert_equal({ level: 2, xp: 120 }, @progression.grant("user-a", pokemon_id, 120))
    assert_equal({ level: 2, xp: 120 }, @progression.get("user-a", pokemon_id))
  end

  def test_grant_recalculates_level_when_crossing_curves
    add_pokemon("user-a", "pikachu", 25)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")

    @progression.grant("user-a", pokemon_id, 350)

    assert_equal({ level: 3, xp: 350 }, @progression.get("user-a", pokemon_id))
  end

  def test_grant_accumulates_xp_across_calls
    add_pokemon("user-a", "pikachu", 25)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")

    @progression.grant("user-a", pokemon_id, 50)
    @progression.grant("user-a", pokemon_id, 50)

    assert_equal({ level: 2, xp: 100 }, @progression.get("user-a", pokemon_id))
  end

  def test_grant_for_another_users_member_is_noop
    add_pokemon("user-a", "pikachu", 25)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")

    assert_nil @progression.grant("user-b", pokemon_id, 100)
    assert_equal({ level: 1, xp: 0 }, @progression.get("user-a", pokemon_id))
  end

  def test_grant_for_unknown_id_is_noop
    assert_nil @progression.grant("user-a", "999999", 100)
  end
end
