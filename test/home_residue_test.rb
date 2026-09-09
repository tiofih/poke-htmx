# frozen_string_literal: true

require_relative "server_test_helpers"

# Residuo home 0077 (home-team.html 1:1, fidelidade hibrida): miolo dos modais
# (C1), manage + evolucao (C2) e catalogo + detalhe (C3). Sem rede (stub PokeApi).
class HomeResidueTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  HOME_USER = "user-home-77"

  def setup
    super
    fill_team(HOME_USER)
    @wallet.grant(HOME_USER, 100)
  end

  def test_center_mart_inner
    pikachu_id = TestDatabase.team_id("pikachu", HOME_USER)
    @progression.update_hp(HOME_USER, pikachu_id, 35, 20)

    get "/team/center", {}, user_session(HOME_USER)

    assert last_response.ok?
    center = last_response.body
    assert_includes center, 'id="center-modal"'
    assert_match(/class="heal-list"/, center)
    assert_match(/class="heal-item"/, center)
    assert_includes center, "pikachu"
    assert_includes center, "20/35"
    assert_includes center, "Custo total:"
    assert_includes center, %(hx-post="/team/heal")
    refute_includes center, "onclick"

    @inventory.add(HOME_USER, "potion", 2)

    get "/team/mart", {}, user_session(HOME_USER)

    assert last_response.ok?
    mart = last_response.body
    assert_includes mart, 'id="mart-modal"'
    assert_match(/class="tabs"/, mart)
    assert_match(/class="mart"/, mart)
    assert_match(/class="mart-name"/, mart)
    assert_match(/class="item-icon"/, mart)
    assert_match(/class="[^"]*\bprice\b[^"]*"/, mart)
    assert_includes mart, "Pocao — 20 ×5"
    assert_includes mart, %(hx-post="/mart/buy")
    assert_includes mart, %(hx-post="/mart/sell")
    assert_includes mart, "Saldo: 100"
    refute_includes mart, "onclick"
  end
end
