# frozen_string_literal: true

require_relative "server_test_helpers"
require_relative "battle_test_helpers"

# Convergencia visual prototipo x app (sessao 0080, C1-C5) — um metodo por
# criterio (S1). Itens 1-4+6 do mapa; item 5 (center/mart) e a sessao 0081.
class Convergence0080Test < Minitest::Test
  include ServerTestHelpers
  include TestSupport
  include ServerBattleTestHelpers

  def style_content
    File.read(File.join(__dir__, "../public/style.css"))
  end

  def convergence_block
    style_content[%r{/\* === Convergencia 1:1 \(0080\) === \*/.*?Open Design System \(0072\): fim}m]
  end

  def test_body_has_global_base_rule
    block = convergence_block

    refute_nil block, "expected a delimited Convergencia 0080 block before the ODS fim marker"
    assert_match(/body\s*\{[^}]*background:\s*var\(--bg\)/m, block,
                 "expected the 0080 block to set body background from --bg")
    assert_match(/body\s*\{[^}]*color:\s*var\(--fg\)/m, block,
                 "expected the 0080 block to set body color from --fg")
    assert_match(/body\s*\{[^}]*font-family:\s*var\(--font-body\)/m, block,
                 "expected the 0080 block to set body font from --font-body")
  end

  def test_topnav_ctas_are_buttons_and_battle_has_back_link
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/"
    end

    assert last_response.ok?
    home_cta = last_response.body[%r{<a href="/battle"[^>]*>}]
    refute_nil home_cta, "expected a /battle CTA on /"
    assert_match(/class="[^"]*\bbtn\b/, home_cta, "expected the home CTA to wear .btn")

    fill_team("user-a")
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    battle_cta = last_response.body[%r{<a href="/battle"[^>]*>}]
    refute_nil battle_cta, "expected a /battle CTA on /battle"
    assert_match(/class="[^"]*\bbtn\b/, battle_cta, "expected the battle CTA to wear .btn, not bare active-text")
    assert_match(%r{<a[^>]*href="/"[^>]*>.*Voltar ao time</a>}m, last_response.body,
                 "expected a Voltar ao time link on /battle")
  end

  def test_roster_grid_with_level_manage_and_reorder
    fill_team("user-a")
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end

    assert last_response.ok?
    body = last_response.body
    assert_match(/class="roster[^"]*"/, body, "expected the team roster")
    assert_match(/Nível \d+/, body, "expected the roster to show each member level")
    assert_match(%r{hx-get="/team/manage"}, body, "expected a Gerenciar link per member")
    moves = body.scan('name="new_slot"').size
    assert_operator moves, :>=, 2, "expected reorder forms (new_slot) preserved"
    assert_includes body, 'hx-post="/team/', "expected reorder posts to /team/:id/move"
  end

  def test_pcard_full_remarkup_mirrors_prototype
    names = %w[charmander squirtle]
    find_map = {
      "charmander" => Pokemon.new(name: "charmander", sprite: "s", number: 4, types: %w[fire]),
      "squirtle" => Pokemon.new(name: "squirtle", sprite: "s", number: 7, types: %w[water])
    }
    forms = names.to_h { |name| [name, true] }
    PokeApiStub.with_all_names(names) do
      PokeApiStub.with_find(find_map) do
        PokeApiStub.with_base_forms(forms) do
          get "/pokemons"
        end
      end
    end

    assert last_response.ok?
    body = last_response.body
    assert_match(/<li class="pcard">/, body, "expected catalog cards")
    assert_match(%r{<div class="sprite-tile">.*?</div>}m, body, "expected a sprite-tile panel per card")
    assert_match(%r{<div class="pcard-name">charmander</div>}, body, "expected the card name")
    assert_match(/class="pcard-meta"/, body, "expected tier/cost in .pcard-meta")
    assert_match(/ · /, body, "expected tier · custo text preserved")
    assert_match(/class="[^"]*\bpcard-add\b/, body, "expected the add button dressed as .pcard-add")
    assert_includes body, 'hx-post="/team"', "expected the POST /team contract preserved"
    assert_includes body, 'name="pokeName"', "expected the pokeName field preserved"
  end

  def test_podium_middle_wrapped_in_card
    fill_team("user-a")
    stub_battle_start { get "/battle", {}, user_session("user-a") }

    assert last_response.ok?
    body = last_response.body
    assert_match(/class="podium"/, body, "expected the central .podium")
    podium_card = /<div class="podium"[^>]*>\s*<div class="card">/m
    podium_middle = /<div class="round-banner">.*?<div class="controls">.*?id="result-box"/m
    assert_match(podium_card, body, "expected a .card opening the .podium")
    assert_match(podium_middle, body, "expected round-banner + controls + #result-box in the card")
  end
end
