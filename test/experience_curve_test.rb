# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/experience_curve"

class ExperienceCurveTest < Minitest::Test
  def test_xp_needed_discounts_early_levels
    assert_equal 60, ExperienceCurve.xp_needed(1)
    assert_equal 60, ExperienceCurve.xp_needed(2)
    assert_equal 60, ExperienceCurve.xp_needed(3)
    assert_equal 400, ExperienceCurve.xp_needed(4)
    assert_equal 500, ExperienceCurve.xp_needed(5)
  end

  def test_level_for_xp_maps_cumulative_ranges
    assert_equal 1, ExperienceCurve.level_for_xp(0)
    assert_equal 1, ExperienceCurve.level_for_xp(99)
    assert_equal 2, ExperienceCurve.level_for_xp(100)
    assert_equal 2, ExperienceCurve.level_for_xp(299)
    assert_equal 3, ExperienceCurve.level_for_xp(300)
    assert_equal 3, ExperienceCurve.level_for_xp(599)
    assert_equal 4, ExperienceCurve.level_for_xp(600)
    assert_equal 4, ExperienceCurve.level_for_xp(999)
    assert_equal 5, ExperienceCurve.level_for_xp(1000)
  end

  def test_level_for_xp_never_below_one
    assert_equal 1, ExperienceCurve.level_for_xp(-5)
    assert_equal 1, ExperienceCurve.level_for_xp(0)
  end
end
