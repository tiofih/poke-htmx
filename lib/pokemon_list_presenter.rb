# frozen_string_literal: true

require_relative "gateways/poke_api_types"

# 0098 C1/C2 — montagem da pagina de lista de Pokemon, pura (sem DB, sem
# session, sem globals): recebe deps ja resolvidas na rota e devolve locals +
# session_write — a escrita na session fica na rota.
class PokemonListPresenter
  PRESENCE_KEYS = %w[type generation tier cost cost_max sort team].freeze

  def initialize(data)
    missing = %i[params session_filters] - data.keys
    raise ArgumentError, "dados faltando: #{missing.join(', ')}" unless missing.empty?

    @data = data
    @params = data.fetch(:params)
    @session_filters = data.fetch(:session_filters)
  end

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

  private

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
