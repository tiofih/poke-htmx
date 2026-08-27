# Sessão 0061 — RESP-1 P1: filtros 44px + battle 900 + barras fluidas (Onda UX)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-27 (D1 B, D2 B, D3 A, D4 A, D5 A, D6 B) |
| Implementação | **Pendente** — aguardando fase 2 (TDD passos 1–3) |
| Validação | **Pendente** — aguardando validação do usuário (fase 3) |

---

## 1. Objetivo

Tornar filtros e batalha responsivos fechando o P1 do `playtest-02` (RESP-1): `filter-controls` com alvo de toque 44px e grid 2col em mobile, `battle-layout` empilhado em 900px e barras HP/PP fluidas — sem tocar `server.rb`/`lib`.

## 2. Contexto (estado atual — diagnóstico)

- **Baseline pós-0060:** suíte 875/3167 lint 0, `SESSIONS.md`/`check_docs` ok. 0060 entregou `<meta viewport>` + `pokemon-grid auto-fill minmax(140px,1fr)` + `list-team-grid` collapse 960 + `img max-width:100%` (revisor Aprovado, validado 2026-08-27). Roadmap Onda 1 UX (0060 P0 → 0061 P1 → 0062 quick-wins).
- **Filtros atuais:** `public/style.css:274-283` `.filter-controls { display:flex; flex-wrap:wrap; gap:0.5em }` + filhos `flex:1 1 8em; min-width:8em` (7 controles: `q` + 5 selects + "Limpar filtros"). Medido com viewport: 375→`q` ~117px 3 linhas, selects ~117px apertados, sem `min-height 44px` (playtest-02 §2 — alvo de toque falha); 320→overflow; `hx-include=".filter-state"` preserva estado mas drawer não existe. `views/_filter_controls.erb:1-56` 7 elementos sem wrapper; `hx-trigger="change"`/`keyup delay:300ms`.
- **Batalha atual:** `public/style.css:171-177` `.battle-layout { grid-template-columns: repeat(3, minmax(0,1fr)); gap:1em }` — sem breakpoint. CDP 768→3×~240px espremidos, 375→3×~100px ilegível (playtest-02 §5). `views/battle.erb:13-22` 3 colunas (Seu Time / controles+log / Oponente) via `_fighter_panel.erb`.
- **Barras:** `public/style.css:211` `.hp-bar { width:120px }` + `:217` `.pp-bar { width:80px }` fixas — vazam em card estreito (flex sem `min-width:0`). `views/_fighter_panel.erb:6-15` `.fighter` sem `min-width:0`/`flex-wrap`.
- **Lista+Time:** `public/style.css:290-310` `team-column min-height 420px` deixa buraco quando vazio em mobile; `list-team-grid` já colapsa em 960 (0060) mas `team-column` ainda 420px fixo.
- **Preservar:** `BattleService`/`TeamService`/`PokemonRatingCache`/`PersistentJsonStore`, htmx alvos (`#pokemon-list`, `#team-view`, `#battle-view`), `oob_pokemon_list` condicional 0059, `TeamBudget`/`poke-cost`/`data-tier`, `page-list` largura cheia, paginação on-demand 36, suíte/lint verdes.

## 3. Escopo

### Produção

- `public/style.css` — **filtros:** em `max-width:600px` virar `filter-controls` para `display:grid; grid-template-columns:1fr 1fr;` com `q` (`input[name="q"]`) ocupando `grid-column:1 / -1` (full-width); todos `select`/`input`/`a` dentro de `filter-controls` ganham `min-height:44px` (alvo toque) e `min-width:0`. Em `max-width:400px` opcional `grid-template-columns:1fr` se 2col ainda apertar (não obrigatório se 2col já legível em 375 — validar por CDP).
- `views/_filter_controls.erb` — mínimo: adicionar wrapper semântico ou classes auxiliares se necessário para o grid 2col (ex.: manter `filter-state` intacto, não quebrar `hx-include=".filter-state"`). Sem mudar `hx-get`/`hx-target`/`hx-trigger`/`hx-swap`; sem JS; sem `type+generation` agrupado nesta P1.
- `public/style.css` — **batalha:** `battle-layout` empilha para `grid-template-columns:1fr` em `max-width:900px` (1fr — controles+log entre os times ou ordem natural); `battle-column` com `min-width:0`.
- `public/style.css` — **barras fluidas:** `.hp-bar { width:100%; max-width:120px }` + `.pp-bar { width:100%; max-width:80px }`; `.fighter { display:flex; flex-wrap:wrap; align-items:center; gap:0.3em; min-width:0 }` ou equivalente que impeça vazamento em 100px; `.bar { flex:1 1 auto; min-width:0 }` se barra dentro de flex.
- `public/style.css` — **team-column:** em `@media (max-width:960px)` (já existente da 0060) adicionar `team-column { min-height:auto }` para remover buraco 420px quando vazio em mobile (reuso do breakpoint 960 da 0060, sem novo breakpoint).
- Sem mudar `server.rb`, `lib/**`, `views/layout.erb`, `views/battle.erb`, `views/_fighter_panel.erb` além de classes CSS, `db/schema.sql`, `db/migrations/*`, gems, `Rakefile`.

### Testes

- `test/style_responsive_test.rb` **estender** (sem rede, lê `public/style.css` + `views/_filter_controls.erb` se necessário): **C1** — arquivo contém `@media (max-width: 600px)` com `.filter-controls` em `grid`/`1fr 1fr` e `input[name="q"]` ou `.filter-controls input` com `grid-column: 1 / -1` **e** contém `min-height: 44px` para `filter-controls` filhos; falha se ainda só `flex 1 1 8em` sem 44px/grid. Nome `test_filter_controls_has_touch_target_and_mobile_grid`.
- `test/style_responsive_test.rb` — **C2** — contém `@media (max-width: 900px)` com `.battle-layout { grid-template-columns: 1fr }`. Nome `test_battle_layout_stacks_at_900`.
- `test/style_responsive_test.rb` — **C3** — contém `.hp-bar` com `width: 100%` + `max-width: 120px` (ou 120) **e** `.pp-bar` com `width: 100%` + `max-width: 80px`, e `.fighter` ou `.bar` com `min-width: 0`/`flex` que evita vazamento. Nome `test_bars_are_fluid`.
- Regressão: `test/pokemon_list_filters_test.rb`, `test/pokemon_list_cost_test.rb`, `test/battle_flow_test.rb` (ou equivalente battle) seguem verdes — filtros `hx-include`/`hx-get`/`oob_pokemon_list`/`TeamBudget` preservados; `test/layout_test.rb` segue verde (viewport).
- `manual` para **C4** — medições CDP 375/320/768/1024 com browser-harness `Emulation.setDeviceMetricsOverride` + `getComputedStyle` + screenshots: filtros 375 2col+44px, `q` full-width, sem overflow 320; battle 768 empilhado 1fr; barras 100% sem vazar.

### Fora de escopo (não abrir)

- **Quick-wins de contrato** (`pokemon.erb` aspas/nav badge/padding) — fica para 0062.
- **`78vh` completo `calc(100vh - header)` + `team-column` refinado além de `min-height:auto`** — se exigir redesign, deixar para 0062; P1 só corrige buraco 420px via `min-height:auto` no breakpoint 960 já existente.
- **Drawer de filtros / agrupamento `type+generation` / overlay JS** — preterido (ver D2); não abrir nesta P1.
- **Toast / juice / animações / copy pt-BR extra** — Onda 0063 (após 0068).
- **Economia (G1 vida zerada, G2 heal trap, G9 pool oponente)** — Onda 2 (0064+); **Estabilidade (T1 race add, T2 escritas atômicas, T3 CSRF)** — Onda 3 (0069+).
- Sem gems novas, sem schema/migration, sem `rubocop:disable`, sem rede em testes.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 (filtros 44px + grid 2col <600 + q full-width):** `public/style.css` em `max-width:600px` aplica `filter-controls` em `grid 1fr 1fr` com `q` em `grid-column:1 / -1` e todos os controles com `min-height:44px`. — prova: `test/style_responsive_test.rb` (`test_filter_controls_has_touch_target_and_mobile_grid` — leitura do arquivo, `assert_match /@media.*600px.*\.filter-controls.*grid.*1fr 1fr/s` + `assert_match /grid-column:\s*1\s*\/\s*-1/` + `assert_match /min-height:\s*44px/`).

### Garantias — teste que prova (S1)

| Critério | Teste que prova | Manual |
| --- | --- | --- |
| C1 (filtros 44px + grid 2col) | `test/style_responsive_test.rb` `test_filter_controls_has_touch_target_and_mobile_grid` | — |
| C2 (battle 1fr em 900) | `test/style_responsive_test.rb` `test_battle_layout_stacks_at_900` | — |
| C3 (barras fluidas 100% + max-width) | `test/style_responsive_test.rb` `test_bars_are_fluid` | — |
| C4 (visual CDP 375/320/768/1024) | `manual` explícito | CDP `Emulation.setDeviceMetricsOverride` + `getComputedStyle` + screenshots 375/320/768/1024: filtros 2col 44px, q full-width sem overflow, battle 1fr, barras sem vazar |

- [ ] **C2 (battle empilha em 900):** `public/style.css` colapsa `.battle-layout` para `1fr` em `max-width:900px`. — prova: `test/style_responsive_test.rb` (`test_battle_layout_stacks_at_900` — `assert_match /@media.*max-width:\s*900px.*\.battle-layout.*grid-template-columns:\s*1fr/s`).
- [ ] **C3 (barras fluidas):** `.hp-bar` usa `width:100%` + `max-width:120px` e `.pp-bar` `width:100%` + `max-width:80px` com `min-width:0`/`flex` no contexto `.fighter`/`.bar`. — prova: `test/style_responsive_test.rb` (`test_bars_are_fluid` — `assert_match /\.hp-bar[^}]*width:\s*100%[^}]*max-width:\s*120px/m` + `assert_match /\.pp-bar[^}]*width:\s*100%[^}]*max-width:\s*80px/m` + `assert_match /min-width:\s*0/`).
- [ ] **C4 (visual CDP — manual):** em 375 filtros 2col legíveis com 44px e `q` full-width sem quebrar; 320 sem overflow; 768 battle empilhado 1fr legível; 1024 3col confortável; barras 100% sem vazar em 100px. — prova: `manual` explícito (CDP + `getComputedStyle` + screenshots 375/320/768/1024; sem teste automatizado).

### Garantias (RNF)

| Critério | Teste que prova | Manual |
| --- | --- | --- |
| G1 (suíte+lint) | `test/style_responsive_test.rb` + suíte completa `./scripts/test` 875/3167 + `./scripts/lint` 0 | — |
| G2 (sem gems/schema/rede) | `test/style_responsive_test.rb` lê arquivo + sem `db/migrations` no diff + `Rack::Test` sem `PokeApi` | — |
| G3 (S4/S5) | `./scripts/check_docs` + `./scripts/checar-sessao 0061` + `SESSIONS.md` atualizado no refinamento | — |
| G4 (htmx preservado) | `./scripts/test test/pokemon_list_filters_test.rb test/pokemon_list_cost_test.rb` htmx/oob/paginação 36 preservados | — |

- [ ] **G1:** suíte completa verde com baseline **875/3167** preservado + novos testes (C1–C3) e lint 0 em todo green; commit obrigatório por passo; 0 regressão.
- [ ] **G2:** sem gems novas / sem mudança de schema / testes sem rede (C1–C3 leem arquivo) / sem `rubocop:disable` novo.
- [ ] **G3:** `SESSIONS.md` atualizado no commit do refinamento (S4) — tabela + "Próxima sessão" — e `REQUIREMENTS.md` se tocar doc; status de validação só após usuário validar (fase 3 — parar na fase 2 e aguardar).
- [ ] **G4:** sem quebrar htmx (`hx-get`/`hx-target`/`hx-swap`/`hx-include=".filter-state"`/`oob_pokemon_list` condicional 0059), paginação on-demand 36, filtros server-side, `TeamBudget`/`poke-cost`/`data-tier` e `Battle/History` largura cheia.

> **S1:** cada critério acima aponta o teste que o prova. Sem teste → `manual` explícito + evidência esperada (ver C4). Baseline suíte 875/3167 de 0060.

## 5. Decisões de refinamento (fechadas com o usuário em 2026-08-27)

- **D1 — Escopo superset CSS + ERB mínimo (B):** só `public/style.css` + `views/_filter_controls.erb` mínimo, sem JS, sem tocar `server.rb`/`lib`. Alternativas preteridas: A — só CSS sem tocar ERB (grid 2col exige `q` full-width via seletor mas wrapper semântico pode faltar), C — refatorar `server.rb`/`lib` para agrupar filtros (aumenta risco, quebra `hx-include`). Motivo: superset mantém htmx intacto e cobre 44px/grid/barras/battle com 2 arquivos.
- **D2 — Filtros mobile (B — grid 2col <600 + q full-width + 44px, não drawer):** `filter-controls` vira `grid 1fr 1fr` em <600 com `q` ocupando linha cheia e `min-height:44px` em todos os controles. Alternativas preteridas: A — drawer/overlay com JS (custo JS, foco/aria, não P1), C — manter flex `1 1 8em` só com `min-height:44px` (ainda 3 linhas em 375, 117px apertado). Motivo: grid 2col entrega 2 toques por linha em 375 (172px cada) validado por CDP, sem JS.
- **D3 — Battle breakpoint 900px (A — 1fr em 900):** `battle-layout 3×1fr` → `1fr` em `900px` empilha controles+log entre os times. Alternativas preteridas: B — 768px (ainda 3×240px espremido em 768), C — 1100px (empilha cedo em 1024 desperdiçando 3col). Motivo: 900 cobre tablet 768 empilhado e preserva 3col em 1024 (1024>900).
- **D4 — Barras fluidas (A — width:100% max-width 120/80 + min-width:0/flex):** `hp-bar 100% max-width 120px`, `pp-bar 100% max-width 80px`, `fighter min-width:0`/`flex` evita vazamento em 100px. Alternativas preteridas: B — manter 120/80 fixas com `overflow:hidden` (ainda vaza flex), C — `width:clamp(60px,20vw,120px)` (complexo, clamp não needed). Motivo: `width:100%` + `max-width` é fluido sem media extra e respeita 120/80 em desktop.
- **D5 — Team-column (A — min-height:auto em <960):** reusar breakpoint 960 já existente da 0060 para `team-column { min-height:auto }` quando vazio. Alternativas preteridas: B — novo breakpoint 600 só para team-column (duplica media), C — remover `min-height` global (perde altura desktop). Motivo: 960 já colapsa `list-team-grid`; `min-height:auto` só em mobile remove buraco 420px sem afetar desktop.
- **D6 — Tamanho/Plano TDD (B — 3 passos + refinamento):** 0 refinamento, 1 filtros C1, 2 battle C2, 3 barras+C4 manual. Alternativas preteridas: A — 2 passos (filtros+battle juntos escondem regressão de grid), C — 5 passos (pulveriza barras/manual). Motivo: cada passo 1 alvo CSS + suíte+lint verdes, parando na fase 2 para revisor e validação (S7).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Parar ao fim da fase 2 e aguardar validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (tabela + "Próxima sessão") | commit `Sessao 0061: refinamento concluido — RESP-1 P1 filtros 44px + battle 900 + barras fluidas, criterios e plano TDD fechados` |
| 1 | **red→green — C1 filtros 44px + grid 2col** — `public/style.css` `@media 600px grid 1fr 1fr` + `q grid-column 1/-1` + `min-height:44px` + `views/_filter_controls.erb` mínimo + `test/style_responsive_test.rb` (`test_filter_controls_has_touch_target_and_mobile_grid`) | `./scripts/test test/style_responsive_test.rb -n /filter_controls_has_touch_target_and_mobile_grid/` + suíte completa + `./scripts/lint` 0; commit `Passo 1: filtros 44px e grid 2col em 600px (q full-width)` |
| 2 | **red→green — C2 battle 900** — `public/style.css` `.battle-layout @900 1fr` + `test/style_responsive_test.rb` (`test_battle_layout_stacks_at_900`) | `./scripts/test test/style_responsive_test.rb -n /battle_layout_stacks_at_900/` + suíte + lint 0; commit `Passo 2: battle-layout empilha em 900px (1fr)` |
| 3 | **red→green — C3 barras fluidas + C4 manual + D5 min-height:auto** — `public/style.css` `.hp-bar/.pp-bar 100% max-width` + `.fighter min-width:0` + `@960 team-column min-height:auto` + evidência CDP 375/320/768/1024 | `./scripts/test test/style_responsive_test.rb -n /bars_are_fluid/` + suíte + lint 0; cdp manual 375/320/768/1024; commit `Passo 3: barras fluidas 100% + team-column auto em 960 (manual 375/320/768/1024)` |
| — | **Fase 2 concluída** → **Revisor (2c)**: loop Implementador↔Revisor até veredito `Aprovado` (teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar Done, não preencher a seção 7, não commitar conclusão. | — |

## 7. Validação (executada pelo usuário — S2)

_Pendente — aguardando implementação (fase 2) e validação do usuário (fase 3). Não preencher antes da fase 3._

| Critério | Evidência automatizada | Evidência manual | Resultado |
| --- | --- | --- | --- |
| C1 (filtros 44px + grid 2col) | `test/style_responsive_test.rb` `test_filter_controls_has_touch_target_and_mobile_grid` — pendente | — | pendente |
| C2 (battle 900) | `test/style_responsive_test.rb` `test_battle_layout_stacks_at_900` — pendente | — | pendente |
| C3 (barras fluidas) | `test/style_responsive_test.rb` `test_bars_are_fluid` — pendente | — | pendente |
| C4 (visual 375/320/768/1024) | `manual` explícito — pendente | CDP 375/320/768/1024 — pendente | pendente |
| G1 (suíte+lint) | `./scripts/test` 875/3167 + `./scripts/lint` 0 — pendente | — | pendente |
| G2 (sem gems/schema/rede) | sem `db/migrations`/`Gems` no diff, testes sem rede — pendente | — | pendente |
| G3 (S4/S5) | `./scripts/check_docs` + `./scripts/checar-sessao 0061` + `SESSIONS.md` — pendente | — | pendente |
| G4 (htmx preservado) | htmx/oob/paginação 36 preservados — pendente | — | pendente |

> **S3:** nenhum ajuste formal — critérios não reabertos (pendente).

## 8. Observações

- **Próxima após 0061:** 0062 RESP-1 P2 quick-wins de contrato (`pokemon.erb` aspas/nav badge/padding) + `78vh` completo `calc(100vh - header)` se couber; depende de 0061 verde. Roadmap Onda 1 UX (0060 P0 → 0061 P1 → 0062 P2), Onda 2 Economia (0064→0068→0063 juice), Onda 3 Estabilidade (0069→0072).
- **Risco drawer/hx-include:** grid 2col mantém `hx-include=".filter-state"` intacto; drawer JS quebraria `filter-state` e foco. Supereset CSS sem JS evita regressão de `hx-trigger`/`hx-target`.
- **Risco 600 vs 400:** se 2col ainda apertar em 375 (172px/select), fallback `400px → 1fr` é aceito sem reabrir C1 se manter 44px.
- **Dependência 0060:** viewport + auto-fill + collapse 960 já validados; 0061 só adiciona medias sem reverter 0060.

## 9. Gotchas / Lições (memória — S6)

_Pendente — registrar na validação (fase 3) se surgirem lições duradouras (ex.: drawer vs grid, hx-include preservado, barras fluidas min-width:0)._

