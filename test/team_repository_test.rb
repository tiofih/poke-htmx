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

  def test_pokemon_hp_defaults_to_zero
    assert_equal 0, build_pokemon_record("pikachu", 25).hp_max
    assert_equal 0, build_pokemon_record("pikachu", 25).hp_current
    with_hp = Pokemon.new(
      name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25,
      hp_max: 45, hp_current: 12
    )
    assert_equal 45, with_hp.hp_max
    assert_equal 12, with_hp.hp_current
  end

  def test_all_returns_empty_moves_by_default
    add_pokemon("user-a", "pikachu", 25)

    assert_equal [], @repository.all("user-a").first.moves
  end

  def test_all_populates_hp_from_progress
    add_pokemon("user-a", "pikachu", 25)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    TestDatabase.with_db do |connection|
      connection.exec_params(
        "UPDATE team_pokemon_progress SET hp_max = $1, hp_current = $2 WHERE team_pokemon_id = $3",
        [45, 12, pokemon_id]
      )
    end

    pokemon = @repository.all("user-a").first
    assert_equal 45, pokemon.hp_max
    assert_equal 12, pokemon.hp_current
  end

  def test_all_defaults_hp_to_zero_when_progress_has_no_hp
    add_pokemon("user-a", "pikachu", 25)

    pokemon = @repository.all("user-a").first
    assert_equal 0, pokemon.hp_max
    assert_equal 0, pokemon.hp_current
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

class TeamProgressTest < Minitest::Test
  include TeamRepositoryTestHelpers

  def test_add_creates_progress_row_with_level_one_and_zero_xp
    @repository.add("user-a", build_pokemon_record("pikachu", 25))
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")

    progress = TestDatabase.progress_row(pokemon_id)

    refute_nil progress, "esperava linha de progresso apos a montagem"
    assert_equal 1, progress["level"].to_i
    assert_equal 0, progress["xp"].to_i
  end

  def test_remove_deletes_progress_row_via_cascade
    @repository.add("user-a", build_pokemon_record("pikachu", 25))
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")

    @repository.remove("user-a", pokemon_id)

    assert_nil TestDatabase.progress_row(pokemon_id)
    assert_empty @repository.all("user-a")
  end

  def test_add_rolls_back_progress_when_insert_fails
    add_pokemon("user-a", "pikachu", 25)

    other_repo = TeamRepository.new
    assert_raises(TeamRepository::DuplicateError) do
      other_repo.add("user-a", build_pokemon_record("raichu", 25))
    end

    assert_equal 1, TestDatabase.progress_count
  end
end

class TeamEvolveTest < Minitest::Test
  include TeamRepositoryTestHelpers

  def test_evolve_updates_number_name_sprite_keeping_identity
    @repository.add("user-a", build_pokemon_record("pikachu", 25))
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @repository.set_moves("user-a", pikachu_id, %w[thunder-shock])

    result = @repository.evolve("user-a", pikachu_id, build_pokemon_record("raichu", 26))

    assert_equal true, result
    rows = @repository.all("user-a")
    assert_equal %w[raichu], rows.map(&:name)
    assert_equal 26, rows.first.number
    assert_equal "https://example.com/raichu.png", rows.first.sprite
    assert_equal pikachu_id.to_i, rows.first.id, "id estavel"
    assert_equal 1, rows.first.slot, "slot intacto"
    assert_equal %w[thunder-shock], rows.first.moves, "moves intactos"
    refute_nil TestDatabase.progress_row(pikachu_id), "progresso intacto"
    assert_equal 1, TestDatabase.progress_row(pikachu_id)["level"].to_i
  end

  def test_evolve_returns_false_for_member_of_other_user
    @repository.add("user-a", build_pokemon_record("pikachu", 25))
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")

    assert_equal false, @repository.evolve("user-b", pikachu_id, build_pokemon_record("raichu", 26))
    assert_equal %w[pikachu], @repository.all("user-a").map(&:name)
  end

  def test_evolve_returns_false_for_unknown_id
    @repository.add("user-a", build_pokemon_record("pikachu", 25))

    assert_equal false, @repository.evolve("user-a", "999999", build_pokemon_record("raichu", 26))
  end

  def test_evolve_does_not_evolve_when_target_number_already_in_team
    @repository.add("user-a", build_pokemon_record("pikachu", 25))
    @repository.add("user-a", build_pokemon_record("raichu", 26))
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")

    assert_equal false, @repository.evolve("user-a", pikachu_id, build_pokemon_record("raichu", 26))
    assert_equal %w[pikachu raichu], @repository.all("user-a").map(&:name)
    assert_equal 25, @repository.all("user-a").first.number
  end

  def test_evolve_to_same_number_is_noop_success
    @repository.add("user-a", build_pokemon_record("pikachu", 25))
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")

    assert_equal true, @repository.evolve("user-a", pikachu_id, build_pokemon_record("pikachu", 25))
  end
end

class TeamAssignItemTest < Minitest::Test
  include TeamRepositoryTestHelpers

  def test_pokemon_assigned_item_defaults_to_nil
    add_pokemon("user-a", "pikachu", 25)

    assert_nil @repository.all("user-a").first.assigned_item
  end

  def test_assign_item_persists_assignment_and_all_returns_it
    add_pokemon("user-a", "pikachu", 25)
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")

    @repository.assign_item("user-a", pikachu_id, "potion")

    assert_equal "potion", @repository.all("user-a").first.assigned_item
  end

  def test_assign_item_clears_assignment_with_empty_item
    add_pokemon("user-a", "pikachu", 25)
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @repository.assign_item("user-a", pikachu_id, "potion")

    @repository.assign_item("user-a", pikachu_id, "")

    assert_nil @repository.all("user-a").first.assigned_item
  end

  def test_assign_item_clears_assignment_with_nil
    add_pokemon("user-a", "pikachu", 25)
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @repository.assign_item("user-a", pikachu_id, "potion")

    @repository.assign_item("user-a", pikachu_id, nil)

    assert_nil @repository.all("user-a").first.assigned_item
  end

  def test_assign_item_of_other_users_member_is_noop
    add_pokemon("user-a", "pikachu", 25)
    add_pokemon("user-b", "bulbasaur", 1)
    bulbasaur_id = TestDatabase.team_id("bulbasaur", "user-b")

    @repository.assign_item("user-a", bulbasaur_id, "potion")

    assert_nil @repository.all("user-b").first.assigned_item
  end

  def test_assign_item_with_unknown_id_is_noop
    add_pokemon("user-a", "pikachu", 25)

    @repository.assign_item("user-a", "999999", "potion")

    assert_equal 1, @repository.all("user-a").size
    assert_nil @repository.all("user-a").first.assigned_item
  end

  def test_assign_item_survives_reorder
    add_team("user-a", [["pikachu", 25], ["bulbasaur", 1]])
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @repository.assign_item("user-a", pikachu_id, "potion")

    @repository.move("user-a", pikachu_id, 2)

    assert_equal "potion", @repository.all("user-a").find { |m| m.number == 25 }.assigned_item
  end
end

class TeamLearnMoveTest < Minitest::Test
  include TeamRepositoryTestHelpers

  def test_learn_move_adds_move_to_saved_list
    @repository.add("user-a", build_pokemon_record("pikachu", 25))
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")

    assert_equal true, @repository.learn_move("user-a", pikachu_id, "thunderbolt")
    assert_equal %w[thunderbolt], @repository.all("user-a").first.moves
  end

  def test_learn_move_appends_moves_up_to_max
    @repository.add("user-a", build_pokemon_record("pikachu", 25))
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")

    %w[a b c d].each { |move| @repository.learn_move("user-a", pikachu_id, move) }

    assert_equal %w[a b c d], @repository.all("user-a").first.moves
  end

  def test_learn_move_is_noop_when_already_has_move
    @repository.add("user-a", build_pokemon_record("pikachu", 25))
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @repository.learn_move("user-a", pikachu_id, "thunderbolt")

    assert_equal false, @repository.learn_move("user-a", pikachu_id, "thunderbolt")
    assert_equal %w[thunderbolt], @repository.all("user-a").first.moves
  end

  def test_learn_move_is_noop_when_cap_is_full
    @repository.add("user-a", build_pokemon_record("pikachu", 25))
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @repository.set_moves("user-a", pikachu_id, %w[a b c d])

    assert_equal false, @repository.learn_move("user-a", pikachu_id, "e")
    assert_equal %w[a b c d], @repository.all("user-a").first.moves
  end

  def test_learn_move_is_noop_for_member_of_other_user
    @repository.add("user-a", build_pokemon_record("pikachu", 25))
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")

    assert_equal false, @repository.learn_move("user-b", pikachu_id, "thunderbolt")
    assert_equal [], @repository.all("user-a").first.moves
  end

  def test_learn_move_is_noop_for_unknown_id
    @repository.add("user-a", build_pokemon_record("pikachu", 25))

    assert_equal false, @repository.learn_move("user-a", "999999", "thunderbolt")
  end
end
