# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/gateways/poke_api_http"

class GatewayInterfaceTest < Minitest::Test
  def setup
    PokeApi.instance = nil
  end

  def teardown
    PokeApi.instance = nil
  end

  def test_instance_defaults_to_the_real_adapter
    assert_instance_of PokeApiHttp, PokeApi.instance
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
