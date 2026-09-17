# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/journey_service"

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

  def test_user_state_repository_constant_is_gone
    path = File.expand_path("../lib/user_state_repository.rb", __dir__)

    refute_path_exists path, "lib/user_state_repository.rb deveria ter sido removido"
    refute Object.const_defined?(:UserStateRepository), "UserStateRepository nao deve resolver"
  end

  def test_journey_service_has_no_persisted_start_hooks
    keywords = JourneyService.instance_method(:initialize).parameters.map(&:last)

    refute_includes keywords, :user_state, "JourneyService nao aceita mais o kwarg user_state:"
    refute_includes JourneyService.instance_methods(false), :mark_started
    refute_includes JourneyService.instance_methods(false), :mark_started_when_full
  end

  def test_test_help_has_no_user_state_hooks
    refute_respond_to TestDatabase, :clear_user_state!,
                      "TestDatabase.clear_user_state! (TRUNCATE user_state) deveria ter saido"
  end
end
