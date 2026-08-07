# frozen_string_literal: true

require_relative "test_helper"

class TeamRepositoryTest < Minitest::Test
  def setup
    TestDatabase.setup!
    @repository = TeamRepository.new
  end

  def test_all_returns_empty_array_for_empty_database
    assert_equal [], @repository.all
  end
end
