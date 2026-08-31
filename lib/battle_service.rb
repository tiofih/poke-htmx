# frozen_string_literal: true

require "set" # rubocop:disable Lint/RedundantRequireStatement
require_relative "battle_engine"
require_relative "battle_registry"
require_relative "battle_repository"
require_relative "evolution_rule"
require_relative "move"
require_relative "opponent_generator"
require_relative "parallelizer"
require_relative "pokemon_rating"
require_relative "pokemon_rating_cache"
require_relative "progression_repository"
require_relative "reward_rule"
require_relative "team_repository"
require_relative "type_effectiveness"
require_relative "wallet_repository"
require_relative "inventory_repository"

# rubocop:disable Metrics/ModuleLength
module BattleServicePreparation
  RATING_SCAN_CAP = 256

  private

  def player_team(user_id, members)
    progress = progress_for(user_id, members)
    Parallelizer.map(members, concurrency: Parallelizer::DEFAULT_CONCURRENCY) do |member|
      detail = api.detail(member.number)
      detail && apply_persisted_hp(battle_fighter_from(progress, member, detail), progress, member)
    end.compact
  end

  def progress_for(user_id, members)
    members.to_h { |member| [member.id, @progression.get(user_id, member.id)] }
  end

  def battle_fighter_from(progress, member, detail)
    BattlePokemon.from(
      detail,
      moves: moves_for(member),
      level: progress.fetch(member.id).to_h.fetch(:level, 1),
      assigned_item: member.assigned_item,
      held_item: member.held_item
    )
  end

  def apply_persisted_hp(fighter, progress, member)
    entry = progress[member.id]
    return fighter if entry.nil? || entry[:hp_max].to_i <= 0

    hp_current = [entry[:hp_current].to_i, entry[:hp_max].to_i].min
    fighter.new(hp_current: hp_current)
  end

  def member_level(user_id, member)
    @progression.get(user_id, member.id)&.fetch(:level) || 1
  end

  def opponent_team(user_id)
    opponent = build_opponent(user_id)
    return nil if opponent.empty?

    Parallelizer.map(opponent, concurrency: Parallelizer::DEFAULT_CONCURRENCY) do |battle_pokemon|
      battle_pokemon.new(moves: moves_for_opponent(battle_pokemon))
    end
  end

  def active_battle?(engine)
    engine && !engine.rounds.zero?
  end

  def build_or_reuse_engine(user_id, members, existing)
    player = player_team(user_id, members)
    return unprepared(:unavailable) if player.size < members.size

    opponent = existing ? existing.teams[1] : opponent_team(user_id)
    return unprepared(:unavailable) unless opponent

    engine = build_engine(player, opponent, user_id)
    @battles.set(user_id, engine)
    { engine: engine, reason: :ok }
  end

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def build_opponent(user_id)
    team = @team.all(user_id)
    avg = average_player_level(user_id, team)
    band = PokemonRating.band_for_level(avg)
    player_gen = generation_for_level(avg)
    level = avg + band_offset(band)
    level = 1 if level < 1
    names = api.respond_to?(:fetch_all_names) ? (api.fetch_all_names || []) : []
    OpponentGenerator.new(
      names: names,
      fetcher: api.method(:detail),
      rng: @opponent_rng.call,
      level: level,
      options: opponent_options(band, player_gen)
    ).team
  end

  def opponent_options(band, player_gen = 9)
    {
      parallelizer: Parallelizer,
      ratings: ->(name) { @rating_cache.rating_for(name) },
      band: band,
      max_candidates: RATING_SCAN_CAP,
      base_checker: lambda do |name|
        return true unless api.respond_to?(:base_form?)

        api.base_form?(name) == true
      end,
      generation_checker: lambda do |name|
        return true unless api.respond_to?(:generation_for)

        gen = api.generation_for(name)
        gen.nil? || gen <= player_gen
      end,
      restricted_checker: lambda do |name|
        return false unless api.respond_to?(:evolution_restricted?)

        api.evolution_restricted?(name) == true
      end
    }
  end
  # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

  # rubocop:disable Lint/DuplicateBranch
  def band_offset(band)
    case band
    when %i[F D] then 0
    when %i[D C] then 0
    when %i[C B] then 1
    when %i[B A] then 1
    when %i[A S] then 1
    else 0
    end
  end
  # rubocop:enable Lint/DuplicateBranch

  # rubocop:disable Metrics/MethodLength, Metrics/CyclomaticComplexity
  def generation_for_level(level)
    lvl = level.to_i
    case lvl
    when 1..2 then 1
    when 3..5 then 2
    when 6..9 then 3
    when 10..14 then 4
    when 15..20 then 5
    when 21..27 then 6
    when 28..34 then 7
    when 35..41 then 8
    else 9
    end
  end
  # rubocop:enable Metrics/MethodLength, Metrics/CyclomaticComplexity

  def average_player_level(user_id, team)
    levels = team.map { |member| member_level(user_id, member) }
    return 1 if levels.empty?

    (levels.sum / levels.size.to_f).round
  end

  def inventory_stock(user_id)
    @inventory.all(user_id).to_h { |entry| [entry[:name], entry[:quantity]] }
  end

  def battle_items(user_id)
    stock = inventory_stock(user_id)
    @team.all(user_id).each do |member|
      item = member.assigned_item
      stock[item] = stock.fetch(item, 0) + 1 if item && !item.to_s.empty?
    end
    stock
  end

  def moves_for(pokemon)
    saved = pokemon.moves.filter_map { |name| api.move(name) }
    return saved unless saved.empty?

    moves = api.moves_for(pokemon.number)
    return moves unless moves.empty?

    [Move.new(name: "Struggle", type: pokemon.types.first || "normal", power: 10, accuracy: nil, pp: 100)]
  end

  # rubocop:disable Metrics/AbcSize
  def moves_for_opponent(pokemon)
    learnable = api.learnable_moves(pokemon.number).to_a
                   .select { |entry| entry[:level].to_i <= pokemon.level.to_i }.last(4)
    moves = learnable.filter_map { |entry| api.move(entry[:name]) }
    return moves unless moves.empty?

    [Move.new(name: "Struggle", type: pokemon.types.first || "normal", power: 10, accuracy: nil, pp: 100)]
  end
  # rubocop:enable Metrics/AbcSize
end
# rubocop:enable Metrics/ModuleLength

module BattleServiceFinalization # rubocop:disable Metrics/ModuleLength
  private

  def debit_used_items(user_id, engine)
    members = @team.all(user_id)
    items_used_in_round(engine).each do |entry|
      consume_used_item(user_id, members, entry)
    end
  end

  def items_used_in_round(engine)
    round = engine.rounds
    engine.log.select { |entry| entry[:round] == round && entry[:action] == :item }
  end

  def consume_used_item(user_id, members, entry)
    member = members[entry[:attacker_index]]
    if member && member.assigned_item.to_s == entry[:item].to_s
      @team.assign_item(user_id, member.id, nil)
    else
      @inventory.use(user_id, entry[:item], 1)
    end
  end

  def record_finished_battle(user_id, engine)
    return unless engine.result

    @battle_history.add(
      user_id,
      engine.result.to_s,
      engine.teams[1].map { |bp| { number: bp.number, name: bp.name } }
    )
  end

  def grant_finished_xp(user_id, engine)
    return unless engine.finished? && engine.result
    return if @granted_xp_engines.include?(engine.object_id)

    delta = RewardRule.new.levels_for(engine.result)
    return if delta.zero?

    @granted_xp_engines.add(engine.object_id)
    @team.all(user_id).each do |member|
      @progression.grant_levels(user_id, member.id, delta)
    end
  end

  def grant_finished_money(user_id, engine)
    return unless engine.result

    @wallet.grant(user_id, RewardRule.new.money_for(engine.result))
  end

  def apply_evolution_and_learning(user_id)
    news = { evolution_news: [], learned_news: [] }
    prefetched_evolution_data(user_id).each do |lookup|
      apply_member_evolution(user_id, lookup, news)
    end
    news
  end

  def prefetched_evolution_data(user_id)
    Parallelizer.map(@team.all(user_id), concurrency: Parallelizer::DEFAULT_CONCURRENCY) do |member|
      {
        member: member,
        evolutions: api.next_evolutions(member.number).to_a,
        learnable: api.learnable_moves(member.number).to_a
      }
    end
  end

  def apply_member_evolution(user_id, lookup, news)
    evolve_member(user_id, lookup[:member], lookup[:evolutions], news[:evolution_news])
    learn_moves_for_member(user_id, lookup[:member], lookup[:learnable], news[:learned_news])
  end

  def rebuild_display_team(user_id, engine)
    fresh_team = @team.all(user_id)
    return unless fresh_team.size == engine.teams[0].size

    engine.replace_team_a(display_team_for(fresh_team, engine, user_id))
  end

  def display_team_for(fresh_team, engine, user_id)
    engine.teams[0].each_with_index.map do |fighter, i|
      display_fighter(fresh_team[i], fighter, user_id)
    end
  end

  def display_fighter(member, fighter, user_id)
    BattlePokemon.new(
      number: member.number, name: member.name, sprite: member.sprite,
      types: fighter.types, stats: fighter.stats,
      hp_max: fighter.hp_max, hp_current: fighter.hp_current,
      moves: fighter.moves, level: member_level(user_id, member),
      assigned_item: fighter.assigned_item, held_item: fighter.held_item
    )
  end

  def persist_finished_hp(user_id, engine)
    list = @team.all(user_id)
    return unless list.size == engine.teams[0].size

    list.zip(engine.teams[0]).each { |member, fighter| save_fighter_hp(user_id, member, fighter) }
  end

  def save_fighter_hp(user_id, member, fighter)
    @progression.update_hp(user_id, member.id, fighter.hp_max, fighter.hp_current)
  end

  def evolve_member(user_id, member, next_evolutions, evolution_news)
    loop do
      target = evolution_target(user_id, member, next_evolutions)
      break unless target
      break if target[:number] == member.number

      evolution_pokemon = api.detail(target[:number])
      break unless evolution_pokemon

      evolved = try_evolve(user_id, member, evolution_pokemon, evolution_news)
      break unless evolved

      member = evolved
    end
  end

  def evolution_target(user_id, member, next_evolutions)
    progress = @progression.get(user_id, member.id)
    EvolutionRule.next_stage(_current_number: member.number, level: progress[:level], evolutions: next_evolutions)
  end

  def try_evolve(user_id, member, evolution_pokemon, evolution_news)
    if @team.evolve(user_id, member.id, evolution_pokemon)
      evolution_news << "#{member.name} evoluiu para #{evolution_pokemon.name}!"
      return evolution_pokemon.new(id: member.id)
    end

    evolution_news << "#{member.name} não evoluiu — #{evolution_pokemon.name} já está no time."
    nil
  end

  def learn_moves_for_member(user_id, member, learnable_moves, learned_news)
    progress = @progression.get(user_id, member.id)
    learnable_moves.each do |entry|
      try_learn(user_id, member, entry, progress, learned_news)
    end
  end

  def try_learn(user_id, member, entry, progress, learned_news)
    return unless entry[:level] <= progress[:level]
    return unless @team.learn_move(user_id, member.id, entry[:name])

    learned_news << "#{member.name} aprendeu #{entry[:name]}!"
  end
end

class BattleService
  include BattleServicePreparation
  include BattleServiceFinalization

  def initialize(dependencies:)
    @api_provider = dependencies[:api]
    @battles = dependencies[:battles]
    @team = dependencies[:team]
    @progression = dependencies[:progression]
    @battle_history = dependencies[:battle_history]
    @wallet = dependencies[:wallet]
    @inventory = dependencies[:inventory]
    @opponent_rng = dependencies[:opponent_rng] || -> { Random.new }
    @rating_cache = dependencies[:rating_cache] || default_rating_cache
    @granted_xp_engines = Set.new
  end

  def prepare(user_id)
    members = @team.all(user_id)
    return unprepared(:empty_team) if members.empty?

    existing = @battles.fetch(user_id)
    return { engine: existing, reason: :ok } if active_battle?(existing)

    build_or_reuse_engine(user_id, members, existing)
  end

  def new_confront(user_id)
    @battles.clear(user_id)
    prepare(user_id)
  end

  def invalidate(user_id)
    @battles.clear(user_id)
  end

  def advance(user_id)
    engine = @battles.fetch(user_id)
    return nil unless engine

    finishing = !engine.finished?
    engine.play_round
    debit_used_items(user_id, engine)
    news = finish_effects(user_id, engine) if finishing && engine.finished?
    battle_payload(engine, news || empty_news)
  end

  private

  def api
    @api_provider.call
  end

  def default_rating_cache
    PokemonRatingCache.new(
      path: ENV["POKERATING_CACHE_PATH"] || "tmp/pokemon_rating_cache.json",
      fetcher: api.method(:detail),
      moves_fetcher: api.method(:moves_for)
    )
  end

  def build_engine(player, opponent, user_id)
    BattleEngine.new(
      team_a: player,
      team_b: opponent,
      effectiveness: TypeEffectiveness.load(api),
      items: battle_items(user_id)
    )
  end

  def unprepared(reason)
    { engine: nil, reason: reason }
  end

  def finish_effects(user_id, engine)
    record_finished_battle(user_id, engine)
    grant_finished_xp(user_id, engine)
    grant_finished_money(user_id, engine)
    news = apply_evolution_and_learning(user_id)
    rebuild_display_team(user_id, engine)
    persist_finished_hp(user_id, engine)
    news
  end

  def battle_payload(engine, news)
    reward = RewardRule.new
    {
      engine: engine,
      xp_gained: engine.finished? ? reward.xp_for(engine.result) : nil,
      money_gained: engine.finished? ? reward.money_for(engine.result) : nil,
      evolution_news: news[:evolution_news],
      learned_news: news[:learned_news]
    }
  end

  def empty_news
    { evolution_news: [], learned_news: [] }
  end
end
