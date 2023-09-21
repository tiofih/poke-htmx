require 'faraday'
require 'pry'
require_relative 'pokemon'

class PokeApi
  def self.all
    response = Faraday.get('https://pokeapi.co/api/v2/pokemon?limit=100000&offset=0').body
    JSON.parse(response)['results']
  end

  def self.find(name)
    response = Faraday.get("https://pokeapi.co/api/v2/pokemon/#{name}").body
    resp = JSON.parse(response)
    Pokemon.new(name: resp['name'], sprite: resp['sprites']['front_default'], number: resp['id'])
  end
end
