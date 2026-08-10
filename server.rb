require "sinatra/base"
require "sinatra/reloader"
require "securerandom"
require "pry"
require_relative "lib/gateways/poke_api"
require_relative "lib/team_repository"
require_relative "lib/battle_pokemon"
require_relative "lib/battle_engine"
require_relative "lib/opponent_generator"
require_relative "lib/battle_registry"
require_relative "lib/progression_repository"
require_relative "lib/reward_rule"

module ServerCommon
  private

  def current_user
    session[:user_id]
  end

  def battle_moves_for(pokemon)
    saved = pokemon.moves.filter_map { |name| settings.api.move(name) }
    return saved unless saved.empty?

    moves = settings.api.moves_for(pokemon.number)
    return moves unless moves.empty?

    [Move.new(name: "Struggle", type: pokemon.types.first || "normal", power: 10, accuracy: nil, pp: 100)]
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
    erb :team, layout: false
  end

  def render_team_manage
    @team = settings.team.all(current_user)
    @available_moves = moves_for_team
    erb :team_manage, layout: false
  end

  def moves_for_team
    @team.to_h { |member| [member.id, settings.api.available_move_names(member.number)] }
  end

  def add_team_member
    pokemon = settings.api.find(params[:pokeName])
    @notice = add_team_notice(pokemon)
    @team = settings.team.all(current_user)
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

  def remove_team_member
    settings.team.remove(current_user, params[:id]) if params[:id]
    @team = settings.team.all(current_user)
    erb :team, layout: false
  end

  def move_team_member
    settings.team.move(current_user, params[:id], params[:new_slot].to_i)
    @team = settings.team.all(current_user)
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

module ServerBattleActions
  private

  def render_battle_fragment
    team = settings.team.all(current_user)
    return empty_team_fragment if team.empty?

    play = playable_engine(team)
    return battle_error_fragment unless play

    @engine = play
    settings.battles.set(current_user, @engine)
    erb :battle, layout: false
  end

  def playable_engine(team)
    player = player_team(team)
    return nil if player.size < team.size

    opponent = opponent_team(team)
    return nil unless opponent

    BattleEngine.new(
      team_a: player,
      team_b: opponent,
      effectiveness: TypeEffectiveness.load(settings.api)
    )
  end

  def player_team(team)
    team.filter_map do |member|
      detail = settings.api.detail(member.number)
      detail && BattlePokemon.from(detail, moves: battle_moves_for(member), level: member_level(member))
    end
  end

  def member_level(member)
    settings.progression.get(current_user, member.id)&.fetch(:level) || 1
  end

  def opponent_team(team)
    opponent = OpponentGenerator.new(
      names: settings.api.fetch_all_names,
      fetcher: settings.api.method(:detail),
      level: average_player_level(team)
    ).team
    return nil if opponent.empty?

    opponent.map { |battle_pokemon| battle_pokemon.new(moves: battle_moves_for(battle_pokemon)) }
  end

  def average_player_level(team)
    levels = team.map { |member| member_level(member) }
    (levels.sum / levels.size.to_f).round
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
    @engine = settings.battles.fetch(current_user)
    return erb :battle, layout: false unless @engine

    was_in_progress = !@engine.finished?
    @engine.play_round
    grant_finished_xp if was_in_progress && @engine.finished?
    @xp_gained = RewardRule.new.xp_for(@engine.result) if @engine.finished?
    erb :battle, layout: false
  end

  def grant_finished_xp
    reward = RewardRule.new.xp_for(@engine.result)
    settings.team.all(current_user).each do |member|
      settings.progression.grant(current_user, member.id, reward)
    end
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
    register_team_manage(app)
    register_add_member(app)
    register_remove_member(app)
    register_move_member(app)
    register_save_moves(app)
  end

  def self.register_team(app)
    app.get("/team") { render_team }
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
    enable :logging
    enable :sessions
    set :session_secret, ENV["SESSION_SECRET"] ||
                         "706f6b656465782d6465762d7365637265742d30313233343536373839616263646566"
    set :bind, "0.0.0.0"
    set :port, 3000
    set :views, "views"
    set :team, TeamRepository.new
    set :progression, ProgressionRepository.new
    set :battles, BattleRegistry.new
    set :api, PokeApi.instance
    register Sinatra::Reloader
  end

  before do
    session[:user_id] ||= SecureRandom.uuid
  end

  include ServerCommon
  include ServerListActions
  include ServerTeamActions
  include ServerBattleActions

  register PokemonRoutes
  register TeamRoutes
  register BattleRoutes
  register ErrorHandling

  run! if $PROGRAM_NAME == app_file
end
