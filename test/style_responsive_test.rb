# frozen_string_literal: true

require_relative "test_helper"

class StyleResponsiveTest < Minitest::Test
  def style_content
    File.read(File.join(__dir__, "../public/style.css"))
  end

  def test_pokemon_grid_is_responsive
    content = style_content

    auto_fill = content.match?(/auto-fill.*minmax\(140px/)
    graduated = content.match?(/@media.*max-width:\s*1100px/) &&
                content.match?(/@media.*max-width:\s*900px/) &&
                content.match?(/@media.*max-width:\s*720px/) &&
                content.match?(/@media.*max-width:\s*520px/)

    assert auto_fill || graduated,
           "expected pokemon-grid to use auto-fill minmax(140px,1fr) or graduated breakpoints 1100/900/720/520"
  end

  def test_list_team_grid_collapses_at_960 # rubocop:disable Naming/VariableNumber
    content = style_content

    assert_match(/@media\s*\(max-width:\s*960px\)/, content,
                 "expected list-team-grid to collapse at 960px")
    assert_match(/\.list-team-grid[^}]*grid-template-columns:\s*1fr/m, content,
                 "expected list-team-grid to use 1fr at 960px")
    assert_match(/\.list-column[^{]*,?[^}]*max-height:\s*none/m, content,
                 "expected list-column to have max-height: none at 960px")
  end

  def test_list_item_images_do_not_overflow
    content = style_content

    assert_match(/\.list-item img[^{]*,[^{]*\.starter-item img[^}]*max-width:\s*100%/m, content,
                 "expected list-item images to have max-width: 100%")
  end

  def test_filter_grid_has_touch_target_and_fluid_grid
    content = style_content

    # Baseline-absolute (home-team.html:138): .filter-grid 2-col estrito, sem .filter-controls.
    assert_match(/\.filter-grid[^}]*display:\s*grid/m, content,
                 "expected filter-grid to use display:grid")
    assert_match(/\.filter-grid[^}]*grid-template-columns:\s*1fr\s+1fr/m,
                 content,
                 "expected filter-grid to be strict 2-col 1fr 1fr (baseline home-team.html:138)")
    assert_match(/\.filter-grid[^}]*gap:\s*8px/m, content,
                 "expected filter-grid to use gap 8px")
    assert_match(/\.filter-grid[^}]*margin-top:\s*10px/m, content,
                 "expected filter-grid to use margin-top 10px")
    assert_match(/\.filter-grid (input|select)[^{]*,[^{]*\.filter-grid (select|input)[^}]*min-height:\s*44px/m,
                 content,
                 "expected filter-grid inputs to have min-height:44px")
  end

  def test_arena_stacks_at_980 # rubocop:disable Naming/VariableNumber
    content = style_content

    # Batalha usa .arena do bloco (0076 2b, C12): sem .battle-layout legado.
    assert_match(/@media\s*\(max-width:\s*980px\)[^}]*\.arena[^}]*grid-template-columns:\s*1fr/m,
                 content,
                 "expected arena to collapse to 1fr at max-width:980px")
  end

  def test_bars_are_fluid
    content = style_content

    # Barras do bloco ODS (0076 2b, C12): .bar flexivel + .bar-fill com ok/mid/low.
    assert_match(/\.bar[^}]*flex:\s*1\s+1\s+auto/m, content,
                 "expected .bar to flex inside the hp row")
    assert_match(/\.bar[^}]*min-width:\s*0/m, content,
                 "expected .bar to have min-width:0 to prevent overflow")
    assert_match(/\.bar-fill\.ok/, content,
                 "expected .bar-fill.ok tier from the block")
    assert_match(/\.bar-fill\.mid/, content,
                 "expected .bar-fill.mid tier from the block")
    assert_match(/\.bar-fill\.low/, content,
                 "expected .bar-fill.low tier from the block")
    # Manual C4: 375/320/768/1024 misurando offsetHeight >=44, arena 1fr, barra sem vazar.
    # Este teste cobre C3 automaticamente; C4 requer CDP browser-harness manual (documentado).
    assert_match(/@media\s*\(max-width:\s*960px\)[\s\S]*?\.team-column[^}]*min-height:\s*auto/m, content,
                 "expected team-column to have min-height:auto at 960px")
  end

  def test_pokemon_erb_has_quoted_value
    content = File.read(File.join(__dir__, "../views/pokemon.erb"))

    assert_match(/value="<%= @pokemon\.name %>"/, content,
                 'expected pokemon.erb to have value="<%= @pokemon.name %>" with quotes')
    refute_match(/value=<%= @pokemon\.name %>/, content,
                 "expected pokemon.erb not to have unquoted value=")
  end

  def test_clear_filters_wears_design_system
    content = style_content
    list = File.read(File.join(__dir__, "../views/pokemon_list.erb"))

    # Limpar filtros veste .btn do bloco (0076 2b, C12/C14): sem .filter-controls a.
    assert_match(/\.btn-sm\s*\{/, content,
                 "expected the block to define .btn-sm")
    assert_match(/class="btn btn-ghost btn-sm"/, list,
                 "expected the clear link to wear btn btn-ghost btn-sm")
    assert_match(/name="team"[^>]*|team=/, list,
                 "expected the clear link to zero the team filter")
  end

  def test_nav_wraps_with_gap_and_touch_target
    content = style_content

    # Shell usa .topnav nav do bloco (0076 2b, C12): sem `header nav` legado.
    assert_match(/\.topnav nav[^}]*flex-wrap:\s*wrap/m, content,
                 "expected topnav nav to use flex-wrap:wrap")
    assert_match(/\.topnav nav[^}]*gap:/m, content,
                 "expected topnav nav to use gap")
    assert_match(/\.topnav nav a[^}]*min-height:\s*44px/m, content,
                 "expected topnav nav a to have min-height:44px")
  end

  def test_body_padding_is_8px_at_600 # rubocop:disable Naming/VariableNumber
    content = style_content

    assert_match(/@media\s*\(max-width:\s*600px\)[\s\S]*?body[^}]*padding[^}]*8px/m, content,
                 "expected @media (max-width: 600px) to apply body padding 8px")
  end

  def test_columns_use_calc_viewport_height
    content = style_content

    assert_match(/\.list-column[^}]*max-height:\s*calc\(100vh - 110px\)/m, content,
                 "expected .list-column to use max-height: calc(100vh - 110px)")
    assert_match(/\.team-column[^}]*max-height:\s*calc\(100vh - 110px\)/m, content,
                 "expected .team-column to use max-height: calc(100vh - 110px)")
    assert_match(/\.list-column[^}]*overflow-y:\s*auto/m, content,
                 "expected .list-column to use overflow-y:auto")
    assert_match(/\.team-column[^}]*overflow-y:\s*auto/m, content,
                 "expected .team-column to use overflow-y:auto")
    assert_match(/@media\s*\(max-width:\s*960px\)[\s\S]*?max-height:\s*none/m, content,
                 "expected @media 960px to reset max-height:none")
    assert_match(/@media\s*\(max-width:\s*960px\)[\s\S]*?overflow-y:\s*visible/m, content,
                 "expected @media 960px to reset overflow-y:visible")
  end

  def test_juice_keyframes_present
    content = style_content

    %w[
      juice-hp
      juice-projectile
      juice-flash
      juice-ko
      juice-damage-number
      juice-shake
      juice-toast-in
      juice-toast-out
      juice-banner
      juice-news
    ].each do |name|
      assert_match(/@keyframes\s+#{Regexp.escape(name)}\b/, content,
                   "keyframe #{name} deve existir no style.css")
    end

    assert_match(/button[^{}]*,[^{}]*\.gameloop-cta[^{}]*\{[^}]*transition:/m, content,
                 "botoes devem ter transition para hover/active")
    assert_match(/\.gameloop-cta:active[^{}]*\{[^}]*transform:/m, content,
                 "active do botao deve ter transform (juice de clique)")
  end

  def test_juice_reduced_motion_disables
    content = style_content
    block = content[/@media\s*\(prefers-reduced-motion:\s*reduce\)\s*\{(.*?)\n\}/m, 1]

    refute_nil block, "media query prefers-reduced-motion deve existir"
    assert_match(/animation:\s*none/, block, "reduce desliga as animacoes de juice")

    %w[
      .battle-log__entry
      .fighter--flash
      .fighter--ko
      .projectile
      .battle-layout
      .hp-bar
      .add-toast
      .winner--pop
      .xp-gained--pop
      .news--pop
    ].each do |selector|
      assert_includes block, selector, "reduced-motion deve desligar #{selector}"
    end

    # Ordem na cascata: o bloco reduce precisa vir DEPOIS de todos os `animation: juice-*`,
    # senao a regra posterior de juice sobrescreve o `animation: none` (bug real detectado
    # no playtest 0063 — o bloco estava na linha 301, antes das regras de juice na 328+).
    reduce_index = content.index("@media (prefers-reduced-motion: reduce)")
    last_juice_animation = content.rindex(/animation:\s*juice-/)
    refute_nil last_juice_animation, "deve haver declaracoes animation: juice-*"
    assert reduce_index > last_juice_animation,
           "o bloco prefers-reduced-motion deve estar depois das declaracoes juice-* para vencer " \
           "na cascata; hoje juice-* (linha posterior) sobrescreve o animation: none"
  end

  def test_shot_only_above_900px
    content = style_content
    block = content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]

    refute_nil block, "expected a delimited Open Design System block in style.css"

    # Juice usa .shot do bloco (0076 2b, C12): sem .projectile legado.
    assert_match(/\.shot[^}]*display:\s*none/m, block,
                 "projetil invisivel por padrao — abaixo de 900px so flash no alvo (D5 A)")
    shot_animation =
      /@media\s*\(min-width:\s*900px\)[\s\S]*\.fighter\.is-attacking \.shot[^}]*animation:\s*juice-projectile/m
    assert_match(shot_animation, block, "projetil anima apenas em viewport >= 900px")
  end

  def test_history_rows_stack_at_920 # rubocop:disable Naming/VariableNumber
    content = style_content

    assert_match(/@media\s*\(max-width:\s*920px\)[\s\S]*?\.history-row[^}]*grid-template-columns:\s*1fr/m,
                 content,
                 "expected history-row to stack to 1fr at max-width:920px")
  end
end
