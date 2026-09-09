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

  def test_filter_controls_wear_design_system
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    body = last_response.body
    assert_match(/<div id="filter-controls" class="filter-grid">/, body,
                 "expected filter card to dress controls in .filter-grid")
    assert_match(/<span class="meta">Arquivo/, body,
                 "expected the Arquivo/clear row from the guide")
    assert_match(%r{class="btn btn-ghost btn-sm"[^>]*>Limpar filtros</a>}, body,
                 "expected Limpar filtros dressed as a ghost small button")
    assert_includes body, "team=",
                    "expected Limpar filtros to reset the team filter"
  end

  def test_home_app_head_lead_meter_catalog
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      PokeApiStub.with_find(build_pokemon_record("pokemon1", 1)) do
        get "/"
      end
    end

    assert last_response.ok?
    body = last_response.body
    assert_match(%r{<p class="lead">Seis vagas.*orçamento.*</p>}m, body,
                 "expected the app head to lead with the journey pitch")
    assert_match(/<div class="meter" role="progressbar" aria-label="Orçamento do time">/, body,
                 "expected an accessible budget meter")
    assert_match(%r{<span class="meta">Arquivo · \d+</span>}, body,
                 "expected the Arquivo row to count the catalog")
    assert_match(/<li class="pcard">/, body, "expected catalog cards")
    assert_match(/<img[^>]*alt=/, body, "expected card sprites")
  end
end
