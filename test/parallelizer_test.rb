# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/parallelizer"

class ParallelizerTest < Minitest::Test
  def now
    Process.clock_gettime(Process::CLOCK_MONOTONIC)
  end

  def test_returns_results_in_input_order
    result = Parallelizer.map([1, 2, 3, 4], concurrency: 2) { |n| n * 10 }

    assert_equal [10, 20, 30, 40], result
  end

  def test_runs_independent_tasks_in_parallel
    start = now
    Parallelizer.map(1..8, concurrency: 8) { sleep 0.08 }
    elapsed = now - start

    assert_operator elapsed, :<, 0.55, "serial de 8 x 0.08s levaria ~0.64s"
  end

  def test_concurrency_one_runs_serially
    start = now
    Parallelizer.map(1..4, concurrency: 1) { sleep 0.04 }
    elapsed = now - start

    assert_operator elapsed, :>=, 0.12, "serial de 4 x 0.04s leva ~0.16s"
  end

  def test_propagates_exception_to_caller
    assert_raises(RuntimeError) do
      Parallelizer.map([1, 2, 3], concurrency: 2) do |n|
        raise "boom #{n}" if n == 3

        n
      end
    end
  end

  def test_empty_collection_returns_empty
    assert_equal [], Parallelizer.map([], concurrency: 4) { |n| n }
  end
end
