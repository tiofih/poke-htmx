# frozen_string_literal: true

require_relative "server_test_helpers"
require "tmpdir"
require "fileutils"

class RatingDetailHotfixTest < Minitest::Test
  include ServerTestHelpers

  def setup
    super
    @orig_rating = Server.settings.rating_source
    @orig_path = ENV.fetch("POKERATING_CACHE_PATH", "tmp/test_pokemon_rating_cache.json")
  end

  def teardown
    Server.set :rating_source, @orig_rating
    super
  end

  def all_stats(value)
    { "HP" => value, "Attack" => value, "Defense" => value,
      "Sp.Atk" => value, "Sp.Def" => value, "Speed" => value }
  end

  def build_detail(name, number, stats_value, types: ["psychic"])
    stats = all_stats(stats_value).map { |k, v| { name: k, value: v } }
    Pokemon.new(name: name, sprite: "https://example.com/#{name}.png", number: number,
                types: types, stats: stats, evolutions: [])
  end

  def test_rating_for_uses_detail_not_find
    # find minimal (como PokeApiHttp#find) sem stats/types/moves -> score 0 -> tier F
    find_minimal = Pokemon.new(name: "mewtwo", sprite: "https://example.com/mewtwo.png", number: 150)
    detail_rich = build_detail("mewtwo", 150, 120) # weighted 120*5.5=660 -> S
    detail_weak = build_detail("pidgey", 16, 30) # weighted 30*5.5=165 -> F

    find_map = { "mewtwo" => find_minimal, "pidgey" => Pokemon.new(name: "pidgey", sprite: "s", number: 16) }
    detail_map = { "mewtwo" => detail_rich, "pidgey" => detail_weak }

    # Isola cache em dir temporário para não depender de stale
    Dir.mktmpdir do |dir|
      path = File.join(dir, "ratings.json")
      # Cache que usa find (bug) deve dar F para mewtwo
      cache_find = PokemonRatingCache.new(
        path: File.join(dir, "find.json"),
        fetcher: ->(name) { find_map[name] },
        moves_fetcher: ->(_number) { [] }
      )
      assert_equal :F, cache_find.rating_for("mewtwo"), "find minimal sem stats dá F (bug latente)"

      # Cache que usa detail (fix) deve dar S para mewtwo
      cache_detail = PokemonRatingCache.new(
        path: path,
        fetcher: ->(name) { detail_map[name] || find_map[name] },
        moves_fetcher: ->(_number) { [] }
      )
      assert_equal :S, cache_detail.rating_for("mewtwo"), "detail com stats altos dá S (fix)"
      assert_equal :F, cache_detail.rating_for("pidgey"), "pidgey fraco permanece F"
    end
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize, Metrics/BlockLength
  def test_tier_filter_uses_detail_rating_not_find
    # Integração: GET /pokemons tier=S deve retornar mewtwo quando rating usa detail,
    # mas retornaria vazio se rating usasse find (todos F).
    find_minimal = Pokemon.new(name: "mewtwo", sprite: "https://example.com/mewtwo.png", number: 150)
    pidgey_minimal = Pokemon.new(name: "pidgey", sprite: "s", number: 16)
    mewtwo_detail = build_detail("mewtwo", 150, 120)
    pidgey_detail = build_detail("pidgey", 16, 30)

    find_map = { "mewtwo" => find_minimal, "pidgey" => pidgey_minimal }
    detail_map = { "mewtwo" => mewtwo_detail, "pidgey" => pidgey_detail }
    names = %w[mewtwo pidgey]
    forms = { "mewtwo" => true, "pidgey" => true }

    Dir.mktmpdir do |dir|
      path = File.join(dir, "ratings.json")
      # Cria rating_source que usa detail (fix) - este é o comportamento esperado após hotfix
      fresh_rating = PokemonRatingCache.new(
        path: path,
        fetcher: ->(name) { detail_map[name] || find_map[name] },
        moves_fetcher: ->(_number) { [] }
      )
      original = Server.settings.rating_source
      Server.set :rating_source, fresh_rating

      PokeApiStub.with_all_names(names) do
        PokeApiStub.with_find(find_map) do
          PokeApiStub.with_detail(detail_map) do
            PokeApiStub.with_base_forms(forms) do
              PokeApiStub.with_pokemon_names_by_type({}) do
                get "/pokemons", tier: "S"
                assert last_response.ok?, "GET /pokemons tier=S deve ser ok"
                assert_includes last_response.body, 'value="mewtwo"',
                                "tier=S deve conter mewtwo (S) quando rating usa detail"
                refute_includes last_response.body, 'value="pidgey"', "tier=S não deve conter pidgey (F)"

                get "/pokemons", tier: "F"
                assert_includes last_response.body, 'value="pidgey"', "tier=F deve conter pidgey"
                refute_includes last_response.body, 'value="mewtwo"', "tier=F não deve conter mewtwo"

                # Também testa sort por tier e custo (antes todos F ficava random)
                get "/pokemons", sort: "tier_desc"
                body = last_response.body
                assert body.index('value="mewtwo"') < body.index('value="pidgey"'),
                       "tier_desc deve ordenar S antes de F"

                get "/pokemons", sort: "cost_desc"
                body = last_response.body
                assert body.index('value="mewtwo"') < body.index('value="pidgey"'), "cost_desc S(120) antes de F(20)"
              end
            end
          end
        end
      end
    ensure
      Server.set :rating_source, original if defined?(original) && original
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize, Metrics/BlockLength

  def test_server_default_rating_uses_detail_hotfix
    # Prova que o fetcher padrão do Server usa detail (não só find).
    # Antes do hotfix 4d, Server.settings.rating_source usava find minimal -> mewtwo = F.
    # Após hotfix, deve usar detail || find -> mewtwo = S.
    find_minimal = Pokemon.new(name: "mewtwo", sprite: "https://example.com/mewtwo.png", number: 150)
    detail_rich = build_detail("mewtwo", 150, 120)

    find_map = { "mewtwo" => find_minimal }
    detail_map = { "mewtwo" => detail_rich }

    # Limpa cache de teste para forçar recomputação (evita stale F)
    test_cache_path = ENV.fetch("POKERATING_CACHE_PATH", "tmp/test_pokemon_rating_cache.json")
    FileUtils.rm_f(test_cache_path)
    # Limpa entradas em memória do cache atual
    if Server.settings.rating_source.instance_variable_defined?(:@entries)
      Server.settings.rating_source.instance_variable_set(:@entries,
                                                          {})
    end

    PokeApiStub.with_find(find_map) do
      PokeApiStub.with_detail(detail_map) do
        tier = Server.settings.rating_source.rating_for("mewtwo")
        assert_equal :S, tier,
                     "hotfix 4d: Server rating_source deve usar detail (stats) e retornar S, não F via find minimal"
      end
    end
  end
end
