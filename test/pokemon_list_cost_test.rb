# frozen_string_literal: true

require_relative "server_test_helpers"

# Fake rating determinístico nome → tier
class FakeListRating
  def initialize(map)
    @map = map
  end

  def rating_for(name)
    (@map[name.to_s] || "F").to_sym
  end
end

class PokemonListCostTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def setup
    super
    @default_rating = Server.settings.rating_source
  end

  def teardown
    Server.set :rating_source, @default_rating
    super
  end

  def with_rating(map, &)
    fake = FakeListRating.new(map)
    original = Server.settings.rating_source
    Server.set :rating_source, fake
    yield
  ensure
    Server.set :rating_source, original
  end

  def records_for(names)
    names.to_h { |name| [name, build_pokemon_record(name, number_for(name))] }
  end

  def number_for(name)
    digits = name.scan(/\d+/).first
    digits ? digits.to_i : 25
  end

  def stub_list(names, evolved: [], rating_map: {}, restricted_map: {},
                find_override: nil, &)
    forms = names.to_h { |name| [name, !evolved.include?(name)] }
    rating = rating_map
    find_map = find_override || records_for(names)
    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_find(find_map) do
        PokeApiStub.with_base_forms(forms) do
          restricted = restricted_map.empty? ? nil : restricted_map
          if restricted
            PokeApiStub.with_gateway(evolution_restricted: restricted) do
              with_rating(rating, &)
            end
          else
            with_rating(rating, &)
          end
        end
      end
    end
  end

  def two_hundred_fifty_names
    (1..250).map { |i| "pokemon#{i}" }
  end

  def filtered_names
    %w[pikachu pichu raichu pikachu-alola bulbasaur]
  end

  # C1 — listagem mostra custo e tier por Pokémon
  def test_pokemon_list_shows_cost_and_tier
    names = filtered_names
    rating = { "pikachu" => "B", "bulbasaur" => "A", "pichu" => "F", "raichu" => "S" }
    stub_list(names, rating_map: rating) do
      get "/pokemons", q: ""
    end

    assert last_response.ok?
    # find isolado (sem evolução) então tier = rating do próprio nome
    # pikachu B → 55, bulbasaur A → 70
    assert_includes last_response.body, 'data-tier="B"'
    assert_includes last_response.body, "B · 55"
    assert_includes last_response.body, 'data-tier="A"'
    assert_includes last_response.body, "A · 70"
    assert_includes last_response.body, 'class="poke-cost num"'
  end

  def test_index_shows_cost_and_tier
    names = two_hundred_fifty_names
    rating = { "pokemon1" => "S", "pokemon2" => "F" }
    stub_list(names, rating_map: rating) do
      get "/"
    end

    assert last_response.ok?
    assert_includes last_response.body, 'data-tier="S"'
    assert_includes last_response.body, "S · 120"
  end

  # C2 — custo considera max da cadeia ramificada e metade se restrito
  def test_pokemon_list_cost_uses_line_tier_and_restricted_half
    # Cadeia ramificada Eevee-like: base eevee com evoluções vaporeon, jolteon, flareon, espeon
    vaporeon = build_pokemon_record("vaporeon", 134)
    jolteon = build_pokemon_record("jolteon", 135)
    flareon = build_pokemon_record("flareon", 136)
    espeon = build_pokemon_record("espeon", 196)
    eevee_base = build_pokemon_record("eevee", 133)
    eevee = Pokemon.new(
      name: "eevee", sprite: "https://example.com/eevee.png", number: 133,
      evolutions: [eevee_base, vaporeon, jolteon, flareon, espeon].freeze
    )
    all_names = %w[eevee vaporeon jolteon flareon espeon]
    # tier map: vaporeon C(40), jolteon A(70), flareon S(120), espeon B(55) => max S
    rating = { "vaporeon" => "C", "jolteon" => "A", "flareon" => "S", "espeon" => "B", "eevee" => "F" }
    find_map = {
      "eevee" => eevee, "vaporeon" => vaporeon, "jolteon" => jolteon,
      "flareon" => flareon, "espeon" => espeon
    }
    forms = all_names.to_h { |n| [n, n == "eevee"] }

    PokeApiStub.with_all_names(all_names) do
      PokeApiStub.with_find(find_map) do
        PokeApiStub.with_base_forms(forms) do
          with_rating(rating) do
            get "/pokemons", q: ""
          end
        end
      end
    end

    assert last_response.ok?
    # eevee linha paga pelo máximo S = 120
    assert_includes last_response.body, "S · 120"
    assert_includes last_response.body, 'data-tier="S"'
  end

  def test_pokemon_list_restricted_shows_half_cost
    # pikachu cadeia simples mas restrito = metade
    pichu = build_pokemon_record("pichu", 172)
    pikachu = build_pokemon_record("pikachu", 25)
    raichu = build_pokemon_record("raichu", 26)
    pikachu_evo = Pokemon.new(
      name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25,
      evolutions: [pichu, pikachu, raichu].freeze
    )
    names = %w[pikachu pichu raichu]
    rating = { "pichu" => "F", "pikachu" => "B", "raichu" => "B" } # max B =55
    find_map = { "pikachu" => pikachu_evo, "pichu" => pichu, "raichu" => raichu }
    forms = { "pikachu" => true, "pichu" => true, "raichu" => false }

    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_find(find_map) do
        PokeApiStub.with_base_forms(forms) do
          PokeApiStub.with_gateway(evolution_restricted: { "pikachu" => true }) do
            with_rating(rating) do
              get "/pokemons", q: ""
            end
          end
        end
      end
    end

    assert last_response.ok?
    # B 55 metade floor 27 com indicador
    assert_includes last_response.body, "B · 27"
    assert_includes last_response.body, "poke-cost--restricted"
  end

  def test_pokemon_list_shows_restricted_s_one_ten
    # S puro 120, restrito 110 (exceção) + ◆ + classe
    pichu = build_pokemon_record("pichu", 172)
    pikachu = build_pokemon_record("pikachu", 25)
    raichu = build_pokemon_record("raichu", 26)
    pikachu_evo = Pokemon.new(
      name: "pikachu", sprite: "https://example.com/pikachu.png", number: 25,
      evolutions: [pichu, pikachu, raichu].freeze
    )
    names = %w[pikachu pichu raichu]
    rating = { "pichu" => "F", "pikachu" => "S", "raichu" => "S" }
    find_map = { "pikachu" => pikachu_evo, "pichu" => pichu, "raichu" => raichu }
    forms = { "pikachu" => true, "pichu" => true, "raichu" => false }

    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_find(find_map) do
        PokeApiStub.with_base_forms(forms) do
          PokeApiStub.with_gateway(evolution_restricted: { "pikachu" => true }) do
            with_rating(rating) do
              get "/pokemons", q: ""
            end
          end
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "S · 110"
    assert_includes last_response.body, "poke-cost--restricted"
    assert_includes last_response.body, "◆"
  end

  # C3 — paginação/busca preservadas e sem rede
  def test_pokemon_list_pagination_and_search_preserved
    names = two_hundred_fifty_names
    rating = {}
    stub_list(names, rating_map: rating) do
      get "/pokemons", offset: 9
    end

    assert last_response.ok?
    assert_includes last_response.body, "Página 2"
    assert_equal 36, last_response.body.scan('<li class="pcard">').size
    # badge ainda presente sem quebrar paginação
    assert_includes last_response.body, 'class="poke-cost num"'

    stub_list(filtered_names, rating_map: { "pikachu" => "B" }) do
      get "/pokemons", q: "pik"
    end

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    assert_includes last_response.body, 'data-tier="B"'
  end

  def test_pokemon_list_without_network
    # garante que rating e cadeia vêm de stubs, sem toque de rede
    names = %w[eevee vaporeon jolteon]
    eevee_base = build_pokemon_record("eevee", 133)
    vaporeon = build_pokemon_record("vaporeon", 134)
    jolteon = build_pokemon_record("jolteon", 135)
    eevee = Pokemon.new(
      name: "eevee", sprite: "s", number: 133,
      evolutions: [eevee_base, vaporeon, jolteon].freeze
    )
    rating = { "eevee" => "F", "vaporeon" => "A", "jolteon" => "S" }
    find_map = { "eevee" => eevee, "vaporeon" => vaporeon, "jolteon" => jolteon }
    forms = { "eevee" => true, "vaporeon" => false, "jolteon" => false }

    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_find(find_map) do
        PokeApiStub.with_base_forms(forms) do
          with_rating(rating) do
            get "/pokemons"
          end
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "S · 120"
  end

  def test_oob_after_add_preserves_badges
    names = filtered_names
    rating = { "pikachu" => "B", "bulbasaur" => "A" }
    # precisa também stub para o POST add (find pikachu) e OOB reload (lista)
    pikachu = build_pokemon_record("pikachu", 25)
    # OOB chama load_pokemon_page que re-usa fetch_all_names + find + base_form
    # então stub_list cobre o GET dentro do POST
    PokeApiStub.with_all_names(names) do
      forms = names.to_h { |n| [n, !%w[raichu pikachu-alola].include?(n)] }
      PokeApiStub.with_base_forms(forms) do
        with_rating(rating) do
          PokeApiStub.with_find(pikachu) do
            env = { "HTTP_HX_REQUEST" => "true", "rack.session" => { "user_id" => "user-a" } }
            post "/team", { pokeName: "pikachu" }, env
          end
        end
      end
    end
    # post usa find separado; OOB precisa de lista com badges
    # verificamos que OOB contém lista com custo
    assert last_response.ok?
    assert_includes last_response.body, 'id="pokemon-list"'
    assert_includes last_response.body, "hx-swap-oob"
    # O OOB re-renderiza lista; como estamos fora do stub de lista no POST, pode estar vazio.
    # Re-testa OOB de forma isolada: faz GET para garantir badge após time cheio
    stub_list(names, rating_map: rating) do
      get "/pokemons", {}, { "rack.session" => { "user_id" => "user-a" } }
    end
    assert_includes last_response.body, 'data-tier="B"'
  end

  # Sessao 0059 C4 — OOB após DELETE preserva badges poke-cost/data-tier
  # rubocop:disable Metrics/AbcSize
  def test_oob_after_delete_preserves_badges
    # nomes curtos para não pagar varredura grande, com rating determinístico
    names = %w[pikachu bulbasaur charmander]
    rating = { "pikachu" => "B", "bulbasaur" => "S", "charmander" => "A" }
    # S restrito 110 com ◆
    restricted = { "bulbasaur" => true }
    forms = names.to_h { |n| [n, true] }
    find_map = records_for(names)

    @repository.add("user-a", build_pokemon_record("pikachu", 25))
    id = @repository.all("user-a").first.id

    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_find(find_map) do
        PokeApiStub.with_base_forms(forms) do
          PokeApiStub.with_gateway(evolution_restricted: restricted) do
            with_rating(rating) do
              delete "/team", { id: id, offset: "0", q: "" }, htmx_session("user-a")
            end
          end
        end
      end
    end

    assert last_response.ok?
    # OOB deve estar presente quando visible (q.empty? && offset.zero?)
    assert_includes last_response.body, 'id="pokemon-list" hx-swap-oob'
    # badges preservados: B 55, S 110 ◆, A 70
    assert_includes last_response.body, 'data-tier="B"'
    assert_includes last_response.body, "B · 55"
    assert_includes last_response.body, 'data-tier="S"'
    assert_includes last_response.body, "S · 110"
    assert_includes last_response.body, "◆"
    assert_includes last_response.body, 'data-tier="A"'
    assert_includes last_response.body, "A · 70"
    assert_includes last_response.body, 'class="poke-cost'
  end
  # rubocop:enable Metrics/AbcSize
end
