# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/pokemon_list_presenter"

class PokemonListPresenterTest < Minitest::Test
  def build(overrides = {})
    { params: {}, session_filters: nil }.merge(overrides)
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

  # --- contrato ---

  def test_requires_params_and_session_filters
    assert_raises(ArgumentError) { PokemonListPresenter.new(params: {}) }
    assert_raises(ArgumentError) { PokemonListPresenter.new(session_filters: nil) }
  end
end
