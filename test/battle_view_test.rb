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

  def test_battle_podium_middle_wrapped_in_card
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    body = last_response.body
    assert_match(/<div class="podium"[^>]*>\s*<div class="card">/m, body,
                 "expected a .card opening the .podium")
    assert_match(/<div class="round-banner">.*?<div class="controls">.*?id="result-box"/m, body,
                 "expected round-banner + controls + #result-box in the card")
  end

  def test_battle_fighter_card_shows_identity_hp_pp_moves
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    body = last_response.body
    assert_match(/<li class="fighter[ "]/, body, "expected li.fighter cards in ul.fighters")
    assert_match(/class="fighter-head"/, body, "expected .fighter-head with sprite + identity")
    assert_match(/class="fighter-id"/, body, "expected .fighter-id with name")
    assert_match(/class="fmeta"/, body, "expected .fmeta with level")
    assert_match(/class="hp"/, body, "expected .hp row with the HP bar")
    assert_match(/class="bar"/, body, "expected .bar reused from the design system")
    assert_match(/class="[^"]*\bhp-val"/, body, "expected .hp-val with real HP numbers")
    assert_includes body, "202/202", "card shows the presenter HP label"
    assert_match(/class="moves"/, body, "expected .moves with the fighter moves")
    assert_match(/class="move"/, body, "expected .move pills per move")
    assert_includes body, "PP 30", "move shows the presenter PP value"
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

  def test_battle_log_groups_entries_by_round_newest_first
    start_battle_for("user-a")
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_match(/class="log-round-head"[^>]*data-round="\d+"/, body,
                 "expected a round header carrying data-round (0086 C1)")
    rounds = body.scan(/class="log-round-head"[^>]*data-round="(\d+)"/).flatten.map(&:to_i)
    assert_equal rounds.sort.reverse, rounds, "newest-first mantido no log"
    assert_match(/id="round-\d+"/, body, "expected round anchors (0086 C1)")
  end

  def test_battle_log_entries_carry_damage_and_ko_chips
    start_battle_for("user-a")
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_match(/class="[^"]*\bchip--dmg\b[^"]*"[^>]*>\s*\d+ de dano/, body,
                 "expected a per-entry damage chip (0086 C1)")
  end

  def test_battle_side_heads_count_active_fighters
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    body = last_response.body
    assert_match(%r{<p class="meta">\d+ ativos</p>}, body,
                 "expected side heads to count the active fighters")
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

  def test_battle_log_item_rows_show_remaining_stock
    tank_a = build_pokemon(number: 1, name: "tanka", hp: 100, attack: 10, defense: 50, speed: 50)
    tank_b = build_pokemon(number: 2, name: "tankb", hp: 100, attack: 10, defense: 50, speed: 50)
    engine = BattleEngine.new(team_a: [tank_a], team_b: [tank_b], items: { "potion" => 0 })
    engine.play_round until engine.finished?
    engine.log << { round: 1, attacker: 0, action: :item, item: "potion",
                    healed: 20, attacker_name: "tanka" }
    Server.settings.battles.set("user-a", engine)
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_match(/chip--stock[^>]*>\s*restam 0/, body,
                 "expected a remaining-stock chip on the item log row (0086 C3)")
    assert_match(/chip--empty[^>]*>\s*última unidade/, body,
                 "expected a last-unit chip when stock hits zero (0086 C3)")
  end

  def test_battle_log_shows_defeat_line_on_loss
    weak_poke = build_pokemon(number: 1, name: "weak", hp: 10, attack: 1, defense: 1, speed: 1)
    strong = build_pokemon(number: 2, name: "strong", hp: 100, attack: 50, defense: 50, speed: 50)
    engine = BattleEngine.new(team_a: [weak_poke], team_b: [strong])
    engine.play_round until engine.finished?
    Server.settings.battles.set("user-a", engine)
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    log_region = body[%r{<ul class="log".*?</ul>}m]
    assert_match(/log__entry--defeat/, log_region.to_s,
                 "expected a defeat line inside the battle log (0086 C3)")
    refute_match(/log__entry--defeat"[^>]*data-round="\d+"/, log_region.to_s,
                 "defeat line is a summary, not a round — no numeric data-round")
    assert_match(/Derrota — seu time foi derrotado/, log_region.to_s,
                 "defeat copy distinguishes participation from victory")
  end

  def test_battle_end_uses_results_desktop_markup
    start_battle_for("user-a")
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_match(/class="res-screen"/, body, "expected .res-screen wrapping the battle end")
    assert_match(/class="res-top"/, body, "expected .res-top result bar (desktop)")
    assert_match(/class="state-title"/, body, "expected .state-title with winner")
    assert_match(/class="state-card"/, body, "expected .state-card for the end state")
    assert_match(/class="mini-arena"/, body, "expected .mini-arena with both sides")
    assert_match(/<li class="frow[ "]/, body, "expected li.frow rows per fighter")
    assert_match(/class="result-card"/, body, "expected .result-card with winner + rewards")
  end
end
