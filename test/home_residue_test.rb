# frozen_string_literal: true

require_relative "server_test_helpers"

# Residuo home 0077 (home-team.html 1:1, fidelidade hibrida): miolo dos modais
# (C1), manage + evolucao (C2) e catalogo + detalhe (C3). Sem rede (stub PokeApi).
class HomeResidueTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  HOME_USER = "user-home-77"

  def setup
    super
    fill_team(HOME_USER)
    @wallet.grant(HOME_USER, 100)
  end

  def test_center_mart_inner
    pikachu_id = TestDatabase.team_id("pikachu", HOME_USER)
    @progression.update_hp(HOME_USER, pikachu_id, 35, 20)

    get "/team/center", {}, user_session(HOME_USER)

    assert last_response.ok?
    center = last_response.body
    assert_includes center, 'id="center-modal"'
    assert_match(/class="heal-list"/, center)
    assert_match(/class="heal-item"/, center)
    assert_includes center, "pikachu"
    assert_includes center, "20/35"
    assert_includes center, "Custo total:"
    assert_includes center, %(hx-post="/team/heal")
    refute_includes center, "onclick"

    @inventory.add(HOME_USER, "potion", 2)

    get "/team/mart", {}, user_session(HOME_USER)

    assert last_response.ok?
    mart = last_response.body
    assert_includes mart, 'id="mart-modal"'
    assert_match(/class="tabs"/, mart)
    assert_match(/class="mart"/, mart)
    assert_match(/class="mart-name"/, mart)
    assert_match(/class="item-icon"/, mart)
    assert_match(/class="[^"]*\bprice\b[^"]*"/, mart)
    assert_includes mart, "Pocao — 20 ×5"
    assert_includes mart, %(hx-post="/mart/buy")
    assert_includes mart, %(hx-post="/mart/sell")
    assert_includes mart, "Saldo: 100"
    refute_includes mart, "onclick"
  end

  def test_manage_evolution
    pikachu_id = TestDatabase.team_id("pikachu", HOME_USER)
    @repository.set_moves(HOME_USER, pikachu_id.to_i, ["growl"])
    @inventory.add(HOME_USER, "thunder-stone", 2)
    find_map = {
      "pikachu" => Pokemon.new(name: "pikachu", sprite: "s", number: 25, types: %w[electric])
    }

    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "growl" }, { level: 1, name: "quick-attack" }]
    ) do
      PokeApiStub.with_find(find_map) do
        get "/team/manage", {}, user_session(HOME_USER)
      end
    end

    assert last_response.ok?
    manage = last_response.body
    assert_includes manage, 'id="manage-modal"'
    assert_match(/class="stat-grid"/, manage)
    assert_match(/class="mv-row marked"/, manage)
    refute_match(/class="evo-row"/, manage)
    assert_match(/class="equip-row"/, manage)
    assert_match(/class="tag-row"/, manage)
    assert_includes manage, "Nível 5"
    assert_includes manage, "Voltar"
    refute_includes manage, "onclick"

    PokeApiStub.with_stone_evolutions([
                                        { number: 26, name: "raichu", item: "thunder-stone" },
                                        { number: 134, name: "vaporeon", item: "water-stone" }
                                      ]) do
      get "/team/#{pikachu_id}/evolution", {}, user_session(HOME_USER)
    end

    assert last_response.ok?
    modal = last_response.body
    assert_includes modal, 'id="evolution-modal"'
    assert_match(/class="[^"]*\bmodal\b/, modal)
    assert_match(/class="evo-row"/, modal)
    assert_includes modal, "raichu"
    assert_includes modal, "Inventário: 2"
    assert_includes modal, %(hx-post="/team/#{pikachu_id}/evolve")
    refute_includes modal, "evolution-modal-box"
    refute_includes modal, "onclick"
  end

  def test_catalog_cards
    names = %w[charmander squirtle]
    find_map = {
      "charmander" => Pokemon.new(name: "charmander", sprite: "s", number: 4, types: %w[fire]),
      "squirtle" => Pokemon.new(name: "squirtle", sprite: "s", number: 7, types: %w[water])
    }
    forms = names.to_h { |name| [name, true] }
    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_find(find_map) do
        PokeApiStub.with_base_forms(forms) do
          get "/pokemons", {}, user_session(HOME_USER)
        end
      end
    end

    assert last_response.ok?
    catalog = last_response.body
    assert_match(/<li class="pcard">/, catalog)
    assert_match(/class="pcard-name"/, catalog)
    assert_match(/class="pcard-meta"/, catalog)
    assert_match(%r{hx-get="/pokemon/4"[^>]*hx-target="#pokemon-detail"}, catalog)
    refute_includes catalog, "onclick"
  end

  def test_catalog_detail
    chain = {
      charmander: build_pokemon_record("charmander", 4),
      charmeleon: build_pokemon_record("charmeleon", 5)
    }
    charizard = Pokemon.new(
      name: "charizard",
      sprite: chain[:charmander].sprite,
      number: 6,
      types: %w[fire flying],
      stats: [
        { name: "HP", value: 78 },
        { name: "Attack", value: 84 },
        { name: "Defense", value: 78 },
        { name: "Speed", value: 100 }
      ],
      evolutions: [chain[:charmander], chain[:charmeleon]]
    )
    PokeApiStub.with_detail(charizard) do
      get "/pokemon/6", {}, user_session(HOME_USER)
    end

    assert last_response.ok?
    detail = last_response.body
    assert_match(/class="tag-row"/, detail)
    assert_match(/class="stat-grid"/, detail)
    assert_match(/class="evo-row"/, detail)
    assert_includes detail, "fire"
    assert_includes detail, "78"
    assert_includes detail, "charmander"
    assert_match(%r{hx-get="/pokemon/4"[^>]*hx-target="#pokemon-detail"}, detail)
    assert_includes detail, %(hx-post="/team")
    assert_includes detail, %(hx-get="/pokemon/close")
    refute_includes detail, "onclick"
  end
end
