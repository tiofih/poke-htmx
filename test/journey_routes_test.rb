# frozen_string_literal: true

require_relative "server_test_helpers"

class JourneyRestartTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def setup
    super
    fill_team("user-a")
    @wallet.grant("user-a", 500)
    @inventory.add("user-a", "potion", 3)
  end

  def test_restart_journey_clears_team_and_resets_balance
    post "/journey/restart", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_empty @repository.all("user-a")
    assert_equal 200, TestDatabase.wallet_balance("user-a")
    refute_includes last_response.body, "pikachu"
  end

  def test_restart_journey_returns_equipped_items_to_inventory
    member = @repository.all("user-a").first
    post "/team/#{member.id}/item", { item_name: "potion" }, htmx_session("user-a")
    assert_equal 2, TestDatabase.inventory_quantity("user-a", "potion"), "equipar debita (3 -> 2)"

    post "/journey/restart", {}, htmx_session("user-a")

    assert_equal 3, TestDatabase.inventory_quantity("user-a", "potion"), "item equipado devolvido ao estoque"
    assert_empty @repository.all("user-a")
  end

  def test_restart_journey_reblocks_battle_gate
    post "/journey/restart", {}, htmx_session("user-a")

    get "/battle", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_match(/Monte seu time inicial/i, last_response.body)
  end

  def test_restart_journey_includes_cta_slot_out_of_band_swap
    post "/journey/restart", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, 'id="cta-slot"'
    assert_includes last_response.body, 'hx-swap-oob="outerHTML"'
    assert_match(/Time vazio/, last_response.body, "pos-restart: pill neutra (S3)")
    refute_includes last_response.body, "cta-hint", "sem mensagem ao lado do botao (S3)"
  end

  def test_restart_journey_full_page_redirects_to_root
    post "/journey/restart", {}, user_session("user-a")

    assert_equal 302, last_response.status
    assert_equal "/", URI(last_response["Location"]).path
    assert_empty @repository.all("user-a")
  end

  def test_restart_journey_is_safe_under_concurrent_calls
    errors = Queue.new
    threads = 3.times.map do
      Thread.new do
        session = Rack::Test::Session.new(Rack::MockSession.new(app))
        session.post "/journey/restart", {}, { "rack.session" => { "user_id" => "user-a" } }
        errors << session.last_response.status unless session.last_response.status == 302
      rescue StandardError => e
        errors << e
      end
    end
    threads.each(&:join)

    assert_equal 0, errors.size, "erros concorrentes: #{Array.new(errors.size) { errors.pop }.inspect}"
    assert_empty @repository.all("user-a")
  end

  def test_restart_journey_refreshes_pokemon_list_oob
    PokeApiStub.with_all_names([]) do
      PokeApiStub.with_find({}) do
        post "/journey/restart", { offset: "0", q: "" }, htmx_session("user-a")
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, %(hx-swap-oob="innerHTML")
    assert_includes last_response.body, 'id="pokemon-list"'
  end
end
