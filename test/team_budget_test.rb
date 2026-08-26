# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/team_budget"

class TeamBudgetTest < Minitest::Test
  # C1 — custo por tier da linha
  def test_cost_by_line_tier
    assert_equal 120, TeamBudget.cost_for(line_tier: "S", restricted: false)
    assert_equal 70, TeamBudget.cost_for(line_tier: "A", restricted: false)
    assert_equal 55, TeamBudget.cost_for(line_tier: "B", restricted: false)
    assert_equal 40, TeamBudget.cost_for(line_tier: "C", restricted: false)
    assert_equal 30, TeamBudget.cost_for(line_tier: "D", restricted: false)
    assert_equal 20, TeamBudget.cost_for(line_tier: "F", restricted: false)
  end

  # C2 — restrição paga metade, arredondado para baixo
  def test_restricted_evolution_costs_half
    # B = 55 → metade arredondada p/ baixo = 27
    assert_equal 27, TeamBudget.cost_for(line_tier: "B", restricted: true)
    # S = 120 → 60
    assert_equal 60, TeamBudget.cost_for(line_tier: "S", restricted: true)
    # A = 70 → 35
    assert_equal 35, TeamBudget.cost_for(line_tier: "A", restricted: true)
    # F = 20 → 10
    assert_equal 10, TeamBudget.cost_for(line_tier: "F", restricted: true)
    # D = 30 → 15
    assert_equal 15, TeamBudget.cost_for(line_tier: "D", restricted: true)
    # C = 40 → 20
    assert_equal 20, TeamBudget.cost_for(line_tier: "C", restricted: true)
  end

  # C3 — fits? com fronteira 450
  def test_add_within_budget_allowed
    assert TeamBudget.fits?(current_total: 400, new_cost: 50)
    assert TeamBudget.fits?(current_total: 0, new_cost: 450)
    assert TeamBudget.fits?(current_total: 430, new_cost: 20)
  end

  def test_add_over_budget_blocked
    refute TeamBudget.fits?(current_total: 400, new_cost: 51)
    refute TeamBudget.fits?(current_total: 0, new_cost: 451)
    refute TeamBudget.fits?(current_total: 451, new_cost: 1)
  end

  # C4 — s_limit_ok? permite 3, bloqueia 4º
  def test_s_limit_allows_three_and_blocks_fourth
    assert TeamBudget.s_limit_ok?(current_s_count: 0)
    assert TeamBudget.s_limit_ok?(current_s_count: 1)
    assert TeamBudget.s_limit_ok?(current_s_count: 2)
    assert TeamBudget.s_limit_ok?(current_s_count: 3)
    refute TeamBudget.s_limit_ok?(current_s_count: 4)
  end
end
