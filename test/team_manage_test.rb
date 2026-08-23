# frozen_string_literal: true

require_relative "server_test_helpers"
class ServerTeamManageTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def test_team_manage_renders_clickable_move_list_without_checkboxes
    @repository.add("user-a", pikachu_pokemon)
    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "growl" }, { level: 1, name: "quick-attack" }, { level: 1, name: "thunder-shock" }]
    ) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "pikachu"
    refute_includes last_response.body, 'type="checkbox"'
    assert_includes last_response.body, 'data-move="growl"'
    assert_includes last_response.body, 'data-move="quick-attack"'
    assert_includes last_response.body, 'data-move="thunder-shock"'
    assert_includes last_response.body, 'hx-post="/team/'
    assert_includes last_response.body, 'hx-get="/team"'
  end

  def test_team_manage_marks_current_moves_in_clickable_list
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @repository.set_moves("user-a", pikachu_id, %w[thunder-shock])

    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "growl" }, { level: 1, name: "thunder-shock" }]
    ) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_match(/class="move-row marked"\s+data-move="thunder-shock"/, last_response.body)
    refute_match(/class="move-row marked"\s+data-move="growl"/, last_response.body)
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

  def test_team_manage_renders_learn_level_label_in_move_list
    @repository.add("user-a", pikachu_pokemon)

    PokeApiStub.with_learnable_moves([{ level: 1, name: "growl" }]) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "growl — Nível 1"
    refute_includes last_response.body, "<html"
  end

  def test_team_manage_keeps_saved_move_outside_learnable_visible_and_marked
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @repository.set_moves("user-a", pikachu_id, %w[tackle])

    PokeApiStub.with_learnable_moves([{ level: 1, name: "growl" }]) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'data-move="growl"'
    assert_match(/class="move-row marked"\s+data-move="tackle"/, last_response.body,
                 "golpe salvo fora do learnable permanece visível/marcado")
    refute_includes last_response.body, "tackle — Nível", "golpe sem aprendizado por nível não ganha rótulo"
  end

  def test_team_manage_keeps_saved_move_above_level_visible_with_level_and_marked
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @repository.set_moves("user-a", pikachu_id, %w[quick-attack])

    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "growl" }, { level: 5, name: "quick-attack" }]
    ) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_match(/class="move-row marked"\s+data-move="quick-attack"/, last_response.body,
                 "golpe salvo acima do nível permanece visível/marcado para permitir remoção")
    assert_includes last_response.body, "quick-attack — Nível 5"
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

  def test_team_manage_member_sprite_has_alt_text
    add_team("user-a", [["pikachu", 25]])

    PokeApiStub.with_learnable_moves([{ level: 1, name: "growl" }]) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_match(/<img[^>]+alt="pikachu"/, last_response.body)
  end

  def test_team_manage_slot_controls_have_aria_labels
    add_team("user-a", [["pikachu", 25]])

    PokeApiStub.with_learnable_moves([{ level: 1, name: "growl" }]) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, 'aria-label="Mover para cima"'
    assert_includes last_response.body, 'aria-label="Mover para baixo"'
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

  def test_move_toggle_updates_marking_without_persisting
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id

    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "growl" }, { level: 1, name: "quick-attack" }]
    ) do
      post "/team/#{pikachu_id}/moves", { draft: "1", toggle: "growl", moves: [] }, user_session("user-a")
    end

    assert last_response.ok?
    assert_match(/class="move-row marked"\s+data-move="growl"/, last_response.body)
    assert_empty @repository.all("user-a").first.moves, "rascunho não persiste"
  end

  def test_move_toggle_removes_selected_move_without_persisting
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    @repository.set_moves("user-a", pikachu_id, %w[growl])

    PokeApiStub.with_learnable_moves([{ level: 1, name: "growl" }]) do
      post "/team/#{pikachu_id}/moves", { draft: "1", toggle: "growl", moves: ["growl"] }, user_session("user-a")
    end

    assert last_response.ok?
    refute_match(/class="move-row marked"\s+data-move="growl"/, last_response.body)
    assert_equal %w[growl], @repository.all("user-a").first.moves, "rascunho não persiste"
  end

  def test_move_toggle_respects_cap_of_four
    @repository.add("user-a", pikachu_pokemon)
    pikachu_id = @repository.all("user-a").first.id
    full = %w[a b c d]

    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "a" }, { level: 1, name: "b" }, { level: 1, name: "c" },
       { level: 1, name: "d" }, { level: 1, name: "e" }]
    ) do
      post "/team/#{pikachu_id}/moves", { draft: "1", toggle: "e", moves: full }, user_session("user-a")
    end

    assert last_response.ok?
    assert_includes last_response.body, "máximo"
    assert_includes last_response.body, "notice--error"
    refute_match(/class="move-row marked"\s+data-move="e"/, last_response.body)
    assert_empty @repository.all("user-a").first.moves, "rascunho não persiste"
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
    assert_includes last_response.body, 'name="toggle"'
    assert_match(/class="move-row marked"\s+data-move="thunder-shock"/, last_response.body)
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
end
