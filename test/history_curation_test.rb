# frozen_string_literal: true

require_relative "server_test_helpers"

# Curadoria fina 1:1 do prototipo open-design/history.html (sessao 0079, C1).
# A base 0075 ja portou pos-card/rank-list/history-list; aqui trava-se o
# faltante: cards sem inline (classe .card--tight do bloco 0079), contratos
# htmx (#history-view, data-od-id) e vazio notice--info intactos.
class HistoryCurationTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def seed_battles(user_id: "user-a", results: %w[win lose])
    history = BattleRepository.new
    results.each do |result|
      history.add(user_id, result, [{ number: 25, name: "pikachu" }])
    end
  end

  def test_history_matches_prototype
    seed_battles

    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_equal 2, body.scan('class="card card--tight"').size,
                 "ranking + recent cards wear .card--tight"
    refute_match(/class="card" style=/, body,
                 "no history card carries inline style")
    assert_match(/data-od-id="your-position"/, body,
                 "position section keeps its contract")
    assert_match(/data-od-id="ranking"/, body,
                 "ranking section keeps its contract")
    assert_match(/data-od-id="recent"/, body,
                 "recent section keeps its contract")
    assert_match(%r{class="rank-bar"><span style="width:\d+%"></span></div>}, body,
                 "bar width stays inline: dado, nao veste")
  end

  def test_history_empty_notice_intact
    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Você ainda não batalhou"
    assert_includes last_response.body, "notice--info"
  end
end
