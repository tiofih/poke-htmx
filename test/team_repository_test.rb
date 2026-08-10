# frozen_string_literal: true

require_relative "test_helper"

module TeamRepositoryTestHelpers
  include TestSupport

  def setup
    TestDatabase.setup!
    TestDatabase.clear_team!
    @repository = TeamRepository.new
  end

  def add_pokemon(user_id, name, number)
    @repository.add(user_id, build_pokemon_record(name, number))
  end
end

class TeamAddTest < Minitest::Test
  include TeamRepositoryTestHelpers

  def test_add_rejects_duplicate_number_with_duplicate_error
    add_pokemon("user-a", "pikachu", 25)
    @repository.add("user-a", build_pokemon_record("pikachu-raichu", 26))

    dup = build_pokemon_record("pikachu", 26)
    error = assert_raises(TeamRepository::DuplicateError) { @repository.add("user-a", dup) }

    assert_match(/já está|repetid/i, error.message)
    assert_equal 2, @repository.all("user-a").size
  end

  def test_add_persists_pokemon_and_all_returns_it
    pokemon = build_pokemon_record("pikachu", 25)

    @repository.add("user-a", pokemon)
    rows = @repository.all("user-a")

    assert_equal 1, rows.size
    assert_instance_of Pokemon, rows.first
    assert_equal "pikachu", rows.first.name
    assert_equal "https://example.com/pikachu.png", rows.first.sprite
    assert_equal 25, rows.first.number
  end

  def test_add_rejects_seventh_pokemon_with_team_full_error
    (1..6).each { |n| @repository.add("user-a", build_pokemon_record("pokemon#{n}", n)) }

    seventh = build_pokemon_record("meowth", 52)
    error = assert_raises(TeamRepository::TeamFullError) { @repository.add("user-a", seventh) }

    assert_match(/cheio|full/i, error.message)
    assert_equal 6, @repository.all("user-a").size
  end

  def test_add_assigns_slots_in_insertion_order_and_persists_slot
    [["pikachu", 25], ["bulbasaur", 1], ["charmander", 4]].each do |name, number|
      @repository.add("user-a", build_pokemon_record(name, number))
    end

    rows = @repository.all("user-a")
    assert_equal [1, 2, 3], rows.map(&:slot)
    assert_equal %w[pikachu bulbasaur charmander], rows.map(&:name)
    assert_equal 3, TestDatabase.team_row("charmander")["slot"].to_i
  end

  def test_add_persists_pokemon_with_user_id
    @repository.add("user-a", build_pokemon_record("pikachu", 25))

    row = TestDatabase.team_row("pikachu")
    assert_equal "user-a", row["user_id"]
  end
end

class TeamReadTest < Minitest::Test
  include TeamRepositoryTestHelpers

  def test_all_returns_empty_array_for_empty_database
    assert_equal [], @repository.all("user-a")
  end

  def test_pokemon_slot_defaults_to_nil_and_accepts_value
    assert_nil build_pokemon_record("pikachu", 25).slot
    with_slot = Pokemon.new(name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25, slot: 3)
    assert_equal 3, with_slot.slot
  end

  def test_all_returns_only_own_users_pokemon
    add_pokemon("user-a", "pikachu", 25)
    add_pokemon("user-b", "bulbasaur", 1)

    assert_equal %w[pikachu], @repository.all("user-a").map(&:name)
    assert_equal %w[bulbasaur], @repository.all("user-b").map(&:name)
  end

  def test_slots_are_independent_per_user
    add_pokemon("user-a", "pikachu", 25)
    add_pokemon("user-b", "bulbasaur", 1)
    add_pokemon("user-a", "squirtle", 7)

    assert_equal [1, 2], @repository.all("user-a").map(&:slot)
    assert_equal [1], @repository.all("user-b").map(&:slot)
  end

  def test_pokemon_moves_defaults_to_empty_array
    assert_equal [], build_pokemon_record("pikachu", 25).moves
    with_moves = Pokemon.new(
      name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25,
      moves: %w[thunder-shock quick-attack]
    )
    assert_equal %w[thunder-shock quick-attack], with_moves.moves
  end

  def test_all_returns_empty_moves_by_default
    add_pokemon("user-a", "pikachu", 25)

    assert_equal [], @repository.all("user-a").first.moves
  end
end

class TeamRemoveTest < Minitest::Test
  include TeamRepositoryTestHelpers

  def test_remove_deletes_pokemon_by_id
    add_pokemon("user-a", "pikachu", 25)
    add_pokemon("user-a", "bulbasaur", 1)

    first_id = TestDatabase.team_id("pikachu", "user-a")
    @repository.remove("user-a", first_id)

    remaining = @repository.all("user-a")
    assert_equal %w[bulbasaur], remaining.map(&:name)
  end

  def test_remove_recompacts_slots
    [["pikachu", 25], ["bulbasaur", 1], ["charmander", 4]].each do |name, number|
      @repository.add("user-a", build_pokemon_record(name, number))
    end

    bulbasaur_id = TestDatabase.team_id("bulbasaur", "user-a")
    @repository.remove("user-a", bulbasaur_id)

    remaining = @repository.all("user-a")
    assert_equal [1, 2], remaining.map(&:slot)
    assert_equal %w[pikachu charmander], remaining.map(&:name)

    @repository.add("user-a", build_pokemon_record("squirtle", 7))
    assert_equal [1, 2, 3], @repository.all("user-a").map(&:slot)
  end

  def test_remove_only_deletes_own_users_pokemon
    add_pokemon("user-a", "pikachu", 25)
    add_pokemon("user-b", "bulbasaur", 1)

    bulbasaur_id = TestDatabase.team_id("bulbasaur", "user-b")
    @repository.remove("user-a", bulbasaur_id)

    assert_equal %w[pikachu], @repository.all("user-a").map(&:name)
    assert_equal %w[bulbasaur], @repository.all("user-b").map(&:name)
  end
end

class TeamMoveTest < Minitest::Test
  include TeamRepositoryTestHelpers

  def four_pokemon_team(user_id)
    add_team(user_id, [["pikachu", 25], ["bulbasaur", 1], ["charmander", 4], ["squirtle", 7]])
  end

  def test_move_moves_member_up_and_keeps_slots_contiguous
    four_pokemon_team("user-a")
    charmander_id = TestDatabase.team_id("charmander", "user-a")

    @repository.move("user-a", charmander_id, 1)

    rows = @repository.all("user-a")
    assert_equal %w[charmander pikachu bulbasaur squirtle], rows.map(&:name)
    assert_equal [1, 2, 3, 4], rows.map(&:slot)
  end

  def test_move_moves_member_down_and_keeps_slots_contiguous
    four_pokemon_team("user-a")

    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @repository.move("user-a", pikachu_id, 4)

    rows = @repository.all("user-a")
    assert_equal %w[bulbasaur charmander squirtle pikachu], rows.map(&:name)
    assert_equal [1, 2, 3, 4], rows.map(&:slot)

    squirtle_id = TestDatabase.team_id("squirtle", "user-a")
    @repository.move("user-a", squirtle_id, 2)

    rows = @repository.all("user-a")
    assert_equal %w[bulbasaur squirtle charmander pikachu], rows.map(&:name)
    assert_equal [1, 2, 3, 4], rows.map(&:slot)
  end

  def test_move_to_same_slot_is_noop
    four_pokemon_team("user-a")
    charmander_id = TestDatabase.team_id("charmander", "user-a")

    @repository.move("user-a", charmander_id, 3)

    assert_equal %w[pikachu bulbasaur charmander squirtle], @repository.all("user-a").map(&:name)
  end

  def test_move_to_out_of_range_slot_is_noop
    four_pokemon_team("user-a")
    charmander_id = TestDatabase.team_id("charmander", "user-a")

    @repository.move("user-a", charmander_id, 0)
    assert_equal [1, 2, 3, 4], @repository.all("user-a").map(&:slot)

    @repository.move("user-a", charmander_id, 99)
    assert_equal [1, 2, 3, 4], @repository.all("user-a").map(&:slot)
  end

  def test_move_with_unknown_id_is_noop
    four_pokemon_team("user-a")

    @repository.move("user-a", "999999", 1)

    assert_equal %w[pikachu bulbasaur charmander squirtle], @repository.all("user-a").map(&:name)
  end

  def test_move_of_other_users_member_is_noop
    four_pokemon_team("user-a")
    four_pokemon_team("user-b")

    charmander_b_id = TestDatabase.team_id("charmander", "user-b")
    @repository.move("user-a", charmander_b_id, 1)

    assert_equal %w[pikachu bulbasaur charmander squirtle], @repository.all("user-a").map(&:name)
    assert_equal %w[pikachu bulbasaur charmander squirtle], @repository.all("user-b").map(&:name)
  end
end

class TeamMovesTest < Minitest::Test
  include TeamRepositoryTestHelpers

  def test_add_persists_moves
    pikachu = Pokemon.new(
      name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25,
      moves: %w[thunder-shock quick-attack]
    )
    @repository.add("user-a", pikachu)

    assert_equal %w[thunder-shock quick-attack], @repository.all("user-a").first.moves
  end

  def test_set_moves_persists_moves_and_all_returns_them
    add_pokemon("user-a", "pikachu", 25)
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")

    @repository.set_moves("user-a", pikachu_id, %w[thunder-shock quick-attack])

    assert_equal %w[thunder-shock quick-attack], @repository.all("user-a").first.moves
  end

  def test_set_moves_caps_at_max_moves_per_pokemon
    add_pokemon("user-a", "pikachu", 25)
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")

    @repository.set_moves("user-a", pikachu_id, %w[a b c d e f])

    assert_equal 4, @repository.all("user-a").first.moves.size
    assert_equal %w[a b c d], @repository.all("user-a").first.moves
  end

  def test_set_moves_clears_moves_when_empty
    add_pokemon("user-a", "pikachu", 25)
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @repository.set_moves("user-a", pikachu_id, %w[thunder-shock])

    @repository.set_moves("user-a", pikachu_id, [])

    assert_equal [], @repository.all("user-a").first.moves
  end

  def test_set_moves_of_other_users_member_is_noop
    add_pokemon("user-a", "pikachu", 25)
    add_pokemon("user-b", "bulbasaur", 1)
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    bulbasaur_id = TestDatabase.team_id("bulbasaur", "user-b")

    @repository.set_moves("user-a", bulbasaur_id, %w[thunder-shock])

    assert_equal [], @repository.all("user-b").first.moves
    @repository.set_moves("user-a", pikachu_id, %w[thunder-shock])
    assert_equal [], @repository.all("user-b").first.moves
  end

  def test_set_moves_with_unknown_id_is_noop
    add_pokemon("user-a", "pikachu", 25)

    @repository.set_moves("user-a", "999999", %w[thunder-shock])

    assert_equal 1, @repository.all("user-a").size
    assert_equal [], @repository.all("user-a").first.moves
  end
end
