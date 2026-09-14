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

  def test_strike_button_swaps_log_beforeend
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    body = last_response.body
    button = body[/<button[^>]*id="play-btn"[^>]*>/]
    refute_nil button, "botao primario presente"
    assert_includes button, 'hx-post="/battle/strike"', "botao primario posta golpe"
    assert_includes button, 'hx-target="#battle-log"', "swap principal anexa no #battle-log"
    assert_includes button, 'hx-swap="beforeend"', "swap principal preserva o <li> intacto"
    assert_includes button, "next-strike from:body", "auto encadeia golpe a golpe"
    assert_includes body, ">Batalhar</button>", "1 clique = 1 golpe"
  end

  def test_strike_appends_exactly_one_log_line_as_main_content
    start_battle_for("user-a")

    post "/battle/strike", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_match(/<li class="log__entry"[^>]*data-round="\d+"/, body,
                 "li viaja no swap principal (beforeend no #battle-log)")
    assert_equal 1, body.scan("log__entry").size, "1 strike = 1 linha"
    assert_match(/data-from-side="[01]"/, body)
    assert_match(/data-to-side="[01]"/, body)
    refute_includes body, 'hx-swap-oob="beforeend:#battle-log"',
                    "OOB do htmx 2.0.3 insere so os filhos e descarta o <li>"
    assert_includes body, 'hx-swap-oob="innerHTML"', "demais fragmentos seguem OOB"
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

  # Review round 11 (0086 Passo 31): o golpe final desabilita o botao primario
  # via OOB; sem isso #play-btn fica vivo apos o fim e cliques devolvem "".
  def test_strike_disables_play_button_when_finished
    start_battle_for("user-a")
    strike_until_finish

    assert last_response.ok?
    play = last_response.body[/<button[^>]*id="play-btn"[^>]*>/]
    refute_nil play, "fim de batalha re-troca #play-btn via OOB"
    assert_includes play, 'hx-swap-oob="outerHTML"', "swap do botao e OOB (htmx 2.0.3 sem delete)"
    assert_includes play, " disabled", "botao Batalhar fica desabilitado apos o fim"
    refute_includes play, "hx-post", "sem acao de golpe no botao final"
  end

  def test_strike_keeps_play_button_while_running
    start_battle_for("user-a")

    post "/battle/strike", {}, user_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, 'id="play-btn"',
                    "em andamento o botao nao e re-renderizado nem removido"
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

  def test_strike_log_entry_travels_as_main_content
    start_battle_for("user-a")

    post "/battle/strike", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    li = body[/<li class="log__entry"[^>]*>/]
    refute_nil li, "li intacto no body (swap principal beforeend em #battle-log)"
    refute_includes li, "hx-swap-oob",
                    "OOB do htmx 2.0.3 descarta o wrapper e achata os <span>"
    assert_includes li, "data-round=", "li carrega data-round"
    assert_includes li, "--log-delay: 0s", "li carrega o proprio --log-delay"
    fx = body[/<span class="fx[^>]*>/]
    refute_nil fx, "fx presente dentro do li"
    assert_includes fx, "--log-delay: 0s", "fx espelha o --log-delay da linha"
    refute_includes body, "<template",
                    "sem embrulho em template (conteudo nunca seria inserido)"
  end

  def test_strike_entry_carries_move_type
    start_battle_for("user-a")
    body = strike_until_damaging

    li = body[/<li class="log__entry"[^>]*>/]
    refute_nil li, "li do strike presente"
    assert_match(/data-move-type="[^"]+"/, li,
                 "strike de ataque expoe data-move-type (0086 C11)")
    assert_includes li, 'data-strategy="strike"',
                    "strike OOB declara a estrategia default strike (0086 C12)"
  end

  def test_strike_oob_flips_arena_gates_for_current_entry
    start_battle_for("user-a")
    body = strike_until_damaging

    assert_includes body, 'id="jx-gates" hx-swap-oob="outerHTML"',
                    "gates via OOB sem re-render da arena"
    assert_includes body, 'data-jx-hit="on"', "golpe com dano acende hit"
    assert_includes body, 'data-jx-dmg="on"', "golpe com dano acende numero"
    assert_includes body, 'data-jx-shot="on"', "atacante acende projetil"
    assert_includes body, 'data-jx-hp="on"', "HP anima no golpe atual"
    if body.include?("KO!")
      assert_includes body, 'data-jx-ko="on"', "KO acende ko"
    else
      assert_includes body, 'data-jx-ko="off"', "sem KO, ko apagado"
    end
  end

  # Passo 29 (0086 C11): o carrier de gates leva o tipo do golpe atual para o
  # .arena propagar --fx-color ate o .shot do atacante.
  def test_strike_gates_carrier_carries_move_type
    start_battle_for("user-a")
    body = strike_until_damaging

    gates = body[/<span id="jx-gates"[^>]*>/]
    refute_nil gates, "gate carrier presente no strike"
    assert_match(/data-move-type="[a-z]+"/, gates,
                 "golpe de ataque carrega data-move-type nos gates (Passo 29)")
  end

  # Passo 29: entradas sem golpe (item/cura) nao emitem data-move-type no
  # carrier — mesmo contrato do log entry.
  def test_strike_gates_carrier_omits_move_type_on_item_entry
    member_id = @repository.all("user-a").first.id
    @inventory.add("user-a", "potion", 1)
    post "/team/#{member_id}/item", { item_name: "potion" }, user_session("user-a")
    @progression.update_hp("user-a", member_id, 200, 90)
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    gates = nil
    12.times do
      post "/battle/strike", {}, user_session("user-a")
      body = last_response.body
      # NB: o copy do item tem bug pre-existente ("1 Pocao", fora do escopo deste
      # passo) — casa pelo nome do item, nao pela frase exata.
      if body.include?("Pocao")
        gates = body[/<span id="jx-gates"[^>]*>/]
        break
      end
    end
    refute_nil gates, "entrada de item (sem golpe) presente em ate 12 golpes"
    refute_includes gates, "data-move-type",
                    "entrada sem golpe omite data-move-type nos gates (Passo 29)"
  end

  # C10 (0086 Passo 25): o gate de shake ja e emitido no dano (server.rb:1125);
  # esta rota nao muda — o teste trava o contrato de que o card do alvo acende.
  def test_strike_shake_gate_emitted_on_damage
    start_battle_for("user-a")
    body = strike_until_damaging

    gates = body[/<span id="jx-gates"[^>]*>/]
    refute_nil gates, "gate carrier presente no strike"
    assert_includes gates, 'data-jx-shake="on"',
                    "dano acende shake no card do alvo (C10; gate ja emitido em server.rb:1125)"
  end

  def test_strike_juice_scoped_to_current_entry_only
    start_battle_for("user-a")
    prev = nil
    20.times do
      post "/battle/strike", {}, user_session("user-a")
      body = last_response.body
      next unless body.include?("chip--dmg")

      cur = strike_parties(body)
      if prev && prev[:attacker] != cur[:attacker] && prev[:target] != cur[:target]
        assert_fighter_class(body, cur[:attacker], "is-attacking", present: true)
        assert_fighter_class(body, cur[:target], "is-hit", present: true)
        assert_fighter_class(body, prev[:attacker], "is-attacking", present: false)
        assert_fighter_class(body, prev[:target], "is-hit", present: false)
        return
      end
      prev = cur
      return if body.include?('id="result-modal"')
    end
    flunk "sem dois golpes com dano e pares distintos"
  end

  def test_battle_arena_ships_jx_gates_carrier_off
    start_battle_for("user-a")

    assert last_response.ok?
    carrier = last_response.body[/<span id="jx-gates"[^>]*>/]
    refute_nil carrier, "arena carrega #jx-gates"
    %w[hit dmg ko shot hp shake].each do |aspect|
      assert_includes carrier, %(data-jx-#{aspect}="off"),
                      "gate #{aspect} comeca apagado no render full"
    end
  end

  private

  def strike_until_damaging(cap: 10)
    cap.times do
      post "/battle/strike", {}, user_session("user-a")
      return last_response.body if last_response.body.include?("chip--dmg")
    end
    flunk "nenhum golpe com dano em #{cap} strikes"
  end

  def strike_parties(body)
    li = body[/<li class="log__entry"[^>]*>/]
    from = li[/data-from-side="(\d)"/, 1].to_i
    to = li[/data-to-side="(\d)"/, 1].to_i
    text = body[%r{<strong>([^<]+)</strong>}, 1]
    attacker = text.split(" usou ").first
    target = text.split(" em ").last.split(",").first
    { attacker: [from, attacker], target: [to, target] }
  end

  def assert_fighter_class(body, (side, name), klass, present:)
    slug = Regexp.escape(name.downcase)
    lis = body.scan(/<li class="([^"]*)"[^>]*data-side="#{side}"[^>]*data-od-id="fighter-#{slug}"/)
    refute_empty lis, "lutador #{name} do lado #{side} renderizado"
    lis.each do |(classes)|
      if present
        assert_includes classes.split, klass, "#{name} veste #{klass} no golpe atual"
      else
        refute_includes classes.split, klass, "#{name} nao veste #{klass} de golpe anterior"
      end
    end
  end

  def strike_until_finish(auto: false, cap: 2000)
    params = auto ? { "auto" => "1" } : {}
    cap.times do
      post "/battle/strike", params, user_session("user-a")
      return if last_response.body.include?('id="result-modal"')
    end
  end
end
