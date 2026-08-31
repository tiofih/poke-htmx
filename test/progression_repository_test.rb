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

    assert_equal({ level: 5, xp: 1000, hp_max: 0, hp_current: 0 }, @progression.get("user-a", pokemon_id))
  end

  # C2 D2 A
  def test_existing_progress_not_migrated
    add_pokemon("user-a", "pikachu", 25)
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    # simula membro antigo nivel 1 xp 0
    TestDatabase.with_db do |connection|
      connection.exec_params(
        "UPDATE team_pokemon_progress SET level = 1, xp = 0 WHERE team_pokemon_id = $1",
        [pikachu_id]
      )
    end
    # novo membro deve nascer 5/1000 sem migrar o antigo
    add_pokemon("user-a", "bulbasaur", 1)
    bulbasaur_id = TestDatabase.team_id("bulbasaur", "user-a")

    assert_equal({ level: 1, xp: 0, hp_max: 0, hp_current: 0 }, @progression.get("user-a", pikachu_id))
    assert_equal({ level: 5, xp: 1000, hp_max: 0, hp_current: 0 }, @progression.get("user-a", bulbasaur_id))
  end

  # alias C2
  def test_existing_team_stays_at_current_level
    add_pokemon("user-a", "pikachu", 25)
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    TestDatabase.with_db do |connection|
      connection.exec_params(
        "UPDATE team_pokemon_progress SET level = 1, xp = 0 WHERE team_pokemon_id = $1",
        [pikachu_id]
      )
    end
    add_pokemon("user-a", "charmander", 4)
    assert_equal 1, @progression.get("user-a", pikachu_id)[:level]
    assert_equal 0, @progression.get("user-a", pikachu_id)[:xp]
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

  def test_get_includes_hp_columns_defaulting_to_zero
    add_pokemon("user-a", "pikachu", 25)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")

    assert_equal(0, @progression.get("user-a", pokemon_id)[:hp_max])
    assert_equal(0, @progression.get("user-a", pokemon_id)[:hp_current])
  end
end

class ProgressionHpTest < Minitest::Test
  include ProgressionRepositoryTestHelpers

  def test_update_hp_persists_values
    add_pokemon("user-a", "pikachu", 25)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")

    @progression.update_hp("user-a", pokemon_id, 45, 12)

    result = @progression.get("user-a", pokemon_id)
    assert_equal 45, result[:hp_max]
    assert_equal 12, result[:hp_current]
  end

  def test_update_hp_overwrites_previous_values
    add_pokemon("user-a", "pikachu", 25)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 45, 12)

    @progression.update_hp("user-a", pokemon_id, 45, 45)

    result = @progression.get("user-a", pokemon_id)
    assert_equal 45, result[:hp_max]
    assert_equal 45, result[:hp_current]
  end

  def test_update_hp_for_unknown_id_is_noop
    @progression.update_hp("user-a", "999999", 45, 12)

    assert_nil @progression.get("user-a", "999999")
  end

  def test_update_hp_for_another_users_member_is_noop
    add_pokemon("user-a", "pikachu", 25)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 45, 12)

    @progression.update_hp("user-b", pokemon_id, 99, 99)

    result = @progression.get("user-a", pokemon_id)
    assert_equal 45, result[:hp_max]
    assert_equal 12, result[:hp_current]
  end
end

class ProgressionGrantTest < Minitest::Test
  include ProgressionRepositoryTestHelpers

  def test_grant_sums_xp_and_returns_new_level_and_xp
    add_pokemon("user-a", "pikachu", 25)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")

    assert_equal({ level: 5, xp: 1120 }, @progression.grant("user-a", pokemon_id, 120))
    assert_equal({ level: 5, xp: 1120, hp_max: 0, hp_current: 0 }, @progression.get("user-a", pokemon_id))
  end

  def test_grant_recalculates_level_when_crossing_curves
    add_pokemon("user-a", "pikachu", 25)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")

    @progression.grant("user-a", pokemon_id, 350)

    assert_equal({ level: 5, xp: 1350, hp_max: 0, hp_current: 0 }, @progression.get("user-a", pokemon_id))
  end

  def test_grant_accumulates_xp_across_calls
    add_pokemon("user-a", "pikachu", 25)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")

    @progression.grant("user-a", pokemon_id, 50)
    @progression.grant("user-a", pokemon_id, 50)

    assert_equal({ level: 5, xp: 1100, hp_max: 0, hp_current: 0 }, @progression.get("user-a", pokemon_id))
  end

  def test_grant_for_another_users_member_is_noop
    add_pokemon("user-a", "pikachu", 25)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")

    assert_nil @progression.grant("user-b", pokemon_id, 100)
    assert_equal({ level: 5, xp: 1000, hp_max: 0, hp_current: 0 }, @progression.get("user-a", pokemon_id))
  end

  def test_grant_for_unknown_id_is_noop
    assert_nil @progression.grant("user-a", "999999", 100)
  end
end
