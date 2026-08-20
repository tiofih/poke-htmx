# frozen_string_literal: true

require_relative "test_helper"
require_relative "test_support"
require_relative "../lib/battle_registry"
require_relative "../lib/battle_repository"
require_relative "../lib/battle_service"
require_relative "../lib/inventory_repository"
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

class BattleServiceTest < Minitest::Test
  include TestSupport

  def setup
    TestDatabase.setup!
    TestDatabase.clear_team!
    @team = TeamRepository.new
    @progression = ProgressionRepository.new
  end

  def build_service(api)
    deps = {
      api: -> { api },
      battles: BattleRegistry.new,
      team: @team,
      progression: @progression,
      battle_history: BattleRepository.new,
      wallet: WalletRepository.new,
      inventory: InventoryRepository.new
    }
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

  def test_prepare_returns_same_opponent_for_same_user
    service = build_service(counting_api)
    add_team_for("user-1")

    first = service.prepare("user-1")[:engine]
    second = service.prepare("user-1")[:engine]

    assert_equal first.teams[1].map(&:name), second.teams[1].map(&:name)
  end
end
