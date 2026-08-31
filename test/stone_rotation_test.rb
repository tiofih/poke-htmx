# frozen_string_literal: true

require "minitest/autorun"
require_relative "../lib/stone_rotation"

class StoneRotationTest < Minitest::Test
  def test_rotation_is_deterministic_three_distinct
    first = StoneRotation.new("user-1", 3).stones
    second = StoneRotation.new("user-1", 3).stones

    assert_equal first, second, "mesma seed deve produzir a mesma oferta"
    assert_equal 3, first.size
    assert_equal 3, first.uniq.size, "pedras distintas"
    assert(first.all? { |name| ItemCatalog.find(name).category == "stone" })
  end

  def test_rotation_changes_as_battle_count_grows
    rotation = StoneRotation.new("user-1", 0).stones
    next_rotation = StoneRotation.new("user-1", 1).stones

    refute_equal rotation, next_rotation, "rodada seguinte deve mudar a oferta"
  end
end
