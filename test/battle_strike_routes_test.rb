# frozen_string_literal: true

require_relative "server_test_helpers"
require_relative "battle_test_helpers"

# POST /battle/strike — append-only OOB per-strike (0086 pedra fundamental:
# 1 strike = 1 linha). /battle/play segue intacto (full fragment).
class BattleStrikeRoutesTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport
  include ServerBattleTestHelpers

  def setup
    super
    fill_team("user-a")
  end

  def test_strike_appends_exactly_one_log_line
    start_battle_for("user-a")

    post "/battle/strike", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, 'hx-swap-oob="beforeend:#battle-log"',
                    "linha anexada ao #battle-log sem re-render"
    assert_equal 1, last_response.body.scan("log__entry").size,
                 "1 strike = 1 linha"
    assert_match(/data-from-side="[01]"/, last_response.body)
    assert_match(/data-to-side="[01]"/, last_response.body)
  end

  def test_strike_updates_hp_oob_per_side
    start_battle_for("user-a")

    post "/battle/strike", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, 'id="fighters-0" hx-swap-oob="innerHTML"'
    assert_includes last_response.body, 'id="fighters-1" hx-swap-oob="innerHTML"'
    assert_match(%r{HP \d+/\d+}, last_response.body)
    refute_includes last_response.body, 'id="battle-view"',
                    "sem re-render do fragmento inteiro"
  end

  def test_strike_omits_result_modal_until_finished
    start_battle_for("user-a")

    post "/battle/strike", {}, user_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, "result-modal",
                    "modal de resultado só no fim"
  end

  def test_strike_shows_result_modal_only_at_finish
    start_battle_for("user-a")
    strike_until_finish

    assert last_response.ok?
    assert_includes last_response.body, 'id="result-modal"'
    assert_includes last_response.body, "Vencedor:"
  end

  def test_strike_auto_chains_next_strike_until_finished
    start_battle_for("user-a")

    post "/battle/strike", { "auto" => "1" }, user_session("user-a")

    assert last_response.ok?
    assert_equal "next-strike", last_response.headers["HX-Trigger"],
                 "auto ligado e golpe em aberto: encadeia next-strike"

    strike_until_finish(auto: true)

    assert last_response.ok?
    assert_includes last_response.body, 'id="result-modal"'
    assert_nil last_response.headers["HX-Trigger"],
               "batalha terminada: cadeia para"
  end

  def test_strike_auto_off_emits_no_trigger
    start_battle_for("user-a")

    post "/battle/strike", {}, user_session("user-a")

    assert last_response.ok?
    assert_nil last_response.headers["HX-Trigger"]
  end

  def test_strike_without_battle_does_not_break
    post "/battle/strike", {}, user_session("user-a")

    assert last_response.ok?
    assert_empty last_response.body
  end

  private

  def strike_until_finish(auto: false, cap: 2000)
    params = auto ? { "auto" => "1" } : {}
    cap.times do
      post "/battle/strike", params, user_session("user-a")
      return if last_response.body.include?('id="result-modal"')
    end
  end
end
