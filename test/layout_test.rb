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
    layout = File.read(File.join(__dir__, "../views/layout.erb"))

    assert_match(%r{href="/battle" class="btn}, layout,
                 "expected the /battle CTA to always wear .btn (no active-text)")
    assert_match(/Voltar ao time/, layout,
                 "expected a Voltar ao time link in the topnav")

    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    refute_includes last_response.body, "Voltar ao time",
                    "expected the back link only on /battle, not on /"
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
