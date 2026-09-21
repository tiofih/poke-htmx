# frozen_string_literal: true

require_relative "server_test_helpers"

class LayoutViewportTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_layout_contains_viewport_meta
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_match(/<meta name="viewport"[^>]*content="width=device-width,\s*initial-scale=1"/, last_response.body)
  end

  def test_battle_page_layout_contains_viewport_meta
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/battle", {}, user_session("user-a")
    end

    assert_match(/<meta name="viewport"[^>]*content="width=device-width,\s*initial-scale=1"/, last_response.body)
  end

  def test_history_page_layout_contains_viewport_meta
    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    assert_match(/<meta name="viewport"[^>]*content="width=device-width,\s*initial-scale=1"/, last_response.body)
  end

  def test_full_page_starts_with_doctype
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_match(/\A<!DOCTYPE html>/i, last_response.body,
                 "expected GET / to start with <!DOCTYPE html> (standards mode, S3 0080 C1b)")
    assert_match(/<html lang="pt-BR"/, last_response.body,
                 "expected <html lang=\"pt-BR\"> like the open-design prototypes")
  end

  def test_nav_shows_team_badge
    server_content = File.read(File.join(__dir__, "../server.rb"))
    layout_content = File.read(File.join(__dir__, "../views/layout.erb"))

    assert_match(/@team_size/, server_content,
                 "expected server.rb to set @team_size")
    assert_match(/settings\.team\.all/, server_content,
                 "expected server.rb to use settings.team.all")
    assert_match(/@team_size/, layout_content,
                 "expected layout.erb to render @team_size")
    assert_match(%r{/6}, layout_content,
                 "expected layout.erb to display /6 badge")

    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("badge-user")
    end

    assert last_response.ok?
    assert_match(%r{0/6|1/6|2/6|3/6|4/6|5/6|6/6}, last_response.body,
                 "expected GET / to contain badge n/6")
  end

  def test_topnav_cta_always_btn_and_back_link_only_on_battle
    cta_slot = File.read(File.join(__dir__, "../views/_cta_slot.erb"))

    assert_match(%r{href="/battle" class="btn}, cta_slot,
                 "expected the /battle CTA to always wear .btn (no active-text)")
    layout = File.read(File.join(__dir__, "../views/layout.erb"))
    assert_match(/Voltar ao time/, layout,
                 "expected a Voltar ao time link in the topnav")

    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    refute_includes last_response.body, "Voltar ao time",
                    "expected the back link only on /battle, not on /"
  end

  # 0083 C1: o CTA Batalhar do topnav passa a refletir o estado do time (gate
  # visual, sem regra nova). Nil-safe: rotas que renderizam o layout sem passar
  # por load_journey_state (ex.: GET /battle) deixam @can_battle nil e o CTA
  # segue habilitado — o gate so aparece quando o estado existe.
  # S3 2026-09-21 (comentario PR#2, emenda a C1 da 0083): o hint de texto saiu —
  # quem explica o gate e a pill do time; o header nao tem mais mensagem.
  def test_battle_cta_gated_hint # rubocop:disable Metrics/AbcSize
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("cta-empty")
    end
    assert last_response.ok?
    cta = last_response.body[/<a[^>]*data-od-id="cta-battle"[^>]*>/]
    refute_nil cta, "o CTA Batalhar continua no header"
    assert_match(/aria-disabled="true"/, cta, "time vazio: CTA gated no header (C1)")
    assert_match(/btn--gated/, cta, "o gate veste .btn--gated (C1)")
    assert_match(/Time vazio/, last_response.body, "time vazio: pill explica (S3)")
    refute_includes last_response.body, "cta-hint", "sem mensagem ao lado do botao (S3)"

    fill_team("cta-ready")
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("cta-ready")
    end
    assert last_response.ok?
    body = last_response.body
    cta = body[/<a[^>]*data-od-id="cta-battle"[^>]*>/]
    refute_nil cta, "o CTA Batalhar continua no header"
    refute_match(/aria-disabled|btn--gated/, cta, "time valido: CTA habilitado (C1)")
    assert_match(%r{Pronto p/ batalhar}, body, "time valido: pill ready")

    fill_team("cta-hurt")
    @repository.all("cta-hurt").each { |m| @progression.update_hp("cta-hurt", m.id, 200, 0) }
    # Saldo para curar: ferido != game over (sem isso o estado e terminal).
    @wallet.grant("cta-hurt", 10_000)
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("cta-hurt")
    end
    cta = last_response.body[/<a[^>]*data-od-id="cta-battle"[^>]*>/]
    assert_match(/aria-disabled="true"/, cta.to_s, "time ferido: CTA gated (C1)")
    assert_match(/Precisa de cura/, last_response.body, "time cheio ferido: pill de cura (S3)")
    refute_includes last_response.body, "cta-hint", "sem mensagem ao lado do botao (S3)"

    # nil-safe: GET /battle nao passa por load_journey_state -> @can_battle nil.
    get "/battle", {}, user_session("cta-battle-page")
    assert last_response.ok?
    cta = last_response.body[/<a[^>]*data-od-id="cta-battle"[^>]*>/]
    refute_nil cta, "o CTA Batalhar continua no header de /battle"
    refute_match(/aria-disabled|btn--gated/, cta,
                 "@can_battle nil (layout compartilhado): sem gate — nil-safe (C1)")
  end

  # S3 2026-09-21 (comentario PR#2): time incompleto e saudavel pede mais
  # na pill em vez de falar de cura.
  def test_battle_cta_pill_incomplete_team_asks_for_more
    five = (1..5).map { |n| build_pokemon_record("pokemon#{n}", n) }
    five.each { |poke| @repository.add("cta-short", poke) }
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("cta-short")
    end
    assert last_response.ok?
    cta = last_response.body[/<a[^>]*data-od-id="cta-battle"[^>]*>/]
    assert_match(/btn--gated/, cta.to_s, "time incompleto: CTA gated (S3)")
    assert_match(/Falta 1/, last_response.body, "time incompleto: pill pede mais (S3)")
    refute_includes last_response.body, "cta-hint", "sem mensagem ao lado do botao (S3)"
  end

  # S3 2026-09-21 (comentario PR#2): o hint saiu - a pill do time explica o gate;
  # sem `aria-describedby` sem alvo e sem CSS morto de hint.
  def test_battle_cta_pill_distinguishes_gated_states
    fill_team("cta-game-over")
    @repository.all("cta-game-over").each { |m| @progression.update_hp("cta-game-over", m.id, 200, 0) }
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("cta-game-over")
    end
    assert last_response.ok?
    assert_match(/Game over/, last_response.body, "game over: pill terminal (S3)")
    refute_includes last_response.body, "cta-hint", "sem mensagem ao lado do botao (S3)"

    fill_team("cta-hurt-rich")
    @repository.all("cta-hurt-rich").each { |m| @progression.update_hp("cta-hurt-rich", m.id, 200, 0) }
    @wallet.grant("cta-hurt-rich", 10_000)
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("cta-hurt-rich")
    end
    assert_match(/Precisa de cura/, last_response.body, "time cheio ferido: pill de cura (S3)")
    refute_includes last_response.body, "cta-hint", "sem mensagem ao lado do botao (S3)"
  end

  # 0088 Passo 4/5 (D1a/D2a — excecao estreita ao RNF-01): unico handler JS do
  # projetil slot-a-slot. Prova estatica: existe, e ligado a um evento htmx
  # (que dispara depois do swap, OOB incluso), le os slots do atacante e do
  # alvo, escreve --fx-dy (destino) e --fx-ox/--fx-oy (origem) inline no .shot e
  # mantem os no-ops (reduced motion, coluna unica) sem lib/polling/SSE. A prova
  # de que o projetil SAI e POUSA nos slots e o e2e do Passo 5 — aqui nao se
  # afirma comportamento.
  def test_projectile_handler_measures_target_slot_offset
    layout = File.read(File.join(__dir__, "../views/layout.erb"))

    assert_match(/document\.addEventListener\(\s*["']htmx:(?:afterSettle|afterSwap|oobAfterSwap)["'],\s*\w+\s*\)/,
                 layout, "o medidor do projetil e ligado a um evento htmx (D2a/G2)")
    assert_match(/getBoundingClientRect\(\)/, layout,
                 "a medida vem da geometria real dos cards (D1a)")
    assert_match(/data-side=.{0,40}data-slot=/, layout,
                 "o handler encontra o card alvo por data-side + data-slot")
    assert_match(/getAttribute\(\s*["']data-to-slot["']\)/, layout,
                 "o slot de destino e lido do proprio .shot")
    assert_match(/setProperty\(\s*["']--fx-dy["']/, layout,
                 "o deslocamento vertical do destino vai para --fx-dy inline (D1a)")
    # 0088 Passo 5: a origem (centro do card do atacante) e o gap que faltava —
    # o keyframe `from` consome --fx-ox/--fx-oy com fallback 0.
    assert_match(/getAttribute\(\s*["']data-from-slot["']\)/, layout,
                 "o slot de origem e lido do proprio .shot (origem x/y)")
    assert_match(/setProperty\(\s*["']--fx-ox["']/, layout,
                 "o offset horizontal da origem vai para --fx-ox inline")
    assert_match(/setProperty\(\s*["']--fx-oy["']/, layout,
                 "o offset vertical da origem vai para --fx-oy inline")
    assert_match(/prefers-reduced-motion:\s*reduce/, layout,
                 "reduced motion e no-op explicito no JS (D4a/C8)")
    assert_match(/min-width:\s*981px/, layout,
                 "coluna unica (<981px) e no-op explicito, mesmo breakpoint do CSS (D5/C9)")
    refute_match(/setInterval|EventSource|new WebSocket/, layout,
                 "sem polling/SSE — so o handler htmx (G2)")
  end
end
