# frozen_string_literal: true

require "vcr"
require "webmock"

VCR.configure do |c|
  c.cassette_library_dir = File.expand_path("cassettes", __dir__)
  c.hook_into :webmock, :faraday
  # Após a gravação inicial, bloqueia hits sem cassette para garantir
  # que nenhum teste dependa de rede ou de tmp/pokeapi_cache.json.
  c.allow_http_connections_when_no_cassette = false
  c.default_cassette_options = {
    record: :new_episodes,
    match_requests_on: %i[method uri],
    allow_playback_repeats: true
  }
  c.filter_sensitive_data("<pokeapi>") { "pokeapi.co" }
end

# Envolve cada teste em um cassette baseado no nome da classe/método.
# Testes que usam PokeApiStub não geram HTTP e gravam cassette vazio (ok);
# testes que fazem hit real (ex.: sem stub e sem cache) gravam a resposta
# e nas próximas execuções rodam offline. Evita depender de tmp/pokeapi_cache.json.
module VCRPerTest
  def before_setup
    cassette = "#{self.class.name}/#{name}".gsub(/[^a-zA-Z0-9_\/]/, "_")
    VCR.insert_cassette(cassette, record: :new_episodes, allow_playback_repeats: true)
    super
  end

  def after_teardown
    super
    VCR.eject_cassette if VCR.current_cassette
  rescue VCR::Errors::UnhandledHTTPRequestError
    VCR.eject_cassette if VCR.current_cassette
    raise
  end
end

Minitest::Test.prepend(VCRPerTest)

# Helper para testes que precisam hit real na PokeAPI sem mock manual.
# Uso: VCR.use_cassette("pokeapi/all_names") { get "/pokemons" }
