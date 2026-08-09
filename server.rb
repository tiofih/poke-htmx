require "sinatra/base"
require "sinatra/reloader"
require "securerandom"
require "pry"
require_relative "lib/poke_api"
require_relative "lib/team_repository"
require_relative "lib/battle_pokemon"
require_relative "lib/battle_engine"
require_relative "lib/opponent_generator"
require_relative "lib/battle_registry"

# rubocop:disable Metrics/ClassLength
class Server < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  configure do
    enable :logging
    enable :sessions
    set :session_secret, ENV["SESSION_SECRET"] ||
                         "706f6b656465782d6465762d7365637265742d30313233343536373839616263646566"
    set :bind, "0.0.0.0"
    set :port, 3000
    set :views, "views"
    set :team, TeamRepository.new
    set :battles, BattleRegistry.new
    register Sinatra::Reloader
  end

  before do
    session[:user_id] ||= SecureRandom.uuid
  end

  helpers do
    def current_user
      session[:user_id]
    end

    def battle_moves_for(pokemon)
      moves = PokeApi.moves_for(pokemon.number)
      return moves unless moves.empty?

      [Move.new(name: "Struggle", type: pokemon.types.first || "normal", power: 10, accuracy: nil, pp: 100)]
    end
  end

  get "/" do
    @offset = 0
    @q = ""
    @page = PokeApi.paginate(offset: @offset, query: @q)
    erb :index
  end

  get "/pokemons" do
    @offset = params[:offset].to_i
    @q = params[:q].to_s
    @page = PokeApi.paginate(offset: @offset, query: @q)
    erb :pokemon_list, layout: false
  end

  get "/pokemon" do
    @pokemon = PokeApi.find(params[:name])
    erb :pokemon, layout: false
  end

  get "/pokemon/close" do
    erb :pokemon_close, layout: false
  end

  get "/pokemon/:poke_id" do
    @pokemon = PokeApi.detail(params[:poke_id])
    erb :pokemon_detail, layout: false
  end

  get "/team" do
    @team = settings.team.all(current_user)
    erb :team, layout: false
  end

  get "/team/manage" do
    @team = settings.team.all(current_user)
    @available_moves = @team.to_h do |member|
      [member.id, PokeApi.available_move_names(member.number)]
    end
    erb :team_manage, layout: false
  end

  post "/team" do
    pokemon = PokeApi.find(params[:pokeName])
    begin
      settings.team.add(current_user, pokemon)
    rescue TeamRepository::TeamFullError, TeamRepository::DuplicateError => e
      @notice = e.message
    end
    @team = settings.team.all(current_user)
    erb :team, layout: false
  end

  delete "/team" do
    settings.team.remove(current_user, params[:id]) if params[:id]
    @team = settings.team.all(current_user)
    erb :team, layout: false
  end

  post "/team/:id/move" do
    settings.team.move(current_user, params[:id], params[:new_slot].to_i)
    @team = settings.team.all(current_user)
    erb :team, layout: false
  end

  get "/battle" do
    team = settings.team.all(current_user)
    if team.empty?
      @message = "Forme seu time para batalhar."
      return erb :battle, layout: false
    end

    player_team = team.map do |member|
      detail = PokeApi.detail(member.number)
      BattlePokemon.from(detail, moves: battle_moves_for(member))
    end
    opponent = OpponentGenerator.new(names: PokeApi.fetch_all_names).team
    opponent = opponent.map { |battle_pokemon| battle_pokemon.new(moves: battle_moves_for(battle_pokemon)) }
    engine = BattleEngine.new(team_a: player_team, team_b: opponent)
    settings.battles.set(current_user, engine)
    @engine = engine
    erb :battle, layout: false
  end

  post "/battle/play" do
    @engine = settings.battles.fetch(current_user)
    return erb :battle, layout: false unless @engine

    @engine.play_round
    erb :battle, layout: false
  end

  get "/battle/close" do
    erb :battle_close, layout: false
  end

  run! if $PROGRAM_NAME == app_file
end
# rubocop:enable Metrics/ClassLength
