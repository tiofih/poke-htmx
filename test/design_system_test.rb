# frozen_string_literal: true

require_relative "server_test_helpers"

# Testes estruturais do Design System base (sessão 0072) — provam C1-C6.
# Base aditiva: tokens oklch + classes-núcleo no style.css + shell do layout.erb.
class DesignSystemTest < Minitest::Test
  include ServerTestHelpers
  include TestSupport

  def style_content
    File.read(File.join(__dir__, "../public/style.css"))
  end

  def test_design_system_root_tokens_oklch
    content = style_content
    root = content[/:root\s*\{.*?\n\}/m]

    refute_nil root, "expected style.css to define a :root block"
    assert_match(/--bg:\s*oklch\(21%\s*0\.05\s*165\)/, root)
    assert_match(/--accent:\s*oklch\(66%\s*0\.17\s*150\)/, root)
    assert_match(/--surface:\s*oklch/, root)
    assert_match(/--fg:\s*oklch/, root)
    assert_match(/--border:\s*oklch/, root)
    assert_match(/--font-display:/, root)
    assert_match(/--radius:/, root)
    assert_match(/--container:/, root)
  end

  def test_design_system_core_classes
    content = style_content

    %w[
      topnav topnav-inner logo pagefoot
      btn btn-primary btn-secondary btn-ghost
      container section stack row row-between card
      eyebrow lead meta num muted
    ].each do |klass|
      assert_match(/\.#{Regexp.escape(klass)}\b/, content,
                   "expected style.css to define .#{klass}")
    end
  end

  def test_design_system_home_screen_classes
    content = style_content

    # Classes de tela anexadas na sessão 0073 (home/catálogo/roster) — C9.
    %w[
      grid-2-1 catalog-pane catalog
      pcard pcard-name pcard-meta pcard-add
      roster member member-top sprite-tile member-name member-lvl
      hp hp-label bar bar-fill hp-val member-actions
      budget-summary budget-meta meter meter-fill services services-row
      field input filter-grid
    ].each do |klass|
      assert_match(/\.#{Regexp.escape(klass)}\b/, content,
                   "expected style.css to define .#{klass}")
    end
  end

  def test_design_system_battle_end_states_classes
    content = style_content
    block = content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]

    refute_nil block, "expected a delimited Open Design System block in style.css"

    # Classes do fim de batalha (sessão 0078, C3): res-screen/res-top do
    # battle-results-desktop.html + state-card/mini-arena/result-card do
    # battle-end-states.html — aditivas, antes da linha fim.
    %w[
      res-screen res-top res-top-left state-title
      state-card state-head state-pill
      mini-arena mini-side-title fighter-rows frow
      result-card
    ].each do |klass|
      assert_match(/\.#{Regexp.escape(klass)}\b/, block,
                   "expected design system block to define .#{klass}")
    end
  end

  def test_design_system_battle_screen_classes
    content = style_content
    block = content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]

    refute_nil block, "expected a delimited Open Design System block in style.css"

    # Classes de batalha anexadas na sessão 0074 (arena/podium/log/result — C7).
    %w[
      arena fighters fighter fainted engaged
      fighter-head fighter-id fname fmeta lvl ftags ftag
      moves move ppnum dot
      podium round-banner turn-status controls
      result winner-badge rewards ctas
      battle-log log-title log lside
    ].each do |klass|
      assert_match(/\.#{Regexp.escape(klass)}\b/, block,
                   "expected design system block to define .#{klass}")
    end
  end

  def test_design_system_battle_juice_reduced_motion
    content = style_content
    block = content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]

    refute_nil block, "expected a delimited Open Design System block in style.css"

    # Juice 0063 portado para os seletores novos dentro do bloco ODS (B1b).
    # 0087 Passo 4: `is-attacking` sai daqui — a classe so existia no bloco como
    # ancestral do projetil; o .shot agora mora na track do .arena e o gate vivo
    # e o carrier #jx-gates. A classe segue contrato do presenter (0086 C9).
    %w[
      is-hit fainted shot log__entry
    ].each do |klass|
      assert_match(/\.#{Regexp.escape(klass)}\b/, block,
                   "expected design system block to port juice to .#{klass}")
    end

    reduce = block[/@media[^{]*prefers-reduced-motion:\s*reduce\)\s*\{(.*?)\n\s*\}/m, 1]
    refute_nil reduce, "design system block must carry its own reduced-motion guard"
    # 0087 Passo 4 (C9): o .shot vive na track do .arena desde o Passo 1; o guard
    # tem que alcancar o projetil no novo lugar (nao no card do lutador).
    [".log__entry", ".is-hit", ".fainted", "#jx-shot-track .shot", ".arena",
     ".winner-badge", ".rewards"].each do |selector|
      assert_includes reduce, selector, "reduced-motion must cover #{selector}"
    end
  end

  def test_design_system_history_screen_classes
    content = style_content
    block = content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]

    refute_nil block, "expected a delimited Open Design System block in style.css"

    # Classes de history anexadas na sessão 0075 (pos-card/rank-list/history-list — C7).
    %w[
      pagehead
      pos-card pos-left pos-badge pos-title pos-stats
      stat-chip
      section-title
      rank-list rank-row rank-pos rank-name rank-bar rank-wins
      history-list history-row
      result-badge history-main h-title h-sub history-date
    ].each do |klass|
      assert_match(/\.#{Regexp.escape(klass)}\b/, block,
                   "expected design system block to define .#{klass}")
    end
  end

  def test_design_system_modal_screen_classes
    content = style_content
    block = content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]

    refute_nil block, "expected a delimited Open Design System block in style.css"

    # Overlay hibrido da sessao 0076 (2a, C2): :target abre, htmx preenche — sem JS.
    %w[
      overlay modal modal-head modal-close modal-sub modal-foot
    ].each do |klass|
      assert_match(/\.#{Regexp.escape(klass)}\b/, block,
                   "expected design system block to define .#{klass}")
    end
    assert_match(/\.overlay:target/, block,
                 "expected overlay to open via :target without JS")
  end

  def test_design_system_juice_safety_net_in_block
    content = style_content
    block = content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]

    refute_nil block, "expected a delimited Open Design System block in style.css"

    # Rede tecnica 0076 (2a, C10/D86-D88): projectile + toast partem do bloco
    # (duplicacao temporaria intencional — o legado permanece integro).
    assert_match(/@keyframes juice-projectile/, block,
                 "expected design system block to carry its own juice-projectile keyframes")
    assert_match(/\.add-toast\b/, block,
                 "expected design system block to define .add-toast")
    assert_match(/@keyframes juice-toast-in/, block,
                 "expected design system block to carry juice-toast-in keyframes")
    assert_match(/@keyframes juice-toast-out/, block,
                 "expected design system block to carry juice-toast-out keyframes")
  end

  def test_design_system_home_residue_classes
    content = style_content
    block = content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]

    refute_nil block, "expected a delimited Open Design System block in style.css"

    # Residuo home 0077 (home-team.html 1:1): miolo center/mart,
    # manage/evolucao, catalogo/detalhe — C4.
    %w[
      heal-list heal-item
      tabs tab
      mart mart-name item-icon price
      mg-head section-label stat-grid stat-row
      mv-row mv-sel
      equip-row equip-current
      evo-row evo-info evo-item evo-arrow
      tag-row
    ].each do |klass|
      assert_match(/\.#{Regexp.escape(klass)}\b/, block,
                   "expected design system block to define .#{klass}")
    end
    assert_match(/Home 1:1 \(0077\)/, block,
                 "expected the 0077 delimiter inside the block")
  end

  def test_design_system_filter_dress_in_block
    content = style_content
    block = content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]

    refute_nil block, "expected a delimited Open Design System block in style.css"

    # Filtros vestidos no ODS (0076 2a, C7/D94): grade + hook com regra + btn-sm.
    %w[
      filter-grid filter-state btn-sm
    ].each do |klass|
      assert_match(/\.#{Regexp.escape(klass)}\b/, block,
                   "expected design system block to define .#{klass}")
    end
  end

  def test_design_system_curation_tokens
    content = style_content
    root = content[/:root\s*\{.*?\n\}/m]

    refute_nil root, "expected style.css to define a :root block"

    # Curadoria 0076 (2a, C8): escala de tipos + espacamentos do prototipo.
    %w[fs-h1 fs-h2 fs-h3 fs-lead fs-body fs-meta].each do |token|
      assert_match(/--#{token}:/, root, "expected :root to define --#{token}")
    end
    %w[gap-xs gap-sm gap-md gap-lg gap-xl gap-2xl].each do |token|
      assert_match(/--#{token}:/, root, "expected :root to define --#{token}")
    end
  end

  def test_design_system_curation_base_faithful
    content = style_content
    block = content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]

    refute_nil block, "expected a delimited Open Design System block in style.css"

    assert_match(/\.topnav\s*\{[^}]*position:\s*sticky/m, block, "topnav sticks")
    assert_match(/\.topnav\s*\{[^}]*backdrop-filter:\s*blur/m, block, "topnav blurs")
    assert_match(/\.topnav nav a\.active/, block, "nav marks the active link")
    assert_match(/\.nav-badge/, block, "nav renders the team badge")
    assert_match(/\.btn-lg/, block, "buttons scale up")
    assert_match(/\.btn:disabled/, block, "buttons show the disabled state")
    assert_match(/\.card\s*\{[^}]*border-radius:\s*var\(--radius-lg\)/m, block, "card uses radius-lg")
    assert_match(/\.lead\s*\{[^}]*color:\s*var\(--muted\)/m, block, "lead reads muted")
    assert_match(/\.meta\s*\{[^}]*font-family:\s*var\(--font-mono\)/m, block, "meta reads mono")
    assert_match(/\.sprite-tile\s*\{[^}]*place-items:\s*center/m, block, "sprite-tile tiles the sprite")
    assert_match(/\.stock-items/, block, "battle stocks its items with a rule")
    assert_match(/\.evolution-news/, block, "end states list evolution news")
    assert_match(/\.learned-news/, block, "end states list learned news")
  end

  def test_design_system_curation_spacing_and_battle_narrow
    content = style_content
    block = content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]

    refute_nil block, "expected a delimited Open Design System block in style.css"

    assert_match(/\.section\s*\{[^}]*var\(--gap-xl\)/m, block, "section breathes with gap-xl")
    assert_match(/\.grid-2-1\s*\{[^}]*var\(--gap-xl\)/m, block, "home grid gaps with gap-xl")
    assert_match(/\.arena\s*\{[^}]*var\(--gap-lg\)/m, block, "arena gaps with gap-lg")
    assert_match(/@media\s*\(max-width:\s*700px\)[^}]*\.podium[^}]*position:\s*static/m, block,
                 "podium unstickies on narrow battle screens")
  end

  def test_design_system_history_curation_classes
    content = style_content
    block = content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]

    refute_nil block, "expected a delimited Open Design System block in style.css"

    # Curadoria fina 0079 (C2): ex-inline dos cards vira classe do bloco.
    assert_match(/History 1:1 \(0079\)/, block,
                 "expected the 0079 curation delimiter inside the block")
    assert_match(/\.card--tight\b/, block,
                 "expected design system block to define .card--tight")
  end

  def test_layout_uses_topnav_footer_shell
    layout = File.read(File.join(__dir__, "../views/layout.erb"))

    assert_match(/<header class="topnav"[^>]*>/, layout,
                 "expected layout.erb to open a <header class=\"topnav\">")
    assert_match(/<footer class="pagefoot"[^>]*>/, layout,
                 "expected layout.erb to open a <footer class=\"pagefoot\">")
    assert_match(%r{<link rel="stylesheet" href="/style\.css}, layout,
                 "expected layout.erb to link /style.css")
  end

  def test_body_gets_page_battle_history
    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/battle", {}, user_session("user-a")
    end
    assert last_response.ok?
    assert_match(/class="[^"]*page-battle[^"]*"/, last_response.body,
                 "expected /battle body to have page-battle class")

    get "/history", {}, user_session("user-a")
    assert last_response.ok?
    assert_match(/class="[^"]*page-history[^"]*"/, last_response.body,
                 "expected /history body to have page-history class")

    PokeApiStub.with_all_names(two_hundred_fifty_names) do
      get "/", {}, user_session("user-a")
    end
    assert last_response.ok?
    assert_match(/class="[^"]*page-list[^"]*"/, last_response.body,
                 "expected / body to keep page-list class")
  end

  def test_design_system_does_not_depend_on_sakura
    content = style_content
    block = content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]

    refute_nil block, "expected a delimited Open Design System block in style.css"
    refute_match(/sakura/i, block,
                 "design system must not depend on sakura resets")
    refute_match(/@import/, block,
                 "design system must not @import external stylesheets")

    # Autonomia do bloco (0076 2b, C11): nenhuma pagina carrega o sakura.
    layout = File.read(File.join(__dir__, "../views/layout.erb"))
    refute_match(/sakura/i, layout,
                 "layout.erb must not link sakura — the ODS block is autonomous")
  end

  def test_legacy_collisions_removed
    content = style_content
    legacy = content.split("Open Design System (0072): fim", 2).last

    refute_nil legacy, "expected CSS after the design system fim marker"

    # Colisoes sob demanda (0076 2b, C12/D71–D76): fora do bloco nao pode
    # restar regra colidente — o bloco ODS e a unica fonte dessas classes.
    {
      /\.filter-controls\b/ => ".filter-controls (filtros vestem .filter-grid)",
      /\.battle-layout\s*\{/ => ".battle-layout (batalha usa .arena)",
      /\.battle-pane\s+\.fighter/ => ".battle-pane .fighter (orfa desde 0074 B1)",
      /header\s+nav\b/ => "header nav (shell usa .topnav nav)",
      /^nav a\.active\s*\{/ => "nav a.active (bloco marca .topnav nav a.active)",
      /\.projectile\s*\{/ => ".projectile (juice usa .shot)",
      /\.add-toast\s*\{/ => ".add-toast (rede C10 no bloco)",
      /\.hp-bar\s*\{/ => ".hp-bar (fluidez vem de .bar/.bar-fill do bloco)",
      /\.pp-bar\s*\{/ => ".pp-bar (idem)",
      /^\.bar\s*\{/ => ".bar legado (bloco define .bar)",
      /^\.bar-fill\s*\{/ => ".bar-fill legado (bloco define .bar-fill)",
      /\.battle-controls\s*\{/ => ".battle-controls (batalha usa .controls)"
    }.each do |pattern, label|
      refute_match(pattern, legacy, "legacy must not define #{label}")
    end
  end

  def test_block_carries_all_juice_keyframes
    content = style_content
    block = content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]

    refute_nil block, "expected a delimited Open Design System block in style.css"

    # Juice parte so do bloco (0076 2b, C13/D86-D88 fechamento): todo `animation:`
    # referenciado no bloco precisa do @keyframes correspondente DENTRO do bloco.
    names = block.scan(/animation:\s*([a-z][\w-]*)/).flatten.uniq - %w[none]
    assert names.any?, "expected the block to reference animations"
    names.each do |name|
      assert_match(/@keyframes\s+#{Regexp.escape(name)}\b/, block,
                   "block references animation #{name} but lacks its @keyframes")
    end
  end

  def test_design_system_convergence_body_base
    content = style_content
    block = content[%r{/\* === Convergencia 1:1 \(0080\) === \*/.*?Open Design System \(0072\): fim}m]

    refute_nil block, "expected a delimited Convergencia 0080 block before the ODS fim marker"
    assert_match(/body\s*\{[^}]*background:\s*var\(--bg\)/m, block,
                 "expected the 0080 block to set body background from --bg")
    assert_match(/body\s*\{[^}]*color:\s*var\(--fg\)/m, block,
                 "expected the 0080 block to set body color from --fg")
    assert_match(/body\s*\{[^}]*font-family:\s*var\(--font-body\)/m, block,
                 "expected the 0080 block to set body font from --font-body")
  end

  def test_style_css_route_serves_text_css
    get "/style.css"

    assert last_response.ok?, "expected GET /style.css to be 200"
    assert_match(%r{\Atext/css}, last_response.content_type,
                 "expected /style.css to respond with text/css")
  end
end
