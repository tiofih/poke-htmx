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
end
