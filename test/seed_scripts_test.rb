# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/seed_team"

class SeedScriptsTest < Minitest::Test
  def setup
    TestDatabase.clear_team!
  end

  def teardown
    TestDatabase.clear_team!
  end

  def test_team_basico_seeds_six_starters_level_one
    load_seed("team_basico", "team-basic")
    members = team_pokemon_names("team-basic")
    assert_equal 6, members.size
    assert_equal 6, team_progress_count("team-basic")

    members.each do |name|
      progress = member_progress(name, "team-basic")
      assert_equal 1, progress["level"].to_i, "#{name} deveria ser nível 1"
      assert_equal 0, progress["xp"].to_i, "#{name} deveria ter XP 0"
    end
  end

  def test_team_evolucao_seeds_near_evolution_thresholds
    load_seed("team_evolucao", "team-evol")
    members = team_pokemon_names("team-evol")
    assert_equal 6, members.size

    charmander = TestDatabase.team_row("charmander")
    refute_nil charmander
    charmander_progress = TestDatabase.progress_row(charmander["id"])
    assert_equal 15, charmander_progress["level"].to_i

    charmeleon = TestDatabase.team_row("charmeleon")
    refute_nil charmeleon
    charmeleon_progress = TestDatabase.progress_row(charmeleon["id"])
    assert_equal 35, charmeleon_progress["level"].to_i
  end

  def test_team_niveis_mistos_seeds_varied_levels
    load_seed("team_niveis_mistos", "team-mixed")
    members = team_pokemon_names("team-mixed")
    assert_equal 6, members.size

    levels = members.map { |n| member_progress(n, "team-mixed")["level"].to_i }
    assert levels.any? { |l| l == 1 }, "deve ter nível 1"
    assert levels.any? { |l| l >= 50 }, "deve ter nível 50+"
    assert_includes levels, 5
    assert_includes levels, 10
    assert_includes levels, 20
    assert_includes levels, 35
  end

  private

  def load_seed(name, user_id)
    load File.expand_path("../db/seeds/#{name}.rb", __dir__)
    klass = Object.const_get(camelize(name))
    klass.call(user_id: user_id)
  end

  def camelize(name)
    name.split("_").map(&:capitalize).join
  end

  def team_pokemon_names(user_id)
    TestDatabase.with_db do |conn|
      conn.exec_params(
        "SELECT name FROM team_pokemons WHERE user_id = $1 ORDER BY slot",
        [user_id]
      ).map { |r| r["name"] }
    end
  end

  def team_progress_count(user_id)
    TestDatabase.with_db do |conn|
      conn.exec_params(
        "SELECT COUNT(*) FROM team_pokemon_progress p " \
        "JOIN team_pokemons t ON t.id = p.team_pokemon_id " \
        "WHERE t.user_id = $1",
        [user_id]
      ).first["count"].to_i
    end
  end

  def member_progress(name, user_id)
    TestDatabase.with_db do |conn|
      conn.exec_params(
        "SELECT p.* FROM team_pokemon_progress p " \
        "JOIN team_pokemons t ON t.id = p.team_pokemon_id " \
        "WHERE t.name = $1 AND t.user_id = $2",
        [name, user_id]
      ).first
    end
  end
end
