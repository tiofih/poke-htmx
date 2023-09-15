require 'sinatra/base'
require 'sinatra/reloader'
require_relative 'lib/poke_api'

class Server < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  configure do
    enable :logging
    set :bind, '0.0.0.0'
    set :port, 3000
    set :views, "views"
    register Sinatra::Reloader
  end

  get '/' do
    @pokemons = PokeApi.all
    erb :index
  end

  get '/pokemon' do
    @pokemon = PokeApi.find(params[:name])
    erb :pokemon
  end

  run!
end
