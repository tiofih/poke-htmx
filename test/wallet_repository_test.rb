# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/wallet_repository"

module WalletRepositoryTestHelpers
  include TestSupport

  def setup
    TestDatabase.setup!
    TestDatabase.clear_wallet!
    @repository = WalletRepository.new
  end
end

class WalletBalanceTest < Minitest::Test
  include WalletRepositoryTestHelpers

  def test_balance_zero_without_row
    assert_equal 0, @repository.balance("user-a")
  end

  def test_balance_zero_does_not_create_row
    @repository.balance("user-a")
    assert_equal 0, TestDatabase.wallet_balance("user-a")
  end

  def test_balance_returns_current_saldo
    @repository.grant("user-a", 100)
    assert_equal 100, @repository.balance("user-a")
  end
end

class WalletGrantTest < Minitest::Test
  include WalletRepositoryTestHelpers

  def test_grant_creates_row_with_amount
    assert_equal 100, @repository.grant("user-a", 100)
    assert_equal 100, TestDatabase.wallet_balance("user-a")
  end

  def test_grant_accumulates_via_upsert
    @repository.grant("user-a", 100)
    assert_equal 150, @repository.grant("user-a", 50)
    assert_equal 150, TestDatabase.wallet_balance("user-a")
  end

  def test_grant_with_zero_is_noop
    @repository.grant("user-a", 100)
    assert_equal 100, @repository.grant("user-a", 0)
    assert_equal 100, TestDatabase.wallet_balance("user-a")
  end

  def test_grant_with_nil_is_noop
    @repository.grant("user-a", 100)
    assert_equal 100, @repository.grant("user-a", nil)
    assert_equal 100, TestDatabase.wallet_balance("user-a")
  end

  def test_grant_with_negative_is_noop
    @repository.grant("user-a", 100)
    assert_equal 100, @repository.grant("user-a", -30)
    assert_equal 100, TestDatabase.wallet_balance("user-a")
  end
end

class WalletIsolationTest < Minitest::Test
  include WalletRepositoryTestHelpers

  def test_wallets_are_isolated_per_user
    @repository.grant("user-a", 100)
    @repository.grant("user-b", 300)

    assert_equal 100, @repository.balance("user-a")
    assert_equal 300, @repository.balance("user-b")
  end
end

class WalletSpendTest < Minitest::Test
  include WalletRepositoryTestHelpers

  def test_spend_debits_and_returns_new_balance
    @repository.grant("user-a", 100)

    assert_equal 80, @repository.spend("user-a", 20)
    assert_equal 80, TestDatabase.wallet_balance("user-a")
  end

  def test_spend_without_enough_balance_is_noop
    @repository.grant("user-a", 50)

    assert_equal 50, @repository.spend("user-a", 100)
    assert_equal 50, TestDatabase.wallet_balance("user-a")
  end

  def test_spend_with_zero_is_noop
    @repository.grant("user-a", 100)

    assert_equal 100, @repository.spend("user-a", 0)
    assert_equal 100, TestDatabase.wallet_balance("user-a")
  end

  def test_spend_with_nil_is_noop
    @repository.grant("user-a", 100)

    assert_equal 100, @repository.spend("user-a", nil)
    assert_equal 100, TestDatabase.wallet_balance("user-a")
  end

  def test_spend_with_negative_is_noop
    @repository.grant("user-a", 100)

    assert_equal 100, @repository.spend("user-a", -30)
    assert_equal 100, TestDatabase.wallet_balance("user-a")
  end

  def test_spend_never_makes_balance_negative
    @repository.grant("user-a", 10)

    @repository.spend("user-a", 50)

    assert_equal 10, TestDatabase.wallet_balance("user-a")
  end

  def test_spend_is_isolated_per_user
    @repository.grant("user-a", 100)
    @repository.grant("user-b", 100)
    @repository.spend("user-a", 40)

    assert_equal 60, TestDatabase.wallet_balance("user-a")
    assert_equal 100, TestDatabase.wallet_balance("user-b")
  end
end

class WalletSetTest < Minitest::Test
  include WalletRepositoryTestHelpers

  def test_set_creates_row_with_amount
    assert_equal 200, @repository.set("user-a", 200)
    assert_equal 200, TestDatabase.wallet_balance("user-a")
  end

  def test_set_overwrites_existing_balance
    @repository.grant("user-a", 500)

    assert_equal 200, @repository.set("user-a", 200)
    assert_equal 200, TestDatabase.wallet_balance("user-a")
  end

  def test_set_is_isolated_per_user
    @repository.grant("user-a", 500)
    @repository.grant("user-b", 50)
    @repository.set("user-a", 200)

    assert_equal 200, TestDatabase.wallet_balance("user-a")
    assert_equal 50, TestDatabase.wallet_balance("user-b")
  end
end
