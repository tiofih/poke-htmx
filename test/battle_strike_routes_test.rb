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

  def test_strike_button_posts_strike_oob_only
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    body = last_response.body
    assert_includes body, 'hx-post="/battle/strike"', "botao primario posta golpe"
    assert_includes body, 'hx-swap="none"', "strike responde so OOB"
    assert_includes body, "next-strike from:body", "auto encadeia golpe a golpe"
    assert_includes body, ">Batalhar</button>", "1 clique = 1 golpe"
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

  def test_strike_log_entry_carries_direct_oob
    start_battle_for("user-a")

    post "/battle/strike", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_match(/<li class="log__entry" hx-swap-oob="beforeend:#battle-log"/, body,
                 "li carrega o OOB direto (htmx 2.0.3 nao desmembra template)")
    refute_includes body, "<template",
                    "sem embrulho em template (conteudo nunca seria inserido)"
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
