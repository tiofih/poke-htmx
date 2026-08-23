# frozen_string_literal: true

require_relative "server_test_helpers"
require_relative "battle_test_helpers"
class ServerBattleTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport
  include ServerBattleTestHelpers

  def setup
    super
    start_journey("user-a")
  end

  def test_battle_page_renders_full_page_with_battle_view
    @repository.add("user-a", pikachu_pokemon)
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "<html"
    assert_includes last_response.body, 'href="/battle" class="active"'
    assert_includes last_response.body, 'id="battle-view"'
  end

  def test_battle_close_route_is_removed
    get "/battle/close"

    assert_equal 404, last_response.status
  end

  def test_battle_renders_remaining_stock_in_player_panel
    @repository.add("user-a", pikachu_pokemon)
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
    @repository.add("user-a", pikachu_pokemon)
    member_id = @repository.all("user-a").first.id
    @progression.update_hp("user-a", member_id, 200, 90)
    @inventory.add("user-a", "potion", 2)

    stub_battle_start { get "/battle", {}, user_session("user-a") }
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "usou Pocao"
    assert_match(/\+20 HP/, last_response.body)
    assert_equal 1, TestDatabase.inventory_quantity("user-a", "potion"), "uma pocao debitada"
  end

  def test_battle_play_without_item_use_does_not_debit_inventory
    @repository.add("user-a", pikachu_pokemon)
    @inventory.add("user-a", "potion", 2)

    stub_battle_start { get "/battle", {}, user_session("user-a") }
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, "usou Pocao"
    assert_equal 2, TestDatabase.inventory_quantity("user-a", "potion"), "nada debitado sem item usado"
  end

  def test_battle_start_loads_into_panel_without_clearing_nav
    @repository.add("user-a", pikachu_pokemon)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Seu Time"
  end

  def test_battle_renders_panels_with_team_and_opponent
    @repository.add("user-a", pikachu_pokemon)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Seu Time"
    assert_includes last_response.body, "Oponente"
    assert_includes last_response.body, "pikachu"
    assert_includes last_response.body, "200/200"
    assert_includes last_response.body, 'hx-target="#battle-view"'
  end

  def test_battle_fragment_has_play_button
    @repository.add("user-a", pikachu_pokemon)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "hx-post=\"/battle/play\""
    refute_includes last_response.body, "Vencedor"
  end

  def test_battle_with_empty_team_shows_friendly_message
    get "/battle", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Forme seu time"
  end

  def test_battle_play_advances_one_round_and_refreshes_fragment
    start_battle_for("user-a")

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Rodada 1"
    assert_includes last_response.body, "usou thunder-shock em"
  end

  def test_battle_play_reuses_state_between_requests
    start_battle_for("user-a")

    post "/battle/play", {}, user_session("user-a")
    round_one_hp = last_response.body

    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Rodada 2"
    refute_equal round_one_hp, last_response.body, "estado avança (HP/log mudam) a cada play"
  end

  def test_battle_play_without_started_battle_does_not_break
    post "/battle/play", {}, user_session("user-a")

    assert last_response.ok?
  end

  def test_battle_end_shows_winner_and_reset_button
    start_battle_for("user-a")
    20.times { post "/battle/play", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "Vencedor:"
    assert_includes last_response.body, "hx-get=\"/battle\""
  end

  def test_battle_reset_starts_a_fresh_battle_with_persisted_hp
    start_battle_for("user-a")
    20.times { post "/battle/play", {}, user_session("user-a") }
    persisted_hp = @repository.all("user-a").map(&:hp_current)

    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "Rodada 0",
                    "reset recria a batalha do zero"
    persisted_hp.each do |hp|
      assert_includes last_response.body, "HP #{hp}/",
                      "time danificado (HP #{hp}) entra no reset"
    end
  end

  def test_battle_shows_moves_with_pp_per_fighter
    @repository.add("user-a", pikachu_pokemon)

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
    @repository.add("user-a", pikachu_pokemon)

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
    @repository.add("user-a", pikachu_pokemon)
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
    @repository.add("user-a", pikachu_pokemon)
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
    @repository.add("user-a", pikachu_pokemon)
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
    @repository.add("user-a", pikachu_pokemon)

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
    @repository.add("user-a", pikachu_pokemon)

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
    @repository.add("user-a", pikachu_pokemon)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Nível 1"
    assert_includes last_response.body, "200/200", "nível 1 não escala stats"
  end

  def test_battle_uses_persisted_member_level_for_player_and_opponent
    @repository.add("user-a", pikachu_pokemon)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.grant("user-a", pokemon_id, 600)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Nível 4"
    assert_includes last_response.body, "202/202", "HP 200 escala para 202 no nível 4"
  end

  def test_battle_play_shows_xp_gained_message_at_finish
    start_battle_for("user-a")
    20.times { post "/battle/play", {}, user_session("user-a") }

    assert last_response.ok?
    assert_match(/Seu Time ganhou \d+ XP/, last_response.body)
  end

  def test_battle_play_grants_xp_once_on_transition_to_finished
    @repository.add("user-a", pikachu_pokemon)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    start_battle_for("user-a")

    20.times { post "/battle/play", {}, user_session("user-a") }

    after_finish = TestDatabase.progress_row(pokemon_id)["xp"].to_i
    assert_includes [20, 25, 50], after_finish, "XP concedido uma vez conforme o resultado"

    5.times { post "/battle/play", {}, user_session("user-a") }

    assert_equal after_finish, TestDatabase.progress_row(pokemon_id)["xp"].to_i,
                 "play após o fim não concede XP de novo (guard de transição)"
  end

  def test_battle_reset_reflects_persisted_xp_on_new_confront
    @repository.add("user-a", pikachu_pokemon)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    start_battle_for("user-a")
    20.times { post "/battle/play", {}, user_session("user-a") }

    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "Nível #{TestDatabase.progress_row(pokemon_id)['level'].to_i}"
  end

  def test_battle_play_grants_money_once_on_transition_to_finished
    @repository.add("user-a", pikachu_pokemon)
    start_battle_for("user-a")
    assert_equal 0, @wallet.balance("user-a"), "moeda não concedida antes do fim"

    20.times { post "/battle/play", {}, user_session("user-a") }

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

    refute_includes last_response.body, "Fim de batalha", "batalha de 3v6 não termina em 1 round"
    assert_equal 0, @wallet.balance("user-a"), "moeda não concedida antes do fim"
  end

  def test_battle_finish_shows_money_gained_message
    start_battle_for("user-a")
    20.times { post "/battle/play", {}, user_session("user-a") }

    assert last_response.ok?
    assert_match(/\d+ de dinheiro/, last_response.body)
    assert_match(/ganhou \d+ XP por Pokémon e \d+ de dinheiro/, last_response.body)
  end

  def test_battle_finish_evolves_member_when_level_reaches_min_level
    @repository.add("user-a", pikachu_pokemon)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.grant("user-a", pokemon_id, 99_999)

    raichu_detail = Pokemon.new(name: "raichu", sprite: "https://example.com/raichu.png", number: 26)
    detail_map = { 25 => battle_pokemon_for_test, 26 => raichu_detail, "pikachu" => battle_pokemon_for_test }
    evolution_data = [{ number: 26, name: "raichu", min_level: 16 }]

    PokeApiStub.with_all_names(%w[pikachu]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_gateway(detail: detail_map, moves_for: battle_moves_for_test,
                                 next_evolutions: evolution_data) do
          get "/battle", {}, user_session("user-a")
          play_until_finish
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "evoluiu para raichu"
    assert_includes last_response.body, 'src="https://example.com/raichu.png"',
                    "painel da batalha deve exibir sprite do pokemon evoluido"
  end

  def test_battle_finish_does_not_evolve_when_target_already_in_team
    @repository.add("user-a", pikachu_pokemon)
    @repository.add("user-a", Pokemon.new(name: "raichu", sprite: "", number: 26))
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.grant("user-a", pikachu_id, 99_999)

    raichu_detail = Pokemon.new(name: "raichu", sprite: "https://example.com/raichu.png", number: 26)
    detail_map = { 25 => battle_pokemon_for_test, 26 => raichu_detail, "pikachu" => battle_pokemon_for_test }
    evolution_data = [{ number: 26, name: "raichu", min_level: 16 }]

    PokeApiStub.with_all_names(%w[pikachu]) do
      PokeApiStub.with_type(neutral_type_json_table) do
        PokeApiStub.with_gateway(detail: detail_map, moves_for: battle_moves_for_test,
                                 next_evolutions: evolution_data) do
          get "/battle", {}, user_session("user-a")
          play_until_finish
        end
      end
    end

    assert last_response.ok?
    assert_includes last_response.body, "não evoluiu"
  end

  def test_battle_finish_learns_moves_when_level_sufficient
    @repository.add("user-a", pikachu_pokemon)
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
    @repository.add("user-a", pikachu_pokemon)

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
    20.times { post "/battle/play", {}, user_session("user-a") }

    rows = TestDatabase.battle_rows("user-a")
    assert_equal 1, rows.size, "exatamente um registro ao finar a batalha"
    assert_includes %w[win lose draw], rows.first["result"]
    assert_includes rows.first["opponent_team"].to_json, "pikachu"
  end

  def test_battle_play_after_finish_does_not_duplicate_battle_record
    start_battle_for("user-a")
    20.times { post "/battle/play", {}, user_session("user-a") }
    after_finish = TestDatabase.battle_rows("user-a").size

    5.times { post "/battle/play", {}, user_session("user-a") }

    assert_equal after_finish, TestDatabase.battle_rows("user-a").size,
                 "play após o fim não persiste novo registro (guard de transição)"
  end

  def test_battle_in_progress_does_not_persist_record
    start_battle_for("user-a")
    post "/battle/play", {}, user_session("user-a")

    assert_empty TestDatabase.battle_rows("user-a")
  end

  def test_battle_records_are_isolated_per_user
    start_battle_for("user-a")
    20.times { post "/battle/play", {}, user_session("user-a") }

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
    post "/battle/play", {}, user_session("user-a")

    members = @repository.all("user-a")
    assert members.all? { |member| member.hp_max.zero? },
           "batalha em andamento não persiste HP"
  end

  def test_new_battle_starts_with_persisted_hp
    @repository.add("user-a", pikachu_pokemon)
    @repository.add("user-a", bulbasaur_pokemon)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 200, 50)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "HP 50/200",
                    "time danificado entra no próximo confronto com o HP persistido"
  end

  def test_new_battle_starts_full_for_member_who_never_battled
    @repository.add("user-a", pikachu_pokemon)

    stub_battle_start do
      get "/battle", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "HP 200/200",
                    "membro que nunca batalhou entra com HP cheio"
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

  def test_battle_opens_after_journey_started
    start_journey("user-a")
    @repository.add("user-a", pikachu_pokemon)

    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    assert_includes last_response.body, "Batalha"
  end
end
