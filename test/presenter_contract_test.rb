# frozen_string_literal: true

require "minitest/autorun"

# 0098 C6 — pin estrutural: a montagem dos fragments mora nos presenters puros
# (lib/*_presenter.rb), o server.rb so delega sob os mesmos nomes de sempre e
# as views continuam chamando esses nomes. Se algum pedaco da extracao voltar
# para o server.rb (ou um nome mudar), aqui quebra.
class PresenterContractTest < Minitest::Test
  ROOT = File.expand_path("..", __dir__)
  SERVER = File.read(File.join(ROOT, "server.rb"))
  SERVER_COMMON = SERVER[/^module ServerCommon$.*?^end$/m] || ""
  VIEWS_SOURCE = Dir[File.join(ROOT, "views", "*.erb")].to_h do |path|
    [File.basename(path), File.read(path)]
  end

  DELEGATIONS = {
    "team_locals" => "TeamPresenter.new",
    "mart_modal_locals" => "MartPresenter.new",
    "filter_controls_locals" => "@pokemon_page.filter_controls_locals",
    "pokemon_list_locals" => "@pokemon_page.list_locals"
  }.freeze

  # helpers (metodos + constantes) que a extracao tirou do server.rb
  ABSENT_FROM_SERVER = [
    "def normalized_type", "def normalized_generation", "def normalized_tier",
    "def normalized_cost_max", "def normalized_sort", "def normalized_team",
    "def restore_filters_from_session", "def persist_filters_to_session",
    "def current_filter_params", "def any_filter_param_present?",
    "def apply_list_filters", "def assign_list_filters", "def load_team_names",
    "def filter_active?", "def sort_active?", "def starters_visible?",
    "def commons_window", "def fetch_commons", "def collect_base_forms",
    "def collect_all_filtered_base_forms", "def build_page", "def sort_names",
    "def type_pokemon_set", "def filtered_base_forms", "def filter_by_team",
    "def common_candidates", "def standard_pagination?", "def current_page_number",
    "def previous_offset", "def next_page_offset", "def load_starters",
    "def build_pokemon_costs", "def pokemon_cost_info", "def load_search_hint",
    "def search_hint", "def first_search_match", "def base_form_for",
    "STARTER_SLUGS", "FIRST_PAGE_COMMONS", "SCAN_BATCH", "ServerSearchHintActions"
  ].freeze

  def test_each_builder_is_defined_exactly_once_inside_server_common
    DELEGATIONS.each_key do |name|
      assert_equal 1, SERVER.scan(/^  def #{name}$/).size, "#{name}: def unico"
      assert_includes SERVER_COMMON, "  def #{name}", "#{name}: deve viver no ServerCommon"
    end
  end

  def test_each_builder_body_delegates_to_its_presenter
    DELEGATIONS.each do |name, delegation|
      body = SERVER_COMMON[/^  def #{name}$.*?^  end$/m] || ""
      assert_includes body, delegation, "#{name}: corpo delega ao presenter"
    end
  end

  def test_views_keep_calling_the_same_helper_names
    assert_includes VIEWS_SOURCE["index.erb"], "locals: team_locals"
    assert_includes VIEWS_SOURCE["index.erb"], "locals: filter_controls_locals"
    assert_includes VIEWS_SOURCE["index.erb"], "locals: pokemon_list_locals"
    refute VIEWS_SOURCE.values.any? { |src| src.include?("mart_modal_locals") },
           "mart_modal_locals so e chamado pelas rotas (server.rb)"
  end

  def test_extracted_code_is_absent_from_server
    ABSENT_FROM_SERVER.each do |token|
      refute_includes SERVER, token, "server.rb nao deve conter #{token}"
    end
  end

  def test_presenters_are_pure_and_required_by_server
    %w[team_presenter mart_presenter pokemon_list_presenter].each do |name|
      source = File.read(File.join(ROOT, "lib", "#{name}.rb"))
      assert_includes SERVER, "require_relative \"lib/#{name}\"", "#{name}: server exige o presenter"
      %w(sinatra settings. session[ current_user TeamRepository PG::).each do |dirty|
        refute_includes source, dirty, "#{name}: presenter deve ficar puro (sem #{dirty})"
      end
    end
  end
end
