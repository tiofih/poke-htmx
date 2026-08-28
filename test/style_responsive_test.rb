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

  def test_filter_controls_has_touch_target_and_mobile_grid
    content = style_content

    assert_match(/@media\s*\(max-width:\s*600px\)[^}]*\.filter-controls[^}]*display:\s*grid/m, content,
                 "expected filter-controls to use display:grid at max-width:600px")
    media_600_grid =
      /@media\s*\(max-width:\s*600px\)[^}]*\.filter-controls[^}]*grid-template-columns:\s*1fr\s+1fr/m
    assert_match(media_600_grid, content,
                 "expected filter-controls to use grid-template-columns:1fr 1fr at 600px")
    assert_match(%r{grid-column:\s*1\s*/\s*-1}, content,
                 "expected input[name=\"q\"] to span full width with grid-column:1 / -1")
    assert_match(/min-height:\s*44px/, content,
                 "expected filter-controls children to have min-height:44px")
    # gap .75em e min-width:0 garantem fluidez em 375 sem overflow
    assert_match(/\.filter-controls[^{]*\{[^}]*gap:\s*0\.75em/m, content,
                 "expected filter-controls mobile grid to use gap .75em")
  end

  def test_battle_layout_stacks_at_900 # rubocop:disable Naming/VariableNumber
    content = style_content

    assert_match(/@media\s*\(max-width:\s*900px\)[^}]*\.battle-layout[^}]*grid-template-columns:\s*1fr/m,
                 content,
                 "expected battle-layout to collapse to 1fr at max-width:900px")
  end

  def test_bars_are_fluid
    content = style_content

    assert_match(/\.hp-bar[^}]*width:\s*100%[^}]*max-width:\s*120px/m, content,
                 "expected .hp-bar to use width:100% + max-width:120px")
    assert_match(/\.pp-bar[^}]*width:\s*100%[^}]*max-width:\s*80px/m, content,
                 "expected .pp-bar to use width:100% + max-width:80px")
    assert_match(/min-width:\s*0/, content,
                 "expected .fighter or .bar to have min-width:0 to prevent overflow")
    # Manual C4: 375/320/768/1024 misurando offsetHeight >=44, battleLayout 1fr, hpBar sem vazar.
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

  def test_clear_filters_is_centered
    content = style_content

    assert_match(/\.filter-controls a[^}]*display:\s*flex/m, content,
                 "expected .filter-controls a to use display:flex")
    assert_match(/\.filter-controls a[^}]*align-items:\s*center/m, content,
                 "expected .filter-controls a to use align-items:center")
    assert_match(/\.filter-controls a[^}]*justify-content:\s*center/m, content,
                 "expected .filter-controls a to use justify-content:center")
    assert_match(/\.filter-controls a[^}]*min-height:\s*44px/m, content,
                 "expected .filter-controls a to have min-height:44px")
  end

  def test_nav_wraps_with_gap_and_touch_target
    content = style_content

    assert_match(/header nav[^}]*flex-wrap:\s*wrap/m, content,
                 "expected header nav to use flex-wrap:wrap")
    assert_match(/header nav[^}]*gap:/m, content,
                 "expected header nav to use gap")
    assert_match(/header nav a[^}]*min-height:\s*44px/m, content,
                 "expected header nav a to have min-height:44px")
  end
end
