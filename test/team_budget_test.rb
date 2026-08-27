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

  # C1 — S restrito = 110 (exceção ao metade floor), demais metade floor
  def test_cost_restricted_s_is_one_ten
    assert_equal 110, TeamBudget.cost_for(line_tier: "S", restricted: true)
  end

  def test_restricted_costs_half_except_s
    # B = 55 → metade 27, A=35, F=10, D=15, C=20 — só S foge (110, não 60)
    assert_equal 27, TeamBudget.cost_for(line_tier: "B", restricted: true)
    assert_equal 35, TeamBudget.cost_for(line_tier: "A", restricted: true)
    assert_equal 10, TeamBudget.cost_for(line_tier: "F", restricted: true)
    assert_equal 15, TeamBudget.cost_for(line_tier: "D", restricted: true)
    assert_equal 20, TeamBudget.cost_for(line_tier: "C", restricted: true)
  end

  def test_cost_by_line_tier_pure
    assert_equal 120, TeamBudget.cost_for(line_tier: "S", restricted: false)
    assert_equal 70, TeamBudget.cost_for(line_tier: "A", restricted: false)
    assert_equal 55, TeamBudget.cost_for(line_tier: "B", restricted: false)
    assert_equal 40, TeamBudget.cost_for(line_tier: "C", restricted: false)
    assert_equal 30, TeamBudget.cost_for(line_tier: "D", restricted: false)
    assert_equal 20, TeamBudget.cost_for(line_tier: "F", restricted: false)
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

  # C2 — fits? fronteira 450 (orçamento único limitador)
  def test_fits_blocks_over_budget
    # 3×S puro 360 + S rest 110 = 470 > 450 bloqueia; 4×S puro 480 > 450
    refute TeamBudget.fits?(current_total: 360, new_cost: 110)
    refute TeamBudget.fits?(current_total: 360, new_cost: 120)
    refute TeamBudget.fits?(current_total: 341, new_cost: 110)
    refute TeamBudget.fits?(current_total: 451, new_cost: 1)
  end

  def test_fits_allows_exact_budget
    assert TeamBudget.fits?(current_total: 330, new_cost: 120)
    assert TeamBudget.fits?(current_total: 340, new_cost: 110)
    assert TeamBudget.fits?(current_total: 430, new_cost: 20)
    assert TeamBudget.fits?(current_total: 0, new_cost: 450)
  end

  # C4 — s_limit_ok? permite 3, bloqueia 4º (será removido no Passo 2)
  def test_s_limit_allows_three_and_blocks_fourth
    assert TeamBudget.s_limit_ok?(current_s_count: 0)
    assert TeamBudget.s_limit_ok?(current_s_count: 1)
    assert TeamBudget.s_limit_ok?(current_s_count: 2)
    assert TeamBudget.s_limit_ok?(current_s_count: 3)
    refute TeamBudget.s_limit_ok?(current_s_count: 4)
  end
end
