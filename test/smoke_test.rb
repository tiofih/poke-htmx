# frozen_string_literal: true

require_relative "test_helper"

class SmokeTest < Minitest::Test
  def test_harness_runs
    assert_equal 2 + 2, 4
  end
end