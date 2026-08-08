# frozen_string_literal: true

require_relative "test_helper"

class TeamRepositoryTest < Minitest::Test
  def setup
    TestDatabase.setup!
    TestDatabase.clear_team!
    @repository = TeamRepository.new
  end

  def test_add_rejects_duplicate_number_with_duplicate_error
    pikachu = Pokemon.new(name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25)
    pikachu_raichu = Pokemon.new(name: "pikachu-raichu", sprite: "https://example.com/raichu.png", number: 26)
    @repository.add("user-a", pikachu)
    @repository.add("user-a", pikachu_raichu)

    dup = Pokemon.new(name: "pikachu", sprite: "https://example.com/pikachu.png", number: 26)
    error = assert_raises(TeamRepository::DuplicateError) { @repository.add("user-a", dup) }

    assert_match(/já está|repetid/i, error.message)
    assert_equal 2, @repository.all("user-a").size
  end

  def test_all_returns_empty_array_for_empty_database
    assert_equal [], @repository.all("user-a")
  end

  def test_pokemon_slot_defaults_to_nil_and_accepts_value
    assert_nil Pokemon.new(name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25).slot
    with_slot = Pokemon.new(name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25, slot: 3)
    assert_equal 3, with_slot.slot
  end

  def test_add_persists_pokemon_and_all_returns_it
    pokemon = Pokemon.new(name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25)

    @repository.add("user-a", pokemon)
    rows = @repository.all("user-a")

    assert_equal 1, rows.size
    assert_instance_of Pokemon, rows.first
    assert_equal "pikachu", rows.first.name
    assert_equal "https://example.com/pikachu.png", rows.first.sprite
    assert_equal 25, rows.first.number
  end

  def test_remove_deletes_pokemon_by_id
    pikachu = Pokemon.new(name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25)
    bulbasaur = Pokemon.new(name: "bulbasaur", sprite: "https://example.com/bulbasaur.png", number: 1)
    @repository.add("user-a", pikachu)
    @repository.add("user-a", bulbasaur)

    first_id = team_id("pikachu", "user-a")
    @repository.remove("user-a", first_id)

    remaining = @repository.all("user-a")
    assert_equal %w[bulbasaur], remaining.map(&:name)
  end

  def test_all_returns_only_own_users_pokemon
    pikachu = Pokemon.new(name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25)
    bulbasaur = Pokemon.new(name: "bulbasaur", sprite: "https://example.com/bulbasaur.png", number: 1)
    @repository.add("user-a", pikachu)
    @repository.add("user-b", bulbasaur)

    assert_equal %w[pikachu], @repository.all("user-a").map(&:name)
    assert_equal %w[bulbasaur], @repository.all("user-b").map(&:name)
  end

  def test_add_rejects_seventh_pokemon_with_team_full_error
    six = (1..6).map do |n|
      Pokemon.new(name: "pokemon#{n}", sprite: "https://example.com/#{n}.png", number: n)
    end
    six.each { |poke| @repository.add("user-a", poke) }

    seventh = Pokemon.new(name: "meowth", sprite: "https://example.com/meowth.png", number: 52)
    error = assert_raises(TeamRepository::TeamFullError) { @repository.add("user-a", seventh) }

    assert_match(/cheio|full/i, error.message)
    assert_equal 6, @repository.all("user-a").size
  end

  def test_add_assigns_slots_in_insertion_order_and_persists_slot
    pikachu = Pokemon.new(name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25)
    bulbasaur = Pokemon.new(name: "bulbasaur", sprite: "https://example.com/bulbasaur.png", number: 1)
    charmander = Pokemon.new(name: "charmander", sprite: "https://example.com/charmander.png", number: 4)

    @repository.add("user-a", pikachu)
    @repository.add("user-a", bulbasaur)
    @repository.add("user-a", charmander)

    rows = @repository.all("user-a")
    assert_equal [1, 2, 3], rows.map(&:slot)
    assert_equal %w[pikachu bulbasaur charmander], rows.map(&:name)
    assert_equal 3, team_row("charmander")["slot"].to_i
  end

  def test_add_persists_pokemon_with_user_id
    pikachu = Pokemon.new(name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25)
    @repository.add("user-a", pikachu)

    row = team_row("pikachu")
    assert_equal "user-a", row["user_id"]
  end

  def test_remove_recompacts_slots
    pikachu = Pokemon.new(name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25)
    bulbasaur = Pokemon.new(name: "bulbasaur", sprite: "https://example.com/bulbasaur.png", number: 1)
    charmander = Pokemon.new(name: "charmander", sprite: "https://example.com/charmander.png", number: 4)
    @repository.add("user-a", pikachu)
    @repository.add("user-a", bulbasaur)
    @repository.add("user-a", charmander)

    bulbasaur_id = team_id("bulbasaur", "user-a")
    @repository.remove("user-a", bulbasaur_id)

    remaining = @repository.all("user-a")
    assert_equal [1, 2], remaining.map(&:slot)
    assert_equal %w[pikachu charmander], remaining.map(&:name)

    @repository.add("user-a", Pokemon.new(name: "squirtle", sprite: "https://example.com/squirtle.png", number: 7))
    assert_equal [1, 2, 3], @repository.all("user-a").map(&:slot)
  end

  def test_remove_only_deletes_own_users_pokemon
    pikachu = Pokemon.new(name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25)
    bulbasaur = Pokemon.new(name: "bulbasaur", sprite: "https://example.com/bulbasaur.png", number: 1)
    @repository.add("user-a", pikachu)
    @repository.add("user-b", bulbasaur)

    bulbasaur_id = team_id("bulbasaur", "user-b")
    @repository.remove("user-a", bulbasaur_id)

    assert_equal %w[pikachu], @repository.all("user-a").map(&:name)
    assert_equal %w[bulbasaur], @repository.all("user-b").map(&:name)
  end

  private

  def team_row(name)
    connection = PG.connect(ENV.fetch("DATABASE_URL"))
    connection.exec_params("SELECT * FROM team_pokemons WHERE name = $1", [name]).first
  ensure
    connection&.close
  end

  def team_id(name, user_id)
    connection = PG.connect(ENV.fetch("DATABASE_URL"))
    connection.exec_params(
      "SELECT id FROM team_pokemons WHERE name = $1 AND user_id = $2",
      [name, user_id]
    ).first["id"]
  ensure
    connection&.close
  end
end
