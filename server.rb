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

module ServerCommon
  private

  def current_user
    session[:user_id]
  end
end

module ServerListActions
  private

  def render_index
    @offset = 0
    @q = ""
    @page = settings.api.paginate(offset: @offset, query: @q)
    @notice = "Não foi possível carregar a lista de Pokémon." if @page[:names].empty? && @q.empty?
    erb :index
  end

  def render_pokemons_list
    @offset = params[:offset].to_i
    @q = params[:q].to_s
    @page = settings.api.paginate(offset: @offset, query: @q)
    @notice = "Não foi possível carregar a lista de Pokémon." if @page[:names].empty? && @q.empty?
    erb :pokemon_list, layout: false
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
    @team = settings.team.all(current_user)
    mart_data
    erb :team, layout: false
  end

  def mart_data
    @catalog = ItemCatalog.all
    @inventory = settings.inventory.all(current_user)
    @balance = settings.wallet.balance(current_user)
  end

  def render_team_manage
    @team = settings.team.all(current_user)
    @available_moves = moves_for_team
    @inventory = settings.inventory.all(current_user)
    erb :team_manage, layout: false
  end

  def moves_for_team
    @team.to_h { |member| [member.id, settings.api.available_move_names(member.number)] }
  end

  def add_team_member
    pokemon = settings.api.find(params[:pokeName])
    pokemon = pokemon_with_level_one_moves(pokemon) if pokemon
    @notice = add_team_notice(pokemon)
    @team = settings.team.all(current_user)
    mart_data
    erb :team, layout: false
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
    @team = settings.team.all(current_user)
    mart_data
    erb :team, layout: false
  end

  def move_team_member
    settings.team.move(current_user, params[:id], params[:new_slot].to_i)
    @team = settings.team.all(current_user)
    mart_data
    erb :team, layout: false
  end

  def heal_team
    @result = settings.heal.heal(current_user)
    @notice = @result[:notice]
    @team = settings.team.all(current_user)
    mart_data
    erb :team, layout: false
  end

  def buy_from_mart
    quantity = params[:quantity].to_i
    @result = settings.mart.buy(current_user, params[:item_name], quantity)
    @notice = @result[:notice]
    @team = settings.team.all(current_user)
    mart_data
    erb :team, layout: false
  end

  def save_team_moves
    @team = settings.team.all(current_user)
    @available_moves = moves_for_team
    member = @team.find { |poke| poke.id.to_s == params[:id].to_s }
    apply_move_selection(member)
    erb :team_manage, layout: false
  end

  def apply_move_selection(member)
    selected = Array(params[:moves])
    error = move_choice_error(member, selected)
    @notice = error
    return unless error.nil? && member

    settings.team.set_moves(current_user, member.id, selected)
    @team = settings.team.all(current_user)
  end

  def move_choice_error(member, selected)
    limit = TeamRepository::MAX_MOVES_PER_POKEMON
    return "Selecione no máximo #{limit} golpes." if selected.size > limit

    available = member ? @available_moves[member.id] : []
    return "Golpe não disponível para este Pokémon." if selected.any? { |move| !available.include?(move) }

    nil
  end
end

module ServerTeamItemActions
  private

  def save_team_item
    team_manage_data
    @inventory = settings.inventory.all(current_user)
    assign_member_item(team_member_for_item)
    erb :team_manage, layout: false
  end

  def team_manage_data
    @team = settings.team.all(current_user)
    @available_moves = moves_for_team
  end

  def team_member_for_item
    @team.find { |poke| poke.id.to_s == params[:id].to_s }
  end

  def assign_member_item(member)
    return unless member

    item_name = params[:item_name].to_s
    if item_name.empty?
      clear_member_item(member)
    else
      assign_catalog_item(member, item_name)
    end
    @team = settings.team.all(current_user)
  end

  def clear_member_item(member)
    settings.team.assign_item(current_user, member.id, nil)
  end

  def assign_catalog_item(member, item_name)
    item = ItemCatalog.find(item_name)
    unless item && item.heal_amount.to_i.positive?
      @notice = "Item não disponível para atribuição."
      return
    end

    settings.team.assign_item(current_user, member.id, item_name)
  end
end

module ServerTeamHeldActions
  private

  def save_team_held_item
    team_manage_data
    @inventory = settings.inventory.all(current_user)
    assign_member_held_item(team_member_for_item)
    erb :team_manage, layout: false
  end

  def team_manage_data
    @team = settings.team.all(current_user)
    @available_moves = moves_for_team
  end

  def team_member_for_item
    @team.find { |poke| poke.id.to_s == params[:id].to_s }
  end

  def assign_member_held_item(member)
    return unless member

    item_name = params[:item_name].to_s
    if item_name.empty?
      settings.team.assign_held_item(current_user, member.id, nil)
    else
      assign_held_catalog_item(member, item_name)
    end
    @team = settings.team.all(current_user)
  end

  def assign_held_catalog_item(member, item_name)
    item = ItemCatalog.find(item_name)
    unless item && item.category == "held" &&
           settings.inventory.count(current_user, item_name).positive?
      @notice = "Item não disponível para equipar."
      return
    end

    settings.team.assign_held_item(current_user, member.id, item_name)
  end
end

module ServerBattleActions
  private

  def render_battle_fragment
    result = settings.battle.prepare(current_user)
    return empty_team_fragment if result[:reason] == :empty_team
    return battle_error_fragment unless result[:engine]

    @engine = result[:engine]
    erb :battle, layout: false
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
    response.headers["HX-Trigger"] = "teamRefresh" if @engine.finished? && @evolution_news&.any?
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

  def render_history_fragment
    history = settings.battle_history
    @current_user = current_user
    @rank = history.ranking
    @stats = history.stats(current_user)
    @position = history.rank_position(current_user)
    @recent = history.recent(current_user)
    erb :history, layout: false
  end
end

module BattleRoutes
  def self.registered(app)
    register_open(app)
    register_play(app)
    register_close(app)
  end

  def self.register_open(app)
    app.get("/battle") { render_battle_fragment }
  end

  def self.register_play(app)
    app.post("/battle/play") { advance_battle }
  end

  def self.register_close(app)
    app.get("/battle/close") { erb :battle_close, layout: false }
  end
end

module HistoryRoutes
  def self.registered(app)
    register_history(app)
    register_history_close(app)
  end

  def self.register_history(app)
    app.get("/history") { render_history_fragment }
  end

  def self.register_history_close(app)
    app.get("/history/close") { erb :history_close, layout: false }
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
    set :heal, HealService.new(
      team: TeamRepository.new, progression: ProgressionRepository.new,
      wallet: WalletRepository.new
    )
    set :inventory, InventoryRepository.new
    set :mart, MartService.new(inventory: InventoryRepository.new, wallet: WalletRepository.new)
    set :battle, BattleService.new(
      dependencies: {
        api: -> { settings.api }, battles: settings.battles, team: settings.team,
        progression: settings.progression, battle_history: settings.battle_history,
        wallet: settings.wallet, inventory: settings.inventory
      }
    )
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
