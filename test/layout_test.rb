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
end
