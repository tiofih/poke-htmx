# frozen_string_literal: true

require_relative "server_test_helpers"
require_relative "battle_test_helpers"

# Resíduo battle 1:1 (sessão 0078) — fim de batalha no protótipo
# open-design/battle-end-states.html: res-screen, state-card (4 estados),
# mini-arena (frow), result-card (rewards/CTAs).
# Revisão S7: a variante res-top/state-title do battle-results-desktop foi
# descartada (compunha com a state-card e duplicava pill + título).
# Motor só leitura: winner nil = empate, @game_over do journey.
class BattleEndStatesTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport
  include ServerBattleTestHelpers

  def setup
    super
    fill_team("user-a")
  end

  def test_battle_end_states
    start_battle_for("user-a")
    finish_battle

    body = last_response.body
    assert_match(/class="[^"]*res-screen[^"]*"/, body, "expected .res-screen wrapping the battle end")
    assert_match(/class="state-card"/, body, "expected .state-card for the end state")
    assert_match(/class="state-pill win"/, body, "expected victory .state-pill")
    assert_match(/class="mini-arena"/, body, "expected .mini-arena with both sides")
    assert_match(/class="mini-side-title"/, body, "expected .mini-side-title per side")
    assert_match(/<li class="frow[ "]/, body, "expected li.frow rows per fighter")
    assert_match(/class="result-card"/, body, "expected .result-card with winner + rewards")
    assert_includes body, "Vencedor:", "winner banner text preserved"
    assert_match(/Novo confronto/, body, "new confront CTA preserved")
  end

  def test_battle_end_states_defeat
    body = finish_with(weak: true)

    assert_match(/class="state-pill loss"/, body, "expected defeat .state-pill")
    assert_match(/class="[^"]*res-screen[^"]*"/, body, "defeat keeps .res-screen")
    assert_match(/class="state-card"/, body, "defeat keeps .state-card")
    assert_match(/<li class="frow lost[ "]/, body, "defeated fighters mark li.frow.lost")
    assert_match(/class="mini-arena"/, body, "defeat keeps .mini-arena")
    assert_includes body, "Vencedor:", "winner banner text preserved"
  end

  def test_battle_end_states_draw
    body = finish_draw

    assert_match(/class="state-pill draw"/, body, "expected draw .state-pill")
    assert_match(/Empate/, body, "draw labels the tied battle")
    assert_match(/class="[^"]*res-screen[^"]*"/, body, "draw keeps .res-screen")
    assert_match(/class="mini-arena"/, body, "draw keeps .mini-arena")
  end

  def test_battle_end_states_game_over
    body = finish_broke_and_defeated

    assert_match(/class="state-pill over"/, body, "expected game-over .state-pill")
    assert_match(/game over/i, body, "game-over text preserved")
    assert_match(/Recome\S* jornada/, body, "restart CTA preserved")
    assert_match(/Vender itens/i, body, "mart CTA preserved")
    refute_includes body, "Novo confronto", "game over hides new confront"
  end

  def test_results_card_rewards
    start_battle_for("user-a")
    finish_battle

    body = last_response.body
    result = body[/<div id="result-box">.*?<div class="log-title"/m].to_s
    assert_equal 1, result.scan('class="state-pill ').size,
                 "0078 A-1: um único .state-pill no fim (sem res-top duplicando pill/título)"
    assert_equal 1, result.scan("<h2").size,
                 "0078 A-1b: um único <h2> no fim (título só no state-head, não no modal-head)"
    refute_match(/<div class="modal-head">\s*<h2/, body,
                 "0078 A-1b: modal-head sem <h2> (mantém só o botão fechar)")
    refute_match(/class="res-top/, body,
                 "0078 A-1: a variante res-top (results-desktop) não compõe a tela")
    assert_match(/<div class="result-card">.*?<p class="rewards">.*?<div class="ctas">/m, body,
                 "C2: rewards dentro do .result-card (padrão battle-end-states.html)")
    assert_includes body, "Vencedor:", "winner banner text preserved"
    assert_match(/data-side="0"/, body, "player column keeps data-side=0")
    assert_match(/data-side="1"/, body, "opponent column keeps data-side=1")
    assert_includes body, 'hx-post="/battle/new"', "new confront posts to /battle/new"
    assert_includes body, 'hx-target="#battle-view"', "fragment swaps into #battle-view"
  end

  # 0078 A-4: "derrotado" deriva de fainted?, não do hp_percent arredondado —
  # hp 1/300 arredonda para 0% mas o pokémon está vivo.
  def test_lost_follows_fainted_not_rounded_hp
    grazed = BattlePokemon.new(
      number: 1, name: "grazed", types: ["normal"],
      stats: [{ name: "HP", value: 300 }, { name: "Attack", value: 50 },
              { name: "Defense", value: 1 }, { name: "Speed", value: 50 }],
      hp_max: 300, hp_current: 1, moves: []
    )
    koed = build_pokemon(number: 2, name: "koed", hp: 0)
    engine = BattleEngine.new(team_a: [grazed], team_b: [koed])
    engine.play_round until engine.finished?
    Server.settings.battles.set("user-a", engine)
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    rows = last_response.body.scan(%r{<li class="frow[^"]*">.*?</li>}m)
    grazed_row = rows.find { |row| row.include?("grazed") }
    koed_row = rows.find { |row| row.include?("koed") }
    refute_nil grazed_row, "expected the grazed fighter row"
    refute_nil koed_row, "expected the koed fighter row"
    refute_includes grazed_row, " lost", "hp 1/300 vivo não pode virar 'lost' (A-4)"
    assert_includes koed_row, " lost", "fainted continua marcando 'lost'"
  end

  private

  def finish_battle
    300.times do
      post "/battle/play", {}, user_session("user-a")
      return if last_response.body.include?("Fim de batalha")
    end
    flunk "battle did not finish"
  end

  def finish_with(weak:)
    weak_poke = build_pokemon(number: 1, name: "weak", hp: 10, attack: 1, defense: 1, speed: 1)
    strong = build_pokemon(number: 2, name: "strong", hp: 100, attack: 50, defense: 50, speed: 50)
    team_a = weak ? [weak_poke] : [strong]
    team_b = weak ? [strong] : [weak_poke]
    engine = BattleEngine.new(team_a: team_a, team_b: team_b)
    engine.play_round until engine.finished?
    Server.settings.battles.set("user-a", engine)
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    last_response.body
  end

  def finish_draw
    fainted_a = build_pokemon(number: 1, name: "drawee-a", hp: 0, attack: 1, defense: 1, speed: 1)
    fainted_b = build_pokemon(number: 2, name: "drawee-b", hp: 0, attack: 1, defense: 1, speed: 1)
    engine = BattleEngine.new(team_a: [fainted_a], team_b: [fainted_b])
    Server.settings.battles.set("user-a", engine)
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    last_response.body
  end

  def finish_broke_and_defeated
    TestDatabase.clear_team!
    fill_team("user-a")
    @repository.all("user-a").each { |member| @progression.update_hp("user-a", member.id, 200, 0) }

    weak = build_pokemon(number: 1, name: "weak", hp: 10, attack: 1, defense: 1, speed: 1)
    strong = build_pokemon(number: 2, name: "strong", hp: 100, attack: 50, defense: 50, speed: 50)
    engine = BattleEngine.new(team_a: [weak], team_b: [strong])
    engine.play_round until engine.finished?
    Server.settings.battles.set("user-a", engine)
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    last_response.body
  end
end
