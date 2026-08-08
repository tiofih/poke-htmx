require "sinatra/base"
require "sinatra/reloader"
require "securerandom"
require "pry"
require_relative "lib/poke_api"
require_relative "lib/team_repository"

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
    register Sinatra::Reloader
  end

  before do
    session[:user_id] ||= SecureRandom.uuid
  end

  helpers do
    def current_user
      session[:user_id]
    end
  end

  get "/" do
    @pokemons = PokeApi.all
    erb :index
  end

  get "/pokemon" do
    @pokemon = PokeApi.find(params[:name])
    erb :pokemon
  end

  post "/team" do
    pokemon = PokeApi.find(params[:pokeName])
    settings.team.add(current_user, pokemon)
    @team = settings.team.all(current_user)
    erb :team
  end

  delete "/team" do
    settings.team.remove(current_user, params[:id]) if params[:id]
    @team = settings.team.all(current_user)
    erb :team
  end

  run! if $PROGRAM_NAME == app_file
end
