# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/user_state_repository"

module UserStateRepositoryTestHelpers
  def setup
    TestDatabase.setup!
    TestDatabase.clear_user_state!
    @repository = UserStateRepository.new
  end
end

class UserStateStartedTest < Minitest::Test
  include UserStateRepositoryTestHelpers

  def test_started_returns_false_by_default
    assert_equal false, @repository.started?("user-a")
  end

  def test_mark_started_persists_flag
    @repository.mark_started("user-a")

    assert_equal true, @repository.started?("user-a")
  end

  def test_mark_started_is_idempotent
    @repository.mark_started("user-a")
    @repository.mark_started("user-a")

    assert_equal true, @repository.started?("user-a")
  end

  def test_isolation_between_users
    @repository.mark_started("user-a")

    assert_equal true, @repository.started?("user-a")
    assert_equal false, @repository.started?("user-b")
  end
end
