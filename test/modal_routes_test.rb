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
    assert_includes body, "Saldo: 100"
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
end
