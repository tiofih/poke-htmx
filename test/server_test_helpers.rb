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
    @repository = TeamRepository.new
    @progression = ProgressionRepository.new
  end

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

  def two_hundred_fifty_names
    (1..250).map { |index| "pokemon#{index}" }
  end

  def filtered_names
    %w[pikachu pichu raichu pikachu-alola bulbasaur]
  end
end
