# frozen_string_literal: true

require_relative "server_test_helpers"
require_relative "battle_test_helpers"

# Contrato data-od-id nas 4 superficies (sessao 0076 2a, C4): shell+nav,
# home/team, battle (ancorada) e modais. History ancorada sem edicao.
class OpenDesignContractTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport
  include ServerBattleTestHelpers

  def home_body(user_id: "user-a")
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session(user_id)
    end
    assert last_response.ok?
    last_response.body
  end

  def test_contract_shell_nav
    body = home_body

    assert_includes body, 'data-od-id="topnav"'
    assert_includes body, 'data-od-id="nav"'
    assert_includes body, 'data-od-id="footer"'
  end

  def test_contract_home_team
    fill_team("user-a")
    body = home_body

    assert_includes body, 'data-od-id="team-pane"'
    assert_includes body, 'data-od-id="catalog"'
    assert_includes body, 'data-od-id="services"'
    assert_includes body, 'data-od-id="members"'
  end

  def test_contract_battle_sides_and_controls
    fill_team("user-a")
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    body = last_response.body
    assert_includes body, 'data-od-id="side-team"'
    assert_includes body, 'data-od-id="side-opponent"'
    assert_includes body, 'data-od-id="controls"'
  end

  def test_contract_history_sections
    history = BattleRepository.new
    history.add("user-a", "win", [{ number: 25, name: "pikachu" }])
    history.add("user-a", "lose", [{ number: 25, name: "pikachu" }])

    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_includes body, 'data-od-id="your-position"'
    assert_includes body, 'data-od-id="ranking"'
    assert_includes body, 'data-od-id="recent"'
  end

  def test_contract_modals_with_closes_and_openers
    fill_team("user-a")
    @wallet = WalletRepository.new
    @wallet.grant("user-a", 100)

    get "/team/center", {}, user_session("user-a")
    assert_includes last_response.body, 'data-od-id="modal-center"'
    assert_includes last_response.body, 'data-od-id="modal-center-close"'

    get "/team/mart", {}, user_session("user-a")
    assert_includes last_response.body, 'data-od-id="modal-mart"'
    assert_includes last_response.body, 'data-od-id="modal-mart-close"'

    PokeApiStub.with_learnable_moves([{ level: 1, name: "growl" }]) do
      get "/team/manage", {}, user_session("user-a")
    end
    assert_includes last_response.body, 'data-od-id="modal-manage"'
    assert_includes last_response.body, 'data-od-id="modal-manage-close"'

    body = home_body
    assert_includes body, 'data-od-id="open-modal-center"'
    assert_includes body, 'data-od-id="open-modal-mart"'
    assert_includes body, 'data-od-id="open-modal-manage"'
  end
end
