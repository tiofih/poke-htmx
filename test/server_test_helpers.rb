# frozen_string_literal: true

require_relative "test_helper"
require_relative "../server"

module ServerTestHelpers
  include Rack::Test::Methods

  def app
    Server
  end

  def setup
    TestDatabase.setup!
    TestDatabase.clear_team!
    Server.settings.battles.clear_all
    @repository = TeamRepository.new
    @progression = ProgressionRepository.new
    @wallet = WalletRepository.new
    @inventory = InventoryRepository.new
  end

  def fill_team(user_id, members: DEFAULT_TEAM_SPECS)
    add_team(user_id, members)
  end

  DEFAULT_TEAM_SPECS = [
    ["pikachu", 25], ["bulbasaur", 1], ["charmander", 4],
    ["squirtle", 7], ["pidgey", 16], ["rattata", 19]
  ].freeze

  def pikachu_pokemon
    build_pokemon_record("pikachu", 25)
  end

  def bulbasaur_pokemon
    build_pokemon_record("bulbasaur", 1)
  end

  def rack_test_session
    Rack::Test::Session.new(Rack::MockSession.new(app))
  end

  def user_session(user_id)
    { "rack.session" => { "user_id" => user_id } }
  end

  def htmx_session(user_id)
    user_session(user_id).merge("HTTP_HX_REQUEST" => "true")
  end

  def two_hundred_fifty_names
    (1..250).map { |index| "pokemon#{index}" }
  end

  def filtered_names
    %w[pikachu pichu raichu pikachu-alola bulbasaur]
  end
end
