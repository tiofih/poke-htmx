# frozen_string_literal: true

require_relative "server_test_helpers"

class ServerTeamFaintedTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  class FaintedRating
    def rating_for(_name)
      :F
    end
  end

  def setup
    super
    @default_rating = Server.settings.rating_source
    Server.set :rating_source, FaintedRating.new
  end

  def teardown
    Server.set :rating_source, @default_rating
    super
  end

  def test_delete_fainted_blocked # rubocop:disable Metrics/AbcSize
    fill_team("user-a")
    target = @repository.all("user-a").first
    @progression.update_hp("user-a", target.id, 10, 0)
    assert target # sanity
    # reload to confirm fainted
    reloaded = @repository.all("user-a").find { |p| p.id == target.id }
    assert_equal true, reloaded.fainted?, "precondition: target deve estar fainted"

    delete "/team", { id: target.id, offset: "0", q: "" }, htmx_session("user-a")

    assert last_response.ok?
    assert_equal 6, @repository.all("user-a").size, "fainted nao deve ser removido (6->6)"
    assert_includes last_response.body, "Pokémon derrotado — cure antes de remover"
    assert_includes last_response.body, "notice--error"
    # OOBs
    assert_includes last_response.body, 'id="pokemon-list"'
    assert_includes last_response.body, 'id="nav-badge"'
    assert_includes last_response.body, "hx-swap-oob"
    # view still shows member
    assert_includes last_response.body, reloaded.name
    # OOB condicional preservado: when visible includes starters
    assert_includes last_response.body, '<ul class="pokemon-list starters">'
  end # rubocop:enable Metrics/AbcSize

  def test_delete_fainted_blocked_does_not_break_oob_when_filtered
    fill_team("user-a")
    target = @repository.all("user-a").first
    @progression.update_hp("user-a", target.id, 10, 0)

    delete "/team", { id: target.id, offset: "0", q: "pika" }, htmx_session("user-a")

    assert last_response.ok?
    assert_equal 6, @repository.all("user-a").size
    assert_includes last_response.body, 'id="pokemon-list" hx-swap-oob'
    refute_includes last_response.body, '<ul class="pokemon-list starters">',
                    "starters nao deveriam aparecer quando q nao vazio"
    assert_includes last_response.body, "Pokémon derrotado"
  end

  def test_team_view_disables_remove_when_fainted
    fill_team("user-a")
    target = @repository.all("user-a").first
    @progression.update_hp("user-a", target.id, 10, 0)

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    # button for fainted has disabled + title
    assert_match(/disabled/, last_response.body)
    assert_match(/title="Pokémon derrotado — cure antes de remover"/, last_response.body)
    # ensure at least one disabled (fainted)
    assert_operator last_response.body.scan("disabled").size, :>=, 1
  end

  def test_team_view_enables_remove_when_alive
    fill_team("user-a")
    # ensure all alive (hp_max 0 -> alive, or update hp to positive)
    @repository.all("user-a").each { |m| @progression.update_hp("user-a", m.id, 10, 5) }

    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    # no fainted => no disabled title for fainted
    refute_includes last_response.body, 'title="Pokémon derrotado — cure antes de remover"'
    # hx-delete still present
    assert_includes last_response.body, 'hx-delete="/team"'
  end

  def test_restart_clears_fainted_team
    fill_team("user-a")
    @repository.all("user-a").each { |m| @progression.update_hp("user-a", m.id, 10, 0) }
    first = @repository.all("user-a").first
    @inventory.add("user-a", "potion", 1)
    @repository.assign_item("user-a", first.id, "potion")
    @inventory.add("user-a", "choice-band", 1)
    @repository.assign_held_item("user-a", first.id, "choice-band")
    @wallet.grant("user-a", 500)

    post "/journey/restart", { offset: "0", q: "" }, htmx_session("user-a")

    assert last_response.ok?
    assert_empty @repository.all("user-a"), "reset deve limpar mesmo com todos fainted (6->0)"
    # inventory restored (repo assign nao debita, entao 1+1 =>2, mas reset devolve)
    # After restart, inventory should have potion restored (was 1, assigned, after reset 2)
    assert_equal 2, TestDatabase.inventory_quantity("user-a", "potion")
    assert_equal 200, TestDatabase.wallet_balance("user-a")
    assert_includes last_response.body, "Jornada recomeçada"
    assert_includes last_response.body, 'id="pokemon-list"'
    assert_includes last_response.body, 'id="nav-badge"'
    assert_match(/Jornada recomeçada/, last_response.body)
  end

  def test_delete_unknown_id_does_not_show_fainted_notice
    fill_team("user-a")
    unknown = (@repository.all("user-a").map(&:id).max.to_i + 999).to_s

    delete "/team", { id: unknown, offset: "0", q: "" }, htmx_session("user-a")

    assert last_response.ok?
    assert_equal 6, @repository.all("user-a").size
    refute_includes last_response.body, "Pokémon derrotado — cure antes de remover"
  end

  def test_remove_fainted_does_not_reindex_slots
    fill_team("user-a")
    members = @repository.all("user-a")
    target = members.first
    @progression.update_hp("user-a", target.id, 10, 0)

    delete "/team", { id: target.id, offset: "0", q: "" }, htmx_session("user-a")

    assert last_response.ok?
    after = @repository.all("user-a")
    assert_equal [1, 2, 3, 4, 5, 6], after.map(&:slot), "slots intactos quando bloqueado"
  end
end

# Sessao 0065 — C4 alias para S1 (FaintedRemoveTest) reaproveita 0064 C7 sem duplicar passo
class FaintedRemoveTest < ServerTeamFaintedTest; end
