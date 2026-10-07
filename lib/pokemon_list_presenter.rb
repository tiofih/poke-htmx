# frozen_string_literal: true

require_relative "gateways/poke_api_types"
require_relative "parallelizer"
require_relative "team_budget"

# 0098 C1/C2 — montagem da pagina de lista de Pokemon, pura (sem DB, sem
# session, sem globals): recebe deps ja resolvidas na rota e devolve locals +
# session_write — a escrita na session fica na rota.
class PokemonListPresenter # rubocop:disable Metrics/ClassLength
  PRESENCE_KEYS = %w[type generation tier cost cost_max sort team].freeze
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
  PAGE_SIZE = 36
  FIRST_PAGE_COMMONS = PAGE_SIZE - STARTER_SLUGS.size
  SCAN_BATCH = 24
  EMPTY_LIST_NOTICE = "Não foi possível carregar a lista de Pokémon."
  DEPS = %i[params session_filters offset q api team_names team_full line_tier
            tier_order notice notice_kind].freeze

  # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
  def initialize(data)
    missing = DEPS - data.keys
    raise ArgumentError, "dados faltando: #{missing.join(', ')}" unless missing.empty?

    @params = data.fetch(:params)
    @session_filters = data.fetch(:session_filters)
    @offset = data.fetch(:offset)
    @q = data.fetch(:q)
    @api = data.fetch(:api)
    @team_names = data.fetch(:team_names)
    @team_full = data.fetch(:team_full)
    @line_tier = data.fetch(:line_tier)
    @tier_order = data.fetch(:tier_order)
    @notice = data.fetch(:notice)
    @notice_kind = data.fetch(:notice_kind)
  end
  # rubocop:enable Metrics/MethodLength

  def filters
    @filters ||= compute_filters
  end

  # :none = sem param explicito (nada a gravar); hash = gravar (chaves string,
  # valores normalizados, nils cortados); :delete = param explicito sem filtro
  # valido sobrando.
  def session_write
    return :none unless any_filter_param_present?

    written = {
      "type" => filters[:type], "generation" => filters[:generation],
      "tier" => filters[:tier], "cost_max" => filters[:cost_max],
      "sort" => filters[:sort], "team" => filters[:team_filter]
    }.compact
    written.empty? ? :delete : written
  end

  # Locals do fragmento views/pokemon_list.erb (chaves e ordem identicas ao
  # builder original que vivia no ServerCommon).
  def list_locals
    compute_page
    {
      items: @items, starters: @starters, offset: @offset, q: @q, type: filters[:type],
      generation: filters[:generation], tier: filters[:tier], cost_max: filters[:cost_max],
      sort: filters[:sort], team_filter: filters[:team_filter], current_page: @current_page,
      prev_offset: @prev_offset, next_offset: @next_offset, search_hint: @search_hint,
      notice: @notice, notice_kind: @notice_kind, pokemon_costs: @pokemon_costs,
      team_full: @team_full, team_names: @team_names
    }
  end

  # Locals do partial views/_filter_controls.erb (chaves e ordem identicas ao
  # builder original que vivia no ServerCommon).
  def filter_controls_locals
    compute_page
    {
      cost_max: filters[:cost_max], generation: filters[:generation], items: @items, q: @q,
      sort: filters[:sort], starters: @starters, team_filter: filters[:team_filter],
      tier: filters[:tier], type: filters[:type]
    }
  end

  # O override de erro so existe quando a pagina vem vazia sem busca/filtro —
  # senao o aviso que a rota ja tinha (@notice) permanece.
  def notice
    compute_page
    @notice
  end

  # Nunca modificado pela montagem; leitura direta.
  attr_reader :notice_kind

  private

  # Ordem de compute identica a load_pokemon_page original: starters ->
  # pagina -> itens -> search_hint -> notice -> custos.
  def compute_page
    return if @page_built

    @starters = starters_visible? ? load_starters : []
    build_page
    @items = Parallelizer.map(@page_names) { |name| [name, @api.find(name)] }
    @search_hint = search_hint(@q) if !@q.empty? && @items.empty?
    @notice = EMPTY_LIST_NOTICE if notice_needed?
    build_pokemon_costs
    @page_built = true
  end

  def notice_needed?
    @page_names.empty? && @q.empty? && !filter_active? && !sort_active?
  end

  def starters_visible?
    @q.empty? && @offset.zero? && !filter_active? && !sort_active?
  end

  def filter_active?
    %i[type generation tier cost_max team_filter].any? { |key| filters[key] }
  end

  def sort_active?
    !filters[:sort].nil?
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
    if filters[:sort]
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

  # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
  def sort_names(names)
    infos = Parallelizer.map(names) do |name|
      pokemon = @api.detail(name) || @api.find(name)
      # guard nil pokemon (should not happen for base forms)
      tier = pokemon ? @line_tier.call(pokemon).to_s : "F"
      restricted = @api.evolution_restricted?(name)
      cost = TeamBudget.cost_for(line_tier: tier, restricted: restricted)
      [name, tier, cost]
    end
    case filters[:sort]
    when "cost_asc"
      infos.sort_by { |_n, _t, c| c }.map(&:first)
    when "cost_desc"
      infos.sort_by { |_n, _t, c| -c }.map(&:first)
    when "tier_desc"
      infos.sort_by { |_n, t, _c| -@tier_order.index(t.to_sym) }.map(&:first)
    when "tier_asc"
      infos.sort_by { |_n, t, _c| @tier_order.index(t.to_sym) }.map(&:first)
    else
      names
    end
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength

  def type_pokemon_set
    @type_pokemon_set ||= Set.new(@api.pokemon_names_by_type(filters[:type]))
  end

  # NOTA PERF 0057-4c: tipo usa endpoint /type (1 fetch_type_json) + interseção Set — rápido (~<1s/1300 nomes).
  # Geração/tier/cost ainda varrem candidatos em lotes 24 com base_form? + detail (+ line_tier) por item.
  # Primeira carga fria lê PersistentJsonStore (~60s/300MB em dev, quente ~0.01s — sessao 0050 C4-b);
  # se p95 rock ainda alto após 4b é warm-up frio, não implementação. Próximo passo: índice
  # por geração/tier similar a /type ou cap max_candidates (fora deste hotfix, limitação aceita).

  # rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
  def filtered_base_forms(batch)
    forms = Parallelizer.map(batch) { |name| [name, @api.base_form?(name)] }
    base_names = forms.select { |_name, is_base| is_base }.map(&:first)
    filtered = base_names
    if filters[:type]
      type_set = type_pokemon_set
      filtered = filtered.select { |name| type_set.include?(name) }
    end
    if filters[:generation]
      gen = Parallelizer.map(filtered) { |name| [name, @api.generation_for(name)] }
      filtered = gen.select { |_name, gen_val| gen_val == filters[:generation] }.map(&:first)
    end
    if filters[:tier] || filters[:cost_max]
      tier_cost = Parallelizer.map(filtered) do |name|
        pokemon = @api.detail(name) || @api.find(name)
        next [name, nil, nil] unless pokemon

        tier = @line_tier.call(pokemon).to_s
        restricted = @api.evolution_restricted?(pokemon.name)
        cost = TeamBudget.cost_for(line_tier: tier, restricted: restricted)
        [name, tier, cost]
      end
      tier_cost = tier_cost.select { |_name, tier_val, _cost| tier_val == filters[:tier] } if filters[:tier]
      tier_cost = tier_cost.select { |_name, _t, cost| cost && cost <= filters[:cost_max] } if filters[:cost_max]
      filtered = tier_cost.map(&:first)
    end
    filtered = filter_by_team(filtered) if filters[:team_filter]
    filtered
  end
  # rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength

  def filter_by_team(names)
    member_set = Set.new(@team_names)
    if filters[:team_filter] == "in"
      names.select { |name| member_set.include?(name) }
    else
      names.reject { |name| member_set.include?(name) }
    end
  end

  def common_candidates
    names = @api.fetch_all_names.to_a
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

  def load_starters
    Parallelizer.map(STARTER_SLUGS) { |name| [name, @api.find(name)] }
  end

  def build_pokemon_costs
    @pokemon_costs = {}
    ((@starters || []) + (@items || [])).each do |name, pokemon|
      next unless pokemon

      @pokemon_costs[name] = pokemon_cost_info(pokemon)
    end
  end

  def pokemon_cost_info(pokemon)
    tier = @line_tier.call(pokemon)
    restricted = @api.evolution_restricted?(pokemon.name)
    cost = TeamBudget.cost_for(line_tier: tier.to_s, restricted: restricted)
    { tier: tier, cost: cost, restricted: restricted }
  end

  def search_hint(query)
    match = first_search_match(query)
    return nil unless match

    return { kind: :starter, name: match } if STARTER_SLUGS.include?(match)

    base = base_form_for(match)
    base ? { kind: :evolution, name: match, base: base.name } : { kind: :generic, name: match }
  end

  def first_search_match(query)
    @api.fetch_all_names.to_a.find { |name| name.downcase.include?(query.downcase) }
  end

  def base_form_for(match)
    @api.detail(match)&.evolutions&.first
  end

  def compute_filters
    explicit = any_filter_param_present?
    {
      type: field("type", "type", explicit) { |v| normalized_type(v) },
      generation: field("generation", "generation", explicit) { |v| normalized_generation(v) },
      tier: field("tier", "tier", explicit) { |v| normalized_tier(v) },
      cost_max: cost_field(explicit),
      sort: field("sort", "sort", explicit) { |v| normalized_sort(v) },
      team_filter: field("team", "team", explicit) { |v| normalized_team(v) }
    }
  end

  # param explicito vale para o campo inteiro; sem param, a session inteira
  # restaura (nenhum campo mistura os dois — contrato da rota).
  def field(param_key, session_key, explicit)
    if explicit
      param_present?(param_key) ? yield(param(param_key)) : nil
    else
      stored = stored_value(session_key)
      stored ? yield(stored) : nil
    end
  end

  def cost_field(explicit)
    if explicit
      return nil unless param_present?("cost_max") || param_present?("cost")

      normalized_cost_max(param("cost_max") || param("cost"))
    else
      stored = stored_value("cost_max") || stored_value("cost")
      stored ? normalized_cost_max(stored) : nil
    end
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

  def stored_value(key)
    return nil unless @session_filters

    @session_filters[key] || @session_filters[key.to_sym]
  end

  def param(key)
    @params[key.to_sym] || @params[key]
  end

  def param_present?(key)
    @params.key?(key) || @params.key?(key.to_sym)
  end

  def any_filter_param_present?
    PRESENCE_KEYS.any? { |key| param_present?(key) }
  end
end
