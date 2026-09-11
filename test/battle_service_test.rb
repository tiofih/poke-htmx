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
require_relative "../lib/team_budget"
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

class ItemDebitEngine
  attr_reader :rounds, :log

  def initialize
    @rounds = 0
    @log = []
  end

  def finished?
    @rounds >= 3
  end

  def play_round
    @rounds += 1
    @log << attack_entry
    @log << item_entry if [1, 3].include?(@rounds)
  end

  def result
    :win
  end

  def teams
    [[], []]
  end

  private

  def attack_entry
    { round: @rounds, attacker: 0, attacker_name: "pikachu",
      target_name: "oponente", move: "tackle", move_type: "normal", damage: 5 }
  end

  def item_entry
    { round: @rounds, attacker: 0, attacker_index: 0, action: :item, item: "potion",
      healed: 20, attacker_name: "pikachu" }
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

  def downgrade_all_to_one(user_id)
    @team.all(user_id).each do |member|
      TestDatabase.with_db do |connection|
        connection.exec_params(
          "UPDATE team_pokemon_progress SET level = 1, xp = 0 WHERE team_pokemon_id = $1",
          [member.id]
        )
      end
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

  def test_resolve_plays_until_finished
    service = build_service(TieredApi.new)
    add_team_for("user-1")

    engine = service.prepare("user-1")[:engine]
    result = service.resolve("user-1")

    assert result[:engine].finished?, "resolve joga todas as rodadas ate o fim"
    assert_operator result[:engine].rounds, :>, 0, "rodadas foram jogadas no servidor"
    assert_same engine, result[:engine], "mesma instancia de engine evoluida"
    refute_nil result[:xp_gained], "payload final carrega XP"
    refute_nil result[:money_gained], "payload final carrega dinheiro"
  end

  def test_resolve_stops_at_round_cap
    service = build_service(TieredApi.new)
    add_team_for("user-1")
    tank = build_pokemon(number: 1, name: "tank", hp: 2_000_000, attack: 1, defense: 200, speed: 1)
    engine = BattleEngine.new(team_a: [tank], team_b: [tank.new(number: 2, name: "tank-b")])
    service.instance_variable_get(:@battles).set("user-1", engine)

    result = service.resolve("user-1")

    assert_equal BattleService::ROUND_CAP, engine.rounds, "teto de rodadas forca a parada"
    refute result[:engine].finished?, "batalha eterna nao termina sozinha"
    assert_nil result[:xp_gained], "sem fim nao ha recompensa XP"
    assert_nil result[:money_gained], "sem fim nao ha recompensa em dinheiro"
  end

  def test_resolve_debits_items_from_all_rounds
    service = build_service(TieredApi.new)
    add_team_for("user-1")
    InventoryRepository.new.add("user-1", "potion", 5)
    service.instance_variable_get(:@battles).set("user-1", ItemDebitEngine.new)

    service.resolve("user-1")

    assert_equal 3, TestDatabase.inventory_quantity("user-1", "potion"),
                 "pocoes das rodadas 1 e 3 debitadas (nao so a ultima)"
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
    assert_equal 6, opponent_names.size
    # banda A-S tenta fortes, mas orcamento 450 limita a 3 S (3*120=360) + 3 F (60)=420
    assert_equal 3, (TieredApi::STRONG & opponent_names).size,
                 "nivel alto (banda A-S) prioriza fortes mas respeita orcamento 450"
    assert_equal 3, (TieredApi::WEAK & opponent_names).size
    total = opponent_names.sum do |name|
      tier = TieredApi::STRONG.include?(name) ? "S" : "F"
      TeamBudget.cost_for(line_tier: tier, restricted: false)
    end
    assert_operator total, :<=, TeamBudget::BUDGET
  end

  def test_build_opponent_prioritizes_weak_band_for_low_level_player
    service = build_service(TieredApi.new)
    add_team_for("user-1")
    downgrade_all_to_one("user-1")

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
    opponent_names = result[:engine].teams[1].map(&:name)
    assert_equal 6, opponent_names.size
    assert_equal 3, (TieredApi::STRONG & opponent_names).size,
                 "banda A-S preservada via ratings provider mas limitada pelo orcamento"
  end

  def test_build_opponent_scales_level_to_average_plus_band_offset # rubocop:disable Metrics/AbcSize
    service = build_service(TieredApi.new)
    add_team_for("user-1")
    downgrade_all_to_one("user-1")
    # nivel 1 => banda F-D offset 0 => level 1
    result = service.prepare("user-1")
    levels = result[:engine].teams[1].map(&:level)
    assert_equal [1], levels.uniq, "banda F-D (nivel 1) sem offset"

    # testa band_offset e generation_for_level diretamente
    assert_equal 0, service.send(:band_offset, %i[F D])
    assert_equal 0, service.send(:band_offset, %i[D C])
    assert_equal 1, service.send(:band_offset, %i[C B])
    assert_equal 1, service.send(:band_offset, %i[B A])
    assert_equal 1, service.send(:band_offset, %i[A S])
    assert_equal 1, service.send(:generation_for_level, 1)
    assert_equal 2, service.send(:generation_for_level, 3)
    assert_equal 9, service.send(:generation_for_level, 42)

    # nivel medio alto => opponent level escalado aumenta HP/level
    # caminho real: xp_for -> grant (curva deriva nivel); grant_levels fora do reward path
    @team.all("user-1").each { |member| @progression.grant_levels("user-1", member.id, 5) } # 1 -> 6
    assert_equal 6, service.send(:average_player_level, "user-1", @team.all("user-1"))
    service_high = build_service(TieredApi.new)
    result_high = service_high.prepare("user-1")
    assert_equal [7], result_high[:engine].teams[1].map(&:level).uniq,
                 "opponent level escala avg 6 + offset C-B(1)=7"
    assert_operator result_high[:engine].teams[1].first.hp_max, :>, 40,
                    "level 7 escala HP acima do base fraco 40"
  end

  def test_build_opponent_filters_by_player_generation
    # Api com geracoes distintas
    gen_api = Class.new(TieredApi) do
      def generation_for(name)
        { "mewtwo" => 1, "mew" => 2, "rayquaza" => 3, "lugia" => 8,
          "groudon" => 9, "kyogre" => 9,
          "pikachu" => 1, "magikarp" => 1, "rattata" => 1, "caterpie" => 1 }[name]
      end

      def base_form?(_name)
        true
      end

      def evolution_restricted?(_name)
        false
      end
    end.new
    service = build_service(gen_api)
    add_team_for("user-1")
    downgrade_all_to_one("user-1") # nivel 1 => player_gen 1 => so gen <=1
    result = service.prepare("user-1")
    opponent_names = result[:engine].teams[1].map(&:name)
    # gen 8/9 devem ser filtrados quando player_gen 1
    refute_includes opponent_names, "lugia", "geracao 8 filtrada para player gen 1"
    refute_includes opponent_names, "groudon"
    refute_includes opponent_names, "kyogre"
    assert(opponent_names.all? { |n| [1, nil].include?(gen_api.generation_for(n)) })
  end

  def test_prepare_unavailable_when_opponent_empty
    empty_api = Class.new do
      def fetch_all_names
        []
      end

      def detail(_id)
        Pokemon.new(name: "pikachu", sprite: "s", number: 25, types: ["normal"],
                    stats: [{ name: "HP", value: 60 }])
      end

      def move(_name)
        Move.new(name: "tackle", type: "normal", power: 40, accuracy: 100, pp: 35)
      end

      def moves_for(_name)
        []
      end

      def type_relations
        { "normal" => { "double" => [], "half" => [], "no" => [] } }
      end

      def next_evolutions(_name)
        []
      end

      def learnable_moves(_name)
        []
      end

      def base_form?(_name)
        true
      end

      def generation_for(_name)
        1
      end

      def evolution_restricted?(_name)
        false
      end
    end.new
    service = build_service(empty_api)
    add_team_for("user-1")
    result = service.prepare("user-1")
    assert_nil result[:engine], "opponent vazio => engine nil"
    assert_equal :unavailable, result[:reason]
  end

  def test_opponent_moves_parity_by_level
    parity_api = Class.new(TieredApi) do
      def learnable_moves(_number)
        [
          { level: 1, name: "tackle" },
          { level: 2, name: "growl" },
          { level: 5, name: "tail-whip" },
          { level: 9, name: "quick-attack" },
          { level: 15, name: "thunderbolt" },
          { level: 20, name: "hyper-beam" }
        ]
      end

      def move(name)
        Move.new(name: name, type: "normal", power: 40, accuracy: 100, pp: 35)
      end

      def base_form?(_name)
        true
      end

      def generation_for(_name)
        1
      end

      def evolution_restricted?(_name)
        false
      end
    end.new
    service = build_service(parity_api)
    add_team_for("parity-1")
    downgrade_all_to_one("parity-1")
    grant_xp_to("parity-1", 100) # nivel 2 => opponent level 2 (banda F-D offset 0)
    result = service.prepare("parity-1")
    opponent = result[:engine].teams[1]
    allowed = %w[tackle growl]
    opponent.each do |fighter|
      assert_operator fighter.moves.size, :<=, 2,
                      "nivel 2 deve ter <=2 golpes, veio #{fighter.moves.size}"
      fighter.moves.each do |mv|
        assert_includes allowed, mv.name, "golpe #{mv.name} deve ser subset de learnable <= level 2"
      end
    end
  end

  def test_opponent_moves_capped_at_learnable # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    many_api = Class.new(TieredApi) do
      def learnable_moves(_number)
        [
          { level: 1, name: "tackle" },
          { level: 2, name: "growl" },
          { level: 5, name: "tail-whip" },
          { level: 9, name: "quick-attack" },
          { level: 15, name: "thunderbolt" },
          { level: 20, name: "hyper-beam" }
        ]
      end

      def move(name)
        Move.new(name: name, type: "normal", power: 40, accuracy: 100, pp: 35)
      end

      def base_form?(_name)
        true
      end

      def generation_for(_name)
        1
      end

      def evolution_restricted?(_name)
        false
      end
    end.new
    service_high = build_service(many_api)
    add_team_for("cap-high")
    grant_xp_to("cap-high", 12_000) # nivel alto => opponent ~16
    result_high = service_high.prepare("cap-high")
    opponent_high = result_high[:engine].teams[1]
    opponent_high.each do |fighter|
      assert_operator fighter.moves.size, :<=, 4, "nivel alto deve ter <=4 golpes"
      refute_empty fighter.moves
    end

    single_api = Class.new(TieredApi) do
      def learnable_moves(_number)
        [{ level: 1, name: "tackle" }]
      end

      def move(name)
        Move.new(name: name, type: "normal", power: 40, accuracy: 100, pp: 35)
      end

      def base_form?(_name)
        true
      end

      def generation_for(_name)
        1
      end

      def evolution_restricted?(_name)
        false
      end
    end.new
    service_single = build_service(single_api)
    add_team_for("cap-single")
    result_single = service_single.prepare("cap-single")
    opponent_single = result_single[:engine].teams[1]
    opponent_single.each do |fighter|
      assert_equal 1, fighter.moves.size, "1 learnable => 1 golpe, sem Struggle indevido"
      assert_equal "tackle", fighter.moves.first.name
    end

    empty_api = Class.new(TieredApi) do
      def learnable_moves(_number)
        []
      end

      def move(_name)
        nil
      end

      def base_form?(_name)
        true
      end

      def generation_for(_name)
        1
      end

      def evolution_restricted?(_name)
        false
      end
    end.new
    service_empty = build_service(empty_api)
    add_team_for("cap-empty")
    result_empty = service_empty.prepare("cap-empty")
    opponent_empty = result_empty[:engine].teams[1]
    opponent_empty.each do |fighter|
      assert_equal 1, fighter.moves.size
      assert_equal "Struggle", fighter.moves.first.name
      assert_equal 10, fighter.moves.first.power
    end
  end
end

# C5 C6 D3 B
class BattleServiceGrantLevelsTest < Minitest::Test
  include TestSupport

  def setup
    TestDatabase.setup!
    TestDatabase.clear_team!
    @team = TeamRepository.new
    @progression = ProgressionRepository.new
    @cache_dir = Dir.mktmpdir("pokedex-ratings")
  end

  def build_service(api, progression: nil, opponent_rng: nil)
    BattleService.new(dependencies: {
                        api: -> { api },
                        battles: BattleRegistry.new,
                        team: @team,
                        progression: progression || @progression,
                        battle_history: BattleRepository.new,
                        wallet: WalletRepository.new,
                        inventory: InventoryRepository.new,
                        opponent_rng: opponent_rng || -> { Random.new(1) },
                        rating_cache: PokemonRatingCache.new(
                          path: File.join(@cache_dir, "ratings.json"),
                          fetcher: api.method(:detail),
                          moves_fetcher: api.method(:moves_for)
                        )
                      })
  end

  def add_team_for(user_id)
    %w[pikachu bulbasaur squirtle].each_with_index do |name, index|
      @team.add(user_id, build_pokemon_record(name, 25 + index))
    end
  end

  FakeEngine = Struct.new(:finished, :result, keyword_init: true) do
    def finished?
      finished
    end
  end

  class CountingProgression
    attr_reader :calls

    def initialize(real)
      @real = real
      @calls = []
    end

    def get(user_id, id)
      @real.get(user_id, id)
    end

    def grant(user_id, id, amount)
      @calls << [user_id, id, amount]
      @real.grant(user_id, id, amount)
    end

    # rubocop:disable Style/ArgumentsForwarding, Naming/BlockForwarding
    def method_missing(name, *args, &block)
      @real.send(name, *args, &block)
    end
    # rubocop:enable Style/ArgumentsForwarding, Naming/BlockForwarding

    def respond_to_missing?(name, include_private = false)
      @real.respond_to?(name, include_private) || super
    end
  end

  def test_finished_win_grants_curve_xp
    api = TieredApi.new
    add_team_for("user-1")
    counting = CountingProgression.new(@progression)
    service = build_service(api, progression: counting)
    engine = FakeEngine.new(finished: true, result: :win)

    service.send(:grant_finished_xp, "user-1", engine)

    assert_equal 3, counting.calls.size
    assert(counting.calls.all? { |_, _, d| d == 50 })
    @team.all("user-1").each do |member|
      entry = @progression.get("user-1", member.id)
      assert_equal 1050, entry[:xp]
      assert_equal 5, entry[:level]
    end
  end

  def test_grant_finished_xp_grants_lose_xp
    api = TieredApi.new
    add_team_for("user-1")
    counting = CountingProgression.new(@progression)
    service = build_service(api, progression: counting)
    engine = FakeEngine.new(finished: true, result: :lose)

    service.send(:grant_finished_xp, "user-1", engine)

    assert_equal 3, counting.calls.size
    assert(counting.calls.all? { |_, _, d| d == 10 })
    @team.all("user-1").each do |member|
      entry = @progression.get("user-1", member.id)
      assert_equal 1010, entry[:xp]
      assert_equal 5, entry[:level]
    end
  end

  def test_grant_finished_xp_grants_draw_xp
    api = TieredApi.new
    add_team_for("user-1")
    counting = CountingProgression.new(@progression)
    service = build_service(api, progression: counting)
    engine = FakeEngine.new(finished: true, result: :draw)

    service.send(:grant_finished_xp, "user-1", engine)

    assert_equal 3, counting.calls.size
    assert(counting.calls.all? { |_, _, d| d == 25 })
  end

  def test_grant_finished_xp_guard_prevents_double_grant
    api = TieredApi.new
    add_team_for("user-1")
    counting = CountingProgression.new(@progression)
    service = build_service(api, progression: counting)
    engine = FakeEngine.new(finished: true, result: :win)

    service.send(:grant_finished_xp, "user-1", engine)
    service.send(:grant_finished_xp, "user-1", engine)
    # guard interno (@granted_xp_engines) + externo finish_effects (advance:397)
    # garante 1x por :finished mesmo se chamado 2x isolado
    assert_equal 1050, @progression.get("user-1", @team.all("user-1").first.id)[:xp],
                 "segunda chamada nao duplica win +50 (1050 nao 1100)"
    assert_equal 3, counting.calls.size, "apenas 3 grant na primeira chamada"
  end

  def test_grant_finished_xp_does_nothing_when_not_finished
    api = TieredApi.new
    add_team_for("user-1")
    counting = CountingProgression.new(@progression)
    service = build_service(api, progression: counting)
    engine = FakeEngine.new(finished: false, result: :win)

    service.send(:grant_finished_xp, "user-1", engine)

    assert_empty counting.calls
    @team.all("user-1").each do |member|
      assert_equal 5, @progression.get("user-1", member.id)[:level]
    end
  end

  def test_average_reflects_level_five
    api = TieredApi.new
    service = build_service(api)
    add_team_for("avg-5")

    avg = service.send(:average_player_level, "avg-5", @team.all("avg-5"))

    assert_equal 5, avg
  end

  def test_band_and_generation_for_level_five
    api = TieredApi.new
    service = build_service(api)
    add_team_for("band-5")

    band = PokemonRating.band_for_level(5)
    gen = service.send(:generation_for_level, 5)
    offset = service.send(:band_offset, band)

    assert_equal %i[D C], band
    assert_equal 2, gen
    assert_equal 0, offset
  end

  def test_build_opponent_level_scales_from_average_five
    api = TieredApi.new
    service = build_service(api)
    add_team_for("opponent-5")

    result = service.prepare("opponent-5")

    levels = result[:engine].teams[1].map(&:level).uniq
    # avg 5 + offset 0 => level 5
    assert_equal [5], levels
    band = PokemonRating.band_for_level(5)
    gen = service.send(:generation_for_level, 5)
    assert_equal %i[D C], band
    assert_equal 2, gen
  end
end
