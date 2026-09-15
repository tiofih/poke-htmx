# frozen_string_literal: true

require_relative "test_helper"

class StyleResponsiveTest < Minitest::Test
  def style_content
    File.read(File.join(__dir__, "../public/style.css"))
  end

  # T6a (0086): a linha do tempo do turno vira contrato nomeado. Estes dois
  # helpers resolvem var/calc -> segundos para os testes provarem a ARITMETICA
  # (nao a mera presenca do token) e falharem se qualquer relacao sair de sincronia.
  def css_time_vars(content)
    vars = {}
    content.scan(/--(beat|t-[a-z-]+)\s*:\s*([^;]+);/) do |name, value|
      vars["--#{name}"] = value.strip
    end
    vars
  end

  def resolve_css_time(expr, vars, seen = [])
    expr = expr.to_s.strip.sub(/\Acalc\((.*)\)\z/m, '\1').strip
    raise ArgumentError, "ciclo na linha do tempo: #{seen.inspect}" if seen.length > 12

    expr.split("+").sum do |term|
      term = term.strip
      if (ref = term[/\Avar\((--[\w-]+)\)\z/, 1])
        raise ArgumentError, "var ausente na linha do tempo: #{ref}" unless vars.key?(ref)

        resolve_css_time(vars.fetch(ref), vars, seen + [ref])
      elsif (secs = term[/\A([\d.]+)s\z/, 1])
        secs.to_f
      else
        raise ArgumentError, "termo nao resolvivel: #{term.inspect}"
      end
    end
  end

  # T6a hardening (Passo 37): o helper so aceita a forma suportada `var(--x)`
  # (soma de instantes). Forma ambigua (ex.: `calc(var(--t-impact) - 0.1s)`)
  # deve falhar alto, em vez de devolver o valor da var ignorando a aritmetica.
  def test_timeline_helper_rejects_unsupported_calc_form
    vars = css_time_vars(style_content)

    assert_raises(ArgumentError, "calc com '-' nao pode ser resolvido silenciosamente") do
      resolve_css_time("calc(var(--t-impact) - 0.1s)", vars)
    end
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

  def test_juice_reduced_motion_disables_all
    content = style_content
    block0086 = content[/0086 C2, inicio.*?0086 C2, fim/m]

    refute_nil block0086, "expected a delimited 0086 juice block in style.css"
    assert_match(/\.log-round-head/, block0086,
                 "0086 veste o cabecalho de rodada (C1) com polish contido")
    assert_match(/\.log__entry--defeat/, block0086,
                 "0086 veste a linha de derrota (C3) com polish contido")

    # Rede final (T20 a11y): o ultimo reduce desliga TODO o juice com
    # !important, depois de todas as animacoes, para vencer a cascata.
    reduce_index = content.rindex("@media (prefers-reduced-motion: reduce)")
    last_juice = content.rindex(/animation:\s*(juice-|battle-log-in)/)
    refute_nil reduce_index, "rede final prefers-reduced-motion deve existir"
    refute_nil last_juice, "deve haver animacoes de juice"
    assert reduce_index > last_juice,
           "a rede final reduce deve vir depois de todas as animacoes de juice"
    tail = content[reduce_index..]
    assert_match(/animation:\s*none\s*!important/, tail,
                 "rede final desliga com !important para vencer a cascata")
    %w[
      .log__entry
      .log-round-head
      .log__entry--defeat
      .is-hit
      .fainted
      .is-attacking
      .shot
      .arena
      .bar-fill
      .winner-badge
      .rewards
    ].each do |selector|
      assert_includes tail, selector, "rede final deve desligar #{selector}"
    end
    assert_includes tail, ".log__entry .fx", "rede final deve desligar o token por linha"
    assert_includes tail, ".log__entry .chip", "rede final deve desligar o chip por linha"
  end

  def test_log_skip_disables_pacing_before_final_reduce
    content = style_content

    skip_index = content.index(".log-skip-input:checked")
    refute_nil skip_index, "expected a CSS-only Pular rule (.log-skip-input:checked)"
    skip_rule = content[skip_index, 200]
    assert_match(/animation:\s*none\s*!important/, skip_rule,
                 "Pular zera o pacing do log")
    assert_includes skip_rule, ".battle-log", "Pular mira as entradas do log"

    reduce_index = content.rindex("@media (prefers-reduced-motion: reduce)")
    refute_nil reduce_index, "rede final prefers-reduced-motion deve existir"
    assert skip_index < reduce_index,
           "Pular vem antes da rede final reduce, que continua por ultimo"
  end

  # C3/C4 (0087 Passo 2): o gate do travel deixa de ser @media (min-width:900px)
  # e passa a ser @container no .arena (container-type: inline-size) — o container
  # mede a largura REAL da arena, nao o viewport.
  def test_shot_only_in_three_column_container
    content = style_content
    block = content[/Open Design System \(0072\): inicio.*?Open Design System \(0072\): fim/m]

    refute_nil block, "expected a delimited Open Design System block in style.css"

    # Juice usa .shot do bloco (0076 2b, C12): sem .projectile legado.
    assert_match(/\.shot[^}]*display:\s*none/m, block,
                 "projetil invisivel por padrao — abaixo de 3 colunas so flash no alvo (D5 A)")
    shot_animation =
      /@container\s*\(min-width:\s*\d+px\)[\s\S]*\.shot[^}]*animation:\s*juice-projectile/m
    assert_match(shot_animation, block, "projetil anima apenas no container de 3 colunas (C3/C4)")
  end

  # C9 (0086 Passo 24): projetil direcional atacante->alvo. Dois keyframes
  # (ltr/rtl) escolhidos pelo data-side do ATACANTE; teto direcional aceito.
  def test_shot_travels_attacker_to_target_directional
    content = style_content

    assert_match(/@keyframes\s+juice-shot-ltr\b/, content,
                 "passo 24: keyframe de travel para o atacante da coluna esquerda")
    assert_match(/@keyframes\s+juice-shot-rtl\b/, content,
                 "passo 24: keyframe de travel para o atacante da coluna direita")
    assert_match(/@keyframes\s+juice-shot-ltr\b[^@]*translateX/m, content,
                 "travel alonga o translateX (D1: reusa o .shot do atacante)")

    assert_match(/data-jx-shot="on"\]\)\s*\[data-side="0"\][^}]*animation-name:\s*juice-shot-ltr/m, content,
                 "data-side=0 (coluna esquerda) viaja ltr sob data-jx-shot (C9)")
    assert_match(/data-jx-shot="on"\]\)\s*\[data-side="1"\][^}]*animation-name:\s*juice-shot-rtl/m, content,
                 "data-side=1 (coluna direita) viaja rtl sob data-jx-shot (C9)")
  end

  # C3/C4 (0087 Passo 2): o gate do travel deixa de ser @media (min-width:900px)
  # e passa a ser @container no .arena (container-type: inline-size). O bloco
  # @container e delimitado da chave de abertura ate a de fechamento
  # correspondente (chaves balanceadas) para provar que as regras de travel moram
  # DENTRO dele. O threshold tem que passar de 980px (a .arena colapsa em 1 coluna
  # em max-width:980px) — so assim a faixa single-column 900-980px, que o gate
  # antigo deixava com travel ativo, fica flash-only.
  def test_shot_travel_disabled_below_900px
    content = style_content

    assert_match(/\.arena\s*\{[^}]*container-type:\s*inline-size/m, content,
                 "o .arena e o container de medicao do gate de travel (C3)")
    refute_match(/@media\s*\(min-width:\s*900px\)/, content,
                 "o gate de travel nao pode ser mais @media min-width:900px (C3)")

    gates = []
    content.scan(/@container\s*(?:[\w-]+\s+)?\(min-width:\s*(\d+)px\)\s*\{/) { gates << Regexp.last_match }
    refute_empty gates, "gate @container de travel deve existir (C3/C4)"
    gate = gates.last
    assert gate[1].to_i > 980,
           "o gate mede a arena em 3 colunas (>980px) e fecha a faixa 900-980px (C4)"

    open = gate.begin(0)
    depth = 0
    close = nil
    content[open..].each_char.with_index do |char, index|
      depth += 1 if char == "{"
      depth -= 1 if char == "}"
      next unless char == "}" && depth.zero?

      close = open + index
      break
    end
    refute_nil close, "o bloco @container de travel deve fechar (chaves balanceadas)"
    container_block = content[open..close]

    %w[juice-shot-ltr juice-shot-rtl].each do |keyframe|
      assert content.include?("animation-name: #{keyframe}"),
             "travel #{keyframe} deve ser aplicado em algum lugar (C3)"
      assert container_block.include?("animation-name: #{keyframe}"),
             "travel #{keyframe} so DENTRO do bloco @container — abaixo de 3 colunas e flash-only (C3/C4)"
    end
  end

  # C10 (0086 Passo 25): shake no card do alvo (is-hit), nunca na arena inteira.
  def test_shake_hits_target_card_not_arena
    content = style_content

    assert_match(/data-jx-shake="on"\]\)\s*\.fighter\.is-hit\s*\{[^}]*juice-shake/m, content,
                 "shake gateado por data-jx-shake no .fighter.is-hit (C10)")
    assert_match(/data-jx-shake="on"\]\)\s*\.fighter\.is-hit\s*\{[^}]*juice-flash/m, content,
                 "shake do alvo compoe com o flash, nao troca a animacao (C10)")

    refute_match(/data-jx-shake="on"\]\s*\{[^}]*animation:\s*juice-shake/m, content,
                 "arena inteira nao pode tremer (C10): sem regra arena-wide de shake")
  end

  # C11 (0086 Passos 26/32): os 18 tipos mapeiam --fx-color para a paleta --t-*
  # existente das tags (sem hex novo); a entrada mapeia pelo proprio
  # data-move-type (seletor generico de atributo, nao so o carrier #jx-gates);
  # entrada sem tipo cai no fallback normal.
  def test_move_type_colors_map_to_type_palette
    content = style_content

    {
      "normal" => "--t-normal", "fire" => "--t-fire", "water" => "--t-water",
      "electric" => "--t-electric", "grass" => "--t-grass", "ice" => "--t-ice",
      "fighting" => "--t-fighting", "poison" => "--t-poison", "ground" => "--t-ground",
      "flying" => "--t-flying", "psychic" => "--t-psychic", "bug" => "--t-bug",
      "rock" => "--t-rock", "ghost" => "--t-ghost", "dragon" => "--t-dragon",
      "dark" => "--t-dark", "steel" => "--t-steel", "fairy" => "--t-fairy"
    }.each do |type, var|
      assert_match(/^[ \t]*\[data-move-type="#{type}"\][^{]*\{[^}]*--fx-color:\s*var\(#{Regexp.escape(var)}\)/m,
                   content,
                   "tipo #{type} deve mapear --fx-color para #{var} na propria entrada, nao so no carrier (C11)")
    end

    assert_match(/\.log__entry\s*\{[^}]*--fx-color:\s*var\(--t-normal\)/m, content,
                 "entrada sem data-move-type cai no fallback normal (C11)")
    assert_match(/\.log__entry \.fx\s*\{[^}]*background:\s*radial-gradient\(circle,\s*var\(--fx-color\)/m,
                 content, "efeito .fx pinta o radial com --fx-color (C11)")
  end

  # C11 (0086 Passo 29): o projetil herda a cor do tipo. O mapeamento dos 18
  # tipos deixa de ser preso ao .log__entry (seletor generico por atributo) e o
  # carrier #jx-gates propaga --fx-color ao .arena via :has — unico ancestral
  # comum com o .shot (o log nao e ancestral da arena).
  def test_move_type_color_reaches_shot_from_arena
    content = style_content

    assert_match(/\.shot\s*\{[^}]*var\(--fx-color,\s*var\(--t-normal\)\)/m, content,
                 "projetil pinta com --fx-color e cai no normal se ausente, nunca transparente (Passo 29)")

    refute_match(/\.log__entry\[data-move-type=/, content,
                 "mapeamento de tipo deixa de ser preso ao .log__entry (Passo 29)")

    %w[normal fire water electric grass ice fighting poison ground flying
       psychic bug rock ghost dragon dark steel fairy].each do |type|
      assert_match(
        /\.arena:has\(>\s*#jx-gates\[data-move-type="#{type}"\]\)[^{]*\{[^}]*--fx-color:\s*var\(--t-#{type}\)/m,
        content,
        "carrier #jx-gates propaga --fx-color do tipo #{type} ao .arena (Passo 29)"
      )
    end
  end

  # C12 (0086 Passo 26) + C5 (0087 Passo 3): contrato de extensibilidade — os
  # tokens --fx-* sao a unica config (cor/travel/shake); keyframes seguem
  # genericos (config-only). O travel deixa de medir o viewport (40vw): mede a
  # largura REAL da arena pela distancia borda->borda do grid 1fr/1.06fr/1fr com
  # gap 32px → 35cqi + 42px, e os keyframes consomem a var sem fallback
  # duplicado. cqi nao e resolvivel estaticamente (D5): aqui provamos a forma; a
  # medida do destino e o e2e do Passo 5.
  def test_fx_contract_vars_declared
    content = style_content

    assert_match(/\.arena\s*\{[^}]*--fx-color:\s*var\(--t-normal\)/m, content,
                 "cor default do efeito no contrato (--fx-color)")
    assert_match(/--fx-travel:\s*calc\(35cqi\s*\+\s*42px\)/, content,
                 "travel do contrato mede a arena em 3 colunas: 35cqi + 42px (C5/D4)")
    assert_match(/--fx-shake:\s*0s/, content, "token de shake do contrato (--fx-shake)")

    %w[juice-shot-ltr juice-shot-rtl].each do |keyframe|
      block = content[/@keyframes\s+#{keyframe}\b\s*\{(?:[^{}]|\{[^{}]*\})*\}/m]
      refute_nil block, "keyframe de travel #{keyframe} deve existir (C5)"
      assert_match(/translateX\(calc\(-?100%[^;]*var\(--fx-travel\)\s*\)\s*\)/, block,
                   "keyframe #{keyframe} le --fx-travel sem fallback duplicado (C5)")
      refute_match(/\d+(?:\.\d+)?(?:vw|px|cqi)/, block,
                   "keyframe #{keyframe} nao carrega distancia hardcoded (C5)")
    end
  end

  # C13 (0086 Passo 27 / Passo 33 / T6a): a linha do tempo do turno e um
  # contrato nomeado — o shake atrasa no instante do impacto e o VALOR tem que
  # bater com a chegada do projetil, nunca no --step-delay acumulado (bug Passo
  # 25). T6a resolve os tokens (var/calc) e prova a ARITMETICA das relacoes:
  # impacto == approach + travel, shake == impacto, hp >= impacto.
  def test_shake_synced_to_impact_instant
    content = style_content
    vars = css_time_vars(content)

    %w[--beat --t-approach --t-travel --t-impact --t-log --t-hp].each do |name|
      assert vars.key?(name), "instante nomeado #{name} deve existir na linha do tempo (T6a)"
    end

    approach = resolve_css_time(vars.fetch("--t-approach"), vars)
    travel = resolve_css_time(vars.fetch("--t-travel"), vars)
    impact = resolve_css_time(vars.fetch("--t-impact"), vars)
    hp = resolve_css_time(vars.fetch("--t-hp"), vars)

    assert_in_delta approach + travel, impact, 0.001,
                    "impacto = approach + travel (--t-impact, T6a)"
    assert hp >= impact, "HP baixa depois (ou no) impacto: --t-hp >= --t-impact (T6a)"

    shot_block = content[/#jx-gates\[data-jx-shot="on"\]\)\s*\.fighter\.is-attacking \.shot\s*\{([^}]*)\}/m, 1]
    refute_nil shot_block, "regra viva do projetil (#jx-gates, >= 900px) deve existir"
    assert_match(/animation:\s*juice-projectile\s+var\(--t-travel\)\s+ease-out\s+var\(--t-approach\)/, shot_block,
                 "projetil usa --t-travel (duracao) e --t-approach (delay), sem literal (T6a)")
    shot_travel = resolve_css_time(shot_block[/var\(--t-travel\)/, 0], vars)
    shot_delay = resolve_css_time(shot_block[/var\(--t-approach\)/, 0], vars)
    assert_in_delta impact, shot_delay + shot_travel, 0.001,
                    "impacto == delay + duracao do projetil (T6a)"

    shake_block = content[/#jx-gates\[data-jx-shake="on"\]\)\s*\.fighter\.is-hit\s*\{([^}]*)\}/m, 1]
    refute_nil shake_block, "regra de shake no card do alvo via #jx-gates deve existir (C10/C13)"
    assert_match(/animation-delay:\s*var\(--fx-shake,\s*0s\)/, shake_block,
                 "shake do alvo atrasa no impacto via --fx-shake (C13)")

    shake_expr = shake_block[/--fx-shake:\s*([^;]+);/, 1]
    refute_nil shake_expr, "o card do alvo carrega --fx-shake derivado do instante de impacto (C13/T6a)"
    shake = resolve_css_time(shake_expr, vars)

    assert_in_delta impact, shake, 0.001,
                    "o shake dispara no instante do impacto: --fx-shake == --t-impact (C13/T6a)"

    refute_match(/data-jx-shake="on"\]\)?\s*\{[^}]*animation-delay:\s*var\(--step-delay/m, content,
                 "arena nao le o --step-delay acumulado (regressao Passo 25)")
    refute_match(/data-jx-shake="on"\]\)?\s*\{[^}]*animation:\s*juice-shake/m, content,
                 "arena inteira nao treme (C10/C13)")
  end

  # C14 (0086 Passo 27): o bloco final !important segue ULTIMO no arquivo e
  # cobre os seletores de fx novos (efeito por tipo e shake no card do alvo).
  def test_reduce_covers_new_fx_selectors_last
    content = style_content

    reduce_index = content.rindex("@media (prefers-reduced-motion: reduce)")
    refute_nil reduce_index, "rede final prefers-reduced-motion deve existir"
    tail = content[reduce_index..]
    assert tail.strip.end_with?("}"), "rede final deve ser a ULTIMA regra do arquivo (C14)"
    refute_includes content[(reduce_index + 10)..], "@media",
                    "nada de @media depois da rede final reduce (C14)"

    assert_includes tail, ".log__entry .fx", "rede final cobre o efeito por tipo (C14)"
    assert_includes tail, ".fighter.is-hit", "rede final cobre o shake do alvo (C14)"
    assert_match(/animation:\s*none\s*!important/, tail,
                 "rede final desliga as animacoes com !important (C14)")
  end

  def test_juice_effects_sync_per_line
    content = style_content

    # Passo 9 (0086) + Passo 11 (0086): efeito por linha via --log-delay no .fx
    # dentro da .log__entry, um bloco por toggle data-jx-*; shake da arena via
    # --step-delay gated por data-jx-shake; fighter li e estado final only.
    assert_match(/data-jx-log="on"\] \.log__entry\s*\{[^}]*--log-delay/m, content,
                 "log entry deve atrasar via --log-delay sob data-jx-log")
    assert_match(/data-jx-fx="on"\] \.log__entry \.fx\s*\{[^}]*--log-delay/m, content,
                 "fx token deve atrasar via --log-delay sob data-jx-fx")
    assert_match(/data-jx-fx="on"\] \.log__entry \.fx--ko\s*\{[^}]*--log-delay/m, content,
                 "fx KO deve atrasar via --log-delay sob data-jx-fx")
    assert_match(/data-jx-chip="on"\] \.log__entry \.chip--dmg\s*\{[^}]*--log-delay/m, content,
                 "chip de dano deve atrasar via --log-delay sob data-jx-chip")
    assert_match(/data-jx-shake="on"\]\)\s*\.fighter\.is-hit\s*\{[^}]*juice-shake/m, content,
                 "shake mora no card do alvo sob data-jx-shake (C10: arena fora)")
    refute_match(/\.fighter\.is-hit\s*\{[^}]*--step-delay/m, content,
                 "fighter li e estado final only — sem staging por --step-delay")
    refute_match(/data-jx-shot="on"\] \.fighter\.is-attacking \.shot[^}]*--step-delay/m, content,
                 "projetil no li e estado final only — sem staging por --step-delay")
  end

  def test_juice_aspects_modular_with_off_defaults
    content = style_content

    # Passo 11 (0086): agregado default OFF (mute ate stepping por linha),
    # per-line timed ON, modal gated com gate capado; um bloco por toggle.
    assert_match(/li\.fighter\s*\{[^}]*--jx-hit:\s*0/m, content,
                 "li.fighter deve desligar --jx-hit por padrao")
    assert_match(/li\.fighter\s*\{[^}]*--jx-dmg:\s*0/m, content,
                 "li.fighter deve desligar --jx-dmg por padrao")
    assert_match(/li\.fighter\s*\{[^}]*--jx-ko:\s*0/m, content,
                 "li.fighter deve desligar --jx-ko por padrao")
    assert_match(/li\.fighter\s*\{[^}]*--jx-shot:\s*0/m, content,
                 "li.fighter deve desligar --jx-shot por padrao")
    assert_match(/li\.fighter\s*\{[^}]*--jx-hp:\s*0/m, content,
                 "li.fighter deve desligar --jx-hp por padrao")
    assert_match(/\.arena\s*\{[^}]*--jx-shake:\s*0/m, content,
                 "arena deve desligar --jx-shake por padrao")
    %w[hit dmg ko shot hp shake log fx chip modal].each do |aspect|
      assert_match(/data-jx-#{aspect}="on"/, content,
                   "aspecto #{aspect} deve ter um bloco gated por data-jx-#{aspect}")
    end
    live_hit = /\.arena:has\(>\s*#jx-gates\[data-jx-hit="on"\]\)\s*\.fighter\.is-hit\s*\{[^}]*animation:\s*juice-flash/m
    assert_match(live_hit, content,
                 "hit agregado so anima sob o carrier vivo #jx-gates[data-jx-hit=on]")
    refute_match(/\.arena\[data-jx-(?:hp|hit|dmg|ko)="on"\]/, content,
                 "Passo 38: regras legadas no .arena nao voltam — atributos estaticos off, gate vivo e #jx-gates")
    assert_match(/\.arena\[data-jx-modal="on"\] \.res-overlay\s*\{[^}]*animation-delay:\s*var\(--log-total/m, content,
                 "modal revela sob data-jx-modal via --log-total")
  end

  def test_skip_and_reduce_cover_step_delay
    content = style_content

    skip_index = content.index(".arena:has(.log-skip-input:checked)")
    refute_nil skip_index, "Pular deve zerar o juice sincronizado via :has na .arena (0086 Passo 6)"
    assert_includes content, ".log__entry .fx",
                    "Pular cobre o token por linha .fx (0086 Passo 9)"
    reduce_index = content.rindex("@media (prefers-reduced-motion: reduce)")
    refute_nil reduce_index, "rede final prefers-reduced-motion deve existir"
    assert skip_index < reduce_index,
           "Pular vem antes da rede final reduce, que continua por ultimo"
    assert_match(/--step-delay:\s*0s/, content[reduce_index..],
                 "rede final deve zerar --step-delay")
    assert_includes content[reduce_index..], ".log__entry .fx",
                    "rede final cobre o token por linha .fx (0086 Passo 9)"
  end

  def test_result_gated_on_log_total_as_modal
    content = style_content

    assert_match(/\.arena\[data-jx-modal="on"\] \.res-overlay\s*\{[^}]*animation-delay:\s*var\(--log-total/m, content,
                 "result reveals only after the log via --log-total sob data-jx-modal (0086 Passo 7+11)")
    assert_match(/@keyframes res-reveal/, content,
                 "res-reveal keyframes drive the gated reveal")
    assert_match(/\.res-dismiss-input:checked ~ \.res-overlay\s*\{[^}]*display:\s*none/m, content,
                 "dismiss checkbox closes the result modal CSS-only")
    assert_match(/\.arena:has\(\.log-skip-input:checked\) \.res-overlay\s*\{[^}]*visibility:\s*visible/m, content,
                 "Pular reveals the result immediately")
  end

  def test_result_modal_reduced_motion_last
    content = style_content

    res_index = content.index(".res-overlay")
    refute_nil res_index, "expected .res-overlay rules (0086 Passo 7)"
    reduce_index = content.rindex("@media (prefers-reduced-motion: reduce)")
    refute_nil reduce_index, "rede final prefers-reduced-motion deve existir"
    assert res_index < reduce_index,
           "result gate comes before the final reduce net, which stays last"
    assert_match(/--log-total:\s*0s/, content[reduce_index..],
                 "rede final deve zerar --log-total e mostrar o resultado")
  end

  def test_history_rows_stack_at_920 # rubocop:disable Naming/VariableNumber
    content = style_content

    assert_match(/@media\s*\(max-width:\s*920px\)[\s\S]*?\.history-row[^}]*grid-template-columns:\s*1fr/m,
                 content,
                 "expected history-row to stack to 1fr at max-width:920px")
  end

  def test_overlay_open_fades_instead_of_flashing
    content = style_content

    # T68: overlay alterna display:none->flex (sem transicao possivel), entao o
    # fade-in via keyframes mascara o flash do outerHTML swap; overflow-y:auto
    # mantem o modal alto rolando dentro do overlay (layout estavel).
    assert_match(/@keyframes\s+overlay-fade\b/, content,
                 "expected overlay-fade keyframes to mask the open flash")
    assert_match(/\.overlay:target,\s*\.overlay\.open[^}]*animation:\s*overlay-fade/m, content,
                 "expected :target/.open to animate overlay-fade on open")
    assert_match(/\.overlay[^}]*overflow-y:\s*auto/m, content,
                 "expected .overlay to scroll internally for layout stability")
  end
end
