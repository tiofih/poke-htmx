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
    assert_match(/<div id="filter-controls">/, body,
                 "expected the filter card to keep the #filter-controls hook")
    assert_match(%r{<div class="field">\s*<label for="fsearch">Buscar no arquivo</label>}m, body,
                 "expected the search textfield on its own full row above the grid")
    assert_match(/<div class="filter-grid">.*?<select/m, body,
                 "expected filter dropdowns on the row(s) below the search")
    assert body.index('id="fsearch"') < body.index('class="filter-grid"'),
           "expected search to come before the filter grid"
    assert_match(/<span class="meta">Arquivo/, body,
                 "expected the Arquivo/clear row from the guide")
    assert_match(%r{class="btn btn-ghost btn-sm"[^>]*>Limpar filtros</a>}, body,
                 "expected Limpar filtros dressed as a ghost small button")
    assert_includes body, "team=",
                    "expected Limpar filtros to reset the team filter"
  end

  # 0083 C2: filtros com labels visiveis + contagem de resultados; em 360px a
  # grade colapsa para 1 coluna (sem scroll-x) e cada select vive num .field.
  def test_filter_labels_count_no_overflow
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    body = last_response.body
    {
      "type" => "Tipo", "generation" => "Geração", "tier" => "Tier",
      "cost_max" => "Custo máx", "sort" => "Ordenação", "team" => "Disponibilidade"
    }.each do |name, label|
      assert_match(%r{<label for="filter-#{name}">#{label}</label>}, body,
                   "filtro #{name} precisa de label visivel (C2)")
    end
    assert_match(%r{<span class="filter-count[^"]*"[^>]*>Resultados · \d+</span>}, body,
                 "contagem de resultados visivel nos filtros (C2)")

    style = File.read(File.join(__dir__, "../public/style.css"))
    block = style[/UI polish \(0083\): inicio.*?UI polish \(0083\): fim/m]
    refute_nil block, "expected a delimited 0083 UI polish block in style.css"
    assert_match(/\.filter-grid\s*\.field[^}]*margin-bottom:\s*0/m, block,
                 "cada select dentro de um .field, sem empilhar margem (C2)")
    assert_match(/@media\s*\(max-width:\s*360px\)[\s\S]*?\.filter-grid[^}]*grid-template-columns:\s*1fr;/m, block,
                 "360px: grade de filtros em 1 coluna, sem overflow horizontal (C2)")
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

  def test_catalog_cards_wear_pcard_name_and_meta
    names = %w[charmander squirtle]
    find_map = {
      "charmander" => Pokemon.new(name: "charmander", sprite: "s", number: 4, types: %w[fire]),
      "squirtle" => Pokemon.new(name: "squirtle", sprite: "s", number: 7, types: %w[water])
    }
    forms = names.to_h { |name| [name, true] }
    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_find(find_map) do
        PokeApiStub.with_base_forms(forms) do
          get "/pokemons"
        end
      end
    end

    assert last_response.ok?
    assert_match(%r{<div class="pcard-name">charmander</div>}, last_response.body,
                 "expected catalog cards to name members in .pcard-name")
    assert_match(/class="pcard-meta"/, last_response.body,
                 "expected catalog cards to wrap cost in .pcard-meta")
  end

  def test_roster_members_show_level_and_manage
    fill_team("user-a")
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end

    assert last_response.ok?
    body = last_response.body
    assert_match(/class="roster[^"]*"/, body, "expected the team roster")
    assert_match(/Nível \d+/, body, "expected each member to show Nível")
    assert_match(%r{hx-get="/team/manage"[^>]*hx-target="body"}, body,
                 "expected a Gerenciar link opening the manage modal")
    assert_includes body, 'name="new_slot"', "expected reorder forms preserved"
  end

  def test_catalog_cards_mirror_prototype_sprite_panel
    names = %w[charmander]
    find_map = {
      "charmander" => Pokemon.new(name: "charmander", sprite: "s", number: 4, types: %w[fire])
    }
    forms = names.to_h { |name| [name, true] }
    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_find(find_map) do
        PokeApiStub.with_base_forms(forms) do
          get "/pokemons"
        end
      end
    end

    assert last_response.ok?
    body = last_response.body
    assert_match(%r{<div class="sprite-tile">.*?</div>}m, body,
                 "expected a sprite-tile panel per card (prototype)")
    assert_match(%r{hx-get="/pokemon/4"[^>]*hx-target="#pokemon-detail"}, body,
                 "expected the detail link preserved in the panel")
    assert_includes body, 'hx-post="/team"',
                    "expected the POST /team contract preserved"
  end

  def test_pokemon_detail_wears_tag_row_stat_grid_evo_row
    chain = {
      charmander: build_pokemon_record("charmander", 4),
      charmeleon: build_pokemon_record("charmeleon", 5)
    }
    charizard = Pokemon.new(
      name: "charizard",
      sprite: chain[:charmander].sprite,
      number: 6,
      types: %w[fire flying],
      stats: [{ name: "HP", value: 78 }, { name: "Speed", value: 100 }],
      evolutions: [chain[:charmander], chain[:charmeleon]]
    )
    PokeApiStub.with_detail(charizard) do
      get "/pokemon/6"
    end

    assert last_response.ok?
    body = last_response.body
    assert_match(/class="tag-row"/, body, "expected detail types in .tag-row")
    assert_match(/class="stat-grid"/, body, "expected detail stats in .stat-grid")
    assert_match(/class="evo-row"/, body, "expected detail evolutions in .evo-row")
    assert_match(%r{hx-get="/pokemon/4"[^>]*hx-target="#pokemon-detail"}, body,
                 "expected evolution links to keep htmx targets")
    assert_includes body, %(hx-post="/team")
    refute_includes body, "onclick"
  end
end
