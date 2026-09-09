# Sessão 0072 — open-design-base (design system `style.css` + shell `layout.erb`)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-09-09 (A1 aditivo, B2 sakura fallback até a 0076, D1 shell agora) |
| Implementação | **Pendente** |
| Validação | **Pendente** (executada pelo usuário) |

---

## 1. Objetivo

Adicionar o **design system do redesenho** (`open-design/`) como **base aditiva** no `public/style.css` — bloco `:root` com tokens oklch + classes-núcleo (topnav, botões, container/section/stack/row, card, tipo) — **sem remover nem alterar** as regras atuais (juice/responsivo/views), e portar o **shell do `layout.erb`** (topnav + footer + `<link rel="stylesheet" href="/style.css">` + `body page-battle/page-history`), mantendo o **sakura CDN como fallback até a 0076** e preservando o JS de `#global-loading`/scroll-restore. 1ª de 5 sessões da Onda open-design (base → home → battle → history → modals-filters).

## 2. Contexto (estado atual — diagnóstico)

- **`public/style.css`** = 770 linhas. Sistema atual (classes dos fragmentos htmx: `.list-team-grid`, `.list-column`, `.filter-controls`, `.team-column`, `.battle-layout`, `.battle-column`, `.round`, `.stock-items`, `.rank-entry`, `.position`, `.battle-history`, `.notice`, `.gameloop-cta`, `.team-budget`) + 10 keyframes `juice-*` + bloco `prefers-reduced-motion` (**precisa ficar DEPOIS** das declarações `animation: juice-*` — teste `style_responsive_test.rb` `test_juice_reduced_motion_disables` valida a ordem na cascata) + breakpoints 1100/960/900/720/600/520 + `.projectile` só ≥900px.
- **Cabeçalho atual** (`public/style.css:1-3`): "estilos próprios sobre a base sakura (CDN)".
- **`views/layout.erb`** (44 linhas): sakura CDN (linha 7) + `/style.css` (linha 8); `<body class="page-battle ... page-list ... page-history ...">` (linha 11); header `<nav>` simples (linhas 13-20); `<main>` sem `id="content"`; **bloco JS inline** (linhas 25-42) com `#global-loading` overlay (`.active` no `htmx:beforeRequest`/`afterRequest`) + scroll-restore (`htmxSavedScrollY` no `htmx:beforeRequest`/`afterSwap`).
- **Views atuais usam SÓ nomenclatura antiga** (`.list-team-grid`/`.list-column`/`.filter-controls`/`.team-column`, `.battle-layout`/`.battle-column`/`.round`/`.stock-items`, `.rank-entry`/`.position`/`.battle-history`, `.notice`/`.gameloop-cta`/`.team-budget`) — sem colisão com a nomenclatura nova (`.topnav`, `.btn`, `.container`, `.card`…). **Única colisão futura conhecida:** `.fighter` (específica de batalha) → só em **0074**.
- **Testes que amarram o atual:** `test/style_responsive_test.rb` (**14**) e `test/layout_test.rb` (**4** — viewport meta em `/`, `/battle`, `/history` + `@team_size`/`/6` no navbar). **Não podem regredir.**
- **`test/server_test_helpers.rb`**: `app` = `Server` (`require_relative "../server"`); `setup` chama `TestDatabase.setup!`/`clear_team!`/`clear_user_state!` + limpa `settings.battles`. `PokeApiStub.with_all_names` é usado para `/` e `/battle`.
- **Rota `/style.css`** é **estático do `public/`** (Sinatra serve da `public_folder` padrão; testável com `get "/style.css"`; content-type `text/css` via Rack::Mime).
- **Baseline:** suíte **1003/3980**, lint 0 (0071, validado em 2026-09-08).
- **Fila reordenada em 2026-09-08** (`REQUIREMENTS.md:698-706`): a Onda open-design entra **antes** das correções pontuais da Onda 3 Estabilidade. Ordem: **0072 open-design-base** → **0073 open-design-home** (`index`/`team`) → **0074 open-design-battle** → **0075 open-design-history** → **0076 open-design-modals-filters** → **0077 escritas atômicas** → **0078 CSRF** → **0079 respiro**.
- **Preservar:** `server.rb`/`lib/**` intocados (só CSS + `layout.erb`; nada de rota/rede/repositório); `style_responsive_test.rb` e `layout_test.rb` verdes.

## 3. Escopo

### Produção

- `public/style.css` — adicionar (de forma **aditiva** — A1) no topo/fim do arquivo o **bloco `:root`** com tokens oklch (do `migration-guide.md` §1.1: `--bg`, `--surface`, `--fg`, `--muted`, `--border`, `--accent`, `--ink`, `--ok`, `--warn`, `--danger`, tipos `--t-*`, `--accent-soft`/`--fg-soft` via `color-mix`, `--font-display`/`--font-body`/`--font-mono`, `--radius`/`--radius-lg`/`--gutter`, `--container`) e as **classes-núcleo** (§1.2: `.topnav`, `.topnav-inner`, `.logo`, `.pagefoot`, `.btn`/`.btn-primary`/`.btn-secondary`/`.btn-ghost`/`.btn-sm`, `.container`, `.section`, `.stack`, `.row`, `.row-between`, `.card`, `.eyebrow`, `.lead`, `.meta`, `.num`, `.muted`; opcionalmente `.pill`/`.pill.warn`/`.pill.danger`, `.tag`, `.meter`/`.meter-fill`). **Não remover/reordenar** as regras atuais (juice, responsivo, `.projectile`, `prefers-reduced-motion`). A remoção do CSS antigo é responsabilidade de cada sessão de view (0073+).
- `views/layout.erb` — portar o **shell** (D1): `<header class="topnav">` + `<div class="container topnav-inner">` (logo `/` + nav Time `n/6` (`@team_size`) + Histórico, "Batalhar" como `.btn.btn-primary` conforme `migration-guide.md` §5.1) + `<main id="content"><%= yield %></main>` + `<footer class="pagefoot">` (© Poké-HTMX + `sprites oficiais PokéAPI` em `.meta`); `<body class="page-battle? / page-history? / page-list?">` conforme `request.path` (C6); manter `<link rel="stylesheet" href="/style.css">` (C3) **e** manter o link sakura CDN (B2); **preservar** o bloco JS de `#global-loading`/scroll-restore (D1) e o `<meta name="viewport">`/htmx script (layout_test).
- `test/design_system_test.rb` — **novo teste Minitest de estrutura** (assert_match via `File.read`/rota) que prova C1–C6.

### Testes

- `test/design_system_test.rb` (**novo**) — estrutural: lê `public/style.css` (via `File.read`), `views/layout.erb` (via `File.read`) e faz requisições (`get "/style.css"`, `get "/battle"`, `get "/history"`).
  - C1: `:root` com tokens oklch (`--bg: oklch(21% 0.05 165)`, `--accent: oklch(66% 0.17 150)`, `--font-display:`, `--radius:`, `--container:`, `--surface:`, `--fg:`, `--border:`).
  - C2: classes-núcleo presentes (`.topnav`, `.topnav-inner`, `.logo`, `.pagefoot`, `.btn`, `.btn-primary`, `.btn-secondary`, `.btn-ghost`, `.container`, `.section`, `.stack`, `.row`, `.row-between`, `.card`, `.eyebrow`, `.lead`, `.meta`, `.num`, `.muted`).
  - C3: `layout.erb` usa `<header class="topnav">`, `<footer class="pagefoot">`, `<link rel="stylesheet" href="/style.css">`.
  - C4 (reinterpretado): design system **autônomo** — as declarações novas (`.topnav`/`.btn`/… e o `:root`) **não dependem** de seletores do sakura (não há `@import`/referência a `sakura`); manter o sakura no `<link>` do layout é OK. **Não asserta remoção do sakura** (isso é critério da **0076**).
  - C5: `get "/style.css"` → **200** com `content-type: text/css`.
  - C6: `body` ganha `page-battle` (em `/battle`) e `page-history` (em `/history`) conforme `request.path` (rota via Rack::Test).

### Fora de escopo (não abrir — RNF-04)

- **Remover o sakura do `layout.erb`** — critério da **0076** (B2); **não** é da 0072 (C4 não asserta remoção).
- **Portar as views** (`index`/`team` → **0073 open-design-home**; `battle`/`_fighter_panel` → **0074**; `history` → **0075**; modais center/mart/membro + filtros `team=in|out` → **0076**).
- **Remover o CSS antigo** (`.list-team-grid`/`.battle-column`/…/`.gameloop-cta`) — responsabilidade de cada sessão de view (0073+).
- **UI das telas com a nomenclatura nova** — a marcação nova (`roster`/`member`/`arena`/`pos-card`/`overlay`/`modal` etc.) só nas sessões de view.
- **Rodas/rotas novas** (modais `GET /team/center`/`mart`, filtro `team=in|out` em `/pokemons`) — 0076.
- **`server.rb`/`lib/**`/`db/*`/`views/*.erb` (exceto `layout.erb`)** — intocados.
- **Mix visual** (topnav dark + conteúdo ainda sakura-light) é **intencional e temporário** (D1) — não é bug; resolved em 0076.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 `style.css` tem bloco `:root` com tokens oklch** — ex.: `--bg: oklch(21% 0.05 165)`, `--accent: oklch(66% 0.17 150)` e também `--font-display:`, `--radius:`, `--container:`, `--surface:`, `--fg:`, `--border:`. — prova: `test/design_system_test.rb` `test_design_system_root_tokens_oklch`.
- [ ] **C2 `style.css` contém as classes-núcleo** — `.topnav`, `.topnav-inner`, `.logo`, `.pagefoot`, `.btn`, `.btn-primary`, `.btn-secondary`, `.btn-ghost`, `.container`, `.section`, `.stack`, `.row`, `.row-between`, `.card`, `.eyebrow`, `.lead`, `.meta`, `.num`, `.muted`. — prova: `test/design_system_test.rb` `test_design_system_core_classes`.
- [ ] **C3 `layout.erb` usa o shell** — `<header class="topnav">`, `<footer class="pagefoot">`, `<link rel="stylesheet" href="/style.css">`. — prova: `test/design_system_test.rb` `test_layout_uses_topnav_footer_shell`.
- [ ] **C4 design system autônomo** — os tokens/classes novos não declaram dependência dos resets do sakura (sem `@import`/referência a `sakura` no `:root`/classes novas); **manter** o sakura no `<link>` do layout é OK. Não asserta remoção do sakura. — prova: `test/design_system_test.rb` `test_design_system_does_not_depend_on_sakura`.
- [ ] **C5 rota `/style.css` responde 200 `text/css`** — `get "/style.css"` → 200 com `content-type: text/css`. — prova: `test/design_system_test.rb` `test_style_css_route_serves_text_css`.
- [ ] **C6 `body` ganha `page-battle`/`page-history` conforme `request.path`** — `/battle` → `body class="page-battle..."`, `/history` → `body class="page-history..."`; `/` mantém `page-list`. — prova: `test/design_system_test.rb` `test_body_gets_page_battle_history`.

### Garantias (RNF)

- [ ] **G1 sem regressão** — `style_responsive_test.rb` (14) e `layout_test.rb` (4) **continuam verdes** + suíte completa + lint 0, com baseline **1003/3980** preservado e novos testes (C1–C6); 0 regressão fora do escopo.
- [ ] **G2 sem gems/schema/rede** — `git diff -- Gemfile* db/ server.rb lib/` vazio (sessão toca só `public/style.css` + `views/layout.erb` + `test/design_system_test.rb`); testes sem rede (usa `File.read`/rota estática; `/battle` com `PokeApiStub`).
- [ ] **G3 S4/S5** — `SESSIONS.md` (tabela + "Próxima sessão") atualizado no commit do refinamento; `./scripts/check_docs` + `./scripts/checar-sessao 0072` verdes; status de validação só após o usuário validar (fase 3 — parar na fase 2 e aguardar).

> **S1:** cada critério acima aponta o teste que o prova; nenhum critério é só manual (todos cobertos por `design_system_test.rb`). Baseline suíte **1003/3980** de 0071. **Parar ao fim da fase 2 e aguardar validação do usuário (fase 3) — não marcar Done, não preencher a seção 7, não commitar conclusão.**

## 5. Decisões de refinamento (fechadas com o usuário em 2026-09-09)

- **A1 — Aditivo (escolhida) vs. remover/reescrever:** adicionar `:root` (tokens oklch) + classes do design system ao `public/style.css` **mantendo intactas** as regras atuais (juice/responsivo/views). A remoção do CSS antigo vira responsabilidade de cada sessão de view (0073+). **B preterida:** remover o CSS antigo de uma vez (mais arriscado; regressão alta). Motivo: base aditiva garante 0 regressão e evita acoplar esta sessão à decisão de view.
- **B2 — Sakura fallback até 0076 (escolhida) vs. remover agora:** manter o link sakura no `layout.erb` até o fim da onda; a **remoção** do sakura é critério da **0076** (não da 0072). C4 da 0072 **não asserta** remoção do sakura. **A preterida:** remover o sakura já na 0072 (quebraria o visual atual das views não-portadas). Motivo: as views ainda usam a base sakura; o topnav dark + conteúdo sakura-light é um mix visual intencional/temporário até as views serem portadas.
- **D1 — Shell agora (escolhida) vs. adiar:** portar `layout.erb` (topnav + footer, `<link rel="stylesheet" href="/style.css">`, `body page-battle/page-history`) **preservando** o JS de `#global-loading`/scroll-restore e mantendo `page-list` no body para `/`. **B preterida:** deixar o shell para a 0073 (atrasaria a base visual). Motivo: C3/C6 exigem o shell; a base visual precisa do shell para as views seguintes.

> **Grafo obrigatório (tier Scout):** `search_graph query="Server routes register"` → `Server < Sinatra::Base` (`server.rb:1171`) e rotas/modules; `get_code_snippet` do layout manutenção. `public/style.css`/`views/layout.erb` são recursos de view (grep/read permitido). `check_index_coverage` em `server.rb`/`views/layout.erb` → `no_recorded_issue` (best-effort).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Parar ao fim da fase 2 e aguardar validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (tabela linha "0072 open-design-base" + "Próxima sessão" → 0073) | commit `Sessao 0072: refinamento concluido — design system base (tokens oklch + classes + shell layout.erb), criterios C1-C6 amarrados a testes, prox sessao 0073 open-design-home` |
| 1 | **red→green — C1 (tokens oklch)** — `test/design_system_test.rb` `test_design_system_root_tokens_oklch` (assert_match via `File.read` em `public/style.css`) + adicionar bloco `:root` com tokens oklch no `public/style.css` | `./scripts/test test/design_system_test.rb -n /root_tokens/` + suíte + lint 0; commit `Passo 1: :root com tokens oklch no style.css` |
| 2 | **red→green — C2 (classes-núcleo)** — `test/design_system_test.rb` `test_design_system_core_classes` (assert_match das classes-núcleo em `public/style.css`) + adicionar as classes-núcleo no `public/style.css` (após o `:root`) | `./scripts/test test/design_system_test.rb -n /core_classes/` + suíte + lint 0; commit `Passo 2: classes-nucleo do design system no style.css (aditivo)` |
| 3 | **red→green — C3+C6 (shell + body)** — `test/design_system_test.rb` `test_layout_uses_topnav_footer_shell` (assert em `views/layout.erb`) e `test_body_gets_page_battle_history` (route `/battle`, `/history`, `/` via Rack::Test com stub) + portar `views/layout.erb` (topnav + footer + `<link rel="stylesheet" href="/style.css">` + `body page-battle/page-history/page-list`; preservar JS `#global-loading`/scroll-restore e `<meta name="viewport">`; manter sakura — B2) | `./scripts/test test/design_system_test.rb -n /layout/` + suíte + lint 0; commit `Passo 3: shell layout.erb (topnav + footer + body page-battle/page-history)` |
| 4 | **red→green — C4+C5 (autônomo + rota)** — `test/design_system_test.rb` `test_design_system_does_not_depend_on_sakura` (assert que `:root`/classes novas não referenciam `sakura`; sem `@import`) e `test_style_css_route_serves_text_css` (`get "/style.css"` → 200 `text/css`) | `./scripts/test test/design_system_test.rb -n /sakura|style_css_route/` + suíte + lint 0; commit `Passo 4: design system autonomo (sem dependencia do sakura) + rota /style.css serve text/css` |
| 5 | **red→green — G1 (regressão + docs)** — suíte completa + lint 0 (baseline **1003/3980** preservado) + `style_responsive_test.rb`/`layout_test.rb` verdes + `./scripts/check_docs` | `./scripts/test` + `./scripts/lint` + `./scripts/check_docs` + `./scripts/checar-sessao 0072`; commit `Passo 5: regressao da suite e docs — design system base aditivo sem quebrar juice/responsivo/layout` |
| — | **Fase 2 concluída** → **Revisor (2c)**: loop Implementador↔Revisor até veredito `Aprovado` (teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar Done, não preencher a seção 7, não commitar conclusão. | — |

## 7. Validação (executada pelo usuário — S2)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 (tokens oklch no `:root`) | `./scripts/test test/design_system_test.rb -n /root_tokens/` | — | |
| C2 (classes-núcleo) | `./scripts/test test/design_system_test.rb -n /core_classes/` | — | |
| C3 (layout.erb shell) | `./scripts/test test/design_system_test.rb -n /layout/` | — | |
| C4 (design system autônomo) | `./scripts/test test/design_system_test.rb -n /sakura/` | — | |
| C5 (rota `/style.css` 200 `text/css`) | `./scripts/test test/design_system_test.rb -n /style_css_route/` | — | |
| C6 (body page-battle/page-history) | `./scripts/test test/design_system_test.rb -n /layout/` | — | |
| G1 (sem regressão) | `./scripts/test` + `./scripts/lint` 0 | `style_responsive_test.rb` (14) + `layout_test.rb` (4) verdes | |
| G2 (sem gems/schema) | `git diff -- Gemfile* db/ server.rb lib/` vazio | — | |
| G3 (S4/S5) | `./scripts/check_docs` + `./scripts/checar-sessao 0072` | — | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.

## 8. Observações

- **Próxima após 0072:** **0073 open-design-home** (`index`/`team`) → 0074 open-design-battle → 0075 open-design-history → 0076 open-design-modals-filters → 0077 escritas atômicas → 0078 CSRF → 0079 respiro. Ver `REQUIREMENTS.md:698-706` e `SESSIONS.md`.
- **`/style.css` passa pelo `before`** (`server.rb:1198`, `settings.team.all(current_user)` toca o banco) e **pelo `after`** (`server.rb:1204`, `release_current_thread!`) — mesmo padrão `/health`. O teste C5 (`get "/style.css"`) precisa de `TestDatabase.setup!` (já em `setup` do `ServerTestHelpers`) e roda sem stub. Confirmar no green do Passo 4 que a rota estática é servida (se Sinatra não servir por algum `set`/condição, o teste exige ajuste — mas o AGENTS.md já confirma que é estático do `public/`).
- **Não reordenar blocos no `style.css`:** o teste `style_responsive_test.rb` `test_juice_reduced_motion_disables` valida que o bloco `prefers-reduced-motion` vem **depois** das declarações `animation: juice-*`. Ao adicionar `:root`/classes novas, manter a ordem existente (adicionar sem mover os blocos atuais) — senão o teste de ordem quebra.
- **Nav do shell:** o `migration-guide.md` §5.1 usa nav Time + Histórico e "Batalhar" como `.btn.btn-primary` (CTA). O `layout_test.rb` `test_nav_shows_team_badge` exige `@team_size` e `/6` no navbar — preservar o badge `Time n/6`. Decidir se o nav mantém o link "Batalha" (atual) ou vira CTA — as classes do shell (C3) e body (C6) são o critério; o conjunto de links do nav é flexível, **preservando o badge `/6`**.
- **`C4 reinterpretado`:** a redação pede design system **autônomo** (não depender dos resets do sakura). Não assertar remoção do sakura — isso é critério da **0076** (B2). Evitar `refute_match` de `sakura` no `style.css`/layout como critério de C4 (só deve verificar que `:root`/classes novas não declaram dependência).
- **Mix visual (topnav dark + conteúdo sakura-light)** é intencional/temporário (D1) — não tratar como defeito da 0072; confirmar visualmente na validação (não é critério automatizado).
- **Nomes de teste sem dígitos** (gotcha da 0070, `Naming/VariableNumber`): usar `test_style_css_route_serves_text_css` (não `..._200`); manter nome de critério exige `# rubocop:disable Naming/VariableNumber` inline se precisar de dígito.
- **`/battle` exige stub** (`PokeApiStub.with_all_names`) para C6; `/history` e `/style.css` não. Seguir o padrão do `layout_test.rb`.

## 9. Gotchas / Lições (memória — S6)

- **Sinatra serve `/style.css` do `public/` com `content-type: text/css`** (Rack::Mime), mas a requisição **passa pelo `before`/`after`** (toca o banco). Em teste, `TestDatabase.setup!` cobre; sem stub de rede. Mesmo padrão do `/health` (0071) — se um dia o `/style.css` for healthcheck puro, condicionar; hoje não é.
- **Aditivo é obrigatório para não regredir juice/responsivo/views.** A única colisão futura de nomenclatura é `.fighter` (batalha) → 0074; hoje `.topnav`/`.btn`/`.container`/`.card` etc. **não colidem** com `.list-team-grid`/`.battle-column`/`.team-column`/`.gameloop-cta`.
- **Ordem de blocos no `style.css` importa** (regra da cascata): o `prefers-reduced-motion` deve continuar **depois** das `animation: juice-*` (bug real da 0063). Inserir `:root`/classes novas **sem mover** os blocos existentes.
- **Sakura mantido até a 0076** — remover é critério da 0076, não da 0072. Não colocar `refute_match` de sakura como critério de C4.
- **`body class` do shell precisa preservar `page-list` para `/`** (D1) além de `page-battle`/`page-history` — o `layout_test.rb`/views atuais dependem de `page-list` na página única `/`.
- **`layout_test.rb` `test_nav_shows_team_badge`** exige `@team_size` e `/6` no `layout.erb` — ao portar o shell, preservar o badge e o `@team_size`/`/6` no navbar.

### Confirmações no green (a preencher pelo implementador)

- *(registrar aqui as confirmações de rota `/style.css`, ordem do `prefers-reduced-motion`, presença do `@team_size` no shell, ao fechar cada passo.)*
