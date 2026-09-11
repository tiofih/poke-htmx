# frozen_string_literal: true

require_relative "server_test_helpers"

# Fragmentos de modal center/mart em overlay hibrido (sessao 0076 2a, C1-C2):
# :target abre, htmx preenche — sem JS.
class ModalRoutesTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def setup
    super
    fill_team("user-a")
    @wallet.grant("user-a", 100)
  end

  def style_block
    content = File.read(File.join(__dir__, "../public/style.css"))
    content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]
  end

  def test_center_fragment_renders_overlay_modal_with_heal_form
    get "/team/center", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_includes body, 'id="center-modal"'
    assert_match(/class="[^"]*\boverlay\b/, body)
    assert_match(/class="[^"]*\bmodal\b/, body)
    assert_includes body, 'role="dialog"'
    assert_includes body, "Poke Center"
    assert_includes body, %(hx-post="/team/heal")
    assert_includes body, "Custo total:"
  end

  def test_mart_fragment_renders_overlay_modal_with_buy_form
    get "/team/mart", {}, user_session("user-a")

    assert last_response.ok?
    body = last_response.body
    assert_includes body, 'id="mart-modal"'
    assert_match(/class="[^"]*\boverlay\b/, body)
    assert_match(/class="[^"]*\bmodal\b/, body)
    assert_includes body, 'role="dialog"'
    assert_includes body, "Poke Mart"
    assert_includes body, %(hx-post="/mart/buy")
    assert_includes body, "Saldo: ¥100"
  end

  def test_overlay_opens_via_target_without_js
    get "/team/center", {}, user_session("user-a")
    fragment = last_response.body
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end
    home = last_response.body

    assert_includes home, 'href="#center-modal"'
    assert_includes home, 'hx-get="/team/center"'
    assert_includes home, 'hx-target="#center-modal"'
    assert_includes home, 'href="#mart-modal"'
    assert_includes home, 'hx-get="/team/mart"'
    assert_includes home, 'hx-target="#mart-modal"'
    refute_includes home, "onclick"
    refute_includes fragment, "onclick"

    refute_nil style_block, "expected a delimited Open Design System block in style.css"
    assert_match(/\.overlay:target/, style_block)
    assert_match(/\.overlay\.open/, style_block)
  end

  def test_center_close_empties_the_overlay_node
    get "/team/center/close", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, 'id="center-modal"'
    refute_includes last_response.body, "Poke Center"
  end

  def test_mart_close_empties_the_overlay_node
    get "/team/mart/close", {}, user_session("user-a")

    assert last_response.ok?
    assert_includes last_response.body, 'id="mart-modal"'
    refute_includes last_response.body, "Poke Mart"
  end

  def test_manage_renders_member_overlay
    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "growl" }, { level: 1, name: "quick-attack" }]
    ) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    body = last_response.body
    assert_includes body, 'id="manage-modal"'
    assert_match(/class="[^"]*\boverlay\b/, body)
    assert_match(/class="[^"]*\bmodal\b/, body)
    assert_includes body, 'role="dialog"'
    assert_includes body, "Gerenciar time"
    assert_includes body, "Voltar"
    assert_includes body, 'hx-post="/team/'
    refute_includes body, "onclick"
  end

  def test_manage_member_renders_single_member_overlay
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "growl" }, { level: 1, name: "quick-attack" }]
    ) do
      get "/team/#{pikachu_id}/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    body = last_response.body
    assert_includes body, 'id="manage-modal"'
    assert_includes body, "pikachu"
    refute_includes body, "bulbasaur"
    refute_includes body, "onclick"
  end

  def test_manage_close_removes_the_overlay_node
    get "/team/manage/close", {}, user_session("user-a")

    assert last_response.ok?
    assert_equal "", last_response.body.strip
  end

  def test_evolution_modal_uses_overlay_pattern
    pikachu_id = TestDatabase.team_id("pikachu", "user-a")
    @inventory.add("user-a", "thunder-stone", 2)

    PokeApiStub.with_stone_evolutions([
                                        { number: 26, name: "raichu", item: "thunder-stone" },
                                        { number: 134, name: "vaporeon", item: "water-stone" }
                                      ]) do
      get "/team/#{pikachu_id}/evolution", {}, user_session("user-a")
    end

    assert last_response.ok?
    body = last_response.body
    assert_includes body, 'id="evolution-modal"'
    assert_match(/class="[^"]*\boverlay\b/, body)
    assert_includes body, 'role="dialog"'
    assert_includes body, "raichu"
    assert_includes body, %(hx-post="/team/#{pikachu_id}/evolve")
    refute_includes body, "onclick"
  end

  def test_evolution_trigger_targets_modal_without_js
    get "/team", {}, htmx_session("user-a")

    assert last_response.ok?
    body = last_response.body
    refute_includes body, 'href="#evolution-modal"'
    refute_includes body, "/evolution\""

    PokeApiStub.with_learnable_moves(
      [{ level: 1, name: "growl" }, { level: 1, name: "quick-attack" }]
    ) do
      get "/team/manage", {}, user_session("user-a")
    end

    assert last_response.ok?
    manage = last_response.body
    assert_includes manage, 'href="#evolution-modal"'
    assert_includes manage, "/evolution\""
    refute_includes manage, "onclick"
  end
end
