require "sinatra/base"
require "sinatra/reloader"
require "securerandom"
require "time"
require "pry"
require_relative "lib/gateways/poke_api"
require_relative "lib/team_repository"
require_relative "lib/battle_pokemon"
require_relative "lib/battle_engine"
require_relative "lib/opponent_generator"
require_relative "lib/battle_registry"
require_relative "lib/battle_repository"
require_relative "lib/progression_repository"
require_relative "lib/wallet_repository"
require_relative "lib/reward_rule"
require_relative "lib/evolution_rule"
require_relative "lib/heal_service"
require_relative "lib/inventory_repository"
require_relative "lib/item_catalog"
require_relative "lib/mart_service"
require_relative "lib/battle_service"
require_relative "lib/team_service"
require_relative "lib/user_state_repository"
require_relative "lib/journey_service"
require_relative "lib/parallelizer"
require_relative "lib/fighter_presenter"
require_relative "lib/battle_log_presenter"

module ServerCommon
  private

  def current_user
    session[:user_id]
  end

  def team_manage_context(member_id = nil)
    data = settings.team_strategy.manage_data(current_user)
    expose_manage_data(data)
    return nil unless member_id

    data[:members].find { |poke| poke.id.to_s == member_id.to_s }
  end

  def expose_manage_data(data)
    @team = data[:members]
    @available_moves = data[:available_moves]
    @inventory = data[:inventory]
  end
end

module ServerListActions
  PAGE_SIZE = 36
  STARTER_SLUGS = %w[
    bulbasaur charmander squirtle
    chikorita cyndaquil totodile
    treecko torchic mudkip
    turtwig chimchar piplup
    snivy tepig oshawott
    chespin fennekin froakie
    rowlet litten popplio
    grookey scorbunny sobble
    sprigatito fuecoco quaxly
  ].freeze
  FIRST_PAGE_COMMONS = PAGE_SIZE - STARTER_SLUGS.size

  private

  def render_index
    @offset = 0
    @q = ""
    prepare_team_fragment_data
    load_pokemon_page
    erb :index
  end

  def render_pokemons_list
    @offset = params[:offset].to_i
    @q = params[:q].to_s
    load_pokemon_page
    erb :pokemon_list, layout: false
  end

  def load_pokemon_page
    @limit = PAGE_SIZE
    @commons = filtered_commons
    build_page_window
    @items = Parallelizer.map(@page_names) { |name| [name, settings.api.find(name)] }.compact
    @starters = @q.empty? && @offset.zero? ? load_starters : []
    @notice = "Não foi possível carregar a lista de Pokémon." if @commons.empty? && @q.empty?
    load_team_names
  end

  def filtered_commons
    names = settings.api.fetch_all_names.to_a
    names = names.select { |name| name.downcase.include?(@q.downcase) } unless @q.empty?
    names.reject { |name| STARTER_SLUGS.include?(name) }
         .select { |name| settings.api.base_form?(name) }
  end

  def build_page_window
    if @q.empty?
      build_window_with_starters
    else
      build_window_filtered
    end
  end

  def build_window_with_starters
    if @offset.zero?
      build_first_page_with_starters
    else
      build_common_page_with_starters
    end
    @total_pages = total_pages_with_starters
  end

  def build_first_page_with_starters
    @page_names = @commons[0, FIRST_PAGE_COMMONS].to_a
    @current_page = 1
    @prev_offset = nil
    @next_offset = @commons.size > FIRST_PAGE_COMMONS ? FIRST_PAGE_COMMONS : nil
  end

  def build_common_page_with_starters
    @page_names = @commons[@offset, PAGE_SIZE].to_a
    @current_page = ((@offset - FIRST_PAGE_COMMONS) / PAGE_SIZE) + 2
    @prev_offset = @current_page == 2 ? 0 : @offset - PAGE_SIZE
    @next_offset = next_offset_present? ? @offset + PAGE_SIZE : nil
  end

  def build_window_filtered
    @page_names = @commons[@offset, PAGE_SIZE].to_a
    @current_page = (@offset / PAGE_SIZE) + 1
    @prev_offset = @offset.positive? ? @offset - PAGE_SIZE : nil
    @next_offset = next_offset_present? ? @offset + PAGE_SIZE : nil
    @total_pages = [(@commons.size.to_f / PAGE_SIZE).ceil, 1].max
  end

  def next_offset_present?
    (@offset + @page_names.size) < @commons.size
  end

  def total_pages_with_starters
    return 1 if @commons.size <= FIRST_PAGE_COMMONS

    1 + ((@commons.size - FIRST_PAGE_COMMONS).to_f / PAGE_SIZE).ceil
  end

  def load_team_names
    team = settings.team.all(current_user)
    @team_names = team.map(&:name)
    @team_full = team.size >= TeamRepository::MAX_TEAM_SIZE
  end

  def load_starters
    Parallelizer.map(STARTER_SLUGS) { |name| [name, settings.api.find(name)] }
  end

  def render_pokemon_fragment
    @pokemon = settings.api.find(params[:name])
    if @pokemon
      erb :pokemon, layout: false
    else
      @message = "Pokémon não encontrado."
      erb :error, layout: false
    end
  end

  def render_pokemon_detail
    @pokemon = settings.api.detail(params[:poke_id])
    if @pokemon
      erb :pokemon_detail, layout: false
    else
      @message = "Pokémon não encontrado."
      erb :error, layout: false
    end
  end
end

module ServerTeamActions
  private

  def render_team
    prepare_team_fragment_data
    return erb :team, layout: false if htmx_request?

    halt 404, "Página não encontrada."
  end

  def mart_data
    @catalog = ItemCatalog.all
    @inventory = settings.inventory.all(current_user)
    @balance = settings.wallet.balance(current_user)
  end

  def render_team_manage
    team_manage_context
    erb :team_manage, layout: false
  end

  def add_team_member
    notice = add_team_notice(new_member_from_api)
    settings.journey.mark_started_when_full(current_user)
    @notice = notice || "Adicionado ao time."
    @notice_kind = notice ? :error : :success
    mini_status = erb :team_add_result, layout: false
    prepare_team_fragment_data
    "#{mini_status}#{oob_team_view}#{oob_pokemon_list}"
  end

  def oob_team_view
    erb :team_view_oob, layout: false
  end

  def oob_pokemon_list
    @offset = params[:offset].to_i
    @q = params[:q].to_s
    load_pokemon_page
    %(<div id="pokemon-list" hx-swap-oob="innerHTML">#{erb :pokemon_list, layout: false}</div>)
  end

  def new_member_from_api
    pokemon = settings.api.find(params[:pokeName])
    return unless pokemon

    pokemon_with_level_one_moves(pokemon)
  end

  def add_team_notice(pokemon)
    return "Pokémon não encontrado." unless pokemon

    begin
      settings.team.add(current_user, pokemon)
      nil
    rescue TeamRepository::TeamFullError, TeamRepository::DuplicateError => e
      e.message
    end
  end

  def pokemon_with_level_one_moves(pokemon)
    learnable = settings.api.learnable_moves(pokemon.number).to_a
    names = learnable.select { |m| m[:level] <= 1 }
                     .map { |m| m[:name] }
                     .first(TeamRepository::MAX_MOVES_PER_POKEMON)
    pokemon.new(moves: names)
  end

  def remove_team_member
    settings.team.remove(current_user, params[:id]) if params[:id]
    "#{render_team_fragment_with_notice}#{oob_pokemon_list}"
  end

  def move_team_member
    settings.team.move(current_user, params[:id], params[:new_slot].to_i)
    render_team_fragment_with_notice
  end

  def heal_team
    return journey_gate_notice unless settings.journey.started?(current_user)

    @result = settings.heal.heal(current_user)
    render_result_notice(@result)
  end

  def buy_from_mart
    return journey_gate_notice unless settings.journey.started?(current_user)

    @result = settings.mart.buy(current_user, params[:item_name], params[:quantity].to_i)
    render_result_notice(@result)
  end

  def render_result_notice(result)
    @notice = result[:notice]
    @notice_kind = result[:kind]
    render_team_fragment_with_notice
  end

  def save_team_moves
    member = team_manage_context(params[:id])
    @notice = params[:draft] ? preview_member_moves(member) : persist_member_moves(member)
    @notice_kind = :error if @notice
    @team = settings.team.all(current_user)
    erb :team_manage, layout: false
  end

  def persist_member_moves(member)
    settings.team_strategy.save_moves(
      current_user, member, Array(params[:moves]), @available_moves
    )
  end

  def preview_member_moves(member)
    selection, notice = settings.team_strategy.preview_move(
      member, Array(params[:moves]), params[:toggle].to_s, @available_moves
    )
    (@draft_moves ||= {})[member.id] = selection if member
    notice
  end
end

module ServerTeamItemActions
  private

  def save_team_item
    member = team_manage_context(params[:id])
    @notice = settings.team_strategy.assign_item(current_user, member, params[:item_name].to_s)
    @team = settings.team.all(current_user)
    erb :team_manage, layout: false
  end
end

module ServerTeamHeldActions
  private

  def save_team_held_item
    member = team_manage_context(params[:id])
    @notice = settings.team_strategy.assign_held_item(current_user, member, params[:item_name].to_s)
    @team = settings.team.all(current_user)
    erb :team_manage, layout: false
  end
end

module ServerBattleActions
  private

  def render_battle
    content = prepare_battle_fragment
    return content if htmx_request?

    @battle_content = content
    erb :battle_page
  end

  def prepare_battle_fragment
    return journey_gate_fragment unless settings.journey.started?(current_user)

    result = settings.battle.prepare(current_user)
    return empty_team_fragment if result[:reason] == :empty_team
    return battle_error_fragment unless result[:engine]

    @engine = result[:engine]
    erb :battle, layout: false
  end

  def journey_gate_notice
    @notice = "Monte seu time inicial de 6 Pokémon para iniciar a jornada."
    render_team_fragment_with_notice
  end

  def journey_gate_fragment
    @message = "Monte seu time inicial de 6 Pokémon para iniciar a jornada."
    erb :battle, layout: false
  end

  def prepare_team_fragment_data
    @journey_started = settings.journey.started?(current_user)
    @team = settings.team.all(current_user)
    mart_data
  end

  def render_team_fragment_with_notice
    prepare_team_fragment_data
    erb :team, layout: false
  end

  def htmx_request?
    request.env["HTTP_HX_REQUEST"] == "true"
  end

  def empty_team_fragment
    @message = "Forme seu time para batalhar."
    erb :battle, layout: false
  end

  def battle_error_fragment
    @message = "Não foi possível preparar a batalha. Tente novamente."
    erb :battle, layout: false
  end

  def advance_battle
    result = settings.battle.advance(current_user)
    return erb :battle, layout: false unless result

    expose_battle_result(result)
    erb :battle, layout: false
  end

  def expose_battle_result(result)
    @engine = result[:engine]
    @xp_gained = result[:xp_gained]
    @money_gained = result[:money_gained]
    @evolution_news = result[:evolution_news]
    @learned_news = result[:learned_news]
  end
end

module PokemonRoutes
  def self.registered(app)
    register_index(app)
    register_pokemons(app)
    register_pokemon(app)
    register_pokemon_close(app)
    register_pokemon_detail(app)
  end

  def self.register_index(app)
    app.get("/") { render_index }
  end

  def self.register_pokemons(app)
    app.get("/pokemons") { render_pokemons_list }
  end

  def self.register_pokemon(app)
    app.get("/pokemon") { render_pokemon_fragment }
  end

  def self.register_pokemon_close(app)
    app.get("/pokemon/close") { erb :pokemon_close, layout: false }
  end

  def self.register_pokemon_detail(app)
    app.get("/pokemon/:poke_id") { render_pokemon_detail }
  end
end

module TeamRoutes
  def self.registered(app)
    register_team(app)
    register_heal(app)
    register_team_manage(app)
    register_add_member(app)
    register_remove_member(app)
    register_move_member(app)
    register_save_moves(app)
    register_save_item(app)
    register_save_held_item(app)
  end

  def self.register_team(app)
    app.get("/team") { render_team }
  end

  def self.register_heal(app)
    app.post("/team/heal") { heal_team }
  end

  def self.register_team_manage(app)
    app.get("/team/manage") { render_team_manage }
  end

  def self.register_add_member(app)
    app.post("/team") { add_team_member }
  end

  def self.register_remove_member(app)
    app.delete("/team") { remove_team_member }
  end

  def self.register_move_member(app)
    app.post("/team/:id/move") { move_team_member }
  end

  def self.register_save_moves(app)
    app.post("/team/:id/moves") { save_team_moves }
  end

  def self.register_save_item(app)
    app.post("/team/:id/item") { save_team_item }
  end

  def self.register_save_held_item(app)
    app.post("/team/:id/held-item") { save_team_held_item }
  end
end

module MartRoutes
  def self.registered(app)
    register_buy(app)
  end

  def self.register_buy(app)
    app.post("/mart/buy") { buy_from_mart }
  end
end

module ServerHistoryActions
  private

  def result_label(result)
    { "win" => "Vitória", "draw" => "Empate", "lose" => "Derrota" }.fetch(result, result)
  end

  def opponent_names(team)
    team.map { |member| member[:name] }.join(", ")
  end

  def render_history
    load_history_data
    return erb :history, layout: false if htmx_request?

    erb :history_page
  end

  def load_history_data
    history = settings.battle_history
    @current_user = current_user
    @rank = history.ranking
    @stats = history.stats(current_user)
    @position = history.rank_position(current_user)
    @recent = history.recent(current_user)
  end
end

module BattleRoutes
  def self.registered(app)
    register_open(app)
    register_play(app)
  end

  def self.register_open(app)
    app.get("/battle") { render_battle }
  end

  def self.register_play(app)
    app.post("/battle/play") { advance_battle }
  end
end

module HistoryRoutes
  def self.registered(app)
    register_history(app)
  end

  def self.register_history(app)
    app.get("/history") { render_history }
  end
end

module ErrorHandling
  def self.registered(app)
    app.error 500 do
      logger.error "#{env['sinatra.error'].class}: #{env['sinatra.error'].message}" if env["sinatra.error"]
      @message = "Algo deu errado. Tente novamente."
      status 200
      erb :error, layout: false
    end
  end
end

module ServerServices
  module_function

  def wire(app, deps)
    app.set :heal, HealService.new(team: deps[:team], progression: deps[:progression], wallet: deps[:wallet])
    app.set :mart, MartService.new(inventory: deps[:inventory], wallet: deps[:wallet])
    app.set :battle, BattleService.new(dependencies: deps)
    app.set :team_strategy, TeamService.new(**strategy_dependencies(deps))
  end

  def strategy_dependencies(deps)
    {
      api: deps[:api], team: deps[:team], progression: deps[:progression],
      inventory: deps[:inventory], wallet: deps[:wallet]
    }
  end
end

class Server < Sinatra::Base
  configure :development do
    register Sinatra::Reloader
  end

  configure do
    enable :logging, :sessions
    set :session_secret, ENV["SESSION_SECRET"] ||
                         "706f6b656465782d6465762d7365637265742d30313233343536373839616263646566"
    set :bind, "0.0.0.0"
    set :port, 3000
    set :views, "views"
    set :team, TeamRepository.new
    set :progression, ProgressionRepository.new
    set :battles, BattleRegistry.new
    set :battle_history, BattleRepository.new
    set :wallet, WalletRepository.new
    set :api, PokeApi.instance
    set :inventory, InventoryRepository.new
    set :user_state, UserStateRepository.new
    set :journey, JourneyService.new(user_state: settings.user_state, team: settings.team)
    deps = {
      api: -> { settings.api }, battles: settings.battles, team: settings.team,
      progression: settings.progression, battle_history: settings.battle_history,
      wallet: settings.wallet, inventory: settings.inventory
    }
    ServerServices.wire(self, deps)
  end

  before do
    session[:user_id] = params["as"] if params["as"]
    session[:user_id] ||= SecureRandom.uuid
  end

  include ServerCommon
  include ServerListActions
  include ServerTeamActions
  include ServerTeamItemActions
  include ServerTeamHeldActions
  include ServerBattleActions
  include ServerHistoryActions

  register PokemonRoutes
  register TeamRoutes
  register MartRoutes
  register BattleRoutes
  register HistoryRoutes
  register ErrorHandling

  run! if $PROGRAM_NAME == app_file
end
