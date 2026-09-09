# frozen_string_literal: true

require_relative "server_test_helpers"

# Testes estruturais da home redesenhada (sessão 0073) — provam C2 (e parte de C1/C9).
# A home deixa de ser "lista + time lado-a-lado" e passa a ser um shell novo
# (app-head + grid-2-1 team/services | catalog-pane), preservando os alvos de fragmento.
class HomeViewTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_index_app_head_team_view_services_saldo
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    assert_match(/class="app-head row-between"/, last_response.body)
    assert_includes last_response.body, 'id="team-view"'
    assert_match(/class="services-row"/, last_response.body)
    assert_includes last_response.body, "Saldo"
  end
end
