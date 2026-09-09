# frozen_string_literal: true

require_relative "server_test_helpers"

# Testes estruturais do historico redesenhado (sessao 0075) — provam C2/C3
# (e, no Passo 3, C4/C5). O historico passa a ser .container > .pagehead +
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
end
