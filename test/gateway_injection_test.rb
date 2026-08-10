# frozen_string_literal: true

require_relative "server_test_helpers"
require_relative "poke_api_fake"

class GatewayInjectionTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_server_uses_the_configured_gateway_instance
    original = Server.settings.api
    Server.set :api, PokeApiFake.new(find: pikachu_pokemon)

    post "/team", { pokeName: "pikachu" }, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    assert_equal 1, @repository.all("user-a").size
  ensure
    Server.set :api, original
  end
end
