# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/evolution_rule"

class EvolutionRuleTest < Minitest::Test
  def test_next_stage_returns_evolution_with_smallest_min_level_reachable
    evolutions = [
      { number: 5, name: "charmeleon", min_level: 16 },
      { number: 6, name: "charizard", min_level: 36 }
    ]

    result = EvolutionRule.next_stage(_current_number: 4, level: 20, evolutions: evolutions)

    assert_equal({ number: 5, name: "charmeleon" }, result)
  end

  def test_next_stage_returns_nil_when_no_stage_reachable
    evolutions = [
      { number: 5, name: "charmeleon", min_level: 16 },
      { number: 6, name: "charizard", min_level: 36 }
    ]

    result = EvolutionRule.next_stage(_current_number: 4, level: 10, evolutions: evolutions)

    assert_nil result
  end

  def test_next_stage_returns_nil_when_evolutions_empty
    result = EvolutionRule.next_stage(_current_number: 4, level: 50, evolutions: [])

    assert_nil result
  end

  def test_next_stage_ignores_evolutions_without_min_level
    evolutions = [
      { number: 136, name: "flareon", min_level: nil },
      { number: 134, name: "vaporeon", min_level: nil },
      { number: 135, name: "jolteon", min_level: nil }
    ]

    result = EvolutionRule.next_stage(_current_number: 133, level: 50, evolutions: evolutions)

    assert_nil result
  end

  def test_next_stage_breaks_tie_with_lower_number_when_same_min_level
    evolutions = [
      { number: 2, name: "ivysaur", min_level: 16 },
      { number: 3, name: "venusaur", min_level: 16 }
    ]

    result = EvolutionRule.next_stage(_current_number: 1, level: 20, evolutions: evolutions)

    assert_equal({ number: 2, name: "ivysaur" }, result)
  end

  def test_next_stage_returns_next_immediate_stage_in_chain
    evolutions = [
      { number: 8, name: "wartortle", min_level: 16 },
      { number: 9, name: "blastoise", min_level: 36 }
    ]

    result = EvolutionRule.next_stage(_current_number: 7, level: 40, evolutions: evolutions)

    assert_equal({ number: 8, name: "wartortle" }, result)
  end
end
