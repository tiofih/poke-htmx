require 'faraday'

class PokeApi
  def self.all
    response = Faraday.get("https://pokeapi.co/api/v2/pokemon?limit=100000&offset=0").body
    JSON.parse(response)["results"]
  end

  def self.find(name)
    response = Faraday.get("https://pokeapi.co/api/v2/pokemon/#{name}").body
    JSON.parse(response)
  end
end
