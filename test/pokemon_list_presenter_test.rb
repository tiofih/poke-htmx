# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/pokemon_list_presenter"

# Fake de PokéAPI para a montagem da página: nomes, details, tipos,
# gerações, restrição de evolução e quais nomes são forma base.
PresenterFakePokemon = Struct.new(:name, :evolutions, keyword_init: true)

class PresenterFakeApi
  def initialize(names: [], details: {}, types: {}, generations: {}, restricted: [], base_forms: {})
    @names = names
    @details = details
    @types = types
    @generations = generations
    @restricted = restricted
    @base_forms = base_forms
  end

  def fetch_all_names
    @names
  end

  def find(name)
    @details[name] || PresenterFakePokemon.new(name: name)
  end

  def detail(name)
    @details[name]
  end

  def base_form?(name)
    @base_forms.fetch(name, true)
  end

  def pokemon_names_by_type(type)
    @types.fetch(type, [])
  end

  def generation_for(name)
    @generations[name]
  end

  def evolution_restricted?(name)
    @restricted.include?(name)
  end
end

class PokemonListPresenterTest < Minitest::Test
  def build(overrides = {})
    {
      params: {}, session_filters: nil, offset: 0, q: "", api: PresenterFakeApi.new,
      team_names: [], team_full: false, line_tier: ->(_pokemon) { :C },
      tier_order: %i[F D C B A S], notice: nil, notice_kind: nil
    }.merge(overrides)
  end

  def commons(count)
    (1..count).map { |i| "pk#{i}" }
  end

  # --- C1: normalizacao dos filtros ---

  def test_filters_are_all_nil_without_params_and_session
    assert_equal(
      { type: nil, generation: nil, tier: nil, cost_max: nil, sort: nil, team_filter: nil },
      PokemonListPresenter.new(**build).filters
    )
  end

  def test_explicit_params_are_normalized
    presenter = PokemonListPresenter.new(
      **build(params: { "type" => "  Grass ", "generation" => "3", "tier" => "s",
                        "cost_max" => "10", "sort" => "tier_asc", "team" => "IN" })
    )

    assert_equal(
      { type: "grass", generation: 3, tier: "S", cost_max: 10, sort: "tier_asc", team_filter: "in" },
      presenter.filters
    )
  end

  def test_invalid_param_values_become_nil
    presenter = PokemonListPresenter.new(
      **build(params: { "type" => "banana", "generation" => "12", "tier" => "Z",
                        "cost_max" => "-1", "sort" => "nope", "team" => "yes" })
    )

    assert_equal({}, presenter.filters.compact)
  end

  def test_cost_alias_param_maps_to_cost_max
    presenter = PokemonListPresenter.new(**build(params: { "cost" => "7" }))

    assert_equal 7, presenter.filters[:cost_max]
  end

  def test_symbol_key_params_also_work
    presenter = PokemonListPresenter.new(**build(params: { type: "water" }))

    assert_equal "water", presenter.filters[:type]
  end

  def test_filters_restored_from_session_when_no_explicit_params
    presenter = PokemonListPresenter.new(
      **build(session_filters: { "type" => "fire", "generation" => 2 })
    )

    assert_equal "fire", presenter.filters[:type]
    assert_equal 2, presenter.filters[:generation]
    assert_nil presenter.filters[:tier]
  end

  def test_session_symbol_keys_also_restored
    presenter = PokemonListPresenter.new(**build(session_filters: { tier: "A" }))

    assert_equal "A", presenter.filters[:tier]
  end

  def test_explicit_params_ignore_session_for_every_field
    # comportamento da rota: qualquer param explicito desliga o restore inteiro
    presenter = PokemonListPresenter.new(
      **build(params: { "type" => "grass" }, session_filters: { "generation" => 3 })
    )

    assert_equal "grass", presenter.filters[:type]
    assert_nil presenter.filters[:generation]
  end

  # --- C1: session_write (a escrita fica na rota) ---

  def test_session_write_is_none_without_explicit_params
    assert_equal :none, PokemonListPresenter.new(**build).session_write
    assert_equal :none,
                 PokemonListPresenter.new(**build(session_filters: { "type" => "fire" })).session_write
  end

  def test_session_write_hash_with_normalized_values_and_string_keys
    presenter = PokemonListPresenter.new(
      **build(params: { "type" => "Grass", "generation" => "4", "team" => "out" })
    )

    assert_equal({ "type" => "grass", "generation" => 4, "team" => "out" }, presenter.session_write)
  end

  def test_session_write_is_delete_when_explicit_params_yield_no_filters
    presenter = PokemonListPresenter.new(**build(params: { "type" => "banana" }))

    assert_equal :delete, presenter.session_write
  end

  def test_session_write_is_delete_when_explicit_params_are_empty
    presenter = PokemonListPresenter.new(**build(params: { "type" => "" }))

    assert_equal :delete, presenter.session_write
  end

  def test_session_write_uses_cost_alias_key_as_cost_max
    presenter = PokemonListPresenter.new(**build(params: { "cost" => "5" }))

    assert_equal({ "cost_max" => 5 }, presenter.session_write)
  end

  # --- C2: montagem da pagina (pagina, itens, custos, hint, sort, filtros) ---

  def test_list_locals_has_the_exact_keys_of_the_fragment
    locals = PokemonListPresenter.new(**build).list_locals

    assert_equal(
      %i[items starters offset q type generation tier cost_max sort team_filter
         current_page prev_offset next_offset search_hint notice notice_kind
         pokemon_costs team_full team_names],
      locals.keys
    )
  end

  def test_filter_controls_locals_has_the_exact_keys
    locals = PokemonListPresenter.new(**build).filter_controls_locals

    assert_equal(%i[cost_max generation items q sort starters team_filter tier type], locals.keys)
  end

  def test_first_page_shows_common_window_with_starters
    api = PresenterFakeApi.new(names: commons(40))
    locals = PokemonListPresenter.new(**build(api: api)).list_locals

    assert_equal commons(PokemonListPresenter::FIRST_PAGE_COMMONS), locals[:items].map(&:first)
    assert_equal PokemonListPresenter::STARTER_SLUGS.size, locals[:starters].size
    assert_equal 1, locals[:current_page]
    assert_nil locals[:prev_offset]
    assert_equal PokemonListPresenter::FIRST_PAGE_COMMONS, locals[:next_offset]
  end

  def test_second_page_continues_commons_without_starters
    api = PresenterFakeApi.new(names: commons(40))
    offset = PokemonListPresenter::FIRST_PAGE_COMMONS
    locals = PokemonListPresenter.new(**build(api: api, offset: offset)).list_locals

    assert_equal commons(40)[offset..], locals[:items].map(&:first)
    assert_empty locals[:starters]
    assert_equal 2, locals[:current_page]
    assert_equal 0, locals[:prev_offset]
    assert_nil locals[:next_offset]
  end

  def test_filter_active_pagination_uses_full_page_steps
    names = commons(100)
    api = PresenterFakeApi.new(names: names, types: { "grass" => names })
    locals = PokemonListPresenter.new(
      **build(api: api, offset: 36, params: { "type" => "grass" })
    ).list_locals

    assert_equal names[36, 36], locals[:items].map(&:first)
    assert_equal 2, locals[:current_page]
    assert_equal 0, locals[:prev_offset]
    assert_equal 72, locals[:next_offset]
    assert_empty locals[:starters]
  end

  def test_notice_error_when_page_empty_without_query_or_filters
    locals = PokemonListPresenter.new(**build(api: PresenterFakeApi.new)).list_locals

    assert_equal "Não foi possível carregar a lista de Pokémon.", locals[:notice]
  end

  def test_no_notice_when_query_active
    locals = PokemonListPresenter.new(**build(api: PresenterFakeApi.new, q: "zzz")).list_locals

    assert_nil locals[:notice]
  end

  def test_search_hint_kind_starter
    api = PresenterFakeApi.new(names: ["bulbasaur"], base_forms: { "bulbasaur" => false })
    locals = PokemonListPresenter.new(**build(api: api, q: "bulb")).list_locals

    assert_empty locals[:items]
    assert_equal({ kind: :starter, name: "bulbasaur" }, locals[:search_hint])
  end

  def test_search_hint_kind_evolution
    details = {
      "charmeleon" => PresenterFakePokemon.new(
        name: "charmeleon", evolutions: [PresenterFakePokemon.new(name: "charizard")]
      )
    }
    api = PresenterFakeApi.new(names: ["charmeleon"], details: details,
                               base_forms: { "charmeleon" => false })
    locals = PokemonListPresenter.new(**build(api: api, q: "char")).list_locals

    assert_equal({ kind: :evolution, name: "charmeleon", base: "charizard" }, locals[:search_hint])
  end

  def test_search_hint_kind_generic_without_detail
    api = PresenterFakeApi.new(names: ["pikachu"], base_forms: { "pikachu" => false })
    locals = PokemonListPresenter.new(**build(api: api, q: "pika")).list_locals

    assert_equal({ kind: :generic, name: "pikachu" }, locals[:search_hint])
  end

  def test_costs_include_starters_and_items_with_tier_and_restriction
    tier_by_name = { "bulbasaur" => :S, "pk1" => :A }
    line_tier = ->(pokemon) { tier_by_name.fetch(pokemon.name, :C) }
    api = PresenterFakeApi.new(names: commons(9), restricted: ["bulbasaur"])
    locals = PokemonListPresenter.new(**build(api: api, line_tier: line_tier)).list_locals

    assert_equal PokemonListPresenter::STARTER_SLUGS.size + 9, locals[:pokemon_costs].size
    assert_equal(
      { tier: :S, cost: TeamBudget.cost_for(line_tier: "S", restricted: true), restricted: true },
      locals[:pokemon_costs]["bulbasaur"]
    )
    assert_equal(
      { tier: :A, cost: TeamBudget.cost_for(line_tier: "A", restricted: false), restricted: false },
      locals[:pokemon_costs]["pk1"]
    )
    assert_equal(
      { tier: :C, cost: TeamBudget.cost_for(line_tier: "C", restricted: false), restricted: false },
      locals[:pokemon_costs]["pk5"]
    )
  end

  def test_sort_tier_desc_uses_injected_tier_order
    tier_by_name = { "aa" => :S, "bb" => :B, "cc" => :F }
    line_tier = ->(pokemon) { tier_by_name.fetch(pokemon.name) }
    api = PresenterFakeApi.new(names: %w[aa bb cc])
    locals = PokemonListPresenter.new(
      **build(api: api, line_tier: line_tier, params: { "sort" => "tier_desc" })
    ).list_locals

    assert_equal %w[aa bb cc], locals[:items].map(&:first)
    assert_empty locals[:starters]
  end

  def test_sort_tier_asc_uses_injected_tier_order
    tier_by_name = { "aa" => :S, "bb" => :B, "cc" => :F }
    line_tier = ->(pokemon) { tier_by_name.fetch(pokemon.name) }
    api = PresenterFakeApi.new(names: %w[aa bb cc])
    locals = PokemonListPresenter.new(
      **build(api: api, line_tier: line_tier, params: { "sort" => "tier_asc" })
    ).list_locals

    assert_equal %w[cc bb aa], locals[:items].map(&:first)
  end

  def test_team_filter_in_keeps_only_members
    api = PresenterFakeApi.new(names: %w[aa bb cc])
    locals = PokemonListPresenter.new(
      **build(api: api, team_names: ["bb"], params: { "team" => "in" })
    ).list_locals

    assert_equal ["bb"], locals[:items].map(&:first)
  end

  def test_type_filter_uses_api_type_set
    api = PresenterFakeApi.new(names: %w[aa bb cc], types: { "grass" => ["bb"] })
    locals = PokemonListPresenter.new(**build(api: api, params: { "type" => "grass" })).list_locals

    assert_equal ["bb"], locals[:items].map(&:first)
  end

  def test_generation_filter_keeps_only_that_generation
    api = PresenterFakeApi.new(names: %w[aa bb cc], generations: { "bb" => 3 })
    locals = PokemonListPresenter.new(
      **build(api: api, params: { "generation" => "3" })
    ).list_locals

    assert_equal ["bb"], locals[:items].map(&:first)
  end

  def test_passes_through_offset_q_notice_and_team
    locals = PokemonListPresenter.new(
      **build(offset: 72, q: "drag", notice: "ok", notice_kind: :info,
              team_names: ["aa"], team_full: true)
    ).list_locals

    assert_equal 72, locals[:offset]
    assert_equal "drag", locals[:q]
    assert_equal "ok", locals[:notice]
    assert_equal :info, locals[:notice_kind]
    assert_equal ["aa"], locals[:team_names]
    assert_equal true, locals[:team_full]
  end

  # --- contrato ---

  def test_requires_params_and_session_filters
    assert_raises(ArgumentError) { PokemonListPresenter.new(params: {}) }
    assert_raises(ArgumentError) { PokemonListPresenter.new(session_filters: nil) }
  end

  def test_every_dependency_is_required
    PokemonListPresenter::DEPS.each do |key|
      assert_raises(ArgumentError, "faltando #{key}") do
        PokemonListPresenter.new(build.except(key))
      end
    end
  end
end
