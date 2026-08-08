# frozen_string_literal: true

require_relative "test_helper"
require_relative "../server"

# rubocop:disable Metrics/ClassLength
class ServerTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Server
  end

  def setup
    TestDatabase.setup!
    TestDatabase.clear_team!
    @repository = TeamRepository.new
  end

  def pikachu_pokemon
    Pokemon.new(name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25)
  end

  def bulbasaur_pokemon
    Pokemon.new(name: "bulbasaur", sprite: "https://example.com/bulbasaur.png", number: 1)
  end

  def rack_test_session
    Rack::Test::Session.new(Rack::MockSession.new(app))
  end

  def user_session(user_id)
    { "rack.session" => { "user_id" => user_id } }
  end

  def test_first_access_generates_session_cookie
    PokeApiStub.with_find(pikachu_pokemon) do
      post "/team", pokeName: "pikachu"
    end

    assert last_response.ok?
    assert_includes last_response.headers["Set-Cookie"], "rack.session"
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def test_two_sessions_keep_isolated_teams
    session_a = rack_test_session
    session_b = rack_test_session

    PokeApiStub.with_find(pikachu_pokemon) do
      session_a.post "/team", pokeName: "pikachu"
    end
    PokeApiStub.with_find(bulbasaur_pokemon) do
      session_b.post "/team", pokeName: "bulbasaur"
    end

    assert_includes session_a.last_response.body, "pikachu"
    refute_includes session_a.last_response.body, "bulbasaur"
    assert_includes session_b.last_response.body, "bulbasaur"
    refute_includes session_b.last_response.body, "pikachu"

    assert_equal 2, distinct_user_ids.size
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def test_post_team_persists_pokemon_for_session_user
    PokeApiStub.with_find(pikachu_pokemon) do
      post "/team", { pokeName: "pikachu" }, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    team = @repository.all("user-a")
    assert_equal 1, team.size
    assert_equal "pikachu", team.first.name
    assert_includes last_response.body, %(name="id" value="#{team.first.id}")
    assert_includes last_response.body, "hx-delete=\"/team\""
    assert_empty @repository.all("user-b")
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def test_delete_team_removes_pokemon_from_own_session
    @repository.add("user-a", pikachu_pokemon)
    id = @repository.all("user-a").first.id

    delete "/team", { id: id }, user_session("user-a")

    assert last_response.ok?
    assert_empty @repository.all("user-a")
    refute_includes last_response.body, "pikachu"
  end

  # rubocop:disable Metrics/AbcSize
  def test_delete_team_with_unknown_id_keeps_team_intact
    @repository.add("user-a", pikachu_pokemon)
    id = @repository.all("user-a").first.id
    unknown_id = (id.to_i + 999).to_s

    delete "/team", { id: unknown_id }, user_session("user-a")

    assert last_response.ok?
    assert_equal 1, @repository.all("user-a").size
    assert_includes last_response.body, "pikachu"
  end
  # rubocop:enable Metrics/AbcSize

  def test_delete_team_without_id_does_not_break
    delete "/team", {}, user_session("user-a")

    assert last_response.ok?
  end

  def test_delete_team_only_removes_own_session_member
    @repository.add("user-a", pikachu_pokemon)
    id = @repository.all("user-a").first.id

    delete "/team", { id: id }, user_session("user-b")

    assert last_response.ok?
    assert_equal 1, @repository.all("user-a").size
    assert_empty @repository.all("user-b")
  end

  def test_get_team_returns_own_session_team
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    assert_includes last_response.body, "hx-delete=\"/team\""
  end

  def test_get_team_is_isolated_per_session
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, user_session("user-b")

    assert last_response.ok?
    refute_includes last_response.body, "pikachu"
  end

  def test_pokemon_detail_route_returns_sprite_and_name
    PokeApiStub.with_detail(pikachu_pokemon) do
      get "/pokemon/25"
    end

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    assert_includes last_response.body, "https://example.com/pikachu.png"
  end

  # rubocop:disable Metrics/MethodLength
  def test_pokemon_detail_renders_types
    pikachu = Pokemon.new(
      name: "pikachu",
      sprite: "https://example.com/pikachu.png",
      number: 25,
      types: ["electric"]
    )

    PokeApiStub.with_detail(pikachu) do
      get "/pokemon/25"
    end

    assert last_response.ok?
    assert_includes last_response.body, "electric"
  end
  # rubocop:enable Metrics/MethodLength

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def test_pokemon_detail_renders_six_base_stats
    pikachu = Pokemon.new(
      name: "pikachu",
      sprite: "https://example.com/pikachu.png",
      number: 25,
      stats: [
        { name: "HP", value: 35 },
        { name: "Attack", value: 55 },
        { name: "Defense", value: 40 },
        { name: "Sp.Atk", value: 50 },
        { name: "Sp.Def", value: 50 },
        { name: "Speed", value: 90 }
      ]
    )

    PokeApiStub.with_detail(pikachu) do
      get "/pokemon/25"
    end

    assert last_response.ok?
    assert_includes last_response.body, "HP"
    assert_includes last_response.body, "35"
    assert_includes last_response.body, "55"
    assert_includes last_response.body, "Speed"
    assert_includes last_response.body, "90"
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def charizard_evolution_pokemons
    {
      charmander: Pokemon.new(name: "charmander", sprite: "https://example.com/charmander.png", number: 4),
      charmeleon: Pokemon.new(name: "charmeleon", sprite: "https://example.com/charmeleon.png", number: 5),
      charizard: Pokemon.new(name: "charizard", sprite: "https://example.com/charizard.png", number: 6)
    }
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
  def test_pokemon_detail_renders_evolution_chain
    chain = charizard_evolution_pokemons
    charizard = Pokemon.new(
      name: "charizard",
      sprite: chain[:charizard].sprite,
      number: 6,
      evolutions: [chain[:charmander], chain[:charmeleon], chain[:charizard]]
    )

    PokeApiStub.with_detail(charizard) do
      get "/pokemon/6"
    end

    assert last_response.ok?
    assert_includes last_response.body, "charmander"
    assert_includes last_response.body, "https://example.com/charmander.png"
    assert_includes last_response.body, "charmeleon"
    assert_includes last_response.body, "https://example.com/charmeleon.png"
    assert_includes last_response.body, "charizard"
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def test_pokemon_detail_without_evolutions_does_not_break
    PokeApiStub.with_detail(pikachu_pokemon) do
      get "/pokemon/25"
    end

    assert last_response.ok?
  end

  private

  def distinct_user_ids
    connection = PG.connect(ENV.fetch("DATABASE_URL"))
    connection.exec("SELECT DISTINCT user_id FROM team_pokemons").map { |row| row["user_id"] }
  ensure
    connection&.close
  end
end
# rubocop:enable Metrics/ClassLength
