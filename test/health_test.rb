# frozen_string_literal: true

require "json"
require_relative "server_test_helpers"

class HealthTest < Minitest::Test
  include ServerTestHelpers

  def test_health_returns_ok
    # Garantia de que o healthcheck não toca a rede/PokéAPI: qualquer tentativa
    # de conexão HTTP real lança WebMock::NetConnectNotAllowedError.
    WebMock.disable_net_connect!

    get "/health"

    assert_equal 200, last_response.status
    assert_equal "ok", JSON.parse(last_response.body)["status"]
  end
end
