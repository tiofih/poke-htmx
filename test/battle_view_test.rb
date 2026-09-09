# frozen_string_literal: true

require_relative "server_test_helpers"
require_relative "battle_test_helpers"

# Testes estruturais da batalha redesenhada (sessão 0074) — provam C2 (e parte de
# C4/C5/C6). A batalha passa a ser um .arena (2x ul.fighters + .podium central
# com round-banner/controles/.log/#result-box), preservando o contrato htmx.
class BattleViewTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport
  include ServerBattleTestHelpers

  def setup
    super
    fill_team("user-a")
  end

  def test_battle_arena_two_fighter_lists_and_podium
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    body = last_response.body
    assert_match(/class="arena"/, body, "expected battle fragment to open an .arena")
    lists = body.scan('<ul class="fighters"').size
    assert_equal(2, lists, "expected exactly two ul.fighters (team + opponent)")
    assert_match(/class="podium"/, body, "expected a central .podium")
    assert_match(/data-side="0"/, body, "player column keeps data-side=0 (juice direction)")
    assert_match(/data-side="1"/, body, "opponent column keeps data-side=1 (juice direction)")
  end

  def test_battle_keeps_htmx_contract_on_play_button
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    body = last_response.body
    assert_includes body, 'hx-post="/battle/play"', "play posts to /battle/play"
    assert_includes body, 'hx-target="#battle-view"', "fragment swaps into #battle-view"
    assert_includes body, 'hx-swap="innerHTML"', "fragment swaps innerHTML"
    assert_includes body, 'hx-indicator="#battle-loading"', "loading indicator preserved"
    assert_includes body, ">Batalhar</button>", "play button label preserved"
  end

  def test_battle_log_uses_new_markup_with_round_metadata
    start_battle_for("user-a")
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_match(/class="log-title"/, body, "expected a .log-title heading the battle log")
    assert_match(/<ul class="log"/, body, "expected the log as ul.log")
    assert_match(/class="[^"]*\blside\b/, body, "expected .lside side badges in the log")
    assert_match(/data-round="\d+"/, body, "log entry keeps data-round (juice C2)")
    assert_match(/--log-delay:/, body, "log keeps --log-delay stagger (resolver 0069)")
  end

  def test_battle_result_uses_winner_badge_and_ctas
    start_battle_for("user-a")
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_includes body, "Fim de batalha", "a single play still resolves the battle"
    assert_match(/class="result"/, body, "expected .result at the end of battle")
    assert_match(/class="winner-badge"/, body, "expected .winner-badge with the winner")
    assert_includes body, "Vencedor:", "winner banner text preserved"
    assert_match(/class="rewards"/, body, "expected .rewards with XP/money news")
    assert_match(/class="ctas"/, body, "expected .ctas with follow-up actions")
    assert_includes body, 'hx-post="/battle/new"', "new confront posts to /battle/new"
    assert_includes body, "Novo confronto", "new confront label preserved"
  end
end
