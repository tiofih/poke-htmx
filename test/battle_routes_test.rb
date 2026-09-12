# frozen_string_literal: true

require_relative "server_test_helpers"
require_relative "battle_test_helpers"
class ServerBattleTest < Minitest::Test # rubocop:disable Metrics/ClassLength
  include ServerTestHelpers
  include TestSupport
  include ServerBattleTestHelpers

  def setup
    super
    fill_team("user-a")
  end

  def test_battle_page_renders_full_page_with_battle_view
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "<html"
    assert_includes last_response.body, 'href="/battle" class="btn btn-primary"'
    assert_includes last_response.body, 'id="battle-view"'
  end

  def test_battle_close_route_is_removed
    get "/battle/close"

    assert_equal 404, last_response.status
  end

  def test_request_releases_thread_connections
    refute_equal 0, ConnectionRegistry.size, "sanity: conexao registrada antes do request"

    get "/", {}, user_session("user-a")

    assert last_response.ok?
    assert_equal 0, ConnectionRegistry.size, "after do request libera as conexoes da thread"
  end

  def test_battle_renders_remaining_stock_in_player_panel
    @inventory.add("user-a", "potion", 2)
    @inventory.add("user-a", "super-potion", 1)

    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "Itens:"
    assert_includes last_response.body, "Pocao"
    assert_includes last_response.body, "×2"
    assert_includes last_response.body, "×1"
  end

  def test_battle_play_debits_used_item_and_shows_heal_log
    member_id = @repository.all("user-a").first.id
    @progression.update_hp("user-a", member_id, 200, 90)
    @inventory.add("user-a", "potion", 2)

    stub_battle_start { get "/battle", {}, user_session("user-a") }
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    used = last_response.body.scan("usou 1 Pocao").size
    assert_operator used, :>=, 1, "pocao usada ao menos uma vez no log"
    assert_equal 2 - used, TestDatabase.inventory_quantity("user-a", "potion"),
                 "cada uso de pocao debitado do inventario"
  end

  def test_battle_play_without_item_use_does_not_debit_inventory
    @inventory.add("user-a", "potion", 2)
    weak = build_pokemon(number: 1, name: "weak", hp: 10, attack: 1, defense: 1, speed: 1)
    strong = build_pokemon(number: 2, name: "strong", hp: 100, attack: 50, defense: 50, speed: 50)
    engine = BattleEngine.new(team_a: [strong], team_b: [weak])
    Server.settings.battles.set("user-a", engine)

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, "usou Pocao", "batalha sem itens nao usa pocao"
    assert_equal 2, TestDatabase.inventory_quantity("user-a", "potion"), "nada debitado sem item usado"
  end

  def test_battle_panel_shows_item_used_badge_after_member_uses_item
    member_id = @repository.all("user-a").first.id
    @progression.update_hp("user-a", member_id, 200, 90)
    @inventory.add("user-a", "potion", 2)

    stub_battle_start { get "/battle", {}, user_session("user-a") }
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "usou 1 Pocao"
    assert_includes last_response.body, "já usou item"
  end

  def test_battle_panel_has_no_item_used_badge_before_any_use
    @inventory.add("user-a", "potion", 2)

    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    refute_includes last_response.body, "já usou item"
  end

  def test_battle_start_loads_into_panel_without_clearing_nav
    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Seu Time"
  end

  def test_battle_renders_panels_with_team_and_opponent
    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Seu Time"
    assert_includes last_response.body, "Oponente"
    assert_includes last_response.body, "pikachu"
    assert_includes last_response.body, "202/202"
    assert_includes last_response.body, 'hx-target="#battle-view"'
  end

  def test_battle_panels_render_hp_bars_for_player_and_opponent
    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'class="bar-fill ok"',
                    "barra de HP presente no painel do jogador"
    assert_includes last_response.body, 'class="bar-fill ok"',
                    "barra de HP presente no painel do oponente"
  end

  def test_battle_hp_bar_width_reflects_hp_share
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 202, 50)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "HP 50/202",
                    "texto de HP preservado"
    assert_includes last_response.body, 'style="width: 25%"',
                    "barra de HP com ~25% para 50/202"
  end

  def test_battle_panels_render_pp_bars_per_move
    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'class="move"',
                    "golpe como pill .move no card do lutador"
    assert_includes last_response.body, "PP 30",
                    "texto de PP preservado"
  end

  def test_battle_fragment_has_battle_button_and_no_play_button
    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, ">Próxima rodada</button>"
    assert_includes last_response.body, "hx-post=\"/battle/play\""
    assert_includes last_response.body, "hx-indicator=\"#battle-loading\""
    assert_includes last_response.body, 'hx-target="#battle-view"'
    refute_includes last_response.body, ">Batalhar</button>", "botao avanca uma rodada por vez"

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "log__entry",
                    "entradas do log com classe de animacao escalonada"
  end

  def test_battle_auto_toggle_chains_advance_until_finished
    start_battle_for("user-a")

    post "/battle/play", { "auto" => "1" }, user_session("user-a")

    assert last_response.ok?
    assert_equal "next-round", last_response.headers["HX-Trigger"],
                 "auto ligado e batalha aberta: servidor emite next-round para encadear"

    300.times do
      break if last_response.body.include?("Fim de batalha")

      post "/battle/play", { "auto" => "1" }, user_session("user-a")
    end

    assert_includes last_response.body, "Fim de batalha", "cadeia auto resolve a batalha"
    assert_nil last_response.headers["HX-Trigger"],
               "batalha terminada: sem header, cadeia para e modal de resultado aparece"
  end

  def test_battle_auto_off_stops_chain
    start_battle_for("user-a")

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_nil last_response.headers["HX-Trigger"],
               "toggle desligado: sem header, sem encadeamento"
    assert_includes last_response.body, ">Próxima rodada</button>"
  end

  def test_battle_auto_stays_checked_across_swaps
    start_battle_for("user-a")

    post "/battle/play", { "auto" => "1" }, user_session("user-a")

    assert last_response.ok?
    assert_match(/<input[^>]*id="auto-play"[^>]*checked/, last_response.body,
                 "auto=1 re-renderiza o toggle marcado para o chain continuar")
  end

  def test_battle_play_button_wires_auto_chain
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    body = last_response.body
    assert_match(/<input[^>]*id="auto-play"[^>]*name="auto"[^>]*value="1"/, body,
                 "toggle JOGAR-AUTO opt-in presente")
    assert_includes body, "JOGAR-AUTO"
    assert_includes body, 'hx-trigger="click, next-round from:body"',
                    "botao ouve click + next-round vindo do body"
    assert_includes body, 'hx-include="#auto-play"', "botao propaga o toggle no chain"
    assert_includes body, 'hx-indicator="#battle-loading"', "indicador de loading preservado"
  end

  def test_battle_with_empty_team_shows_journey_gate
    get "/battle", {}, user_session("user-novo")

    assert last_response.ok?
    assert_match(/jornada/i, last_response.body)
  end

  def test_battle_gate_shows_game_over_fragment_when_stuck
    TestDatabase.clear_team!
    fill_team("user-a")
    @repository.all("user-a").each { |member| @progression.update_hp("user-a", member.id, 200, 0) }

    get "/battle", {}, htmx_session("user-a")

    assert last_response.ok?
    assert_match(/game over/i, last_response.body)
    assert_match(/Vender itens/i, last_response.body)
    assert_match(/Recome\S* jornada/, last_response.body)
  end

  def test_battle_play_after_resolve_keeps_final_state
    start_battle_for("user-a")
    play_until_finish(fallback_plays: 300)
    final_round = last_response.body[/Rodada (\d+) — Fim de batalha/, 1]
    final_hp = last_response.body[%r{HP \d+/\d+}]

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_match(/Rodada #{final_round} — Fim de batalha/, last_response.body,
                 "play apos resolver nao avanca a rodada")
    assert_includes last_response.body, final_hp, "estado final preservado"
  end

  def test_battle_play_without_started_battle_does_not_break
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
  end

  def test_battle_play_advances_single_round_per_request
    start_battle_for("user-a")

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Rodada 1", "um play avanca exatamente uma rodada"
    refute_includes last_response.body, "Fim de batalha", "um unico play nao resolve a batalha inteira"
    assert_includes last_response.body, ">Próxima rodada</button>"
  end

  def test_battle_log_grows_round_by_round_until_finish
    start_battle_for("user-a")

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Rodada 1",
                    "primeiro play mostra a primeira rodada"

    play_until_finish(fallback_plays: 300)

    assert last_response.ok?
    assert_match(/Fim de batalha/, last_response.body,
                 "plays sucessivos levam a batalha ao fim")
  end

  def test_battle_fragment_marks_juice_targets
    start_battle_for("user-a")

    play_until_finish(fallback_plays: 300)

    assert last_response.ok?
    body = last_response.body
    assert_includes body, "Fim de batalha", "precondition: plays ate o fim resolvem a batalha"

    # log: origem/alvo por entrada (juice C2)
    assert_match(/data-round="\d+"/, body, "entrada do log marca a rodada")
    assert_match(/data-from-side="[01]"/, body, "entrada do log marca a origem 0/1")
    assert_match(/data-to-side="[01]"/, body, "entrada do log marca o alvo 0/1")

    # painéis: HP inicial + flash de dano + KO + projétil
    assert_match(/data-hp-initial="\d+"/, body, "painel marca o HP inicial do lutador")
    assert_match(/data-damage="\d+"/, body, "painel marca o dano para o numero flutuante")
    assert_match(/is-hit/, body, "painel do alvo marca flash de dano")
    assert_match(/fainted/, body, "lutador derrotado marca KO fade/grayscale")
    assert_match(/is-attacking/, body, "painel do atacante marca o projetil")
    assert_match(/class="shot"/, body, "elemento do projetil presente no atacante")

    # banner vitória/derrota + news com classes de animacao (D4 C, markup 0074)
    assert_includes body, 'class="winner-badge"', "banner de vitoria animado"
    assert_includes body, 'class="rewards"', "news de XP animada"
  end

  def test_battle_end_shows_winner_and_reset_button
    start_battle_for("user-a")
    play_until_finish(fallback_plays: 300)

    assert last_response.ok?
    assert_includes last_response.body, "Vencedor:"
    assert_match(/Novo confronto/, last_response.body)
  end

  def test_finished_battle_shows_game_over_and_restart_when_broke
    TestDatabase.clear_team!
    fill_team("user-a")
    @repository.all("user-a").each { |member| @progression.update_hp("user-a", member.id, 200, 0) }

    weak = build_pokemon(number: 1, name: "weak", hp: 10, attack: 1, defense: 1, speed: 1)
    strong = build_pokemon(number: 2, name: "strong", hp: 100, attack: 50, defense: 50, speed: 50)
    engine = BattleEngine.new(team_a: [weak], team_b: [strong])
    engine.play_round until engine.finished?
    Server.settings.battles.set("user-a", engine)

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Vencedor:"
    assert_match(/game over/i, last_response.body)
    assert_match(/Recome\S* jornada/, last_response.body)
    assert_match(/Vender itens/i, last_response.body)
    refute_includes last_response.body, "Novo confronto"
  end

  def test_finish_screen_disables_new_confront_when_team_defeated
    TestDatabase.clear_team!
    fill_team("user-a")
    @repository.all("user-a").each { |member| @progression.update_hp("user-a", member.id, 200, 0) }
    @wallet.grant("user-a", 1000)

    weak = build_pokemon(number: 1, name: "weak", hp: 10, attack: 1, defense: 1, speed: 1)
    strong = build_pokemon(number: 2, name: "strong", hp: 100, attack: 50, defense: 50, speed: 50)
    engine = BattleEngine.new(team_a: [weak], team_b: [strong])
    engine.play_round until engine.finished?
    Server.settings.battles.set("user-a", engine)

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Vencedor:"
    assert_match(/Novo confronto/, last_response.body)
    assert_match(/disabled title="Recupere seus pok[ée]mons/, last_response.body)
  end

  def test_heal_from_battle_refreshes_battle_view_with_new_confront_enabled
    TestDatabase.clear_team!
    fill_team("user-a")
    @repository.all("user-a").each { |member| @progression.update_hp("user-a", member.id, 200, 0) }
    @wallet.grant("user-a", 1000)

    weak = build_pokemon(number: 1, name: "weak", hp: 10, attack: 1, defense: 1, speed: 1)
    strong = build_pokemon(number: 2, name: "strong", hp: 100, attack: 50, defense: 50, speed: 50)
    engine = BattleEngine.new(team_a: [weak], team_b: [strong])
    engine.play_round until engine.finished?
    Server.settings.battles.set("user-a", engine)

    post "/battle/play", {}, user_session("user-a")

    assert_match(/disabled title="Recupere seus pok[ée]mons/, last_response.body)

    env = user_session("user-a").merge("HTTP_HX_CURRENT_URL" => "http://example.org/battle")
    stub_battle_start { post "/team/heal", {}, env }

    assert last_response.ok?
    refute_includes last_response.body, 'id="battle-view"'
    assert_includes last_response.body, "Pronto p/ batalhar"
  end

  def test_heal_and_battle_from_battle_starts_fresh_confrontation
    TestDatabase.clear_team!
    fill_team("user-a")
    @repository.all("user-a").each { |member| @progression.update_hp("user-a", member.id, 200, 0) }
    @wallet.grant("user-a", 1000)

    weak = build_pokemon(number: 1, name: "weak", hp: 10, attack: 1, defense: 1, speed: 1)
    strong = build_pokemon(number: 2, name: "strong", hp: 100, attack: 50, defense: 50, speed: 50)
    engine = BattleEngine.new(team_a: [weak], team_b: [strong])
    engine.play_round until engine.finished?
    Server.settings.battles.set("user-a", engine)

    post "/battle/play", {}, user_session("user-a")

    assert_match(/disabled title="Recupere seus pok[ée]mons/, last_response.body)

    env = user_session("user-a").merge("HTTP_HX_CURRENT_URL" => "http://example.org/battle")
    stub_battle_start { post "/team/heal", { heal_and_battle: "1" }, env }

    assert last_response.ok?
    assert_includes last_response.body, 'id="battle-view" hx-swap-oob="innerHTML"'
    assert_includes last_response.body, 'hx-post="/battle/play"'
    refute_match(/disabled title="Recupere seus pok/, last_response.body)
  end

  def test_heal_outside_battle_omits_battle_view_oob
    TestDatabase.clear_team!
    fill_team("user-a")
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 200, 100)
    @wallet.grant("user-a", 200)

    post "/team/heal", {}, user_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, 'id="battle-view"'
  end

  def test_center_modal_offers_heal_and_heal_and_battle
    get "/team/center", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Curar e batalhar"
    assert_includes last_response.body, 'name="heal_and_battle" value="1"'
  end

  def test_finish_screen_keeps_new_confront_active_when_team_has_hp
    TestDatabase.clear_team!
    fill_team("user-a")

    hero = build_pokemon(number: 1, name: "hero", hp: 100, attack: 50, defense: 50, speed: 50)
    minion = build_pokemon(number: 2, name: "minion", hp: 10, attack: 1, defense: 1, speed: 1)
    engine = BattleEngine.new(team_a: [hero], team_b: [minion])
    engine.play_round until engine.finished?
    Server.settings.battles.set("user-a", engine)

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Vencedor:"
    assert_includes last_response.body, 'hx-post="/battle/new"'
    refute_match(/disabled title="Recupere seus pok/, last_response.body)
  end

  def test_battle_end_shows_gameloop_ctas
    start_battle_for("user-a")
    play_until_finish(fallback_plays: 300)

    assert last_response.ok?
    assert_match(%r{hx-get="/team/center"[^>]*>Poke Center</(a|button)>}, last_response.body)
    assert_match(%r{hx-get="/team/mart"[^>]*>Poke Mart</a>}, last_response.body)
    assert_includes last_response.body, "Novo confronto"
  end

  def test_battle_reset_starts_a_fresh_battle_with_persisted_hp
    start_battle_for("user-a")
    play_until_finish(fallback_plays: 300)
    persisted_hp = @repository.all("user-a").map(&:hp_current)

    stub_battle_start { post "/battle/new", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "Rodada 0",
                    "novo confronto recria a batalha do zero"
    persisted_hp.each do |hp|
      assert_includes last_response.body, "HP #{hp}/",
                      "time danificado (HP #{hp}) entra no novo confronto"
    end
  end

  def test_battle_revisits_keep_same_opponent
    first = nil
    second = nil

    stub_battle_start do
      get "/battle", {}, htmx_session("user-a")
      first = last_response.body
      get "/battle", {}, htmx_session("user-a")
      second = last_response.body
    end

    assert last_response.ok?
    assert_equal first, second, "revisitar mantem a batalha preparada identica (mesmo oponente)"
  end

  def test_new_confront_generates_new_opponent
    TestDatabase.clear_team!
    fill_team("user-a")
    first = nil
    second = nil
    names = %w[pikachu bulbasaur charmander squirtle eevee jigglypuff]
    details = names.to_h { |name| [name, battle_pokemon_named(name, 1)] }
                   .merge(25 => pikachu_pokemon)
    [1, 4, 7, 16, 19].each { |number| details[number] = battle_pokemon_for_test }

    with_seeded_battle_rng do
      PokeApiStub.with_all_names(names) do
        PokeApiStub.with_type(neutral_type_json_table) do
          PokeApiStub.with_gateway(detail: details) do
            PokeApiStub.with_moves_for(battle_moves_for_test) do
              get "/battle", {}, htmx_session("user-a")
              first = last_response.body
              post "/battle/new", {}, htmx_session("user-a")
              second = last_response.body
            end
          end
        end
      end
    end

    assert last_response.ok?
    refute_equal first, second, "novo confronto gera oponente diferente"
  end

  def test_removing_member_resets_prepared_battle
    member_id = @repository.all("user-a").first.id
    first = nil
    second = nil

    with_seeded_battle_rng do
      stub_battle_start do
        get "/battle", {}, htmx_session("user-a")
        first = last_response.body
      end
      delete "/team", { id: member_id }, htmx_session("user-a")
      stub_battle_start do
        get "/battle", {}, htmx_session("user-a")
        second = last_response.body
      end
    end

    assert last_response.ok?
    refute_equal first, second, "remover membro invalida a batalha preparada (novo confronto)"
  end

  def test_battle_shows_moves_with_pp_per_fighter
    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "thunder-shock"
    assert_includes last_response.body, "PP 30"
  end

  def test_battle_log_shows_used_move_name
    start_battle_for("user-a")

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "thunder-shock"
    assert_includes last_response.body, "usou thunder-shock em"
  end

  def test_battle_with_struggle_fallback_does_not_break
    PokeApiStub.with_all_names(%w[pikachu bulbasaur charmander squirtle eevee jigglypuff]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_detail(battle_pokemon_for_test) do
          PokeApiStub.with_moves_for([]) do
            get "/battle", {}, user_session("user-a")
          end
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "Struggle"
  end

  def test_battle_uses_saved_moves_for_player
    pikachu_id = @repository.all("user-a").first.id
    @repository.set_moves("user-a", pikachu_id, %w[quick-attack])

    PokeApiStub.with_all_names(%w[pikachu bulbasaur charmander squirtle eevee jigglypuff]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_detail(battle_pokemon_for_test) do
          PokeApiStub.with_moves_for(battle_moves_for_test) do
            PokeApiStub.with_move("quick-attack" => build_move("quick-attack", type: "normal", power: 40, pp: 30)) do
              get "/battle", {}, user_session("user-a")
            end
          end
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "quick-attack"
  end

  def test_battle_play_log_uses_saved_move_name
    pikachu_id = @repository.all("user-a").first.id
    @repository.set_moves("user-a", pikachu_id, %w[quick-attack])

    PokeApiStub.with_all_names(%w[pikachu bulbasaur charmander squirtle eevee jigglypuff]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_detail(battle_pokemon_for_test) do
          PokeApiStub.with_moves_for(battle_moves_for_test) do
            PokeApiStub.with_move("quick-attack" => build_move("quick-attack", type: "normal", power: 40, pp: 30)) do
              get "/battle", {}, user_session("user-a")
            end
          end
        end
      end
    end

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "usou quick-attack em"
  end

  def test_battle_with_unresolvable_saved_moves_falls_back_to_default
    pikachu_id = @repository.all("user-a").first.id
    @repository.set_moves("user-a", pikachu_id, %w[obsolete-move])

    PokeApiStub.with_all_names(%w[pikachu bulbasaur charmander squirtle eevee jigglypuff]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_detail(battle_pokemon_for_test) do
          PokeApiStub.with_moves_for(battle_moves_for_test) do
            PokeApiStub.with_move({}) do
              get "/battle", {}, user_session("user-a")
            end
          end
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "thunder-shock"
  end

  def test_battle_with_member_detail_nil_shows_friendly_message
    PokeApiStub.with_all_names(%w[pikachu bulbasaur charmander squirtle eevee jigglypuff]) do
      PokeApiStub.with_detail(nil) do
        get "/battle", {}, user_session("user-a")
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "Não foi possível preparar a batalha."
    assert_includes last_response.body, "<html"
  end

  def test_battle_with_empty_opponent_shows_friendly_message
    PokeApiStub.with_all_names([]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_detail(battle_pokemon_for_test) do
          PokeApiStub.with_moves_for(battle_moves_for_test) do
            get "/battle", {}, user_session("user-a")
          end
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "Não foi possível preparar a batalha."
  end

  def test_battle_renders_level_one_per_fighter_by_default
    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Nível 5"
    assert_includes last_response.body, "202/202", "nível 5 escala stats"
  end

  def test_battle_uses_persisted_member_level_for_player_and_opponent
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.grant("user-a", pokemon_id, 600)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Nível 6"
    assert_includes last_response.body, "203/203", "HP 202 escala para 203 no nível 6"
  end

  def test_battle_play_shows_xp_gained_message_at_finish
    start_battle_for("user-a")
    play_until_finish(fallback_plays: 300)

    assert last_response.ok?
    assert_match(/Seu Time ganhou \d+ XP|Derrota — \+\d+ XP/, last_response.body)
  end

  def test_battle_play_grants_xp_once_on_transition_to_finished
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    start_battle_for("user-a")

    play_until_finish(fallback_plays: 300)

    after_finish = TestDatabase.progress_row(pokemon_id)["xp"].to_i
    # base 1000 (nv 5) + delta do resultado: lose 10 / draw 25 / win 50 (flat, sem grant de level)
    assert_includes [1010, 1025, 1050], after_finish, "XP concedido uma vez conforme o resultado"

    5.times { post "/battle/play", {}, user_session("user-a") }

    assert_equal after_finish, TestDatabase.progress_row(pokemon_id)["xp"].to_i,
                 "play após o fim não concede XP de novo (guard de transição)"
  end

  def test_battle_reset_reflects_persisted_xp_on_new_confront
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    start_battle_for("user-a")
    play_until_finish(fallback_plays: 300)

    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "Nível #{TestDatabase.progress_row(pokemon_id)['level'].to_i}"
  end

  def test_battle_play_grants_money_once_on_transition_to_finished
    start_battle_for("user-a")
    assert_equal 0, @wallet.balance("user-a"), "moeda não concedida antes do fim"

    play_until_finish(fallback_plays: 300)

    after_finish = @wallet.balance("user-a")
    assert_includes [40, 50, 100], after_finish, "moeda concedida uma vez conforme o resultado"

    5.times { post "/battle/play", {}, user_session("user-a") }

    assert_equal after_finish, @wallet.balance("user-a"),
                 "play após o fim não concede moeda de novo (guard de transição)"
  end

  def test_battle_play_does_not_grant_money_before_finish
    start_battle_for("user-a")
    assert_equal 0, @wallet.balance("user-a"), "moeda não concedida ao abrir a batalha"

    post "/battle/play", {}, user_session("user-a")

    assert_includes last_response.body, "Rodada 1", "primeiro play avanca uma rodada"
    refute_includes last_response.body, "Fim de batalha", "batalha 6v6 nao termina em 1 rodada"
    assert_equal 0, @wallet.balance("user-a"), "sem moeda antes do fim"
  end

  def test_battle_finish_shows_money_gained_message
    start_battle_for("user-a")
    play_until_finish(fallback_plays: 300)

    assert last_response.ok?
    assert_match(/¥\d+/, last_response.body)
    body = last_response.body
    assert(body.match?(/ganhou \d+ XP por Pokémon e \+¥\d+/) ||
           body.match?(/Derrota — \+\d+ XP por Pokémon e \+¥\d+/),
           "XP de vitoria ou derrota")
  end

  def test_battle_finish_evolves_member_when_level_reaches_min_level
    TestDatabase.clear_team!
    fill_team("user-a")
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.grant("user-a", pokemon_id, 99_999)

    raichu_detail = Pokemon.new(name: "raichu", sprite: "https://example.com/raichu.png", number: 26)
    detail_map = { 25 => battle_pokemon_for_test, 26 => raichu_detail, "pikachu" => battle_pokemon_for_test }
    [1, 4, 7, 16, 19].each { |number| detail_map[number] = battle_pokemon_for_test }
    evolution_data = [{ number: 26, name: "raichu", min_level: 16 }]

    PokeApiStub.with_all_names(%w[pikachu]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_gateway(detail: detail_map, moves_for: battle_moves_for_test,
                                 next_evolutions: evolution_data) do
          get "/battle", {}, user_session("user-a")
          play_until_finish(fallback_plays: 300)
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "evoluiu para raichu"
    assert_includes last_response.body, 'src="https://example.com/raichu.png"',
                    "painel da batalha deve exibir sprite do pokemon evoluido"
  end

  def test_battle_finish_does_not_evolve_when_target_already_in_team
    TestDatabase.clear_team!
    fill_team("user-a",
              members: [["pikachu", 25], ["raichu", 26], ["charmander", 4], ["squirtle", 7], ["pidgey", 16],
                        ["rattata", 19]])
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.grant("user-a", pikachu_id, 99_999)

    raichu_detail = Pokemon.new(name: "raichu", sprite: "https://example.com/raichu.png", number: 26)
    detail_map = { 25 => battle_pokemon_for_test, 26 => raichu_detail, "pikachu" => battle_pokemon_for_test }
    [4, 7, 16, 19].each { |number| detail_map[number] = battle_pokemon_for_test }
    evolution_data = [{ number: 26, name: "raichu", min_level: 16 }]

    PokeApiStub.with_all_names(%w[pikachu]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_gateway(detail: detail_map, moves_for: battle_moves_for_test,
                                 next_evolutions: evolution_data) do
          get "/battle", {}, user_session("user-a")
          play_until_finish(fallback_plays: 300)
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "não evoluiu"
  end

  def test_battle_finish_learns_moves_when_level_sufficient
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.grant("user-a", pokemon_id, 99_999)

    learnable = [{ level: 5, name: "quick-attack" }, { level: 30, name: "thunderbolt" }]
    stub_battle_start do
      PokeApiStub.with_learnable_moves(learnable) do
        get "/battle", {}, user_session("user-a")
        play_until_finish(fallback_plays: 50)
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "aprendeu quick-attack"
    assert_includes last_response.body, "aprendeu thunderbolt"
    assert_includes @repository.all("user-a").first.moves, "quick-attack"
    assert_includes @repository.all("user-a").first.moves, "thunderbolt"
  end

  def test_battle_finish_does_not_learn_when_level_insufficient
    stub_battle_start do
      PokeApiStub.with_learnable_moves([{ level: 50, name: "thunder" }]) do
        get "/battle", {}, user_session("user-a")
        play_until_finish(fallback_plays: 50)
      end
    end

    assert last_response.ok?
    refute_includes last_response.body, "aprendeu"
    assert_empty @repository.all("user-a").first.moves
  end

  def test_battle_finish_persists_one_record_in_battles
    start_battle_for("user-a")
    play_until_finish(fallback_plays: 300)

    rows = TestDatabase.battle_rows("user-a")
    assert_equal 1, rows.size, "exatamente um registro ao finar a batalha"
    assert_includes %w[win lose draw], rows.first["result"]
    assert_includes rows.first["opponent_team"].to_json, "pikachu"
  end

  def test_battle_play_after_finish_does_not_duplicate_battle_record
    start_battle_for("user-a")
    play_until_finish(fallback_plays: 300)
    after_finish = TestDatabase.battle_rows("user-a").size

    5.times { post "/battle/play", {}, user_session("user-a") }

    assert_equal after_finish, TestDatabase.battle_rows("user-a").size,
                 "play após o fim não persiste novo registro (guard de transição)"
  end

  def test_battle_in_progress_does_not_persist_record
    start_battle_for("user-a")

    assert_empty TestDatabase.battle_rows("user-a"),
                 "batalha aberta (nao resolvida) nao persiste registro"
  end

  def test_battle_records_are_isolated_per_user
    start_battle_for("user-a")
    play_until_finish(fallback_plays: 300)

    assert_empty TestDatabase.battle_rows("user-b")
  end

  def play_until_finish(fallback_plays: 20)
    fallback_plays.times do
      post "/battle/play", {}, user_session("user-a")
      return if last_response.body.include?("Fim de batalha")
    end
  end

  def test_battle_finish_persists_hp_per_member
    start_battle_for("user-a")
    play_until_finish(fallback_plays: 50)

    members = @repository.all("user-a")
    assert members.all? { |member| member.hp_max.positive? },
           "hp_max persistido após a batalha"
    assert members.any? { |member| member.hp_current < member.hp_max },
           "algum membro terminou a batalha com dano"
  end

  def test_battle_finish_persists_hp_only_once
    start_battle_for("user-a")
    play_until_finish(fallback_plays: 50)
    first = @repository.all("user-a").map(&:hp_current)

    5.times { post "/battle/play", {}, user_session("user-a") }

    assert_equal first, @repository.all("user-a").map(&:hp_current),
                 "plays após o fim não re-persistem HP (guard de transição)"
  end

  def test_battle_in_progress_does_not_persist_hp
    start_battle_for("user-a")

    members = @repository.all("user-a")
    assert members.all? { |member| member.hp_max.zero? },
           "batalha aberta (nao resolvida) nao persiste HP"
  end

  def test_new_battle_starts_with_persisted_hp
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 202, 50)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "HP 50/202",
                    "time danificado entra no próximo confronto com o HP persistido"
  end

  def test_new_battle_starts_full_for_member_who_never_battled
    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "HP 202/202",
                    "membro que nunca batalhou entra com HP cheio"
  end
end

class ServerBattleHpGateTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport
  include ServerBattleTestHelpers

  def zero_all_hp(user_id)
    @repository.all(user_id).each { |member| @progression.update_hp(user_id, member.id, 200, 0) }
  end

  def test_battle_blocked_when_all_hp_zero
    fill_team("user-a")
    zero_all_hp("user-a")
    @wallet.grant("user-a", 1000)

    get "/battle", {}, user_session("user-a")

    assert last_response.ok?
    assert_match(/Poke Center/, last_response.body)
    refute_includes last_response.body, %(hx-post="/battle/play")
    assert_match(/<button class="btn btn-secondary" disabled title="Recupere seus pok[ée]mons/, last_response.body)
  end

  def test_new_confront_blocked_when_all_hp_zero
    fill_team("user-a")
    zero_all_hp("user-a")
    @wallet.grant("user-a", 1000)

    post "/battle/new", {}, user_session("user-a")

    assert last_response.ok?
    assert_match(/Poke Center/, last_response.body)
    refute_includes last_response.body, %(hx-post="/battle/play")
    assert_match(/<button class="btn btn-secondary" disabled title="Recupere seus pok[ée]mons/, last_response.body)
  end

  def test_battle_opens_when_partial_team_has_hp
    fill_team("user-a")
    zero_all_hp("user-a")
    first = @repository.all("user-a").first
    @progression.update_hp("user-a", first.id, 200, 100)

    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "Batalha"
  end
end

class ServerJourneyGateBattleTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport
  include ServerBattleTestHelpers

  def test_battle_blocked_before_journey_with_partial_team
    3.times { |n| @repository.add("user-novo", build_pokemon_record("pokemon#{n}", n + 1)) }

    get "/battle", {}, user_session("user-novo")

    assert last_response.ok?
    assert_includes last_response.body, "<html"
    assert_match(/jornada/i, last_response.body)
    refute_includes last_response.body, %(hx-post="/battle/play")
  end

  def test_battle_blocked_when_team_shrinks_below_six
    fill_team("user-a")
    2.times { delete "/team", { id: @repository.all("user-a").first.id }, user_session("user-a") }

    get "/battle", {}, user_session("user-a")

    assert last_response.ok?
    assert_match(/jornada/i, last_response.body)
    refute_includes last_response.body, %(hx-post="/battle/play")
  end

  def test_battle_opens_after_journey_started
    fill_team("user-a")

    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "Batalha"
  end
end
