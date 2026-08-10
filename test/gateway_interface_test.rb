# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/gateways/poke_api_http"
require_relative "../lib/gateways/poke_api_cache"

class GatewayInterfaceTest < Minitest::Test
  def setup
    PokeApi.instance = nil
  end

  def teardown
    PokeApi.instance = nil
  end

  def test_instance_defaults_to_cached_real_adapter
    cached = PokeApi.instance

    assert_instance_of PokeApiCache, cached
    assert_instance_of PokeApiHttp, cached.inner
  end

  def test_instance_defaults_use_fixed_ttl_and_max_entries
    cached = PokeApi.instance

    assert_equal 600, cached.ttl
    assert_equal 1000, cached.max_entries
  end

  def test_instance_value_is_a_singleton
    assert_same PokeApi.instance, PokeApi.instance
  end

  def test_instance_can_be_overridden
    fake = Object.new
    PokeApi.instance = fake
    assert_same fake, PokeApi.instance
  end
end
