# frozen_string_literal: true

require_relative "test_helper"

# Sessao 0089 — guarda da remocao do estado morto `user_state` (D2/D3).
class UserStateRemovalTest < Minitest::Test
  def setup
    TestDatabase.setup!
  end

  def test_user_state_table_is_gone_after_setup
    relation = TestDatabase.with_db do |connection|
      connection.exec("SELECT to_regclass('user_state') AS relation").first["relation"]
    end

    assert_nil relation, "user_state nao deve existir apos o setup (schema + migracoes)"
  end
end
