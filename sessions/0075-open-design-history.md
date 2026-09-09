# Sessão 0075 — open-design-history (`history` + `history_page` — pos-card/ranking/batalhas no ODS)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-09-09 (B, A, C, A×7 — ver seção 5) |
| Implementação | **Concluída** — 3 commits (`aca31eb`/`25363f9`/`9e0c1ea`), suíte 1025/4402 0 falhas, lint 0, revisor 2c **Aprovado** sem S3 |
| Validação | **Concluída** — validada pelo usuário em 2026-09-09 (**Done**; S2 C1–C8+G1–G3 ok + M1 ok, sem S3) |

---

## 1. Objetivo

Portar a tela de **histórico** (`history.erb` + `history_page.erb` re-marcado com `pagehead`/`container`) para o design system do `open-design/` (`migration-guide.md` §1.2/§2 — protótipo `history.html`), vestindo a view existente com **`.pos-card`** (posição + 3× `.stat-chip`), **`ul.rank-list>li.rank-row`** (ranking com barra ∝ e `.you`) e **`ul.history-list>li.history-row`** (batalhas com `.result-badge`), **preservando** o contrato de fragmento `#history-view` (`render_history`/`load_history_data` intocados, sem rota nova) e o vazio `p.notice.notice--info`. 4ª de 5 sessões da Onda open-design (base → home → battle → history → modals-filters).

## 2. Contexto (estado atual — diagnóstico)

- **0072/0073/0074 entregues** (todas validadas 2026-09-09, baseline **1018/4279**, lint 0): no `public/style.css` o **bloco delimitado** `/* === Open Design System (0072): inicio / fim === */` (linhas 6–890) com `:root` (tokens oklch) + classes-núcleo + classes de home/catálogo/roster (0073) + classes de batalha/arena/podium/log/result + juice portado (0074). `layout.erb` já dá `body page-history` em `/history`. **Sakura mantido como fallback até a 0076**.
- **`views/history.erb` (31 linhas)** — marcação antiga: `h1` + gate vazio (`@rank.empty? && @recent.empty?` → `p.notice.notice--info` "Você ainda não batalhou."); senão `h2 Ranking global` + `p.rank-entry` (`current` quando `row[:user_id] == @current_user`, texto `"N. user_id — W vitórias (T batalhas)"`) + `h2 Sua posição` + `p.position` (`"Posição N — Vitórias: W — Derrotas: L — Empates: D"` ou "Você ainda não tem vitórias." quando `@position` nil) + `h2 Últimas batalhas` + `ul.battle-history > li` (`result_label` + "contra" + `opponent_names` + `Time.parse(created_at).strftime("%d/%m/%Y %H:%M")`).
- **`views/history_page.erb` (3 linhas)** — `<div id="history-view"><%= erb :history %></div>`. `server.rb:1076-1090` (`render_history` só envolve quando **NÃO** `htmx_request?`; `load_history_data` injeta `@current_user`/`@rank`/`@stats`/`@position`/`@recent` via `BattleRepository#ranking`/`#stats`/`#rank_position`/`#recent`) e `HistoryRoutes.register_history` (`server.rb:1118-1120`, `GET /history`). **Nenhuma rota/helper muda nesta sessão (escolha 4 = A).**
- **Protótipo `open-design/history.html`** — `main.container[data-od-id="history"]` + `.pagehead` (`.eyebrow` + `h1` + `.lead`) + `section[data-od-id="your-position"] > .pos-card` (`.pos-left` > `.pos-badge>.num` + `.pos-title` > `h2` + `.meta.num`; `.pos-stats` > 3× `.stat-chip.win/.loss/.draw` > `.n` + `.l`) + `section[data-od-id="ranking"]` (`h2.section-title` + `.card > ul.rank-list > li.rank-row` [`.rank-pos.num` + `.rank-name` (+`.meta`) + `.rank-bar>span` + `.rank-wins` (`strong.num` + ` / total`)] — `.you` na linha atual) + `section[data-od-id="recent"]` (`h2.section-title` + `.card > ul.history-list > li.history-row` [`.result-badge.win/.loss/.draw` + `.history-main` (`.h-title`/`.h-sub`) + `.history-date.num`]).
- **Testes que amarram a marcação antiga** (impacto da re-marcação): `test/history_routes_test.rb` (63 linhas) — `:7-21` `test_history_page_renders_full_page_with_history_view` (`id="history-view"`, `Ranking global`, `Vitórias: 1`/`Derrotas: 1`), `:23-31` `test_history_highlights_current_user_in_ranking` (`user-a` — sem `.you`), `:33-39` vazio (`notice--info` — **mantém**), `:41-46` `page-history` (**mantém**), `:48-52` close 404 (**mantém**), `:54-62` link no index (**mantém**). `test/design_system_test.rb` (152 linhas — sem bloco history). `test/style_responsive_test.rb` (207 linhas — sem regra de history; **será estendido** com regra nova ≤920px).
- **Baseline:** suíte **1018/4279**, lint 0 (0074). Fila (SESSIONS.md): 0074 Done → **0075 open-design-history** → 0076 open-design-modals-filters → 0077 escritas atômicas → 0078 CSRF → 0079 respiro.
- **Preservar:** `server.rb`/`lib/**`/`db/*` intocados (só CSS + views + testes); `render_history`/`load_history_data` intocados; delimitadores ODS estáveis.

## 3. Escopo

### Produção

- **`public/style.css`** — anexar, **dentro** do bloco delimitado do design system (marcadores `inicio`/`fim` intactos), as classes de history do §1.2 traduzidas do `<style>` do protótipo `open-design/history.html` (linhas ~62-109): `.pagehead`, `.pos-card`/`.pos-left`/`.pos-badge`/`.pos-title`/`.pos-stats`, `.stat-chip` (+`.win`/`.loss`/`.draw` com `.n`/`.l`), `.section-title`, `.rank-list`/`.rank-row` (+`.you`)/`.rank-pos`/`.rank-name`/`.rank-bar`/`.rank-wins`, `.history-list`/`.history-row`, `.result-badge` (+`.win`/`.loss`/`.draw`), `.history-main`/`.h-title`/`.h-sub`, `.history-date`. **Reuso:** `.container`/`.card`/`.eyebrow`/`.lead`/`.meta`/`.num`/`.muted` já existem no bloco — harmonizar em vez de duplicar. CSS antigo (`body.page-history`, regra ~1068) **permanece íntegro**.
- **`views/history.erb`** — re-marcar **in-place** (escolha 4 = A): `pagehead` (`.eyebrow` "Histórico · Bancada de batalhas" + `h1` + `.lead`) + `.pos-card` (`.pos-badge>.num` com a posição + `.pos-title` + 3× `.stat-chip.win/.loss/.draw` com `@stats`; `@position` nil → frase "ainda não tem vitórias" **dentro do card**) + ranking como `ul.rank-list>li.rank-row` (`.rank-pos.num` = índice+1, `.rank-name` = `user_id`, `.rank-bar>span` com `width` ∝ `wins/total`, `.rank-wins` com `strong.num` + `/ total`, `.you` quando `row[:user_id] == @current_user`) + batalhas como `ul.history-list>li.history-row` (`.result-badge.win/.loss/.draw` via `result_label(record[:result])`, `.history-main` > `.h-title` "Contra …" via `opponent_names` + `.h-sub` com dado do record, `.history-date.num` com `strftime("%d/%m %H:%M")`). **Vazio `p.notice.notice--info` intacto.**
- **`views/history_page.erb`** — **re-marcado mas preservado**: wrapper `#history-view` + contrato htmx intactos (fragmento `erb :history, layout: false` continua o alvo do swap).

### Testes

- **`test/history_view_test.rb`** — **novo teste estrutural** (padrão `test/home_view_test.rb` / `test/battle_view_test.rb`): prova **C2** (`.pagehead` + `.container`), **C3** (`.pos-card` + `.pos-badge>.num` + 3× `.stat-chip.win/.loss/.draw`), **C4** (`ul.rank-list>li.rank-row` + `.you` + `.rank-bar>span` + `.rank-wins`) e **C5** (`ul.history-list>li.history-row` + `.result-badge` + `.history-main` + `.history-date`).
- **`test/design_system_test.rb`** — **estender** (C7): novo método `test_design_system_history_screen_classes` (assert das classes de history presentes **no bloco**: `.pagehead`, `.pos-card`, `.pos-badge`, `.pos-title`, `.pos-stats`, `.stat-chip`, `.section-title`, `.rank-list`, `.rank-row`, `.rank-pos`, `.rank-name`, `.rank-bar`, `.rank-wins`, `.history-list`, `.history-row`, `.result-badge`, `.history-main`, `.history-date`).
- **Editar `test/history_routes_test.rb`** (marcação antiga substituída — nomes sem dígitos, gotcha 0070):
  - **`test_history_page_renders_full_page_with_history_view`** (`:7-21` — C1): **mantém** `id="history-view"` + nav `active` + `Ranking global`; `Vitórias: 1`/`Derrotas: 1` → asserts dos **chips novos** (`.stat-chip.win`/`.loss`).
  - **`test_history_highlights_current_user_in_ranking`** (`:23-31` — C4): `user-a` + **`.you` na `li.rank-row` atual** (era `current` no `p.rank-entry`).
  - **`test_history_shows_empty_message_without_battles`** (`:33-39` — C6): **mantém verde sem edição** (`notice--info` intacto).
  - **`:41-62` mantidos** (`page-history`, close 404, link no index).
- **`test/style_responsive_test.rb`** — **estender** (C8): nova regra de history — `@media (max-width: 920px)` empilhando `.history-row` (badge+main+date em coluna) — + novo método `test_history_rows_stack_at_920`.

### Fora de escopo (não abrir — RNF-04; fica para 0076)

- **Modais center/mart/membro + filtros `team=in|out` + remoção do CSS antigo (sakura + regras legadas) + re-marcação dos gates `@message`** → 0076.
- **`server.rb`/`lib/**`/`db/*`/helpers** (`render_history`/`load_history_data`/`result_label`/`opponent_names`) — intocados, sem rota nova.
- **Mudança de dados**: `.h-sub` usa só o que o record já expõe; formato de data novo (`%d/%m %H:%M`) é só apresentação.

## 4. Critérios de aceite

### Resultado (S1 — cada critério aponta o teste que o prova)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| C1 `GET /history` renderiza página completa com `#history-view` + `body.page-history` — wrapper `history_page.erb` re-marcado, contrato htmx preservado | `test/history_routes_test.rb` `test_history_page_renders_full_page_with_history_view` (mantém `id="history-view"` + nav `active`; chips no lugar de `Vitórias:/Derrotas:`) + `test_history_page_uses_full_width_body_class` (mantém) | ok |
| C2 fragmento novo tem `.pagehead` (eyebrow + h1 + lead) dentro de `.container` | `test/history_view_test.rb` `test_history_pagehead_and_container` (novo, estrutural) | ok |
| C3 `.pos-card` com `.pos-badge>.num` + `.pos-title` + 3× `.stat-chip.win/.loss/.draw` (valores de `@stats`); `@position` nil → frase "ainda não tem vitórias" dentro do card | `test/history_view_test.rb` `test_history_position_card_with_stat_chips` + `test_history_position_nil_shows_fallback_in_card` (novos) | ok |
| C4 ranking como `ul.rank-list>li.rank-row` (`.rank-pos.num` + `.rank-name` + `.rank-bar>span` + `.rank-wins`, barra ∝ `wins/total`, `.you` na linha atual) | `test/history_view_test.rb` `test_history_ranking_list_with_bars_and_current_user` (novo) + `test/history_routes_test.rb` `test_history_highlights_current_user_in_ranking` (editado p/ `.you`) | ok |
| C5 batalhas como `ul.history-list>li.history-row` (`.result-badge.win/.loss/.draw` via `result_label`, `.history-main>.h-title/.h-sub`, `.history-date.num` em `dd/mm HH:MM`) | `test/history_view_test.rb` `test_history_recent_battles_list` (novo) | ok |
| C6 vazio mantém `p.notice.notice--info` ("Você ainda não batalhou.") | `test/history_routes_test.rb` `test_history_shows_empty_message_without_battles` (mantém verde sem edição) | ok |
| C7 CSS: classes de history presentes no bloco ODS + CSS antigo íntegro | `test/design_system_test.rb` `test_design_system_history_screen_classes` (estendido) | ok |
| C8 responsivo: `.history-row` empilha em coluna ≤920px (regra nova no CSS) | `test/style_responsive_test.rb` `test_history_rows_stack_at_920` (novo, estendido) | ok |

### Garantias (RNF)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| G1 sem regressão — suíte completa (baseline **1018/4279** + novos testes) + lint 0; regras antigas íntegras | `./scripts/test` + `./scripts/lint` | ok |
| G2 sem gems/schema/rede/backend — só `views/*.erb` + `public/style.css` + testes | `git diff -- Gemfile* db/ server.rb lib/` vazio; testes sem rede | ok |
| G3 S4/S5 — `SESSIONS.md` (tabela linha "0075 open-design-history" + "Próxima sessão" → **0076 open-design-modals-filters**) atualizado no commit do refinamento | `./scripts/check_docs` + `./scripts/checar-sessao 0075` verdes | ok |

### Manual

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| M1 reflow da history ≤920px no navegador (pos-card empilha, rank/history-rows legíveis, sem overflow horizontal) | `manual` (subir o app com `./scripts/run`, navegar `/history` com e sem batalhas, redimensionar ≤920px) | ok |

> **S1:** cada critério acima aponta o teste que o prova (arquivo + método); o único critério **puramente manual é o M1** (visual — evidência manual explícita). **Parar ao fim da fase 2 e aguardar a validação do usuário (fase 3) — não marcar Done, não preencher a seção 7, não commitar conclusão.**

## 5. Decisões de refinamento (fechadas com o usuário em 2026-09-09)

- **1B — objetivo (escolhida):** portar `history.erb` + `history_page.erb` (re-marcar o wrapper com `pagehead`/`container`).
- **2A — escopo (escolhida):** entra `history.erb` + `history_page.erb` + CSS aditivo + testes; fica para 0076 (modais/filtros `team=in|out`/remoção sakura+CSS antigo/`@message` gates).
- **3C — critérios→teste (escolhida):** novo `test/history_view_test.rb` estrutural + estender `design_system_test.rb` (classes history no bloco ODS) + editar `history_routes_test.rb` (seletores antigos) + **estender** `style_responsive_test.rb` com regra nova de history + 1 `manual` (reflow ≤920px).
- **4A — vestir (escolhida):** re-marcar `history.erb` in-place, `render_history`/`load_history_data` intocados, sem rota nova (`history_page.erb` re-marcado mas wrapper `#history-view` + htmx preservados).
- **5A — CSS (escolhida):** aditivo dentro do bloco ODS (`/* === Open Design System (0072): inicio/fim === */`), antigo íntegro.
- **6A — ranking (escolhida):** `ul.rank-list>li.rank-row` (`.rank-pos.num` + `.rank-name` + `.rank-bar>span` + `.rank-wins`, barra ∝ `wins/total`, `.you` na linha atual).
- **7A — posição (escolhida):** `.pos-card` (`.pos-badge>.num` + `.pos-title` + 3× `.stat-chip.win/.loss/.draw`; `@position` nil → frase "ainda não tem vitórias" dentro do card).
- **8A — batalhas (escolhida):** `ul.history-list>li.history-row` (`.result-badge.win/.loss/.draw` via `result_label` + `.history-main>.h-title/.h-sub` + `.history-date.num` dd/mm HH:MM).
- **9A — vazio (escolhida):** `p.notice.notice--info` intacto.
- **10A — tamanho (escolhida):** history inteira (3 blocos), 3-4 commits previstos.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Parar ao fim da fase 2 e aguardar a validação do usuário (fase 3).

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (tabela linha "0075 open-design-history" + "Próxima sessão" → 0076) | commit `Sessao 0075: refinamento concluido — history (pos-card+rank-list+history-list no ODS, vestir in-place sem rota nova), criterios C1-C8+G1+manual amarrados, prox sessao 0076 open-design-modals-filters` |
| 1 | **red→green — C7 (style.css classes de history no ODS)** — estender `test/design_system_test.rb` `test_design_system_history_screen_classes` (assert das classes novas no bloco) + anexar as classes de history do §1.2 ao `public/style.css` **dentro** do bloco delimitado (sem tocar nos marcadores; sem remover regras antigas) | `./scripts/test test/design_system_test.rb -n /history_screen_classes/` + suíte + lint 0; commit `Passo 1: classes de history do §1.2 no bloco ODS (pos-card/stat-chip/rank-list/history-list, aditivo)` |
| 2 | **red→green — C1+C2+C3+C6 (history.erb pagehead+pos-card + history_page wrapper)** — criar `test/history_view_test.rb` (C2: `.pagehead`/`.container`; C3: `.pos-card`/badge/3 chips + fallback nil no card) + re-marcar `views/history.erb` (pagehead + pos-card; vazio intacto) + re-marcar `views/history_page.erb` (wrapper `#history-view` preservado) + editar `test/history_routes_test.rb` `:19-20` (chips) mantendo `:7-17,33-46` | `./scripts/test test/history_view_test.rb` + `./scripts/test test/history_routes_test.rb` + suíte + lint 0; commit `Passo 2: history.erb com pagehead e pos-card (fallback nil no card), wrapper #history-view preservado` |
| 3 | **red→green — C4+C5+C8 (ranking + batalhas + responsivo)** — ranking `ul.rank-list>li.rank-row` (`.you`, barra ∝ `wins/total` com guarda `total` 0) + batalhas `ul.history-list>li.history-row` (badges via `result_label`, data `strftime("%d/%m %H:%M")`) + regra `@media (max-width: 920px)` empilhando `.history-row` + editar `test/history_routes_test.rb` `:23-31` (`.you`) + estender `test/style_responsive_test.rb` `test_history_rows_stack_at_920` | `./scripts/test test/history_view_test.rb` + `./scripts/test test/history_routes_test.rb -n /ranking/` + `./scripts/test test/style_responsive_test.rb -n /history_rows/` + suíte + lint 0; commit `Passo 3: ranking com barra proporcional e .you + ultimas batalhas com badges, reflow em 920px` |
| 4 | **red→green — G1 (regressão + docs)** — suíte completa + lint 0 (baseline **1018/4279** preservado + `history_view_test.rb`/`design_system_test.rb`/`style_responsive_test.rb` estendidos) + `./scripts/check_docs` + `./scripts/checar-sessao 0075` | `./scripts/test` + `./scripts/lint` + `./scripts/check_docs` + `./scripts/checar-sessao 0075`; commit `Passo 4: regressao da suite e docs — history no ODS sem quebrar responsivo/design-system` |
| — | **Fase 2 concluída** → **Revisor (2c)**: loop Implementador↔Revisor até veredito `Aprovado` (teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar Done, não preencher a seção 7, não commitar conclusão. | — |

## 7. Validação (executada pelo usuário — S2)

**Validada pelo usuário em 2026-09-09 (resposta "validado", sem S3).**

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 (`GET /history` → `#history-view` + `page-history`) | `test/history_routes_test.rb` `test_history_page_renders_full_page_with_history_view` + `test_history_page_uses_full_width_body_class` | — | ok |
| C2 (`.pagehead` + `.container`) | `test/history_view_test.rb` `test_history_pagehead_and_container` | — | ok |
| C3 (`.pos-card` + badge + 3 chips; fallback nil no card) | `test/history_view_test.rb` `test_history_position_card_with_stat_chips` + `test_history_position_nil_shows_fallback_in_card` | — | ok |
| C4 (`ul.rank-list>li.rank-row` + barra ∝ + `.you`) | `test/history_view_test.rb` `test_history_ranking_list_with_bars_and_current_user` + `test/history_routes_test.rb` `test_history_highlights_current_user_in_ranking` | — | ok |
| C5 (`ul.history-list>li.history-row` + badges + data dd/mm HH:MM) | `test/history_view_test.rb` `test_history_recent_battles_list` | — | ok |
| C6 (vazio `notice--info`) | `test/history_routes_test.rb` `test_history_shows_empty_message_without_battles` | — | ok |
| C7 (CSS history no bloco ODS + antigo íntegro) | `test/design_system_test.rb` `test_design_system_history_screen_classes` | — | ok |
| C8 (`.history-row` empilha ≤920px) | `test/style_responsive_test.rb` `test_history_rows_stack_at_920` | — | ok |
| G1 (sem regressão) | `./scripts/test` (baseline 1018/4279 + novos) + `./scripts/lint` 0 | navegação `/`, `/battle`, `/history` | ok |
| G2 (sem gems/schema/rede/backend) | `git diff -- Gemfile* db/ server.rb lib/` vazio; testes com stub | — | ok |
| G3 (S4/S5 docs consistentes) | `./scripts/check_docs` + `./scripts/checar-sessao 0075` verdes | — | ok |
| M1 (reflow history ≤920px) | — | `manual`: `./scripts/run`, `/history` com/sem batalhas, redimensionar ≤920px (pos-card empilha, rows legíveis, sem overflow-x) | ok |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.

## 8. Observações

- **Formato de data muda só na apresentação (8A):** `strftime("%d/%m/%Y %H:%M")` → `strftime("%d/%m %H:%M")` (protótipo exibe `02/09 14:32`); nenhum teste atual ancora o ano — só o `history_view_test.rb` novo ancora o formato curto.
- **Barra ∝ precisa de guarda `total` 0:** `width: (100.0 * wins / total).round` — `ranking` só traz `user_id` com batalhas (`GROUP BY` sobre `battles`), mas blindar divisão por zero no ERB custa 1 linha e evita 500 futuro.
- **`.h-sub` sem API nova:** o record de `recent` expõe `id/result/opponent_team/created_at` — a linha secundária usa só esses dados (ex.: "N oponentes" via `opponent_team.size`); nada de nível/XP do protótipo (dados que o backend não tem — fora de escopo, G2).
- **`.rank-name` exibe o `user_id` cru** (como hoje no `p.rank-entry`) — trocar por apelido é feature nova, fora de escopo.
- **Nomes de teste sem dígitos** (gotcha 0070 — `Naming/VariableNumber`): `history_view_test.rb` usa nomes por extenso (`..._at_920` → escrever `..._at_nine_twenty`? não — seguir o padrão local: `test_battle_layout_stacks_at_900` usa `# rubocop:disable Naming/VariableNumber`; aplicar o mesmo disable no teste novo de 920).
- **Suíte de referência:** baseline **1018/4279**, lint 0 (0074). Fila: 0074 Done → **0075 open-design-history** → 0076 open-design-modals-filters → 0077 escritas atômicas → 0078 CSRF → 0079 respiro.

## 9. Gotchas / Lições (memória — S6)

- **Re-marcação do `history.erb` colapsa 3 asserts de `history_routes_test.rb`** (`:19-20` `Vitórias:/Derrotas:`, `:30` highlight sem `.you`): reconciliar os seletores de classe antes do green do Passo 2/3 — o vazio (`:33-39`) e o resto (`:41-62`) seguem verdes sem edição porque `notice--info`/`page-history`/rotas não mudam.
- **`style_responsive_test.rb` ganha regra nova (diferença da 0074):** aqui a extensão é aditiva (nova `@media (max-width: 920px)` + teste novo) — nada do CSS antigo é tocado, então os testes legados seguem verdes por construção.
- **Delimitadores do bloco ODS são contrato do C4 (0072):** não renomear/mexer nos marcadores `Open Design System (0072): inicio|fim`; anexar as classes de history **dentro** do bloco (linhas 6–890).
