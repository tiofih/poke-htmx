# frozen_string_literal: true

require_relative "server_test_helpers"
class ServerHistoryTest < Minitest::Test
  include ServerTestHelpers

  def test_history_renders_fragment_with_rank_and_metrics
    history = BattleRepository.new
    history.add("user-a", "win", [{ number: 25, name: "pikachu" }])
    history.add("user-a", "lose", [{ number: 4, name: "charmander" }])

    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, "<html"
    assert_match(/Ranking global/, last_response.body)
    assert_match(/Vitórias: 1/, last_response.body)
    assert_match(/Derrotas: 1/, last_response.body)
  end

  def test_history_highlights_current_user_in_ranking
    history = BattleRepository.new
    history.add("user-a", "win", [{ number: 25, name: "pikachu" }])

    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    assert_match(/user-a/, last_response.body)
  end

  def test_history_shows_empty_message_without_battles
    get "/history", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Você ainda não batalhou"
    assert_includes last_response.body, "notice--info"
  end

  def test_history_close_route_returns_empty_fragment
    get "/history/close"

    assert last_response.ok?
    assert_empty last_response.body
  end

  def test_index_has_history_target_and_link
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'href="/history"'
    assert_includes last_response.body, "Histórico"
  end
end
