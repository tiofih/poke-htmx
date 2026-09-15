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

  def test_battle_keeps_htmx_contract_on_strike_button
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    body = last_response.body
    assert_includes body, 'hx-post="/battle/strike"', "batalhar posta um golpe em /battle/strike"
    button = body[/<button[^>]*id="play-btn"[^>]*>/]
    refute_nil button, "botao primario presente"
    assert_includes button, 'hx-target="#battle-log"', "swap principal anexa no #battle-log"
    assert_includes button, 'hx-swap="beforeend"', "swap principal preserva o <li> intacto"
    assert_includes body, 'hx-indicator="#battle-loading"', "loading indicator preserved"
    assert_includes body, ">Batalhar</button>", "1 clique = 1 golpe"
  end

  def test_battle_renders_empty_log_container_before_first_strike
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    body = last_response.body
    assert_match(/<ul class="log"[^>]*id="battle-log"/, body,
                 "expected empty #battle-log so strike OOB appends land from strike 1")
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

  def test_battle_log_groups_entries_by_round_chronological
    start_battle_for("user-a")
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_match(/class="log-round-head"[^>]*data-round="\d+"/, body,
                 "expected a round header carrying data-round (0086 C1)")
    rounds = body.scan(/class="log-round-head"[^>]*data-round="(\d+)"/).flatten.map(&:to_i)
    assert_equal rounds.sort, rounds, "chronological mantido no log (S3 0086: round 1 no topo)"
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

  def test_battle_log_entries_carry_move_type
    tank_a = build_pokemon(number: 1, name: "tanka", hp: 100, attack: 10, defense: 50, speed: 50)
    tank_b = build_pokemon(number: 2, name: "tankb", hp: 100, attack: 10, defense: 50, speed: 50)
    engine = BattleEngine.new(team_a: [tank_a], team_b: [tank_b], items: { "potion" => 0 })
    engine.play_round until engine.finished?
    engine.log << { round: 1, attacker: 0, move_type: "electric", move: "thunder-shock",
                    damage: 5, ko: false, attacker_name: "tanka", target_name: "tankb" }
    engine.log << { round: 1, attacker: 0, action: :item, item: "potion",
                    healed: 20, attacker_name: "tanka" }
    Server.settings.battles.set("user-a", engine)
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    entries = last_response.body.scan(%r{<li class="log__entry".*?</li>}m)
    typed_line = entries.find { |li| li.include?("thunder-shock") }
    refute_nil typed_line, "linha de ataque tipado presente"
    assert_match(/data-move-type="electric"/, typed_line,
                 "ataque expoe data-move-type no render full (0086 C11)")
    item_line = entries.find { |li| li.include?("chip--stock") }
    refute_nil item_line, "linha de item presente"
    refute_includes item_line, "data-move-type",
                    "linha sem golpe omite data-move-type (nao emite vazio/nil)"
  end

  def test_battle_log_entries_carry_strategy_default_strike
    tank_a = build_pokemon(number: 1, name: "tanka", hp: 100, attack: 10, defense: 50, speed: 50)
    tank_b = build_pokemon(number: 2, name: "tankb", hp: 100, attack: 10, defense: 50, speed: 50)
    engine = BattleEngine.new(team_a: [tank_a], team_b: [tank_b], items: { "potion" => 0 })
    engine.play_round until engine.finished?
    engine.log << { round: 1, attacker: 0, move_type: "fire", move: "ember",
                    damage: 5, ko: false, attacker_name: "tanka", target_name: "tankb" }
    Server.settings.battles.set("user-a", engine)
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    entries = last_response.body.scan(%r{<li class="log__entry".*?</li>}m)
    typed_line = entries.find { |li| li.include?("ember") }
    refute_nil typed_line, "linha de ataque presente"
    assert_match(/data-strategy="strike"/, typed_line,
                 "entrada declara a estrategia default strike (0086 C12)")
    assert_match(/data-move-type="fire"/, typed_line,
                 "tipo do golpe presente junto da estrategia (0086 C11)")
  end

  def test_battle_side_heads_count_active_fighters
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    body = last_response.body
    assert_match(%r{<p class="meta">\d+ ativos</p>}, body,
                 "expected side heads to count the active fighters")
  end

  def play_until_finish(fallback_plays: 300)
    fallback_plays.times do
      post "/battle/play", {}, user_session("user-a")
      return if last_response.body.include?("Fim de batalha")
    end
  end

  def test_battle_result_uses_winner_badge_and_ctas
    start_battle_for("user-a")
    play_until_finish

    assert last_response.ok?
    body = last_response.body
    assert_includes body, "Fim de batalha", "plays sucessivos resolvem a batalha"
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

  def pace_step_for(round)
    return 0.2 if round >= 10
    return 0.5 if round >= 4

    1.0
  end

  def log_chunks_with_entries(body)
    chunks = body.split('class="log-round-head"').drop(1)
    chunks.map do |chunk|
      head_round = chunk[/data-round="(\d+)"/, 1].to_i
      pairs = chunk.scan(/data-round="(\d+)"[^>]*style="--log-delay: ([\d.]+)s"/)
                   .map { |round, delay| [round.to_i, delay.to_f] }
      [head_round, pairs]
    end
  end

  def test_battle_log_pacing_is_cumulative_per_entry
    start_battle_for("user-a")
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    groups = log_chunks_with_entries(last_response.body).select { |_, pairs| pairs.size > 1 }
    refute_empty groups, "expected a round with 2+ entries to prove per-entry pacing"
    groups.each do |head_round, pairs|
      assert_equal head_round, pairs.first.first,
                   "entries carry the round of their header (0086 Passo 5)"
      delays = pairs.map(&:last)
      assert_equal delays.sort, delays,
                   "delays grow entry by entry inside the round (cumulative pacing)"
    end
  end

  def test_battle_log_pacing_uses_tiered_step
    start_battle_for("user-a")
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    checked = 0
    log_chunks_with_entries(last_response.body).each do |chunk|
      pairs = chunk.last
      pairs.each_cons(2) do |(round_a, delay_a), (round_b, delay_b)|
        next unless round_a == round_b

        assert_in_delta pace_step_for(round_a), delay_b - delay_a, 0.001,
                        "tiered step na rodada #{round_a} (1s ate R3, 0.5s R4-9, 0.2s R10+)"
        checked += 1
      end
    end
    assert checked.positive?, "expected same-round pairs to prove the tiered step"
  end

  def test_battle_log_has_skip_control
    start_battle_for("user-a")
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_match(/<input[^>]*type="checkbox"[^>]*id="log-skip"/, body,
                 "expected a CSS-only Pular checkbox before the log (0086 Passo 5)")
    assert_match(%r{<label[^>]*for="log-skip"[^>]*>Pular</label>}, body,
                 "expected a Pular label toggling the skip checkbox")
  end

  def test_battle_fighter_cards_carry_side_and_step_delay
    start_battle_for("user-a")
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_match(/<li class="fighter[^"]*"[^>]*data-side="0"/, body,
                 "fighter li carries data-side=0 (0086 Passo 6)")
    assert_match(/<li class="fighter[^"]*"[^>]*data-side="1"/, body,
                 "fighter li carries data-side=1 (0086 Passo 6)")
    assert_match(/<li class="fighter[^"]*"[^>]*--step-delay: [\d.]+s/, body,
                 "fighter li exposes --step-delay synced to log pacing (0086 Passo 6)")
    assert_match(/<li class="fighter[^"]*"[^>]*data-slot="\d+"/, body,
                 "fighter li exposes its team slot (0088 C5)")
  end

  def test_battle_arena_carries_step_delay_and_per_line_fx
    start_battle_for("user-a")
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_match(/<div class="arena"[^>]*--step-delay: [\d.]+s/, body,
                 "arena exposes --step-delay for the shake (0086 Passo 9)")
    fx_pattern = /<li class="log__entry"[^>]*>\s*<span class="fx fx--(hit|ko|heal|tick)"[^>]*>/
    assert_match(fx_pattern, body,
                 "each log line carries its own fx token (0086 Passo 9)")
    assert_match(/<li class="log__entry"[^>]*style="--log-delay: [\d.]+s"/, body,
                 "the line (ancestor) declares --log-delay")
    refute_match(/<span class="fx[^>]*--log-delay/, body,
                 "fx inherits --log-delay from its line (Passo 36: sem declaracao duplicada)")
  end

  def test_battle_arena_carries_jx_toggles_per_aspect
    start_battle_for("user-a")
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    arena = body[/<div class="arena"[^>]*>/]
    refute_nil arena, "expected an .arena div"
    %w[log fx chip modal].each do |aspect|
      assert_includes arena, %(data-jx-#{aspect}="on"),
                      "arena keeps per-line/modal aspect #{aspect} ON (0086 Passo 11)"
    end
    %w[hit dmg ko shot hp shake].each do |aspect|
      assert_includes arena, %(data-jx-#{aspect}="off"),
                      "arena mutes aggregate aspect #{aspect} OFF ate stepping por linha (0086 Passo 11)"
    end
  end

  # Passo 29 (0086 C11): o render full nao tem golpe corrente; o carrier de
  # gates omite data-move-type (mesma regra do log entry) e o .arena mantem o
  # fallback normal.
  def test_battle_arena_gates_carrier_omits_move_type_at_rest
    start_battle_for("user-a")

    assert last_response.ok?
    carrier = last_response.body[/<span id="jx-gates"[^>]*>/]
    refute_nil carrier, "arena carrega #jx-gates"
    refute_includes carrier, "data-move-type",
                    "render full sem golpe corrente omite data-move-type (Passo 29)"
  end

  def test_battle_end_uses_results_desktop_markup
    start_battle_for("user-a")
    play_until_finish

    assert last_response.ok?
    body = last_response.body
    assert_match(/class="[^"]*res-screen[^"]*"/, body, "expected .res-screen wrapping the battle end")
    assert_match(/class="res-top"/, body, "expected .res-top result bar (desktop)")
    assert_match(/class="state-title"/, body, "expected .state-title with winner")
    assert_match(/class="state-card"/, body, "expected .state-card for the end state")
    assert_match(/class="mini-arena"/, body, "expected .mini-arena with both sides")
    assert_match(/<li class="frow[ "]/, body, "expected li.frow rows per fighter")
    assert_match(/class="result-card"/, body, "expected .result-card with winner + rewards")
  end

  def test_battle_result_gated_modal_after_log
    start_battle_for("user-a")
    play_until_finish

    assert last_response.ok?
    body = last_response.body
    assert_match(/<div class="arena"[^>]*--log-total: [\d.]+s/, body,
                 "arena exposes --log-total gating the result (0086 Passo 7)")
    log_total = body[/--log-total: ([\d.]+)s/, 1].to_f
    assert_operator log_total, :<=, 3.0,
                    "modal gate capped at 3s so long logs still reveal (0086 T114)"
    assert_match(/--log-total-full: [\d.]+s/, body,
                 "arena keeps full pacing in --log-total-full (0086 T114)")
    assert_match(/<div class="overlay open res-screen res-overlay"[^>]*id="result-modal"/, body,
                 "result reuses Center .overlay.open modal pattern (0086 Passo 7)")
    assert_match(/role="dialog"[^>]*aria-modal="true"/, body,
                 "result modal is a dialog")
    assert_match(/<input[^>]*type="checkbox"[^>]*id="res-dismiss"/, body,
                 "result has a CSS-only dismiss checkbox")
    assert_match(%r{<label[^>]*for="res-dismiss"[^>]*>×</label>}, body,
                 "result has a close button")
  end
end
