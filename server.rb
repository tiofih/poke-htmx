require "sinatra/base"
require "sinatra/reloader"
require "pry"
require_relative "lib/poke_api"
require_relative "lib/team_repository"

class Server < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  configure do
    enable :logging
    set :bind, "0.0.0.0"
    set :port, 3000
    set :views, "views"
    set :team, TeamRepository.new
    register Sinatra::Reloader
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
    settings.team.add(pokemon)
    @team = settings.team.all
    erb :team
  end

  get "/team" do
    settings.team.remove(params[:index]) if params[:index]
    @team = settings.team.all
    erb :team
  end

  run! if $PROGRAM_NAME == app_file
end
