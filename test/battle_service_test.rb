# frozen_string_literal: true

require "tmpdir"
require_relative "test_helper"
require_relative "test_support"
require_relative "../lib/battle_registry"
require_relative "../lib/battle_repository"
require_relative "../lib/battle_service"
require_relative "../lib/inventory_repository"
require_relative "../lib/pokemon_rating_cache"
require_relative "../lib/progression_repository"
require_relative "../lib/team_repository"
require_relative "../lib/wallet_repository"

class SlowCountingApi
  attr_reader :max_active, :detail_calls

  def initialize(names)
    @names = names
    @by_number = names.to_h { |name, number| [number, name] }
    @detail_calls = 0
    @active = 0
    @max_active = 0
    @mutex = Mutex.new
  end

  def detail(poke_id)
    @mutex.synchronize { @detail_calls += 1 }
    tracked do
      sleep 0.03
      pokemon(poke_id)
    end
  end

  def fetch_all_names
    @names.keys
  end

  def move(_name)
    Move.new(name: "tackle", type: "normal", power: 40, accuracy: 100, pp: 35)
  end

  def moves_for(_poke_id)
    tracked do
      sleep 0.03
      [move("tackle")]
    end
  end

  def type_relations
    { "normal" => { "double" => [], "half" => %w[rock steel], "no" => %w[ghost] } }
  end

  def next_evolutions(_number)
    []
  end

  def learnable_moves(_number)
    [{ level: 1, name: "tackle" }]
  end

  private

  def pokemon(poke_id)
    id = poke_id.to_i
    Pokemon.new(
      name: @by_number.fetch(id, "monster"), sprite: "s", number: id,
      types: ["normal"],
      stats: [{ name: "HP", value: 60 }, { name: "Attack", value: 10 },
              { name: "Defense", value: 10 }, { name: "Speed", value: 10 }]
    )
  end

  def tracked
    @mutex.synchronize do
      @active += 1
      @max_active = @active if @active > @max_active
    end
    yield
  ensure
    @mutex.synchronize { @active -= 1 }
  end
end

class TieredApi
  BASE = { s: 120, a: 100, c: 70, f: 40 }.freeze
  POOL = {
    "mewtwo" => :s, "mew" => :s, "rayquaza" => :s, "lugia" => :s,
    "groudon" => :s, "kyogre" => :s, "pikachu" => :f, "magikarp" => :f,
    "rattata" => :f, "caterpie" => :f
  }.freeze
  STRONG = %w[mewtwo mew rayquaza lugia groudon kyogre].freeze
  WEAK = %w[pikachu magikarp rattata caterpie].freeze
  PLAYER_NUMBERS = { 25 => "pikachu", 1 => "bulbasaur", 7 => "squirtle",
                     4 => "charmander", 133 => "eevee", 143 => "snorlax" }.freeze

  def fetch_all_names
    POOL.keys
  end

  def detail(poke_id)
    name = POOL.key?(poke_id.to_s) ? poke_id.to_s : PLAYER_NUMBERS.fetch(poke_id.to_i, "monster")
    value = BASE.fetch(POOL.fetch(name, :f))
    Pokemon.new(
      name: name, sprite: "s", number: poke_id.to_i, types: ["normal"],
      stats: %w[HP Attack Defense Sp.Atk Sp.Def Speed].map { |s| { name: s, value: value } }
    )
  end

  def move(_name)
    Move.new(name: "tackle", type: "normal", power: 40, accuracy: 100, pp: 35)
  end

  def moves_for(_number)
    []
  end

  def type_relations
    { "normal" => { "double" => [], "half" => %w[rock steel], "no" => %w[ghost] } }
  end

  def next_evolutions(_number)
    []
  end

  def learnable_moves(_number)
    []
  end
end

class BattleServiceTest < Minitest::Test
  include TestSupport

  def setup
    TestDatabase.setup!
    TestDatabase.clear_team!
    @team = TeamRepository.new
    @progression = ProgressionRepository.new
    @cache_dir = Dir.mktmpdir("pokedex-ratings")
  end

  def build_service(api, opponent_rng: nil, rating_cache: nil)
    deps = {
      api: -> { api },
      battles: BattleRegistry.new,
      team: @team,
      progression: @progression,
      battle_history: BattleRepository.new,
      wallet: WalletRepository.new,
      inventory: InventoryRepository.new,
      rating_cache: rating_cache || PokemonRatingCache.new(
        path: File.join(@cache_dir, "ratings.json"),
        fetcher: api.method(:detail),
        moves_fetcher: api.method(:moves_for)
      )
    }
    deps[:opponent_rng] = opponent_rng if opponent_rng
    BattleService.new(dependencies: deps)
  end

  def add_team_for(user_id)
    %w[pikachu bulbasaur squirtle charmander eevee snorlax].each_with_index do |name, index|
      @team.add(user_id, build_pokemon_record(name, 25 + index))
    end
  end

  def counting_api
    SlowCountingApi.new(
      "pikachu" => 25, "bulbasaur" => 1, "squirtle" => 7, "charmander" => 4,
      "eevee" => 133, "snorlax" => 143
    )
  end

  def test_prepare_fetches_player_and_opponent_details_in_parallel
    api = counting_api
    service = build_service(api)
    add_team_for("user-1")

    result = service.prepare("user-1")

    assert_equal :ok, result[:reason]
    assert_equal 6, result[:engine].teams[0].size
    assert_equal 6, result[:engine].teams[1].size
    assert_operator api.max_active, :>, 1, "fetches de detail/moves deveriam ser paralelos"
  end

  def test_prepare_keeps_same_opponent_when_battle_not_started
    seed = 0
    service = build_service(TieredApi.new, opponent_rng: -> { Random.new(seed += 1) })
    add_team_for("user-1")

    first = service.prepare("user-1")[:engine]
    second = service.prepare("user-1")[:engine]

    assert_equal first.teams[1].map(&:name), second.teams[1].map(&:name),
                 "batalha nao iniciada mantem o mesmo oponente ao revisitar"
  end

  def test_prepare_generates_new_opponent_after_new_confront
    seed = 0
    service = build_service(TieredApi.new, opponent_rng: -> { Random.new(seed += 1) })
    add_team_for("user-1")

    first = service.prepare("user-1")[:engine]
    second = service.new_confront("user-1")[:engine]

    refute_equal first.teams[1].map(&:name), second.teams[1].map(&:name),
                 "novo confronto gera oponente novo"
  end

  def test_prepare_refreshes_player_hp_while_keeping_opponent
    seed = 0
    service = build_service(TieredApi.new, opponent_rng: -> { Random.new(seed += 1) })
    add_team_for("user-1")

    first = service.prepare("user-1")[:engine]
    member_id = @team.all("user-1").first.id
    @progression.update_hp("user-1", member_id, 200, 50)
    second = service.prepare("user-1")[:engine]

    assert_equal first.teams[1].map(&:name), second.teams[1].map(&:name),
                 "oponente preservado na batalha nao iniciada"
    assert_equal 50, second.teams[0].first.hp_current,
                 "time do jogador re-derivado do estado persistido (HP curado)"
  end

  def test_prepare_preserves_in_progress_battle
    seed = 0
    service = build_service(TieredApi.new, opponent_rng: -> { Random.new(seed += 1) })
    add_team_for("user-1")

    first = service.prepare("user-1")[:engine]
    service.advance("user-1")
    second = service.prepare("user-1")[:engine]

    assert_same first, second, "batalha em andamento preservada (mesma instancia)"
    assert second.rounds.positive?, "rodadas jogadas preservadas"
  end

  def test_prepare_returns_finished_battle_as_is
    seed = 0
    service = build_service(TieredApi.new, opponent_rng: -> { Random.new(seed += 1) })
    add_team_for("user-1")

    first = service.prepare("user-1")[:engine]
    20.times { service.advance("user-1") }
    second = service.prepare("user-1")[:engine]

    assert_same first, second, "batalha finalizada mantem o resultado (nao prepara nova)"
    assert second.finished?
  end

  def test_invalidate_clears_active_battle
    seed = 0
    service = build_service(TieredApi.new, opponent_rng: -> { Random.new(seed += 1) })
    add_team_for("user-1")

    first = service.prepare("user-1")[:engine]
    service.invalidate("user-1")
    second = service.prepare("user-1")[:engine]

    refute_same first, second, "batalha ativa limpa pela invalidacao"
  end

  def grant_xp_to(user_id, amount)
    @team.all(user_id).each { |member| @progression.grant(user_id, member.id, amount) }
  end

  def test_build_opponent_uses_high_band_for_high_level_player
    service = build_service(TieredApi.new)
    add_team_for("user-1")
    grant_xp_to("user-1", 12_000)

    result = service.prepare("user-1")

    opponent_names = result[:engine].teams[1].map(&:name)
    assert_equal TieredApi::STRONG.sort, opponent_names.sort,
                 "nivel alto (banda A-S) so gera oponentes fortes"
  end

  def test_build_opponent_prioritizes_weak_band_for_low_level_player
    service = build_service(TieredApi.new)
    add_team_for("user-1")

    result = service.prepare("user-1")

    opponent_names = result[:engine].teams[1].map(&:name)
    assert_equal 6, opponent_names.size
    assert_equal TieredApi::WEAK.sort, (TieredApi::WEAK & opponent_names).sort,
                 "nivel 1 (banda F-D) prioriza oponentes fracos"
    assert_equal 2, (TieredApi::STRONG & opponent_names).size,
                 "fallback completa o time com o restante do pool"
  end

  def test_build_opponent_rates_pool_names_through_rating_cache
    rating_cache = Class.new do
      attr_reader :queried

      def initialize(api)
        @api = api
        @queried = []
      end

      def rating_for(name)
        @queried << name
        TieredApi::STRONG.include?(name) ? :S : :F
      end
    end.new(TieredApi.new)
    service = build_service(TieredApi.new, rating_cache: rating_cache)
    add_team_for("user-1")
    grant_xp_to("user-1", 12_000)

    result = service.prepare("user-1")

    refute_empty rating_cache.queried, "varredura da banda passa pelo rating cache"
    assert_equal TieredApi::STRONG.sort, result[:engine].teams[1].map(&:name).sort,
                 "banda A-S preservada via ratings provider"
  end
end
