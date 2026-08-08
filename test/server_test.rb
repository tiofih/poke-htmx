# frozen_string_literal: true

require_relative "test_helper"
require_relative "../server"

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

  # rubocop:disable Metrics/AbcSize
  def test_post_team_persists_pokemon_in_database
    PokeApiStub.with_find(pikachu_pokemon) do
      post "/team", pokeName: "pikachu"
    end

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    team = @repository.all
    assert_equal 1, team.size
    assert_equal "pikachu", team.first.name
    assert_includes last_response.body, %(name="id" value="#{team.first.id}")
    assert_includes last_response.body, "hx-delete=\"/team\""
  end
  # rubocop:enable Metrics/AbcSize

  def test_delete_team_removes_pokemon_by_id
    @repository.add(pikachu_pokemon)
    id = @repository.all.first.id

    delete "/team", id: id

    assert last_response.ok?
    assert_empty @repository.all
    refute_includes last_response.body, "pikachu"
  end

  # rubocop:disable Metrics/AbcSize
  def test_delete_team_with_unknown_id_keeps_team_intact
    @repository.add(pikachu_pokemon)
    id = @repository.all.first.id
    unknown_id = (id.to_i + 999).to_s

    delete "/team", id: unknown_id

    assert last_response.ok?
    assert_equal 1, @repository.all.size
    assert_includes last_response.body, "pikachu"
  end
  # rubocop:enable Metrics/AbcSize

  def test_delete_team_without_id_does_not_break
    delete "/team"

    assert last_response.ok?
  end

  def test_get_team_route_is_removed
    get "/team"

    assert last_response.not_found?
  end
end
