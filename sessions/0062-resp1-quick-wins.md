# Sessão 0062 — RESP-1 P2: quick-wins maximal (aspas+nav+padding+calc+badge)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-28 (D1 C maximal, D2 B calc, D3 C CSS+ERB+server.rb, D4 A file-read+style, D5 B 3 passos+refinamento, D6 C badge real via before) |
| Implementação | Pendente |
| Validação | Pendente |

---

## 1. Objetivo

Fechar RESP-1 P2 com quick-wins maximal: corrigir contrato + polir responsivo + trocar viewport height por calc + exibir badge de time n/6 na nav via server.rb — mantendo orçamento maximal contido (sem abrir Economia/Estabilidade além do badge).

## 2. Contexto (estado atual — diagnóstico)

- **Baseline pós-0061:** suíte 878/3187 lint 0, `SESSIONS.md`/`check_docs` ok. 0061 entregou filtros `grid 2col <600 + q full-width + min-height 44px` + `battle-layout 1fr @900` + barras `width:100% max-width 120/80 + min-width:0` + `team-column min-height:auto @960` (revisor Aprovado, validado 2026-08-27). Roadmap Onda 1 UX (0060 P0 viewport+grid → 0061 P1 filtros/batalha → 0062 P2 quick-wins), Onda 2 Economia (0064→0068→0063 juice), Onda 3 Estabilidade (0069→0072). `SESSIONS.md:369` "Depois da 0061: 0062 RESP-1 P2 quick-wins — a critério do usuário".
- **Candidatos P2 mapeados (playtest-02 + gotchas + débito):**
  - **Q1 — aspas `value` (contrato/XSS):** `views/pokemon.erb:12` `<input type="hidden" name="pokeName" value=<%= @pokemon.name %>>` sem aspas — quebra em nome com espaço/hífen e abre XSS de atributo. Contrato (não só visual) → corrige para `value="<%= @pokemon.name %>"`.
  - **Q2 — Limpar filtros sem centralizar (gotcha 0061):** `views/_filter_controls.erb:52` `<a>Limpar filtros</a>` ganhou `min-height:44px` em 0061 mas sem `display:flex; align-items:center; justify-content:center` o texto fica desalinhado no block 44px (gotcha registrado em `sessions/0061-resp1-filtros-batalha.md:139`).
  - **Q3 — nav sem wrap/gap/44px (playtest-02 §6):** `views/layout.erb:13-19` `<nav>` com `strong + 3 <a>` em `header nav a { margin-right:1em }` — sem `flex-wrap`/`gap`, 375px quebra feio e alvo de toque do nav <44px.
  - **Q4 — body padding 13→8px @600:** sakura padrão com padding lateral ~13px aperta 375; reduzir para 8px em `<600` libera ~10px de conteúdo.
  - **Q5 — `78vh` → `calc(100vh - 110px)` (style.css:287,345):** `.list-column` + `.team-column` com `max-height:78vh; overflow-y:auto` gera duplo scroll + altura descalibrada do header (~110px). Maximal troca para `calc(100vh - 110px)` em desktop e `none/visible` em `@960` (já existente).
  - **Q6 — team-column refinado:** já coberto por `min-height:auto @960` da 0061; maximal mantém refinado mas sem nova regra além de Q5.
  - **Q7 — nav badge n/6 (layout.erb:14-18 + server.rb before + TeamRepository):** `views/layout.erb` sem contador do time na nav; usuário pede badge real `n/6` via `before { @team_size = TeamRepository.new(...).all(current_user).size }` + `layout.erb` exibindo `Time n/6` ou badge. Toca `server.rb`/`lib` — por isso maximal vira mini-feature.
  - **Q8 — history UUID:** preterido nesta P2 (fora do maximal escolhido).
- **Por que maximal agora:** Q1 é bug de contrato (aspas) com custo 1 linha ERB; Q2 é regressão direta da 0061; Q3+Q4 são polimentos baratos só CSS; Q5 corrige `78vh` que já causa duplo scroll medido; Q7 é o único que demanda `server.rb`/`lib` mas entrega jornada visível (n/6 na nav). Conjunto cabe em 3 passos sem abrir `db/migrations`/gems/Estabilidade — validar por `file-read + style + manual CDP`.
- **Arquivos atuais:** `views/pokemon.erb:12` sem aspas, `views/layout.erb:13-19` nav sem gap/wrap, `views/_filter_controls.erb:52` link sem flex, `public/style.css` com `78vh` desktop e `max-height:none @960` já, `server.rb:1077-1080` `before` só com `session[:user_id]` sem `@team_size`.
- **Preservar:** `BattleService`/`TeamService`/`PokemonRatingCache`/`PersistentJsonStore`, htmx alvos (`#pokemon-list`, `#team-view`, `#battle-view`), `oob_pokemon_list` condicional 0059, `TeamBudget`/`poke-cost`/`data-tier`, paginação 36, filtros server-side, `ConnectionRegistry.release_current_thread!`, suíte/lint verdes.

## 3. Escopo

### Produção

- `views/pokemon.erb:12` — **Q1** corrigir para `<input type="hidden" name="pokeName" value="<%= @pokemon.name %>">` (aspas duplas). Sem mudar `hx-post`/`hx-target`/`@pokemon.number`/`sprite`/`alt`.
- `public/style.css` — **Q2** centralizar "Limpar filtros": `.filter-controls a { display:flex; align-items:center; justify-content:center; min-height:44px }` (ou equivalente flex dentro do link) para texto centrado no 44px; manter `gap 0.75em` e `min-width:0` já existentes.
- `public/style.css` + `views/layout.erb:13-19` — **Q3** nav responsiva: `header nav { display:flex; flex-wrap:wrap; gap:0.5em 0.75em; align-items:center }` + `header nav a { min-height:44px; display:inline-flex; align-items:center }` + `strong` com `margin-right` preservado ou convertido em gap; validar 375 sem wrap quebrado.
- `public/style.css` — **Q4** body padding: `@media (max-width: 600px) { body { padding-left:8px; padding-right:8px } }` ou `body.page-list, body` com 13→8px; manter sakura base.
- `public/style.css` — **Q5** `calc(100vh - 110px)`: `.list-column { max-height: calc(100vh - 110px); overflow-y:auto }` + `.team-column { max-height: calc(100vh - 110px); overflow-y:auto }` em desktop (fora de `@960`); em `@media (max-width: 960px)` manter/confirmar `.list-column, .team-column { max-height:none; overflow-y:visible; min-height:auto }` (já existe — garantir `calc` não vaza para mobile).
- `server.rb:1077-1084` + `views/layout.erb:13-19` + `lib/journey_service.rb` opcional — **Q7** badge real: `before do` passa a setar `@team_size = settings.team.all(current_user).size` (ou `TeamRepository.new.all(current_user).size` via `settings.team`; preferir `settings.team` já injetado) e `views/layout.erb` exibe badge `n/6` na nav (ex.: `<span class="nav-badge"><%= @team_size %>/6</span>` dentro do link Lista ou ao lado do título). Sem mudar `ConnectionRegistry`/`after`/`session_secret`; sem nova rota.
- `views/_filter_controls.erb` — só se preciso para Q2/Q3 auxiliar (manter `filter-state`/`hx-get`/`hx-target`/`hx-include` intactos; sem JS; sem mudar `server.rb` além do `before` do badge).
- Sem tocar `db/schema.sql`, `db/migrations/*`, `Gemfile*`, `Rakefile`, `PokeApi`/`PokemonRatingCache`/`TeamBudget`/`BattleService` além do badge via `settings.team`.

### Testes

- `test/style_responsive_test.rb` **estender** (sem rede, lê `public/style.css` + ERBs):
  - **C1 (Q1 aspas)** — `test/pokemon_detail_test.rb` ou `test/style_responsive_test.rb` com `File.read("views/pokemon.erb")` contém `value="<%= @pokemon.name %>"` (com aspas). Nome `test_pokemon_erb_has_quoted_value` — falha se ainda `value=<%=`.
  - **C2 (Q2 limpar filtros flex)** — `test/style_responsive_test.rb` contém `.filter-controls a` com `display:flex` + `align-items:center` + `justify-content:center` (ou `display:flex` + `min-height:44px` centralizado). Nome `test_clear_filters_is_centered`.
  - **C3 (Q3 nav wrap/gap/44px)** — contém `header nav` com `flex-wrap:wrap` + `gap:` e `header nav a` com `min-height:44px`. Nome `test_nav_wraps_with_gap_and_touch_target`.
  - **C4 (Q4 body padding 8px @600)** — contém `@media (max-width: 600px)` com `body` e `padding: 8px` ou `padding-left:8px`/`padding-right:8px`. Nome `test_body_padding_is_8px_at_600`.
  - **C5 (Q5 calc)** — contém `.list-column` e `.team-column` com `max-height: calc(100vh - 110px)` + `overflow-y:auto` em desktop e `@media (max-width: 960px)` com `max-height:none` + `overflow-y:visible`. Nome `test_columns_use_calc_viewport_height`.
  - **C6 (Q7 badge)** — `test/layout_test.rb` ou `test/style_responsive_test.rb` file-read: `views/layout.erb` contém `n/6` ou `@team_size` + `/6` e `server.rb` contém `@team_size` + `settings.team.all` ou `TeamRepository`. Nome `test_nav_shows_team_badge`. Também `GET /` com `Rack::Test` retorna badge (opcional se `server.rb` tocado).
- Regressão: `test/pokemon_list_filters_test.rb`, `test/pokemon_list_cost_test.rb`, `test/battle_flow_test.rb` seguem verdes — filtros `hx-include`/`hx-get`/`oob_pokemon_list`/`TeamBudget`/`poke-cost`/`data-tier` preservados; `test/layout_test.rb` viewport preservado.
- `manual` para **C7** — medições CDP 375/768/1024 com browser-harness `Emulation.setDeviceMetricsOverride` + `getComputedStyle` + screenshots: nav 375 wrap sem overflow + gap + 44px, limpar filtros centralizado, body 8px, `calc` sem duplo scroll, badge n/6 atualizando.

### Fora de escopo (não abrir)

- **Drawer de filtros / agrupamento `type+generation` / overlay JS** — preterido (ver D2 0061); não abrir.
- **Juice/toast/animações/copy pt-BR extra** — Onda 0063 (após 0068).
- **Economia:** G1 vida zerada, G2 heal trap/death spiral, G9 pool oponente, M2 pedras no Mart, custo extra além do badge — Onda 2 (0064+).
- **Estabilidade:** T1 race no add, T2 escritas atômicas, T3 CSRF/identidade `?as=`, pry/CI/Redis — Onda 3 (0069+).
- **History UUID (Q8) / team-column refinado além de Q5** — preterido nesta P2; `team-column min-height:auto` já Done em 0061.
- Sem gems novas, sem schema/migration, sem `rubocop:disable` novo, sem rede em testes além do badge via `TeamRepository` stubado.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 (Q1 aspas — contrato):** `views/pokemon.erb:12` contém `value="<%= @pokemon.name %>"` com aspas duplas (antes `value=<%=`). — prova: `test/style_responsive_test.rb` ou `test/pokemon_detail_test.rb` `test_pokemon_erb_has_quoted_value` — `File.read("views/pokemon.erb")` + `assert_match /value="<%= @pokemon.name %>"/` (falha se sem aspas).
- [ ] **C2 (Q2 limpar filtros centralizado):** `.filter-controls a` centraliza texto no alvo 44px (`display:flex; align-items:center; justify-content:center` + `min-height:44px`). — prova: `test/style_responsive_test.rb` `test_clear_filters_is_centered` — `assert_match /\.filter-controls a[^}]*display:\s*flex/m` + `assert_match /align-items:\s*center/` + `assert_match /justify-content:\s*center/`.
- [ ] **C3 (Q3 nav wrap/gap/44px):** `header nav` com `flex-wrap:wrap` + `gap` e links com `min-height:44px` (nav 375 sem overflow). — prova: `test/style_responsive_test.rb` `test_nav_wraps_with_gap_and_touch_target` — `assert_match /header nav[^}]*flex-wrap:\s*wrap/m` + `assert_match /header nav[^}]*gap:/m` + `assert_match /header nav a[^}]*min-height:\s*44px/m`.
- [ ] **C4 (Q4 body padding 8px @600):** `@media (max-width: 600px)` aplica `body` com `padding` 8px (reduz de 13). — prova: `test/style_responsive_test.rb` `test_body_padding_is_8px_at_600` — `assert_match /@media\s*\(max-width:\s*600px\)[\s\S]*?body[^}]*padding[^}]*8px/m`.
- [ ] **C5 (Q5 calc viewport):** `.list-column` e `.team-column` usam `max-height: calc(100vh - 110px)` + `overflow-y:auto` em desktop e `max-height:none` + `overflow-y:visible` em `@960`. — prova: `test/style_responsive_test.rb` `test_columns_use_calc_viewport_height` — `assert_match /\.list-column[^}]*max-height:\s*calc\(100vh - 110px\)/m` + `assert_match /\.team-column[^}]*max-height:\s*calc\(100vh - 110px\)/m` + `assert_match /@media\s*\(max-width:\s*960px\)[\s\S]*?max-height:\s*none/m`.
- [ ] **C6 (Q7 badge n/6 real):** `server.rb` `before` seta `@team_size = settings.team.all(current_user).size` e `views/layout.erb` exibe `n/6` (badge) na nav atualizando por tamanho do time. — prova: `test/layout_test.rb` ou `test/style_responsive_test.rb` `test_nav_shows_team_badge` — `File.read("server.rb")` contém `@team_size` + `settings.team.all` e `File.read("views/layout.erb")` contém `@team_size` + `/6`; `GET /` com `Rack::Test` contém `1/6` ou `0/6` conforme stub.
- [ ] **C7 (visual CDP — manual):** em 375 nav wrap sem overflow + gap + 44px, limpar filtros centralizado 44px, body 8px, `calc` sem duplo scroll; 768 Lista+Time 1fr empilhados; 1024 confortável; badge n/6 visível e atual. — prova: `manual` explícito (CDP `Emulation.setDeviceMetricsOverride` + `getComputedStyle` + screenshots 375/768/1024).

### Garantias — teste que prova (S1)

| Critério | Teste que prova | Manual |
| --- | --- | --- |
| C1 (aspas) | `test/style_responsive_test.rb` `test_pokemon_erb_has_quoted_value` (file-read `views/pokemon.erb` `value="<%= @pokemon.name %>"`) | — |
| C2 (limpar filtros flex) | `test/style_responsive_test.rb` `test_clear_filters_is_centered` (`.filter-controls a display:flex` + `align-items:center` + `justify-content:center`) | — |
| C3 (nav wrap/gap/44px) | `test/style_responsive_test.rb` `test_nav_wraps_with_gap_and_touch_target` (`header nav flex-wrap:wrap` + `gap` + `min-height:44px`) | — |
| C4 (body 8px @600) | `test/style_responsive_test.rb` `test_body_padding_is_8px_at_600` (`@media 600px body padding 8px`) | — |
| C5 (calc 100vh-110) | `test/style_responsive_test.rb` `test_columns_use_calc_viewport_height` (`calc(100vh - 110px)` + `overflow-y:auto` + `@960 none/visible`) | — |
| C6 (badge n/6) | `test/layout_test.rb` `test_nav_shows_team_badge` (`server.rb @team_size` + `layout.erb @team_size/6` + `GET /` badge) | — |
| C7 (visual CDP) | `manual` explícito | CDP 375/768/1024: nav wrap+gap+44px, limpar filtros centralizado, body 8px, calc sem duplo scroll, badge n/6 |
| G1 (suíte+lint) | `test/style_responsive_test.rb` + `test/layout_test.rb` + suíte completa `./scripts/test` 878/3187 + `./scripts/lint` 0 | — |
| G2 (sem gems/schema/rede além do badge) | file-read sem `PokeApi` em C1–C5 + `git diff -- Gemfile* db/` vazio + sem `rubocop:disable` novo | — |
| G3 (S4/S5) | `./scripts/check_docs` + `./scripts/checar-sessao 0062` + `SESSIONS.md` atualizado no refinamento | — |
| G4 (htmx preservado) | `./scripts/test test/pokemon_list_filters_test.rb test/pokemon_list_cost_test.rb test/battle_flow_test.rb` htmx/oob/paginação 36 preservados | — |

- [ ] **G1:** suíte completa verde com baseline **878/3187** preservado + novos testes (C1–C6) e lint 0 em todo green; commit obrigatório por passo; 0 regressão. — prova: `./scripts/test` + `./scripts/lint`.
- [ ] **G2:** sem gems novas / sem mudança de schema / sem rede em C1–C5 (file-read) e badge usa `TeamRepository` via `settings.team` stubado / sem `rubocop:disable` novo.
- [ ] **G3:** `SESSIONS.md` atualizado no commit do refinamento (S4) — tabela + "Próxima sessão" — e `REQUIREMENTS.md` se tocar doc; status de validação só após usuário validar (fase 3 — parar na fase 2 e aguardar).
- [ ] **G4:** sem quebrar htmx (`hx-get`/`hx-target`/`hx-swap`/`hx-include=".filter-state"`/`oob_pokemon_list` condicional 0059), paginação on-demand 36, filtros server-side, `TeamBudget`/`poke-cost`/`data-tier` e `Battle/History` largura cheia; `server.rb` só `before` para badge.

> **S1:** cada critério acima aponta o teste que o prova. Sem teste → `manual` explícito + evidência esperada (ver C7). Baseline suíte 878/3187 de 0061.

## 5. Decisões de refinamento (fechadas com o usuário em 2026-08-28)

- **D1 — Escopo maximal C (Q1+Q2+Q3+Q4+Q5+Q7):** superset polimento Q1+Q2+Q3+Q4 + `78vh→calc(100vh - 110px)` (Q5) + badge n/6 via `server.rb` (Q7); vira mini-feature tocando `server.rb`/`lib`. **A:** Q1 só aspas (1 arquivo, sem CSS) — preterido: deixa nav/padding/calc/badge para depois e desperdiça janela P2. **B:** Q1+Q2+Q3+Q4 só CSS/ERB sem `server.rb` — preterido: sem badge perde jornada visível n/6. **C escolhida:** maximal cabe em 3 passos, contrato (Q1 XSS) + gotcha 0061 (Q2) + nav/padding (Q3/Q4) + calc (Q5) + badge (Q7) sem abrir Economia/Estabilidade; `Q8 history UUID` preterido para não misturar identidade. Motivo: bundle entrega P2 completo validável por file-read + CDP sem nova gem/migration.
- **D2 — Desktop calc B (`calc(100vh - 110px)`):** `list-column/team-column max-height calc(100vh - 110px) + overflow-y:auto` desktop, `none/visible @960`. **A:** manter `78vh` — preterido: duplo scroll + header descalibrado (playtest). **B escolhida:** `calc(100vh - 110px)` aproxima header real (~110px) e evita viewport curto. **C:** `100dvh` — preterido: suporte menor, não validado por CDP. Motivo: `calc` já usado em `list-team-grid` collapse @960 sem quebrar 0042/0060.
- **D3 — Arquivos C (CSS+ERB+server.rb):** pode tocar `public/style.css` + `views/pokemon.erb` + `views/layout.erb` (+ `_filter_controls.erb` se preciso) + `server.rb` before + `lib/journey_service` se necessário para badge. **A:** só `style.css` — preterido: sem aspas/badge. **B:** CSS+ERB sem `server.rb` — preterido: badge fake sem `TeamRepository`. **C escolhida:** escopo explícito lista arquivos tocáveis e proíbe `db/migrations`/gems fora do badge. Motivo: badge real exige `before` + `settings.team` — tocar `server.rb` mínimo e auditável.
- **D4 — Testes A (estender style_responsive + 1 ERB file-read):** estender `test/style_responsive_test.rb` + 1 teste ERB file-read para aspas; regressão filtros/battle verdes; **C visual manual CDP**. **A escolhida:** file-read sem rede para Q1–Q5 + `layout_test.rb` para badge + `manual` para CDP. **B:** só CDP manual — preterido: perde S1 automatizado. **C:** testes de integração com DB — preterido: rede/DB além do badge. Motivo: `style_responsive_test.rb` já lê `public/style.css`; file-read para ERB evita `Rack::Test` desnecessário em Q1.
- **D5 — Tamanho B (3 passos + refinamento):** 0 refinamento, 1 Q1+Q2, 2 Q3 nav, 3 Q4 body+calc+badge+manual. **A:** 2 passos (Q1+Q2+Q3 juntos) — preterido: esconde regressão nav vs aspas. **B escolhida:** cada passo 1 alvo dominante + suíte+lint verdes, parando na fase 2 para revisor e validação (S7). **C:** 5 passos — preterido: pulveriza calc/badge. Motivo: 3 passos equilibra S1 por passo (passo1 C1+C2, passo2 C3, passo3 C4+C5+C6+C7) e mantém commits atômicos.
- **D6 — Badge C (real com server.rb before):** `before { @team_size = settings.team.all(current_user).size }` + `layout.erb` badge `n/6`. **A:** badge fake via `session[:team_size]` — preterido: dessincroniza com `TeamRepository`. **B:** `JourneyService#team_size` — preterido: indireção sem ganho (já tem `settings.team`). **C escolhida:** direto via `settings.team` injetado, sem novo `TeamRepository.new` por request além do já singleton, sem cache. Motivo: `settings.team` já é singleton registrado em `server.rb:1050`; `before` é o hook existente para `session[:user_id]` — co-localiza identidade + badge sem migração.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Parar ao fim da fase 2 e aguardar validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (tabela + "Próxima sessão") | commit `Sessao 0062: refinamento concluido — RESP-1 P2 quick-wins maximal (aspas+nav+padding+calc+badge), criterios e plano TDD fechados` |
| 1 | **red→green — C1 Q1 aspas + C2 limpar filtros flex** — `views/pokemon.erb` `value="<%= @pokemon.name %>"` + `public/style.css` `.filter-controls a display:flex align/justify center min-height:44px` + `test/style_responsive_test.rb` (`test_pokemon_erb_has_quoted_value`, `test_clear_filters_is_centered`) + `views/_filter_controls.erb` mínimo se necessário | `./scripts/test test/style_responsive_test.rb -n /test_pokemon_erb_has_quoted_value|test_clear_filters_is_centered/` + suíte completa + `./scripts/lint` 0; commit `Passo 1: aspas em pokemon.erb + limpar filtros flex centralizado (44px)` |
| 2 | **red→green — C3 nav wrap/gap/44px** — `public/style.css` `header nav flex-wrap:wrap gap` + `header nav a min-height:44px inline-flex align:center` + `views/layout.erb` ajuste mínimo se necessário + `test/style_responsive_test.rb` (`test_nav_wraps_with_gap_and_touch_target`) | `./scripts/test test/style_responsive_test.rb -n /test_nav_wraps_with_gap_and_touch_target/` + suíte + lint 0; commit `Passo 2: nav wrap gap e 44px (375 sem overflow)` |
| 3 | **red→green — C4 body 8px@600 + C5 calc(100vh-110px) + C6 badge n/6 + C7 manual CDP** — `public/style.css` `body 8px @600` + `.list-column/.team-column calc(100vh - 110px) overflow:auto desktop / none visible @960` + `server.rb` `before @team_size` + `views/layout.erb` badge `n/6` + `test/style_responsive_test.rb` (`test_body_padding_is_8px_at_600`, `test_columns_use_calc_viewport_height`) + `test/layout_test.rb` (`test_nav_shows_team_badge`) + evidência CDP 375/768/1024 | `./scripts/test test/style_responsive_test.rb -n /test_body_padding_is_8px_at_600|test_columns_use_calc_viewport_height/` + `./scripts/test test/layout_test.rb -n /test_nav_shows_team_badge/` + suíte completa + `./scripts/lint` 0; cdp manual 375/768/1024; commit `Passo 3: body 8px@600 + calc(100vh-110px) + badge n/6 (manual 375/768/1024)` |
| — | **Fase 2 concluída** → **Revisor (2c)**: loop Implementador↔Revisor até veredito `Aprovado` (teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar Done, não preencher a seção 7, não commitar conclusão. | — |

## 7. Validação (executada pelo usuário — S2)

_Pendente — aguardando implementação (fase 2) e validação do usuário (fase 3). Não preencher antes da fase 3._

| Critério | Evidência automatizada | Evidência manual | Resultado |
| --- | --- | --- | --- |
| C1 (aspas) | — | — | pendente |
| C2 (limpar filtros flex) | — | — | pendente |
| C3 (nav wrap/gap/44px) | — | — | pendente |
| C4 (body 8px @600) | — | — | pendente |
| C5 (calc 100vh-110) | — | — | pendente |
| C6 (badge n/6) | — | — | pendente |
| C7 (visual CDP) | `manual` | — | pendente |
| G1 (suíte+lint) | — | — | pendente |
| G2 (sem gems/schema/rede) | — | — | pendente |
| G3 (S4/S5) | — | — | pendente |
| G4 (htmx preservado) | — | — | pendente |

> **S3 — Ajuste formal 2026-08-28 (fase 3 validação, reabertura de critérios):**
> Bug reportado na validação (fase 3): "após remover o primeiro pokemon do time, além de ter que clicar 2x, a badge de #1 sumiu, ficando sempre da #2 em diante".
> *Reabertura:* **C5 (calc)** e **C6 (badge)** já estavam verdes em suíte isolada (`test_remove_recompacts_slots` + `DELETE /team` htmx_session valida `1..5` em teste), mas em navegação real o OOB de lista e o `before @team_size` stale mascaravam o reindex — a nav não atualizava e o double-click sugeria `hx-sync`/`hx-disabled-elt` quebrando 1-clique (regressão Q5 0059). Motivo: `TeamRepository#remove` fazia `DELETE` fora de transação + `UPDATE slot-1` separado e `server.rb:610 remove_team_member` não recarregava `@team_size` nem fazia OOB para `nav-badge` (before calculava antes do delete), deixando nav stale até refresh full-page; slot-badge stale só se reindex falhasse por concorrência/before stale.
> *Correção S3:* `lib/team_repository.rb:188` envolto em `connection.transaction` (DELETE + reindex atômicos); `views/layout.erb:16` ganha `id="nav-badge"` para OOB; `server.rb` ganha `prepare_team_fragment_data @team_size=@team.size` + helper `oob_nav_badge` (`<span id="nav-badge" hx-swap-oob="innerHTML">n/6</span>`) anexado a `add_team_success`, `budget_blocked_response`, `remove_team_member`, `render_restart_fragment` para atualizar `0/6..6/6` sem refresh; hardening `team.erb` mantido `hx-delete + hx-target #team-view + hx-swap innerHTML + hx-include .list-state + hx-params * + hx-sync closest form:replace + hx-indicator #team-view + hx-disabled-elt this` validado em 1 request idempotente.
> *Provas S1 após S3:* `test/team_routes_test.rb` `ServerTeamRemoveQ5Test` já cobre 1-clique + idempotência + OOB condicional; S3 adiciona `test_remove_first_slot_reindexes_to_one`, `test_nav_badge_updates_after_remove`, `test_nav_badge_oob_after_add` e `test_delete_in_one_request` (todos em `ServerTeamRemoveHtmxTest`/`ServerTeamRemoveQ5Test`) — cada critério reaberto aponta teste verde; suíte completa 884→~888/3230→~3250 + lint 0 preservados sem `db/migrations`.

## 8. Observações

- **Próxima após 0062:** Onda 1 UX fechada (0060 P0 → 0061 P1 → 0062 P2 maximal). Próxima é **Onda 2 Economia** (0064 vida zerada → 0065 death spiral+game over → 0066 pool oponente → 0067 pedras+modais → 0068 resolver batalha → 0063 juice) a critério do usuário; Onda 3 Estabilidade (0069 race add → 0070 escritas atômicas → 0071 CSRF → 0072 respiro) permanece fila.
- **Risco calc 110px:** `calc(100vh - 110px)` assume header ~110px; se header crescer com badge/gap, validar CDP 768 sem duplo scroll; fallback `78vh` não reabre C5 se `calc` já verde.
- **Risco badge:** `@team_size` em `before` roda em todo request — usar `settings.team` singleton evita N conexões; `release_current_thread!` do `after` já cobre (ver 0051).
- **Dependência 0061:** 44px/grid 2col/battle 900/barras fluidas já validados; 0062 não reverte 0061 — Q2 corrige gotcha 0061 sem mudar `hx-include`.

## 9. Gotchas / Lições (memória — S6)

_Pendente — preencher na validação (fase 3) com handoff + gotchas duradouros._

