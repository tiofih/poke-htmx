# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/opponent_generator"

class PlumbingParallelizer
  attr_reader :items

  def map(items, &)
    @items = items.dup
    items.map(&)
  end
end

class OpponentGeneratorTest < Minitest::Test
  NAMES = %w[pikachu bulbasaur squirtle charmander eevee snorlax meowth psyduck].freeze
  MANY_NAMES = Array.new(24) { |i| "poke#{i}" }.freeze

  def build_pokemon(name)
    Pokemon.new(
      name: name,
      sprite: "https://example.com/#{name}.png",
      number: NAMES.index(name) + 1,
      types: ["normal"],
      stats: [{ name: "HP", value: 50 }, { name: "Speed", value: 20 }]
    )
  end

  def generator(names: NAMES, size: 6, seed: 42, fetcher: nil, level: 1, # rubocop:disable Metrics/ParameterLists
                parallelizer: nil, rater: nil, moves_fetcher: nil, band: nil,
                ratings: nil, max_candidates: nil, base_checker: nil,
                generation_checker: nil, restricted_checker: nil, budget_limit: nil) # rubocop:enable Metrics/ParameterLists
    fetcher ||= ->(name) { build_pokemon(name) }
    moves_fetcher ||= ->(_number) { [] }
    OpponentGenerator.new(
      names: names, size: size, rng: Random.new(seed), fetcher: fetcher, level: level,
      options: {
        parallelizer: parallelizer, rater: rater, moves_fetcher: moves_fetcher,
        band: band, ratings: ratings, max_candidates: max_candidates,
        base_checker: base_checker, generation_checker: generation_checker,
        restricted_checker: restricted_checker, budget_limit: budget_limit
      }.compact
    )
  end

  def test_team_returns_battle_pokemon_built_from_fetched_details
    team = generator.team

    assert_equal 6, team.size
    assert team.all?(BattlePokemon)
    assert_equal [["normal"]], team.map(&:types).uniq
  end

  def test_team_names_does_not_repeat_slugs
    names = generator.team_names

    assert_equal 6, names.size
    assert_equal names.uniq, names, "sorteio não repete slugs"
  end

  def test_team_respects_custom_size
    names = generator(size: 3).team_names

    assert_equal 3, names.size
  end

  def test_team_names_with_fewer_names_than_size_uses_all
    names = generator(names: %w[a b c], size: 6).team_names

    assert_equal 3, names.size
    assert_equal names.uniq, names
  end

  def test_same_seed_generates_same_team_order
    first = generator(seed: 42).team_names
    second = generator(seed: 42).team_names

    assert_equal first, second
  end

  def test_different_seed_generates_different_order
    first = generator(seed: 42).team_names
    second = generator(seed: 7).team_names

    refute_equal first, second, "seeds diferentes tendem a gerar ordens diferentes"
  end

  def test_team_names_with_empty_names_returns_empty
    assert_empty generator(names: []).team_names
    assert_empty generator(names: []).team
  end

  def test_team_with_non_positive_size_returns_empty
    assert_empty generator(size: 0).team
    assert_empty generator(size: -1).team
  end

  def test_team_defaults_to_level_one_per_member
    team = generator.team

    assert_equal [1], team.map(&:level).uniq
    assert_equal 50, team.first.hp_max, "HP base sem escala"
  end

  def test_team_with_explicit_level_scales_each_member
    team = generator(level: 5).team

    assert_equal [5], team.map(&:level).uniq
    assert_equal 52, team.first.hp_max, "HP 50 + (5-1)*0.5 = 52"
  end

  def test_team_delegates_fetching_to_injected_parallelizer
    parallelizer = PlumbingParallelizer.new
    gen = generator(seed: 42, parallelizer: parallelizer)
    expected = generator(seed: 42).team_names

    team = gen.team

    assert_equal 6, team.size
    assert_equal expected, parallelizer.items
    assert_equal expected, team.map(&:name)
  end

  def test_team_keeps_team_names_order_by_default
    team = generator(seed: 42).team

    assert_equal generator(seed: 42).team_names, team.map(&:name)
  end

  def tiers_by_name
    { "pikachu" => :S, "bulbasaur" => :A, "squirtle" => :A, "charmander" => :B,
      "eevee" => :B, "snorlax" => :B, "meowth" => :D, "psyduck" => :F }
  end

  def rater
    ->(pokemon, _moves) { tiers_by_name.fetch(pokemon.name, :C) }
  end

  def ratings_provider
    ->(name) { tiers_by_name.fetch(name, :C) }
  end

  def many_ratings(received:)
    lambda do |name|
      received << name
      %w[poke0 poke1].include?(name) ? :S : :F
    end
  end

  def test_team_names_caps_scan_and_falls_back
    received = []
    gen = generator(names: MANY_NAMES, size: 6, seed: 42,
                    ratings: many_ratings(received: received), band: [:S],
                    max_candidates: 10)

    names = gen.team_names

    assert_equal 6, names.size
    assert_equal names.uniq, names, "fallback nao repete nomes"
    assert_operator received.size, :<, MANY_NAMES.size,
                    "cap corta a varredura antes de avaliar o pool inteiro"
    refute names.all? { |name| %w[poke0 poke1].include?(name) },
           "fallback puro completa o time com nomes fora da banda"
  end

  def test_team_names_without_cap_scans_until_band_fills
    received = []
    gen = generator(names: MANY_NAMES, size: 2, seed: 42,
                    ratings: many_ratings(received: received), band: [:S])

    names = gen.team_names

    assert_equal 2, names.size
    assert_operator received.size, :>, 2, "sem cap a varredura segue avaliando candidatos"
  end

  def test_team_names_filters_to_band_with_ratings
    gen = generator(size: 3, ratings: ratings_provider, band: [:B])

    names = gen.team_names

    assert_equal 3, names.size
    assert_equal %w[charmander eevee snorlax].sort, names.sort
  end

  def test_team_names_with_ratings_is_deterministic_for_seed
    first = generator(size: 3, seed: 42, ratings: ratings_provider, band: [:B]).team_names
    second = generator(size: 3, seed: 42, ratings: ratings_provider, band: [:B]).team_names

    assert_equal first, second
  end

  def test_ratings_scan_uses_parallelizer_in_batches
    parallelizer = PlumbingParallelizer.new
    gen = generator(size: 3, seed: 42, parallelizer: parallelizer,
                    ratings: ratings_provider, band: [:B])

    gen.team_names

    refute_empty parallelizer.items, "varredura da banda delegada ao parallelizer em lotes"
  end

  def test_ratings_receives_species_name
    received = []
    ratings = lambda do |name|
      received << name
      tiers_by_name.fetch(name, :C)
    end
    gen = generator(size: 2, ratings: ratings, band: [:B])

    gen.team_names

    refute_empty received, "ratings consultado por nome de espécie"
    assert_includes received, "charmander"
  end

  def test_team_names_filters_to_band
    gen = generator(size: 3, rater: rater, band: [:B])

    names = gen.team_names

    assert_equal 3, names.size
    assert_equal %w[charmander eevee snorlax].sort, names.sort
  end

  def test_team_names_falls_back_to_random_when_band_exhausted
    gen = generator(size: 6, rater: rater, band: [:S])

    names = gen.team_names

    assert_equal 6, names.size
    assert_includes names, "pikachu"
    assert_equal names.uniq, names, "fallback nao repete nomes"
  end

  def test_team_with_band_builds_fighters_from_band
    gen = generator(size: 2, rater: rater, band: [:A])

    team = gen.team

    assert_equal 2, team.size
    assert_equal %w[bulbasaur squirtle].sort, team.map(&:name).sort
  end

  def test_team_names_with_band_is_deterministic_for_seed
    first = generator(size: 3, seed: 42, rater: rater, band: [:B]).team_names
    second = generator(size: 3, seed: 42, rater: rater, band: [:B]).team_names

    assert_equal first, second
  end

  def test_team_names_without_rater_uses_pure_random
    names = generator(seed: 42).team_names

    assert_equal 6, names.size
    assert_equal names.uniq, names
  end

  def test_rater_receives_moves_for_pokemon_number
    fetched_numbers = []
    moves_fetcher = lambda do |number|
      fetched_numbers << number
      []
    end
    gen = generator(
      size: 1, rater: ->(_pokemon, _moves) { :B },
      moves_fetcher: moves_fetcher, band: [:B]
    )

    gen.team_names

    refute_empty fetched_numbers, "moves_fetcher consultado para classificar candidatos"
  end

  def test_team_names_via_base_checker_excludes_non_base
    base_checker = ->(name) { name != "raichu" }
    names = %w[pikachu raichu bulbasaur charmander eevee snorlax meowth psyduck]
    gen = generator(names: names, size: 6, seed: 42,
                    ratings: ->(_name) { :B }, band: [:B],
                    base_checker: base_checker)

    team = gen.team_names

    refute_includes team, "raichu", "base_checker filtra nao-base"
    assert_equal team.uniq, team
  end

  def test_team_names_filters_by_player_generation
    gen_map = { "pikachu" => 1, "bulbasaur" => 1, "charmander" => 2, "squirtle" => 3,
                "eevee" => 1, "snorlax" => 3, "meowth" => 2, "psyduck" => 1 }
    generation_checker = lambda do |name|
      gen = gen_map[name]
      gen.nil? || gen <= 1
    end
    gen = generator(names: NAMES, size: 6, seed: 42,
                    ratings: ratings_provider, band: %i[B A S D F C],
                    generation_checker: generation_checker)

    team = gen.team_names

    assert team.none? { |n| gen_map[n] && gen_map[n] > 1 }, "geracao > player_gen excluida"
    # nil fail open: nome desconhecido (sem geracao) deve ser mantido
    gen_unknown = generator(names: %w[unknown pikachu], size: 2, seed: 42,
                            ratings: ->(_n) { :B }, band: [:B],
                            generation_checker: ->(n) { gen_map[n].nil? || gen_map[n] <= 1 })
    assert_includes gen_unknown.team_names, "unknown", "geracao nil mantem candidato (fail open)"
  end

  def test_ratings_scan_uses_single_parallelizer_pass_for_base_and_generation_and_band
    calls = [0]
    counting = Class.new do
      attr_reader :calls

      def initialize(counter)
        @counter = counter
      end

      def map(items, &block)
        @counter[0] += 1
        items.map(&block)
      end
    end.new(calls)
    base_checker = ->(_n) { true }
    generation_checker = ->(_n) { true }
    gen = generator(names: NAMES, size: 3, seed: 42, parallelizer: counting,
                    ratings: ratings_provider, band: [:B],
                    base_checker: base_checker, generation_checker: generation_checker)

    gen.team_names

    assert_equal 1, calls[0], "single-pass Parallelizer.map por batch (nao duplica varredura)"
  end
end
