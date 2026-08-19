# frozen_string_literal: true

require_relative "server_test_helpers"
class ServerTeamTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_first_access_generates_session_cookie
    PokeApiStub.with_find(pikachu_pokemon) do
      post "/team", pokeName: "pikachu"
    end

    assert last_response.ok?
    assert_includes last_response.headers["Set-Cookie"], "rack.session"
  end

  def test_two_sessions_keep_isolated_teams
    session_a = rack_test_session
    session_b = rack_test_session

    PokeApiStub.with_find(pikachu_pokemon) do
      session_a.post "/team", pokeName: "pikachu"
    end
    PokeApiStub.with_find(bulbasaur_pokemon) do
      session_b.post "/team", pokeName: "bulbasaur"
    end

    assert_includes session_a.last_response.body, "pikachu"
    refute_includes session_a.last_response.body, "bulbasaur"
    assert_includes session_b.last_response.body, "bulbasaur"
    refute_includes session_b.last_response.body, "pikachu"

    assert_equal 2, TestDatabase.distinct_user_ids.size
  end

  def test_post_team_persists_pokemon_for_session_user
    PokeApiStub.with_find(pikachu_pokemon) do
      post "/team", { pokeName: "pikachu" }, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    team = @repository.all("user-a")
    assert_equal 1, team.size
    assert_equal "pikachu", team.first.name
    assert_includes last_response.body, %(name="id" value="#{team.first.id}")
    assert_includes last_response.body, "hx-delete=\"/team\""
    assert_empty @repository.all("user-b")
  end

  def test_post_team_starts_with_level_one_moves
    PokeApiStub.with_find(pikachu_pokemon) do
      PokeApiStub.with_learnable_moves(
        [{ level: 1, name: "growl" },
         { level: 1, name: "thunder-shock" },
         { level: 5, name: "quick-attack" }]
      ) do
        post "/team", { pokeName: "pikachu" }, user_session("user-a")
      end
    end

    assert last_response.ok?
    moves = @repository.all("user-a").first.moves
    assert_includes moves, "growl"
    assert_includes moves, "thunder-shock"
    refute_includes moves, "quick-attack", "move de nível 5 não deveria vir na montagem"
  end

  def test_delete_team_removes_pokemon_from_own_session
    @repository.add("user-a", pikachu_pokemon)
    id = @repository.all("user-a").first.id

    delete "/team", { id: id }, user_session("user-a")

    assert last_response.ok?
    assert_empty @repository.all("user-a")
    refute_includes last_response.body, "pikachu"
  end

  def test_delete_team_with_unknown_id_keeps_team_intact
    @repository.add("user-a", pikachu_pokemon)
    id = @repository.all("user-a").first.id
    unknown_id = (id.to_i + 999).to_s

    delete "/team", { id: unknown_id }, user_session("user-a")

    assert last_response.ok?
    assert_equal 1, @repository.all("user-a").size
    assert_includes last_response.body, "pikachu"
  end

  def test_delete_team_without_id_does_not_break
    delete "/team", {}, user_session("user-a")

    assert last_response.ok?
  end

  def test_delete_team_only_removes_own_session_member
    @repository.add("user-a", pikachu_pokemon)
    id = @repository.all("user-a").first.id

    delete "/team", { id: id }, user_session("user-b")

    assert last_response.ok?
    assert_equal 1, @repository.all("user-a").size
    assert_empty @repository.all("user-b")
  end

  def test_post_team_when_full_returns_warning_and_keeps_six
    six = (1..6).map do |n|
      build_pokemon_record("pokemon#{n}", n)
    end
    six.each { |poke| @repository.add("user-a", poke) }
    seventh = build_pokemon_record("meowth", 52)

    PokeApiStub.with_find(seventh) do
      post "/team", { pokeName: "meowth" }, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Time cheio"
    assert_equal 6, @repository.all("user-a").size
    refute_includes @repository.all("user-a").map(&:name), "meowth"
  end

  def test_post_team_with_duplicate_returns_warning_and_does_not_insert
    @repository.add("user-a", pikachu_pokemon)

    PokeApiStub.with_find(pikachu_pokemon) do
      post "/team", { pokeName: "pikachu" }, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "pikachu já está no time."
    assert_equal 1, @repository.all("user-a").size
  end

  def test_get_team_returns_own_session_team
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    assert_includes last_response.body, "hx-delete=\"/team\""
  end

  def test_get_team_is_isolated_per_session
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, user_session("user-b")

    assert last_response.ok?
    refute_includes last_response.body, "pikachu"
  end

  def test_team_remove_button_still_deletes_after_sprite_link
    @repository.add("user-a", pikachu_pokemon)
    @repository.add("user-a", bulbasaur_pokemon)
    pikachu_id = @repository.all("user-a").find { |poke| poke.name == "pikachu" }.id

    delete "/team", { id: pikachu_id }, user_session("user-a")

    assert last_response.ok?
    assert_equal 1, @repository.all("user-a").size
    refute_includes @repository.all("user-a").map(&:name), "pikachu"
    assert_includes @repository.all("user-a").map(&:name), "bulbasaur"
    assert_includes last_response.body, "Remove from Team"
    assert_includes last_response.body, "bulbasaur"
  end

  def test_team_fragment_renders_slot_badge_and_ordered_by_slot
    @repository.add("user-a", bulbasaur_pokemon)
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "#1"
    assert_includes last_response.body, "#2"
    order = last_response.body.index("bulbasaur") < last_response.body.index("pikachu")
    assert order, "expected bulbasaur (slot 1) before pikachu (slot 2)"
  end

  def test_team_member_links_to_detail
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "hx-get=\"/pokemon/25\""
    assert_includes last_response.body, "hx-target=\"#pokemon\""
  end

  def test_team_member_sprite_is_link_not_submit
    @repository.add("user-a", pikachu_pokemon)

    get "/team", {}, user_session("user-a")

    assert last_response.ok?
    assert_equal 2, last_response.body.scan(%r{hx-get="/pokemon/25"}).size
    refute_includes last_response.body, 'input type="image"'
    assert_includes last_response.body, 'hx-delete="/team"'
  end

  def test_post_team_move_reorders_team_fragment
    add_team("user-a", [["pikachu", 25], ["bulbasaur", 1], ["charmander", 4], ["squirtle", 7]])
    charmander_id = @repository.all("user-a").find { |poke| poke.name == "charmander" }.id

    post "/team/#{charmander_id}/move", { new_slot: 1 }, user_session("user-a")

    assert last_response.ok?
    order = last_response.body.index("charmander") < last_response.body.index("pikachu")
    assert order, "expected charmander (slot 1) before pikachu"
    assert_includes last_response.body, "#1"
  end

  def test_team_move_invalid_slot_keeps_team_intact
    add_team("user-a", [["pikachu", 25], ["bulbasaur", 1], ["charmander", 4], ["squirtle", 7]])
    pikachu_id = @repository.all("user-a").find { |poke| poke.name == "pikachu" }.id

    post "/team/#{pikachu_id}/move", { new_slot: 99 }, user_session("user-a")

    assert last_response.ok?
    assert_equal %w[pikachu bulbasaur charmander squirtle], @repository.all("user-a").map(&:name)
  end

  def test_team_move_of_other_users_member_is_noop
    @repository.add("user-a", pikachu_pokemon)
    @repository.add("user-b", bulbasaur_pokemon)
    bulbasaur_id = @repository.all("user-b").first.id

    post "/team/#{bulbasaur_id}/move", { new_slot: 1 }, user_session("user-a")

    assert last_response.ok?
    assert_equal %w[pikachu], @repository.all("user-a").map(&:name)
    assert_equal %w[bulbasaur], @repository.all("user-b").map(&:name)
  end

  def test_team_move_does_not_break_delete
    add_team("user-a", [["pikachu", 25], ["bulbasaur", 1], ["charmander", 4], ["squirtle", 7]])
    pikachu_id = @repository.all("user-a").find { |poke| poke.name == "pikachu" }.id

    post "/team/#{pikachu_id}/move", { new_slot: 1 }, user_session("user-a")
    delete "/team", { id: pikachu_id }, user_session("user-a")

    assert last_response.ok?
    refute_includes @repository.all("user-a").map(&:name), "pikachu"
    assert_includes last_response.body, "Remove from Team"
  end

  def test_team_fragment_renders_move_buttons
    add_team("user-a", [["pikachu", 25], ["bulbasaur", 1], ["charmander", 4], ["squirtle", 7]])

    get "/team", {}, user_session("user-a")

    assert last_response.ok?
    assert_equal 9, last_response.body.scan("hx-post=\"/team/").size
    assert_includes last_response.body, ">▲</button>"
    assert_includes last_response.body, ">▼</button>"
    assert_includes last_response.body, 'name="new_slot"'
    assert_includes last_response.body, 'hx-target="#team"'
  end

  def test_team_manage_renders_move_checkboxes_for_each_member
    @repository.add("user-a", pikachu_pokemon)
    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "growl" }, { level: 1, name: "quick-attack" }, { level: 1, name: "thunder-shock" }]
    ) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    assert_includes last_response.body, 'name="moves"'
    assert_includes last_response.body, 'value="growl"'
    assert_includes last_response.body, 'value="quick-attack"'
    assert_includes last_response.body, 'value="thunder-shock"'
    assert_includes last_response.body, 'hx-post="/team/'
    assert_includes last_response.body, 'hx-get="/team"'
  end

  def test_team_manage_checks_currently_selected_moves
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @repository.set_moves("user-a", pikachu_id, %w[thunder-shock])

    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "growl" }, { level: 1, name: "thunder-shock" }]
    ) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'value="thunder-shock" checked'
    refute_includes last_response.body, 'value="growl" checked'
  end

  def test_team_manage_gates_available_moves_by_member_level
    @repository.add("user-a", pikachu_pokemon)

    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "growl" },
       { level: 5, name: "quick-attack" },
       { level: 10, name: "thunder" }]
    ) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'value="growl"'
    refute_includes last_response.body, 'value="quick-attack"', "move de nível 5 não liberado p/ nível 1"
    refute_includes last_response.body, 'value="thunder"', "move de nível 10 não liberado p/ nível 1"
  end

  def test_team_manage_higher_level_member_sees_more_learnable_moves
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @progression.grant("user-a", pikachu_id, 1200)

    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "growl" },
       { level: 5, name: "quick-attack" },
       { level: 10, name: "thunder" }]
    ) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'value="growl"'
    assert_includes last_response.body, 'value="quick-attack"', "nível 5 deve liberar o move de nível 5"
    refute_includes last_response.body, 'value="thunder"', "move de nível 10 bloqueado p/ nível 5"
  end

  def test_team_manage_renders_learn_level_label_in_move_checkbox
    @repository.add("user-a", pikachu_pokemon)

    PokeApiStub.with_learnable_moves([{ level: 1, name: "growl" }]) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "growl — Nível 1"
    refute_includes last_response.body, "<html"
  end

  def test_team_manage_keeps_saved_move_outside_learnable_visible_and_checked
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @repository.set_moves("user-a", pikachu_id, %w[tackle])

    PokeApiStub.with_learnable_moves([{ level: 1, name: "growl" }]) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'value="growl"'
    assert_includes last_response.body, 'value="tackle" checked',
                    "golpe salvo fora do learnable permanece visível/marcado"
    refute_includes last_response.body, "tackle — Nível", "golpe sem aprendizado por nível não ganha rótulo"
  end

  def test_team_manage_is_isolated_per_session
    @repository.add("user-a", pikachu_pokemon)

    get "/team/manage", {}, user_session("user-b")

    assert last_response.ok?
    refute_includes last_response.body, "pikachu"
  end

  def test_team_manage_renders_slot_controls_and_back_link
    add_team("user-a", [["pikachu", 25], ["bulbasaur", 1], ["charmander", 4], ["squirtle", 7]])

    PokeApiStub.with_learnable_moves([{ level: 1, name: "growl" }]) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'name="new_slot"'
    assert_includes last_response.body, ">▲</button>"
    assert_includes last_response.body, ">▼</button>"
    assert_includes last_response.body, 'hx-get="/team"'
    assert_includes last_response.body, "Voltar"
  end

  def test_team_manage_fragment_has_no_html_wrapper
    @repository.add("user-a", pikachu_pokemon)

    PokeApiStub.with_learnable_moves([{ level: 1, name: "growl" }]) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    refute_includes last_response.body, "<html"
    refute_includes last_response.body, "<head>"
  end

  def test_post_team_moves_saves_selected_moves
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id

    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "growl" }, { level: 1, name: "quick-attack" }, { level: 1, name: "thunder-shock" }]
    ) do
      post "/team/#{pikachu_id}/moves", { moves: %w[growl thunder-shock] }, user_session("user-a")
    end

    assert last_response.ok?
    assert_equal %w[growl thunder-shock], @repository.all("user-a").first.moves
  end

  def test_post_team_moves_rerenders_manage_fragment
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id

    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "growl" }, { level: 1, name: "thunder-shock" }]
    ) do
      post "/team/#{pikachu_id}/moves", { moves: ["thunder-shock"] }, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'name="moves"'
    assert_includes last_response.body, 'value="thunder-shock" checked'
    refute_includes last_response.body, "<html"
  end

  def test_post_team_moves_with_more_than_four_shows_notice_and_does_not_save
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "a" }, { level: 1, name: "b" }, { level: 1, name: "c" },
       { level: 1, name: "d" }, { level: 1, name: "e" }, { level: 1, name: "f" }]
    ) do
      post "/team/#{pikachu_id}/moves", { moves: %w[a b c d e f] }, user_session("user-a")
    end

    assert last_response.ok?
    assert_empty @repository.all("user-a").first.moves
    assert_includes last_response.body, "máximo"
  end

  def test_post_team_moves_with_move_outside_available_shows_notice_and_does_not_save
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id

    PokeApiStub.with_learnable_moves([{ level: 1, name: "growl" }]) do
      post "/team/#{pikachu_id}/moves", { moves: %w[not-a-real-move] }, user_session("user-a")
    end

    assert last_response.ok?
    assert_empty @repository.all("user-a").first.moves
    assert_includes last_response.body, "dispon"
  end

  def test_post_team_moves_with_move_above_member_level_shows_notice_and_does_not_save
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id

    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "growl" }, { level: 5, name: "quick-attack" }]
    ) do
      post "/team/#{pikachu_id}/moves", { moves: %w[quick-attack] }, user_session("user-a")
    end

    assert last_response.ok?
    assert_empty @repository.all("user-a").first.moves
    assert_includes last_response.body, "dispon", "golpe acima do nível não pode ser salvo"
  end

  def test_post_team_moves_at_member_level_saves
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @progression.grant("user-a", pikachu_id, 1200)

    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "growl" }, { level: 5, name: "quick-attack" }]
    ) do
      post "/team/#{pikachu_id}/moves", { moves: %w[growl quick-attack] }, user_session("user-a")
    end

    assert last_response.ok?
    assert_equal %w[growl quick-attack], @repository.all("user-a").first.moves
  end

  def test_post_team_moves_of_other_users_member_is_noop
    @repository.add("user-a", pikachu_pokemon)
    @repository.add("user-b", bulbasaur_pokemon)
    bulbasaur_id = @repository.all("user-b").first.id

    PokeApiStub.with_learnable_moves([{ level: 1, name: "growl" }]) do
      post "/team/#{bulbasaur_id}/moves", { moves: ["growl"] }, user_session("user-a")
    end

    assert last_response.ok?
    assert_empty @repository.all("user-b").first.moves
  end

  def test_post_team_with_unknown_name_shows_notice_and_does_not_insert
    PokeApiStub.with_find(nil) do
      post "/team", { pokeName: "xyz" }, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "Pokémon não encontrado."
    refute_includes last_response.body, "<html"
    assert_empty @repository.all("user-a")
  end

  def test_unexpected_error_renders_friendly_fragment_without_stack
    @repository.add("user-a", pikachu_pokemon)

    raising_api = Class.new do
      def learnable_moves(_number)
        raise "boom inesperado"
      end
    end.new
    previous = Server.settings.api
    Server.set :api, raising_api

    get "/team/manage", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Algo deu errado. Tente novamente."
    refute_includes last_response.body, "<html"
    refute_includes last_response.body, "boom inesperado"
  ensure
    Server.set :api, previous
  end

  def test_team_heal_cures_team_and_charges_wallet
    @repository.add("user-a", pikachu_pokemon)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 200, 100)
    @wallet.grant("user-a", 200)

    post "/team/heal", {}, user_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, "<html"
    assert_match(/curado por 50/i, last_response.body.strip)
    assert_equal 150, @wallet.balance("user-a")
    assert_equal 200, @progression.get("user-a", pokemon_id)[:hp_current]
    assert_includes last_response.body, "Poke Center"
  end

  def test_team_heal_with_insufficient_balance_shows_notice_without_debiting
    @repository.add("user-a", pikachu_pokemon)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 200, 100)
    @wallet.grant("user-a", 10)

    post "/team/heal", {}, user_session("user-a")

    assert last_response.ok?
    assert_match(/insuficiente/i, last_response.body.strip)
    assert_equal 10, @wallet.balance("user-a")
    assert_equal 100, @progression.get("user-a", pokemon_id)[:hp_current]
  end

  def test_team_heal_already_cured_shows_notice_without_debiting
    @repository.add("user-a", pikachu_pokemon)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 200, 200)
    @wallet.grant("user-a", 100)

    post "/team/heal", {}, user_session("user-a")

    assert last_response.ok?
    assert_match(/já está curado/i, last_response.body.strip)
    assert_equal 100, @wallet.balance("user-a")
  end

  def test_team_heal_with_empty_team_does_not_break
    post "/team/heal", {}, user_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, "<html"
  end

  def test_team_fragment_shows_poke_center_with_hp_and_heal_button
    @repository.add("user-a", pikachu_pokemon)
    pokemon_id = TestDatabase.team_id("pikachu", "user-a")
    @progression.update_hp("user-a", pokemon_id, 200, 100)

    get "/team", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, "Poke Center"
    assert_includes last_response.body, "HP 100/200"
    assert_includes last_response.body, %(hx-post="/team/heal")
  end

  def test_team_fragment_omits_heal_button_for_empty_team
    get "/team", {}, user_session("user-a")

    assert last_response.ok?
    refute_includes last_response.body, "Poke Center"
  end
end
