# frozen_string_literal: true

require_relative "server_test_helpers"

class ServerTeamS3FixTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def setup
    super
    @default_rating = Server.settings.rating_source
    # DefaultFakeRating is defined in team_routes_test.rb; define minimal here
    fake = Class.new do
      def rating_for(_name)
        :F
      end
    end.new
    Server.set :rating_source, fake
    @fake_rating = fake
  end

  def teardown
    Server.set :rating_source, @default_rating
    super
  end

  # C6 reaberto S3: após remover slot 1, badges devem ser #1..#5 contíguos, #6 ausente
  def test_remove_first_slot_reindexes_to_one
    fill_team("user-s3-a")

    first = @repository.all("user-s3-a").find { |p| p.slot == 1 }
    refute_nil first, "slot 1 should exist before remove"
    first_id = first.id

    delete "/team", { id: first_id, offset: "0", q: "" }, htmx_session("user-s3-a")

    assert last_response.ok?
    team = @repository.all("user-s3-a")
    assert_equal 5, team.size
    assert_equal [1, 2, 3, 4, 5], team.map(&:slot), "slots devem reindexar para 1..5 após remover slot 1"
    # badges no fragmento devem ser #1..#5, sem #6 stale
    assert_includes last_response.body, "#1", "badge #1 deve existir após reindex"
    assert_includes last_response.body, "#5", "badge #5 deve existir"
    refute_includes last_response.body, "#6", "badge #6 não deve aparecer após remover 1 de 6"
    # O primeiro remanescente (antigo slot 2) agora é slot 1
    first_after = team.first
    assert_equal 1, first_after.slot
    assert_equal "bulbasaur", first_after.name, "bulbasaur (antigo slot 2) deve virar slot 1"
  end

  # C6 reaberto S3: nav-badge OOB deve atualizar para 5/6 após remover slot 1
  def test_nav_badge_updates_after_remove
    fill_team("user-s3-b")
    first_id = @repository.all("user-s3-b").first.id

    delete "/team", { id: first_id, offset: "0", q: "" }, htmx_session("user-s3-b")

    assert last_response.ok?
    # OOB do nav-badge
    assert_match(%r{id="nav-badge".*5/6}m, last_response.body,
                 "expected nav-badge OOB 5/6 após remover 1 de 6")
    assert_match(/hx-swap-oob="innerHTML"/, last_response.body,
                 "expected hx-swap-oob for nav-badge")
    # GET / full page também reflete 5/6
    get "/", {}, user_session("user-s3-b")
    assert_match(%r{5/6}, last_response.body, "GET / deve mostrar 5/6 após remoção")
  end

  # C6 reaberto S3: nav-badge OOB após adicionar o 6º deve mostrar 6/6
  def test_nav_badge_oob_after_add
    5.times { |n| @repository.add("user-s3-c", build_pokemon_record("pokemon#{n}", n + 1)) }
    sixth = build_pokemon_record("pikachu", 25)

    PokeApiStub.with_find(sixth) do
      PokeApiStub.with_learnable_moves([{ level: 1, name: "growl" }]) do
        post "/team", { pokeName: "pikachu" }, htmx_session("user-s3-c")
      end
    end

    assert last_response.ok?
    assert_match(%r{id="nav-badge".*6/6}m, last_response.body,
                 "expected nav-badge OOB 6/6 após completar time")
    assert_match(/hx-swap-oob="innerHTML"/, last_response.body)
  end

  # Q5 reaberto S3: DELETE em 1 request e idempotente segundo request sem mudar size
  def test_delete_in_one_request
    fill_team("user-s3-d")
    id = @repository.all("user-s3-d").first.id
    assert_equal 6, @repository.all("user-s3-d").size

    delete "/team", { id: id, offset: "0", q: "" }, htmx_session("user-s3-d")

    assert last_response.ok?
    assert_equal 5, @repository.all("user-s3-d").size, "1º DELETE deve remover em 1 request (6→5)"
    refute_includes last_response.body, "Algo deu errado"
    assert_includes last_response.body, 'id="pokemon-list"'
    assert_includes last_response.body, "hx-swap-oob"

    delete "/team", { id: id, offset: "0", q: "" }, htmx_session("user-s3-d")

    assert last_response.ok?
    assert_equal 5, @repository.all("user-s3-d").size, "2º DELETE mesmo id deve ser idempotente 200 sem mudar size"
    refute_includes last_response.body, "Algo deu errado"
  end

  # Hardening S3: form hx-delete deve ter atributos de 1-clique (hx-sync, hx-indicator, hx-disabled-elt)
  def test_remove_form_has_hardening_attrs_after_s3
    fill_team("user-s3-e")

    get "/team", {}, htmx_session("user-s3-e")

    assert last_response.ok?
    remove_form = last_response.body[%r{<form[^>]*hx-delete="/team".*?</form>}m]
    refute_nil remove_form, "form hx-delete não encontrado"
    assert_match(/hx-disabled-elt="this"/, remove_form)
    assert_match(/hx-sync="closest form:replace"/, remove_form)
    assert_match(/hx-indicator="#team-view"/, remove_form)
    assert_match(/hx-params="\*"/, remove_form)
    assert_match(/hx-include="\.list-state"/, remove_form)
  end
end
