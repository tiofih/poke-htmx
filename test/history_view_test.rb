# frozen_string_literal: true

require_relative "server_test_helpers"

# Testes estruturais do historico redesenhado (sessao 0075) — provam C2/C3
# (Passo 2) e C4/C5 (Passo 3). O historico passa a ser .container > .pagehead +
# .pos-card + ul.rank-list + ul.history-list, preservando o contrato htmx
# (#history-view) e o vazio p.notice.notice--info.
class HistoryViewTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def seed_battles(user_id: "user-a", results: %w[win lose])
    history = BattleRepository.new
    results.each do |result|
      history.add(user_id, result, [{ number: 25, name: "pikachu" }])
    end
  end

  def test_history_pagehead_and_container
    seed_battles

    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_match(/<div class="container">/, body, "expected history fragment in .container")
    assert_match(/class="pagehead"/, body, "expected a .pagehead header")
    assert_match(/class="eyebrow"/, body, "expected a .eyebrow kicker")
    assert_includes body, "Bancada de batalhas", "eyebrow names the battle bench"
    assert_match(/<h1>/, body, "expected an h1 in the pagehead")
    assert_match(/class="lead"/, body, "expected a .lead intro")
  end

  def test_history_position_card_with_stat_chips
    seed_battles

    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_match(/class="pos-card"/, body, "expected a .pos-card with the current position")
    assert_match(/class="pos-badge"/, body, "expected a .pos-badge with the rank number")
    assert_match(/class="pos-title"/, body, "expected a .pos-title next to the badge")
    assert_equal 1, body.scan('class="stat-chip win"').size, "expected one win chip"
    assert_equal 1, body.scan('class="stat-chip loss"').size, "expected one loss chip"
    assert_equal 1, body.scan('class="stat-chip draw"').size, "expected one draw chip"
    assert_includes body, "Vitórias", "win chip labels the victories"
    assert_includes body, "Derrotas", "loss chip labels the defeats"
    assert_includes body, "Empates", "draw chip labels the draws"
  end

  def test_history_position_nil_shows_fallback_in_card
    seed_battles(user_id: "user-b", results: %w[win])

    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_match(/class="pos-card"/, body, "card renders even without a position")
    assert_includes body, "Você ainda não tem vitórias",
                    "nil position falls back inside the card"
  end

  def test_history_ranking_list_with_bars_and_current_user
    seed_battles(user_id: "user-b", results: %w[win win])
    seed_battles

    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_match(/<ul class="rank-list">/, body, "expected ranking as ul.rank-list")
    assert_match(/<li class="rank-row you">/, body, "current user row carries .you")
    assert_match(/class="rank-pos num"/, body, "expected .rank-pos.num with the index")
    assert_match(/class="rank-name"/, body, "expected .rank-name with the user id")
    assert_includes body, "user-a", "ranking names the current user"
    assert_includes body, "width:50%", "bar width is proportional to wins/total"
    assert_match(/class="rank-wins"/, body, "expected .rank-wins with wins/total")
    assert_match(%r{<strong class="num">1</strong> / 2}, body,
                 "rank-wins shows strong wins over total")
  end

  def test_history_ranking_section_wears_spacing_class
    seed_battles

    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    # Curadoria 0076 (2b, C12/D80): sem inline — o respiro vem de classe do bloco.
    refute_match(/data-od-id="ranking" style=/, body,
                 "ranking section must not carry inline style")
    assert_match(/<section data-od-id="ranking" class="gap-after">/, body,
                 "ranking section wears the spacing class")
  end

  def test_history_cards_wear_tight_class_without_inline_style
    seed_battles

    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    # Curadoria 0079 (C1): ex-inline do prototipo vira classe do bloco.
    refute_match(/class="card" style=/, body,
                 "history cards must not carry inline style")
    assert_equal 2, body.scan('class="card card--tight"').size,
                 "ranking + recent cards wear .card--tight"
  end

  def test_history_recent_battles_list
    seed_battles

    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_match(/<ul class="history-list">/, body, "expected battles as ul.history-list")
    assert_match(/<li class="history-row">/, body, "expected li.history-row per battle")
    assert_match(/class="result-badge win"/, body, "win battle carries .result-badge.win")
    assert_match(/class="result-badge loss"/, body, "loss battle carries .result-badge.loss")
    assert_includes body, "Vitória", "badge labels the win via result_label"
    assert_includes body, "Derrota", "badge labels the loss via result_label"
    assert_match(/class="history-main"/, body, "expected .history-main per row")
    assert_match(/class="h-title"/, body, "expected .h-title with Contra + opponent names")
    assert_includes body, "Contra pikachu", "h-title names the opponents"
    assert_match(/class="h-sub"/, body, "expected .h-sub with the secondary line")
    assert_match(/class="history-date num"/, body, "expected .history-date.num per row")
    assert_match(%r{\d{2}/\d{2} \d{2}:\d{2}}, body, "date renders as dd/mm HH:MM")
  end
end
