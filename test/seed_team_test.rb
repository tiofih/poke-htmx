# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/seed_team"

class SeedTeamTest < Minitest::Test
  def setup
    TestDatabase.clear_team!
    @user_id = "seed-test-user"
  end

  def teardown
    TestDatabase.clear_team!
  end

  def test_add_member_inserts_team_and_progress
    seed = SeedTeam.new(user_id: @user_id)
    seed.clear!
    seed.add_member(
      name: "pikachu", sprite: "https://example.com/pikachu.png",
      number: 25, slot: 1, moves: %w[thunder-shock quick-attack],
      level: 5, experience: 1499
    )

    row = TestDatabase.team_row("pikachu")
    refute_nil row
    assert_equal @user_id, row["user_id"]
    assert_equal "25", row["number"]
    assert_equal "1", row["slot"]
    assert_includes row["moves"], "thunder-shock"

    progress = TestDatabase.progress_row(row["id"])
    refute_nil progress
    assert_equal 5, progress["level"].to_i
    assert_equal 1499, progress["xp"].to_i
  end

  def test_add_member_defaults_level_and_xp
    seed = SeedTeam.new(user_id: @user_id)
    seed.clear!
    seed.add_member(
      name: "pikachu", sprite: "sprite", number: 25, slot: 1
    )

    row = TestDatabase.team_row("pikachu")
    progress = TestDatabase.progress_row(row["id"])
    assert_equal 1, progress["level"].to_i
    assert_equal 0, progress["xp"].to_i
  end

  def test_add_member_defaults_empty_moves
    seed = SeedTeam.new(user_id: @user_id)
    seed.clear!
    seed.add_member(
      name: "pikachu", sprite: "sprite", number: 25, slot: 1
    )

    row = TestDatabase.team_row("pikachu")
    assert_equal "{}", row["moves"]
  end

  def test_add_member_across_multiple_slots
    seed = SeedTeam.new(user_id: @user_id)
    seed.clear!
    [
      { name: "charmander", sprite: "s1", number: 4, slot: 1 },
      { name: "squirtle", sprite: "s2", number: 7, slot: 2 },
      { name: "bulbasaur", sprite: "s3", number: 1, slot: 3 },
      { name: "pikachu", sprite: "s4", number: 25, slot: 4 },
      { name: "eevee", sprite: "s5", number: 133, slot: 5 },
      { name: "dratini", sprite: "s6", number: 147, slot: 6 }
    ].each { |m| seed.add_member(**m) }

    rows = TestDatabase.with_db do |conn|
      conn.exec_params(
        "SELECT * FROM team_pokemons WHERE user_id = $1 ORDER BY slot",
        [@user_id]
      ).to_a
    end
    assert_equal 6, rows.size
    assert_equal(%w[charmander squirtle bulbasaur pikachu eevee dratini],
                 rows.map { |r| r["name"] })
    assert_equal(%w[1 2 3 4 5 6], rows.map { |r| r["slot"] })

    6.times do |i|
      progress = TestDatabase.progress_row(rows[i]["id"])
      refute_nil progress, "progress faltando para #{rows[i]['name']}"
    end
  end

  def test_clear_removes_only_own_user_id
    seed = SeedTeam.new(user_id: @user_id)
    seed.clear!
    seed.add_member(name: "pikachu", sprite: "s", number: 25, slot: 1)

    other = SeedTeam.new(user_id: "other-user")
    other.clear!
    other.add_member(name: "charmander", sprite: "s", number: 4, slot: 1)

    seed.clear!

    assert_nil TestDatabase.team_row("pikachu")
    refute_nil TestDatabase.team_row("charmander")
  end
end
