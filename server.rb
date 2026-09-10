require "sinatra/base"
require "sinatra/reloader"
require "securerandom"
require "time"
require "set" # rubocop:disable Lint/RedundantRequireStatement
require "pry" if ENV["RACK_ENV"] == "development"
require_relative "lib/gateways/poke_api"
require_relative "lib/team_repository"
require_relative "lib/battle_pokemon"
require_relative "lib/battle_engine"
require_relative "lib/opponent_generator"
require_relative "lib/battle_registry"
require_relative "lib/battle_repository"
require_relative "lib/progression_repository"
require_relative "lib/wallet_repository"
require_relative "lib/reward_rule"
require_relative "lib/evolution_rule"
require_relative "lib/heal_service"
require_relative "lib/inventory_repository"
require_relative "lib/item_catalog"
require_relative "lib/mart_service"
require_relative "lib/battle_service"
require_relative "lib/team_service"
require_relative "lib/user_state_repository"
require_relative "lib/journey_service"
require_relative "db/seeds/saldo_inicial"
require_relative "lib/parallelizer"
require_relative "lib/fighter_presenter"
require_relative "lib/battle_log_presenter"
require_relative "lib/battle_juice_presenter"
require_relative "lib/team_budget"
require_relative "lib/pokemon_rating_cache"
require_relative "lib/stone_rotation"

module ServerCommon
  private

  def current_user
    session[:user_id]
  end

  def team_manage_context(member_id = nil)
    data = settings.team_strategy.manage_data(current_user)
    expose_manage_data(data)
    return nil unless member_id

    data[:members].find { |poke| poke.id.to_s == member_id.to_s }
  end

  def expose_manage_data(data)
    @team = data[:members]
    @available_moves = data[:available_moves]
    @inventory = data[:inventory]
    @team_types = team_types_map(@team)
    @member_levels = member_levels_map(@team)
  end

  # Niveis 0077 (C2): progressao local por membro, fail-closed 1 (sem rede).
  def member_levels_map(members)
    Array(members).to_h { |member| [member.id.to_s, member_level_for(member)] }
  end

  def member_level_for(member)
    settings.progression.get(current_user, member.id)&.fetch(:level, 1) || 1
  rescue StandardError
    1
  end

  # Enrichment 0076 2a (C5): o schema team_pokemons nao tem coluna de tipos —
  # resolve via api.detail (com tipos) com fallback api.find, memo por nome; fail-closed [] (sem rede em teste).
  def team_types_map(members)
    cache = {}
    Array(members).to_h { |member| [member.id, member_types_from_api(cache, member)] }
  end

  def member_types_from_api(cache, member)
    stored = member.types.to_a
    return stored unless stored.empty?

    cache.fetch(member.name) do
      found = settings.api.detail(member.name) || settings.api.find(member.name)
      cache[member.name] = found ? found.types.to_a : []
    rescue StandardError
      []
    end
  end

  def reload_manage_state
    @team = settings.team.all(current_user)
    @inventory = settings.inventory.all(current_user)
  end
end

STARTER_SLUGS = %w[
  bulbasaur charmander squirtle
  chikorita cyndaquil totodile
  treecko torchic mudkip
  turtwig chimchar piplup
  snivy tepig oshawott
  chespin fennekin froakie
  rowlet litten popplio
  grookey scorbunny sobble
  sprigatito fuecoco quaxly
].freeze

# rubocop:disable Metrics/ModuleLength
module ServerListActions
  PAGE_SIZE = 36
  FIRST_PAGE_COMMONS = PAGE_SIZE - STARTER_SLUGS.size
  SCAN_BATCH = 24

  private

  def render_index
    @offset = 0
    @q = ""
    prepare_team_fragment_data
    load_pokemon_page
    erb :index
  end

  def render_pokemons_list
    @offset = params[:offset].to_i
    @q = params[:q].to_s
    load_pokemon_page
    erb(:pokemon_list, layout: false) + (filter_controls_needs_sync? ? oob_filter_controls : "")
  end

  def oob_filter_controls
    %(<div id="filter-controls" hx-swap-oob="innerHTML">#{erb :_filter_controls, layout: false}</div>)
  end

  def filter_controls_needs_sync?
    %w[type generation tier cost cost_max sort team].any? { |k| filter_param_present?(k) }
  end

  # rubocop:disable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
  def load_pokemon_page
    @limit = PAGE_SIZE
    @type = normalized_type(params[:type]) if filter_param_present?("type")
    @generation = normalized_generation(params[:generation]) if filter_param_present?("generation")
    @tier = normalized_tier(params[:tier]) if filter_param_present?("tier")
    if filter_param_present?("cost_max") || filter_param_present?("cost")
      @cost_max = normalized_cost_max(params[:cost_max] || params[:cost])
    end
    @sort = normalized_sort(params[:sort]) if filter_param_present?("sort")
    @team_filter = normalized_team(params[:team]) if filter_param_present?("team")
    # restore from session when no explicit filter param
    restore_filters_from_session unless any_filter_param_present?
    # persist when explicit filter params were sent
    persist_filters_to_session if any_filter_param_present?
    # ensure nil defaults when no session and no params
    @type ||= nil
    @generation ||= nil
    @tier ||= nil
    @cost_max ||= nil
    @sort ||= nil
    @team_filter ||= nil
    load_team_names
    @starters = starters_visible? ? load_starters : []
    build_page
    @items = Parallelizer.map(@page_names) { |name| [name, settings.api.find(name)] }
    load_search_hint
    if @page_names.empty? && @q.empty? && !filter_active? && !sort_active?
      @notice = "Não foi possível carregar a lista de Pokémon."
    end
    build_pokemon_costs
  end
  # rubocop:enable Metrics/AbcSize, Metrics/MethodLength, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity

  def starters_visible?
    @q.empty? && @offset.zero? && !filter_active? && !sort_active?
  end

  def normalized_type(value)
    v = value.to_s.strip.downcase
    return nil if v.empty?
    return nil unless PokeApiTypes::TYPE_NAMES.include?(v)

    v
  end

  def normalized_generation(value)
    v = value.to_s.strip
    return nil if v.empty?

    n = Integer(v, 10, exception: false)
    return nil unless n&.between?(1, 9)

    n
  end

  def normalized_tier(value)
    v = value.to_s.strip.upcase
    return nil if v.empty?
    return nil unless %w[S A B C D F].include?(v)

    v
  end

  def normalized_cost_max(value)
    v = value.to_s.strip
    return nil if v.empty?

    n = Integer(v, 10, exception: false)
    return nil unless n && n >= 0

    n
  end

  def normalized_sort(value)
    v = value.to_s.strip
    return nil if v.empty?
    return nil unless %w[cost_asc cost_desc tier_desc tier_asc].include?(v)

    v
  end

  def normalized_team(value)
    v = value.to_s.strip.downcase
    return nil if v.empty?
    return nil unless %w[in out].include?(v)

    v
  end

  def filter_active?
    !@type.nil? || !@generation.nil? || !@tier.nil? || !@cost_max.nil? || !@team_filter.nil?
  end

  def sort_active?
    !@sort.nil?
  end

  def filter_param_present?(key)
    params.key?(key) || params.key?(key.to_sym)
  end

  def any_filter_param_present?
    %w[type generation tier cost cost_max sort team].any? { |k| filter_param_present?(k) }
  end

  def persist_filters_to_session
    filters = current_filter_params
    if filters.empty?
      session.delete(:list_filters)
    else
      session[:list_filters] = filters
    end
  end

  def current_filter_params
    {
      "type" => @type,
      "generation" => @generation,
      "tier" => @tier,
      "cost_max" => @cost_max,
      "sort" => @sort,
      "team" => @team_filter
    }.compact
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
  def restore_filters_from_session
    stored = session[:list_filters]
    return unless stored

    @type = normalized_type(stored["type"] || stored[:type]) if stored["type"] || stored[:type]
    gen = stored["generation"] || stored[:generation]
    @generation = normalized_generation(gen) if gen
    tier_val = stored["tier"] || stored[:tier]
    @tier = normalized_tier(tier_val) if tier_val
    cost_val = stored["cost_max"] || stored[:cost_max] || stored["cost"] || stored[:cost]
    @cost_max = normalized_cost_max(cost_val) if cost_val
    s = stored["sort"] || stored[:sort]
    @sort = normalized_sort(s) if s
    team_val = stored["team"] || stored[:team]
    @team_filter = normalized_team(team_val) if team_val
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength

  def load_search_hint
    @search_hint = search_hint(@q) if !@q.empty? && @items.empty?
  end

  def build_page
    @page_names, more = commons_window
    @current_page = current_page_number
    @prev_offset = previous_offset
    @next_offset = more ? next_page_offset : nil
  end

  def commons_window
    if @q.empty? && @offset.zero? && !filter_active? && !sort_active?
      fetch_commons(0, FIRST_PAGE_COMMONS)
    else
      fetch_commons(@offset, PAGE_SIZE)
    end
  end

  # rubocop:disable Metrics/MethodLength
  def fetch_commons(offset, count)
    if @sort
      all = collect_all_filtered_base_forms
      sorted = sort_names(all)
      more = sorted.size > offset + count
      [sorted[offset, count].to_a, more]
    else
      base_forms = []
      collect_base_forms(base_forms, offset + count)
      more = base_forms.size >= offset + count
      [base_forms[offset, count].to_a, more]
    end
  end
  # rubocop:enable Metrics/MethodLength

  def collect_base_forms(base_forms, target)
    common_candidates.each_slice(SCAN_BATCH) do |batch|
      base_forms.concat(filtered_base_forms(batch))
      break if base_forms.size >= target
    end
  end

  def collect_all_filtered_base_forms
    all = []
    common_candidates.each_slice(SCAN_BATCH) do |batch|
      all.concat(filtered_base_forms(batch))
    end
    all
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
  def sort_names(names)
    infos = Parallelizer.map(names) do |name|
      pokemon = settings.api.detail(name) || settings.api.find(name)
      # guard nil pokemon (should not happen for base forms)
      tier = pokemon ? line_tier_for(pokemon).to_s : "F"
      restricted = settings.api.evolution_restricted?(name)
      cost = TeamBudget.cost_for(line_tier: tier, restricted: restricted)
      [name, tier, cost]
    end
    case @sort
    when "cost_asc"
      infos.sort_by { |_n, _t, c| c }.map(&:first)
    when "cost_desc"
      infos.sort_by { |_n, _t, c| -c }.map(&:first)
    when "tier_desc"
      infos.sort_by { |_n, t, _c| -ServerTeamActions::TIER_ORDER.index(t.to_sym) }.map(&:first)
    when "tier_asc"
      infos.sort_by { |_n, t, _c| ServerTeamActions::TIER_ORDER.index(t.to_sym) }.map(&:first)
    else
      names
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength

  def type_pokemon_set
    return @type_pokemon_set if defined?(@type_pokemon_set) && @type_pokemon_set && @type_pokemon_set_type == @type

    @type_pokemon_set_type = @type
    @type_pokemon_set = Set.new(settings.api.pokemon_names_by_type(@type))
  end

  # NOTA PERF 0057-4c: tipo usa endpoint /type (1 fetch_type_json) + interseção Set — rápido (~<1s/1300 nomes).
  # Geração/tier/cost ainda varrem candidatos em lotes 24 com base_form? + detail (+ line_tier) por item.
  # Primeira carga fria lê PersistentJsonStore (~60s/300MB em dev, quente ~0.01s — sessao 0050 C4-b);
  # se p95 rock ainda alto após 4b é warm-up frio, não implementação. Próximo passo: índice
  # por geração/tier similar a /type ou cap max_candidates (fora deste hotfix, limitação aceita).

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
  def filtered_base_forms(batch)
    forms = Parallelizer.map(batch) { |name| [name, settings.api.base_form?(name)] }
    base_names = forms.select { |_name, is_base| is_base }.map(&:first)
    filtered = base_names
    if @type
      type_set = type_pokemon_set
      filtered = filtered.select { |name| type_set.include?(name) }
    end
    if @generation
      gen = Parallelizer.map(filtered) { |name| [name, settings.api.generation_for(name)] }
      filtered = gen.select { |_name, gen_val| gen_val == @generation }.map(&:first)
    end
    if @tier || @cost_max
      tier_cost = Parallelizer.map(filtered) do |name|
        pokemon = settings.api.detail(name) || settings.api.find(name)
        next [name, nil, nil] unless pokemon

        tier = line_tier_for(pokemon).to_s
        restricted = settings.api.evolution_restricted?(pokemon.name)
        cost = TeamBudget.cost_for(line_tier: tier, restricted: restricted)
        [name, tier, cost]
      end
      tier_cost = tier_cost.select { |_name, tier_val, _cost| tier_val == @tier } if @tier
      tier_cost = tier_cost.select { |_name, _t, cost| cost && cost <= @cost_max } if @cost_max
      filtered = tier_cost.map(&:first)
    end
    filtered = filter_by_team(filtered) if @team_filter
    filtered
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength

  def base_form_names(batch)
    forms = Parallelizer.map(batch) { |name| [name, settings.api.base_form?(name)] }
    forms.select { |_name, is_base| is_base }.map(&:first)
  end

  def filter_by_team(names)
    member_set = Set.new(@team_names)
    if @team_filter == "in"
      names.select { |name| member_set.include?(name) }
    else
      names.reject { |name| member_set.include?(name) }
    end
  end

  def common_candidates
    names = settings.api.fetch_all_names.to_a
    names = names.select { |name| name.downcase.include?(@q.downcase) } unless @q.empty?
    return names if filter_active? || sort_active?

    names.reject { |name| STARTER_SLUGS.include?(name) }
  end

  def standard_pagination?
    @q.empty? && !filter_active? && !sort_active?
  end

  def current_page_number
    if standard_pagination? && !@offset.zero?
      ((@offset - FIRST_PAGE_COMMONS) / PAGE_SIZE) + 2
    else
      (@offset / PAGE_SIZE) + 1
    end
  end

  def previous_offset
    return nil if @offset.zero?
    return 0 if standard_pagination? && @current_page == 2

    @offset - PAGE_SIZE
  end

  def next_page_offset
    return FIRST_PAGE_COMMONS if standard_pagination? && @offset.zero?

    @offset + PAGE_SIZE
  end

  def load_team_names
    team = settings.team.all(current_user)
    @team_names = team.map(&:name)
    @team_full = team.size >= TeamRepository::MAX_TEAM_SIZE
  end

  def load_starters
    Parallelizer.map(STARTER_SLUGS) { |name| [name, settings.api.find(name)] }
  end

  def build_pokemon_costs
    @pokemon_costs = {}
    ((@starters || []) + (@items || [])).each do |name, pokemon|
      next unless pokemon

      @pokemon_costs[name] = pokemon_cost_info(pokemon)
    end
  end

  def pokemon_cost_info(pokemon)
    tier = line_tier_for(pokemon)
    restricted = settings.api.evolution_restricted?(pokemon.name)
    cost = TeamBudget.cost_for(line_tier: tier.to_s, restricted: restricted)
    { tier: tier, cost: cost, restricted: restricted }
  end

  def render_pokemon_fragment
    @pokemon = settings.api.find(params[:name])
    if @pokemon
      erb :pokemon, layout: false
    else
      @message = "Pokémon não encontrado."
      erb :error, layout: false
    end
  end

  def render_pokemon_detail
    @pokemon = settings.api.detail(params[:poke_id])
    if @pokemon
      erb :pokemon_detail, layout: false
    else
      @message = "Pokémon não encontrado."
      erb :error, layout: false
    end
  end
end
# rubocop:enable Metrics/ModuleLength

module ServerSearchHintActions
  private

  def search_hint(query)
    match = first_search_match(query)
    return nil unless match

    return { kind: :starter, name: match } if STARTER_SLUGS.include?(match)

    base = base_form_for(match)
    base ? { kind: :evolution, name: match, base: base.name } : { kind: :generic, name: match }
  end

  def first_search_match(query)
    settings.api.fetch_all_names.to_a.find { |name| name.downcase.include?(query.downcase) }
  end

  def base_form_for(match)
    settings.api.detail(match)&.evolutions&.first
  end
end

# rubocop:disable Metrics/ModuleLength
module ServerTeamActions
  private

  def render_team
    prepare_team_fragment_data
    return erb :team, layout: false if htmx_request?

    halt 404, "Página não encontrada."
  end

  def mart_data
    @catalog = ItemCatalog.all
    @inventory = settings.inventory.all(current_user)
    @balance = settings.wallet.balance(current_user)
    @rotation = stone_rotation_stones(current_user)
  end

  def stone_rotation_stones(user_id)
    battle_count = settings.battle_history.stats(user_id)[:total]
    StoneRotation.new(user_id, battle_count).stones
  end

  def center_data
    @heal_cost = settings.heal.preview_cost(current_user)
    @balance = settings.wallet.balance(current_user)
  end

  def render_team_manage
    team_manage_context
    erb :_manage_modal, layout: false
  end

  def render_team_manage_member
    member = team_manage_context(params[:id])
    return member_not_found_notice unless member

    @team = [member]
    erb :_manage_modal, layout: false
  end

  def close_team_manage
    ""
  end

  def render_team_center
    prepare_team_fragment_data
    erb :_center_modal, layout: false
  end

  def render_team_mart
    prepare_team_fragment_data
    erb :_mart_modal, layout: false
  end

  def close_team_center
    erb :_center_slot, layout: false
  end

  def close_team_mart
    erb :_mart_slot, layout: false
  end

  def add_team_member
    pokemon = new_member_from_api
    return budget_blocked_response("Pokémon não encontrado.") unless pokemon

    lt = line_tier_for(pokemon)
    cost = pokemon_cost(pokemon, lt)
    team = settings.team.all(current_user)
    current_cost = team_total_cost(team)
    notice = budget_notice(current_cost, cost)
    return budget_blocked_response(notice) if notice

    add_team_success(pokemon)
  end

  def add_team_success(pokemon)
    notice = add_team_notice(pokemon)
    settings.journey.mark_started_when_full(current_user)
    settings.battle.invalidate(current_user) unless notice
    @notice = notice || "Adicionado ao time."
    @notice_kind = notice ? :error : :success
    @toast_pokemon = pokemon unless notice
    mini_status = erb :team_add_result, layout: false
    prepare_team_fragment_data
    "#{mini_status}#{oob_team_view}#{oob_pokemon_list}#{oob_nav_badge}"
  end

  def budget_blocked_response(msg)
    @notice = msg
    @notice_kind = :error
    mini_status = erb :team_add_result, layout: false
    prepare_team_fragment_data
    "#{mini_status}#{oob_team_view}#{oob_pokemon_list}#{oob_nav_badge}"
  end

  def oob_team_view
    erb :team_view_oob, layout: false
  end

  def oob_nav_badge
    %(<span id="nav-badge" hx-swap-oob="innerHTML">#{@team_size || @team.size}/6</span>)
  end

  def oob_pokemon_list
    @offset = params[:offset].to_i
    @q = params[:q].to_s
    load_pokemon_page
    %(<div id="pokemon-list" hx-swap-oob="innerHTML">#{erb :pokemon_list, layout: false}</div>)
  end

  def new_member_from_api
    pokemon = settings.api.find(params[:pokeName])
    return unless pokemon

    pokemon_with_level_one_moves(pokemon)
  end

  def add_team_notice(pokemon)
    return "Pokémon não encontrado." unless pokemon

    begin
      settings.team.add(current_user, pokemon)
      nil
    rescue TeamRepository::TeamFullError, TeamRepository::DuplicateError => e
      e.message
    end
  end

  def pokemon_with_level_one_moves(pokemon)
    learnable = settings.api.learnable_moves(pokemon.number).to_a
    names = learnable.select { |m| m[:level] <= 1 }
                     .map { |m| m[:name] }
                     .first(TeamRepository::MAX_MOVES_PER_POKEMON)
    pokemon.new(moves: names)
  end

  # Calcula o tier da linha evolutiva (máximo dos tiers dos membros da cadeia).
  # Para membros do time (sem evolutions no DB), busca pelo nome via API.
  def line_tier_for(pokemon)
    names = evolution_chain_names(pokemon)
    return :F if names.empty?

    tiers = names.filter_map { |n| settings.rating_source.rating_for(n)&.to_sym }
    tiers.empty? ? :F : tier_max(tiers)
  end

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity
  def evolution_chain_names(pokemon)
    return pokemon.evolutions.map(&:name) if pokemon.evolutions.any?

    resolved = settings.api.detail(pokemon.name) || settings.api.find(pokemon.name)
    chain = resolved&.evolutions
    chain && !chain.empty? ? chain.map(&:name) : [pokemon.name]
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity

  # rubocop:disable Lint/UselessConstantScoping
  TIER_ORDER = %i[F D C B A S].freeze
  # rubocop:enable Lint/UselessConstantScoping

  def tier_max(tiers)
    tiers.max_by { |t| TIER_ORDER.index(t) || 0 }
  end

  # Custo total derivado do time atual.
  def team_total_cost(team)
    team.sum do |member|
      restricted = settings.api.evolution_restricted?(member.name)
      lt = line_tier_for(member)
      TeamBudget.cost_for(line_tier: lt.to_s, restricted: restricted)
    end
  end

  # Contagem de membros de linha S no time.
  def team_s_count(team)
    team.count { |member| line_tier_for(member) == :S }
  end

  def pokemon_cost(pokemon, line_tier)
    restricted = settings.api.evolution_restricted?(pokemon.name)
    TeamBudget.cost_for(line_tier: line_tier.to_s, restricted: restricted)
  end

  def budget_notice(current_cost, new_cost)
    return if TeamBudget.fits?(current_total: current_cost, new_cost: new_cost)

    "Orçamento insuficiente para adicionar este Pokémon."
  end

  def remove_team_member # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    if params[:id]
      member = settings.team.all(current_user).find { |poke| poke.id.to_s == params[:id].to_s }
      result = settings.team_strategy.remove_member(current_user, params[:id])
      if result == false && member&.fainted?
        @notice = "Pokémon derrotado — cure antes de remover"
        @notice_kind = :error
        fragment = render_team_fragment_with_notice
        return "#{fragment}#{oob_pokemon_list}#{oob_nav_badge}"
      end
    end
    settings.battle.invalidate(current_user)
    fragment = render_team_fragment_with_notice
    "#{fragment}#{oob_pokemon_list}#{oob_nav_badge}"
  end # rubocop:enable Metrics/AbcSize, Metrics/MethodLength

  def move_team_member
    settings.team.move(current_user, params[:id], params[:new_slot].to_i)
    settings.battle.invalidate(current_user)
    render_team_fragment_with_notice
  end

  def heal_team
    return journey_gate_notice unless settings.journey.started?(current_user)

    @result = settings.heal.heal(current_user)
    render_result_notice(@result)
  end

  def buy_from_mart
    return journey_gate_notice unless settings.journey.started?(current_user)

    @result = settings.mart.buy(current_user, params[:item_name], params[:quantity].to_i)
    render_mart_result_notice(@result)
  end

  def sell_from_mart
    return journey_gate_notice unless settings.journey.started?(current_user)

    @result = settings.mart.sell(current_user, params[:item_name], params[:quantity].to_i)
    render_mart_result_notice(@result)
  end

  def render_mart_result_notice(result)
    @notice = result[:notice]
    @notice_kind = result[:kind]
    "#{render_team_fragment_with_notice}#{oob_mart_modal}"
  end

  def oob_mart_modal
    erb(:_mart_modal, layout: false).sub('id="mart-modal"', 'id="mart-modal" hx-swap-oob="outerHTML"')
  end

  def render_result_notice(result)
    @notice = result[:notice]
    @notice_kind = result[:kind]
    render_team_fragment_with_notice
  end

  def save_team_moves
    member = team_manage_context(params[:id])
    @notice = params[:draft] ? preview_member_moves(member) : persist_member_moves(member)
    @notice_kind = :error if @notice
    @team = settings.team.all(current_user)
    erb :team_manage, layout: false
  end

  def persist_member_moves(member)
    settings.team_strategy.save_moves(
      current_user, member, Array(params[:moves]), @available_moves
    )
  end

  def preview_member_moves(member)
    selection, notice = settings.team_strategy.preview_move(
      member, Array(params[:moves]), params[:toggle].to_s, @available_moves
    )
    (@draft_moves ||= {})[member.id] = selection if member
    notice
  end
end
# rubocop:enable Metrics/ModuleLength

module ServerTeamItemActions
  private

  def save_team_item
    member = team_manage_context(params[:id])
    @notice = settings.team_strategy.assign_item(current_user, member, params[:item_name].to_s)
    reload_manage_state
    erb :team_manage, layout: false
  end
end

module ServerTeamHeldActions
  private

  def save_team_held_item
    member = team_manage_context(params[:id])
    @notice = settings.team_strategy.assign_held_item(current_user, member, params[:item_name].to_s)
    reload_manage_state
    erb :team_manage, layout: false
  end
end

module ServerTeamEvolutionActions
  private

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity
  def use_stone
    member = team_member_by_id(params[:id])
    return member_not_found_notice unless member
    return evolution_modal_error(member, "#{member.name} está derrotado e não pode evoluir agora.") if member.fainted?

    stone = params[:item_name].to_s
    return evolution_modal_error(member, "Escolha uma pedra de evolução para usar.") unless stone_item?(stone)
    unless settings.inventory.count(current_user, stone).positive?
      return evolution_modal_error(member, stone_not_owned_message(stone))
    end

    stage = stone_stage_for(member, stone)
    return evolution_modal_error(member, no_stone_stage_message(member, stone)) unless stage

    target = settings.api.find(stage[:name]) || settings.api.detail(stage[:name])
    return evolution_modal_error(member, no_stone_stage_message(member, stone)) unless target

    unless settings.team.evolve(current_user, member.id, target)
      return evolution_modal_error(member, "A evolução de #{member.name} já está no seu time.")
    end

    settings.inventory.use(current_user, stone, 1)
    render_evolution_modal(member, "#{member.name} evoluiu para #{target.name}!", :success)
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity

  def open_evolution_modal
    member = team_member_by_id(params[:id])
    return member_not_found_notice unless member

    render_evolution_modal(member, nil, nil)
  end

  def close_evolution_modal
    ""
  end

  def team_member_by_id(member_id)
    settings.team.all(current_user).find { |poke| poke.id.to_s == member_id.to_s }
  end

  def stone_item?(name)
    item = ItemCatalog.find(name)
    item && item.category == "stone"
  end

  def stone_stage_for(member, stone)
    settings.api.stone_evolutions(member.number).find { |stage| stage[:item] == stone }
  end

  def render_evolution_modal(member, notice, kind) # rubocop:disable Metrics/AbcSize
    @member = settings.team.all(current_user).find { |poke| poke.id.to_s == member.id.to_s } || member
    @notice = notice
    @notice_kind = kind
    @evolutions = settings.api.stone_evolutions(@member.number)
    @inventory_qty = @evolutions.to_h { |evo| [evo[:item], settings.inventory.count(current_user, evo[:item])] }
    erb :_evolution_modal, layout: false
  end

  def evolution_modal_error(member, message)
    render_evolution_modal(member, message, :error)
  end

  def stone_not_owned_message(stone)
    item = ItemCatalog.find(stone)
    "Você não tem #{item&.display_name || stone} no inventário."
  end

  def no_stone_stage_message(member, stone)
    item = ItemCatalog.find(stone)
    "#{item&.display_name || stone} não evolui #{member.name}."
  end

  def member_not_found_notice
    @notice = "Membro não encontrado."
    @notice_kind = :error
    render_team_fragment_with_notice
  end
end

module ServerJourneyActions
  private

  def restart_journey
    settings.team_strategy.reset(current_user)
    settings.wallet.set(current_user, SaldoInicial::INITIAL_BALANCE)
    settings.battle.invalidate(current_user)
    return redirect "/" unless htmx_request?

    render_restart_fragment
  end

  def render_restart_fragment
    @notice = "Jornada recomeçada. Monte seu time inicial de 6 Pokémon."
    @notice_kind = :info
    content = render_team_fragment_with_notice
    content += oob_pokemon_list if list_state_present?
    content += oob_nav_badge
    content
  end

  def list_state_present?
    %w[offset q type generation tier cost cost_max sort].any? { |k| params.key?(k) || params.key?(k.to_sym) }
  end
end

module ServerBattleActions
  private

  def render_battle
    content = prepare_battle_fragment
    return content if htmx_request?

    @battle_content = content
    erb :battle_page
  end

  def prepare_battle_fragment
    gate = battle_gate_fragment
    return gate if gate

    result = settings.battle.prepare(current_user)
    return empty_team_fragment if result[:reason] == :empty_team
    return battle_error_fragment unless result[:engine]

    @engine = result[:engine]
    expose_new_confront_state
    erb :battle, layout: false
  end

  def expose_new_confront_state
    @can_new_confront = settings.journey.battle_ready?(current_user)
    @game_over = settings.journey.game_over?(current_user)
  end

  def battle_gate_fragment
    return journey_gate_fragment unless settings.journey.started?(current_user)
    return game_over_fragment if settings.journey.game_over?(current_user)
    return defeated_gate_fragment unless settings.journey.battle_ready?(current_user)

    nil
  end

  def journey_gate_notice
    @notice = "Monte seu time inicial de 6 Pokémon para iniciar a jornada."
    render_team_fragment_with_notice
  end

  def journey_gate_fragment
    @message = "Monte seu time inicial de 6 Pokémon para iniciar a jornada."
    erb :battle, layout: false
  end

  def defeated_gate_fragment
    @message = "Seu time está todo derrotado. Cure seus Pokémon no Poke Center."
    @gate_cta = { href: "/", label: "Ir para o Poke Center" }
    @gate_disabled_cta = { label: "Novo confronto", title: "Recupere seus pokémons no Poke Center para batalhar." }
    erb :battle, layout: false
  end

  def game_over_fragment
    @message = "Game Over — seu time está derrotado e você não tem dinheiro para curar no Poke Center."
    @gate_cta = { href: "/", label: "Vender itens no Poke Mart" }
    @gate_action = { href: "/journey/restart", label: "Recomeçar jornada" }
    erb :battle, layout: false
  end

  def prepare_team_fragment_data
    load_journey_state
    @team = settings.team.all(current_user)
    @team_size = @team.size
    @team_cost = team_total_cost(@team)
    @team_budget = TeamBudget::BUDGET
    @team_s_count = team_s_count(@team)
    @team_types = team_types_map(@team)
    @member_levels = member_levels_map(@team)
    center_data
    mart_data
  end

  def load_journey_state
    journey = settings.journey
    @journey_started = journey.started?(current_user)
    @can_battle = journey.battle_ready?(current_user)
    @game_over = journey.game_over?(current_user)
  end

  def render_team_fragment_with_notice
    prepare_team_fragment_data
    erb :team, layout: false
  end

  def htmx_request?
    request.env["HTTP_HX_REQUEST"] == "true"
  end

  def empty_team_fragment
    @message = "Forme seu time para batalhar."
    erb :battle, layout: false
  end

  def battle_error_fragment
    @message = "Não foi possível preparar a batalha. Tente novamente."
    erb :battle, layout: false
  end

  def advance_battle
    result = settings.battle.resolve(current_user)
    return erb :battle, layout: false unless result

    expose_battle_result(result)
    erb :battle, layout: false
  end

  def new_confront_battle
    gate = battle_gate_fragment
    return gate if gate

    result = settings.battle.new_confront(current_user)
    return empty_team_fragment if result[:reason] == :empty_team
    return battle_error_fragment unless result[:engine]

    @engine = result[:engine]
    expose_new_confront_state
    erb :battle, layout: false
  end

  def expose_battle_result(result)
    @engine = result[:engine]
    @xp_gained = result[:xp_gained]
    @money_gained = result[:money_gained]
    @evolution_news = result[:evolution_news]
    @learned_news = result[:learned_news]
    expose_new_confront_state
  end
end

module PokemonRoutes
  def self.registered(app)
    register_index(app)
    register_pokemons(app)
    register_pokemon(app)
    register_pokemon_close(app)
    register_pokemon_detail(app)
  end

  def self.register_index(app)
    app.get("/") { render_index }
  end

  def self.register_pokemons(app)
    app.get("/pokemons") { render_pokemons_list }
  end

  def self.register_pokemon(app)
    app.get("/pokemon") { render_pokemon_fragment }
  end

  def self.register_pokemon_close(app)
    app.get("/pokemon/close") { erb :pokemon_close, layout: false }
  end

  def self.register_pokemon_detail(app)
    app.get("/pokemon/:poke_id") { render_pokemon_detail }
  end
end

module TeamRoutes
  # rubocop:disable Metrics/MethodLength
  def self.registered(app)
    register_team(app)
    register_heal(app)
    register_center(app)
    register_mart(app)
    register_team_manage(app)
    register_add_member(app)
    register_remove_member(app)
    register_move_member(app)
    register_save_moves(app)
    register_save_item(app)
    register_save_held_item(app)
    register_use_stone(app)
  end
  # rubocop:enable Metrics/MethodLength

  def self.register_team(app)
    app.get("/team") { render_team }
  end

  def self.register_heal(app)
    app.post("/team/heal") { heal_team }
  end

  def self.register_team_manage(app)
    app.get("/team/manage") { render_team_manage }
    app.get("/team/:id/manage") { render_team_manage_member }
    app.get("/team/manage/close") { close_team_manage }
  end

  def self.register_center(app)
    app.get("/team/center") { render_team_center }
    app.get("/team/center/close") { close_team_center }
  end

  def self.register_mart(app)
    app.get("/team/mart") { render_team_mart }
    app.get("/team/mart/close") { close_team_mart }
  end

  def self.register_add_member(app)
    app.post("/team") { add_team_member }
  end

  def self.register_remove_member(app)
    app.delete("/team") { remove_team_member }
  end

  def self.register_move_member(app)
    app.post("/team/:id/move") { move_team_member }
  end

  def self.register_save_moves(app)
    app.post("/team/:id/moves") { save_team_moves }
  end

  def self.register_save_item(app)
    app.post("/team/:id/item") { save_team_item }
  end

  def self.register_save_held_item(app)
    app.post("/team/:id/held-item") { save_team_held_item }
  end

  def self.register_use_stone(app)
    app.post("/team/:id/evolve") { use_stone }
    app.get("/team/:id/evolution") { open_evolution_modal }
    app.get("/team/:id/evolution/close") { close_evolution_modal }
  end
end

module MartRoutes
  def self.registered(app)
    register_buy(app)
  end

  def self.register_buy(app)
    app.post("/mart/buy") { buy_from_mart }
    app.post("/mart/sell") { sell_from_mart }
  end
end

module JourneyRoutes
  def self.registered(app)
    register_restart(app)
  end

  def self.register_restart(app)
    app.post("/journey/restart") { restart_journey }
  end
end

module ServerHistoryActions
  private

  def result_label(result)
    { "win" => "Vitória", "draw" => "Empate", "lose" => "Derrota" }.fetch(result, result)
  end

  def opponent_names(team)
    team.map { |member| member[:name] }.join(", ")
  end

  def render_history
    load_history_data
    return erb :history, layout: false if htmx_request?

    erb :history_page
  end

  def load_history_data
    history = settings.battle_history
    @current_user = current_user
    @rank = history.ranking
    @stats = history.stats(current_user)
    @position = history.rank_position(current_user)
    @recent = history.recent(current_user)
  end
end

module BattleRoutes
  def self.registered(app)
    register_open(app)
    register_play(app)
    register_new_confront(app)
  end

  def self.register_open(app)
    app.get("/battle") { render_battle }
  end

  def self.register_play(app)
    app.post("/battle/play") { advance_battle }
  end

  def self.register_new_confront(app)
    app.post("/battle/new") { new_confront_battle }
  end
end

module HistoryRoutes
  def self.registered(app)
    register_history(app)
  end

  def self.register_history(app)
    app.get("/history") { render_history }
  end
end

module HealthRoutes
  def self.registered(app)
    register_health(app)
  end

  def self.register_health(app)
    app.get("/health") do
      content_type :json
      { status: "ok" }.to_json
    end
  end
end

module ErrorHandling
  def self.registered(app)
    app.error 500 do
      logger.error "#{env['sinatra.error'].class}: #{env['sinatra.error'].message}" if env["sinatra.error"]
      @message = "Algo deu errado. Tente novamente."
      status(htmx_request? ? 200 : 500)
      erb :error, layout: false
    end
  end
end

module ServerServices
  module_function

  def wire(app, deps) # rubocop:disable Metrics/AbcSize
    app.set :heal, HealService.new(team: deps[:team], progression: deps[:progression], wallet: deps[:wallet])
    app.set :mart, MartService.new(
      inventory: deps[:inventory], wallet: deps[:wallet],
      rotation_source: lambda { |user_id|
        battle_count = deps[:battle_history].stats(user_id)[:total]
        StoneRotation.new(user_id, battle_count).stones
      }
    )
    app.set :battle, BattleService.new(dependencies: deps)
    app.set :team_strategy, TeamService.new(**strategy_dependencies(deps))
  end

  def strategy_dependencies(deps)
    {
      api: deps[:api], team: deps[:team], progression: deps[:progression],
      inventory: deps[:inventory], wallet: deps[:wallet]
    }
  end
end

class Server < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  # rubocop:disable Metrics/BlockLength
  configure do
    enable :logging, :sessions
    set :session_secret, ENV["SESSION_SECRET"] ||
                         "706f6b656465782d6465762d7365637265742d30313233343536373839616263646566"
    set :bind, "0.0.0.0"
    set :port, 3000
    set :views, "views"
    set :team, TeamRepository.new
    set :progression, ProgressionRepository.new
    set :battles, BattleRegistry.new
    set :battle_history, BattleRepository.new
    set :wallet, WalletRepository.new
    set :api, PokeApi.instance
    set :rating_source, PokemonRatingCache.new(
      fetcher: ->(name) { settings.api.detail(name) || settings.api.find(name) },
      moves_fetcher: ->(number) { settings.api.moves_for(number) },
      path: ENV["POKERATING_CACHE_PATH"] || "tmp/pokemon_rating_cache.json"
    )
    set :inventory, InventoryRepository.new
    set :user_state, UserStateRepository.new
    set :journey, JourneyService.new(
      user_state: settings.user_state, team: settings.team,
      wallet: settings.wallet,
      heal_preview: ->(user_id) { settings.heal.preview_cost(user_id) }
    )
    deps = {
      api: -> { settings.api }, battles: settings.battles, team: settings.team,
      progression: settings.progression, battle_history: settings.battle_history,
      wallet: settings.wallet, inventory: settings.inventory
    }
    ServerServices.wire(self, deps)
  end
  # rubocop:enable Metrics/BlockLength

  before do
    # Healthcheck puro: `/health` não deve tocar o banco (health do banco é
    # responsabilidade do `pg_isready` no docker-compose.yml), nem a PokéAPI/rede.
    next if request.path_info == "/health"

    session[:user_id] = params["as"] if params["as"]
    session[:user_id] ||= SecureRandom.uuid
    @team_size = settings.team.all(current_user).size
  end

  after do
    ConnectionRegistry.release_current_thread!
  end

  include ServerCommon
  include ServerListActions
  include ServerSearchHintActions
  include ServerTeamActions
  include ServerTeamItemActions
  include ServerTeamHeldActions
  include ServerTeamEvolutionActions
  include ServerJourneyActions
  include ServerBattleActions
  include ServerHistoryActions

  register PokemonRoutes
  register TeamRoutes
  register MartRoutes
  register JourneyRoutes
  register BattleRoutes
  register HistoryRoutes
  register HealthRoutes
  register ErrorHandling

  run! if $PROGRAM_NAME == app_file
end
