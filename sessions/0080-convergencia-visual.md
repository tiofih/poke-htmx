# Sessão 0080 — convergencia-visual (fechar o gap protótipo × app: body/topnav/roster/pcard/podium)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — escolhas do usuário em 2026-09-10 (escopo B: 0080 = itens 1-4+6, item 5 center/mart vira 0081 própria; item 5 = B modal-only; roster = A; pcard = B; demais = recomendadas do mapa — ver seção 5) |
| Implementação (fase 2, TDD) | **TDD concluída** — passos 1-4 verdes + regressão (1085/5291) + lint (0 no escopo); **aguardando Revisor S7** |
| Validação (fase 3) | Pendente — **fase do usuário; ao fim da fase 2, PARAR e aguardar** |

---

## 1. Objetivo

Fechar a **convergência visual** entre os protótipos `open-design/` e as views de produção — regra base global do `body`, topnav com CTAs consistentes + "Voltar ao time" em `/battle`, roster do time em grid 2-col com nível + Gerenciar, re-marcação completa do `.pcard` espelhando `home-team.html`, e meio do `.podium` envolvido em `.card` — **sem tocar backend/motor/economia** (item 5 center/mart vai para a 0081 própria).

## 2. Contexto (estado atual — diagnóstico)

- **Onda open-design fechada** (0072→0076, suíte 1057/4900 na validação da 0076); **resíduo por tela refinado** (0077 home-1a1, 0078 battle-1a1, 0079 history-1a1 — fase 2 pendente).
- **Grafo (tier Verify, project Users-tiofih-workspace-poke-htmx, generation 2026-09-09T22:00:47Z):** `layout.erb:19` (CTA aparece como texto `active` em `/battle`, não como botão); `style.css` **sem regra base `body`** (só `body.page-*` com max-width em :1896/1901/1946); `team.erb:37-58` (`.member`/`.sprite-tile`/`.mtag`/`.hp` ainda em linhas, sem grid/nível/Gerenciar); `pokemon_list_item.erb:1-25` (`li.pcard` + tier·custo + botão, marcação aquém do `home-team.html`); `battle.erb:40` (`.podium` com round-banner + controles + `#result-box`, **sem wrapper `.card`**); `_center`/`_mart` + rotas `GET /team/center|mart` (0076 — **NÃO tocar na 0080**).
- **Coverage:** ERB `not_tracked` (leitura exata antes de editar); `open-design/*` excluded do índice — referência visual são os screenshots `tmp/proto-home/battle/history.png` (`prints/` obsoletos).
- **Financeiros:** sem migração/schema/gems; motor de batalha e economia intocados.

## 3. Escopo

### Produção

- **`public/style.css` (só dentro do bloco ODS, ANTES da linha `fim`, com delimitador próprio `0080`):** regra base global do `body` + classes dos itens 1-4+6, aditivas.
- **`views/layout.erb`:** CTA sempre `.btn` (fim do CTA `active`-texto em `/battle`) + link "Voltar ao time" em `/battle`.
- **`views/team.erb` (roster, :37-58):** grid 2-col + nível do membro + link Gerenciar, **PRESERVANDO** os botões ▲▼ (`name="new_slot"`).
- **`views/pokemon_list_item.erb` (:1-25):** re-marcação completa espelhando `home-team.html` (tier·custo + botão preservados no conteúdo).
- **`views/battle.erb` (:40):** meio do `.podium` (round-banner + controles + `#result-box`) envolvido em `.card`.

### Testes

- **Novo:** `test/convergence_0080_test.rb` (C1–C5, um método por critério — ver §4).
- **Estender (cirúrgico, regressão A):** `test/design_system_test.rb` (classes 0080 no bloco), `test/home_view_test.rb` (roster/pcard), `test/battle_view_test.rb` (podium), `test/layout_test.rb` (topnav/body) — **sem tocar `test/open_design_contract_test.rb`**.

### Fora de escopo (não abrir — RNF-04)

- Item 5 center/mart (`_center`/`_mart`, rotas `GET /team/center|mart`) → **sessão 0081** (modal-only, §8); backend/motor/economia (`BattleEngine`, `resolve`/`finish_effects`, heal/mart services); migração/schema/gems; identidade `?as=`, CSRF, escritas atômicas → 0082+; erro-status, respiro.

## 4. Critérios de aceite

### Resultado (S1 — cada critério aponta o teste que o prova)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| C1 body global: regra base do `body` no bloco ODS (delimitador `0080`), aditiva, ANTES da linha `fim` | `test/convergence_0080_test.rb` `test_body_has_global_base_rule` (novo) + `test/design_system_test.rb` estendido + `test/layout_test.rb` estendido | verde (passo 1) |
| C2 topnav: CTA sempre `.btn` em toda rota (fim do `active`-texto em `/battle`) + "Voltar ao time" em `/battle` | `test/convergence_0080_test.rb` `test_topnav_ctas_are_buttons_and_battle_has_back_link` (novo) + `test/layout_test.rb` estendido | verde (passo 1) |
| C3 roster: `team.erb` em grid 2-col com nível do membro + Gerenciar, ▲▼ (`new_slot`) preservados | `test/convergence_0080_test.rb` `test_roster_grid_with_level_manage_and_reorder` (novo) + `test/home_view_test.rb` estendido | verde (passo 2) |
| C4 pcard: `pokemon_list_item.erb` re-marcado por completo espelhando `home-team.html` (tier·custo + botão no conteúdo) | `test/convergence_0080_test.rb` `test_pcard_full_remarkup_mirrors_prototype` (novo) + `test/home_view_test.rb` estendido | verde (passo 3) |
| C5 podium: meio do `.podium` (round-banner + controles + `#result-box`) envolvido em `.card` | `test/convergence_0080_test.rb` `test_podium_middle_wrapped_in_card` (novo) + `test/battle_view_test.rb` estendido | verde (passo 4) |

### Garantias

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| G1 sem regressão — suíte completa (baseline **1057/4900** + novos) + lint 0 | `./scripts/test` + `./scripts/lint` | verde passo 5 (**1085/5291**, 0 falhas; lint 0 no escopo — 19 ofensas preexistentes em `scripts/sweep-balance.rb`, fora do escopo) |
| G2 só visual — sem migração/schema/gems; motor/economia intocados; `open_design_contract` intacto | `git diff --stat -- db/ Gemfile* test/open_design_contract_test.rb` vazio + revisão S7 confere | verde (diff vazio nos 4 commits; +1 linha view-data `@member_levels` em `prepare_team_fragment_data` via helper existente) |
| G3 S4/S5 + revisão — `SESSIONS.md` + `check_docs` + `checar-sessao 0080` verdes; revisor S7 `Aprovado` antes da 3 | `./scripts/check_docs` + `./scripts/checar-sessao 0080` + veredito do Revisor | parcial (checks verdes; S7 pendente) |

### Manual

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| M1 convergência no navegador 1440px (home/battle/history lado a lado com o protótipo, sem overflow-x) | `manual` (`./scripts/run`, screenshots `tmp/comp-home|battle|history.png` vs `tmp/proto-home|battle|history.png`) | pendente |

> **S1:** cada critério acima aponta o teste que o prova (arquivo + método); o único critério puramente manual é **M1**. **Ao fim da fase 2 (suíte + lint verdes, revisor S7 `Aprovado`), PARAR e aguardar a validação do usuário — não marcar Done, não preencher a seção 7, não commitar conclusão.**

## 5. Decisões de refinamento (fechadas com o usuário em 2026-09-10 — prevalecem sobre o mapa)

- **Escopo B (escolhida):** 0080 = itens 1-4+6 (body, topnav, roster, pcard, podium); item 5 (center/mart) vira **sessão 0081 própria** (§8).
- **Item 5 = B modal-only (escolhida):** registrada na 0081, **NÃO implementada na 0080** (`_center`/`_mart` + rotas 0076 intocados).
- **Roster = A (escolhida):** grid 2-col + nível + Gerenciar, **PRESERVA** ▲▼.
- **Pcard = B (escolhida):** re-marcação completa espelhando `home-team.html`.
- **Body = A (recomendada, aceita):** regra base global no bloco ODS (delimitador `0080`).
- **Topnav = A (recomendada, aceita):** CTA sempre `.btn` + "Voltar ao time" em `/battle`.
- **Podium = A (recomendada, aceita):** envolve o meio em `.card`.
- **S1 = A (recomendada, aceita):** 1 arquivo Minitest novo (`convergence_0080_test.rb`, C1–C5) + manuais via screenshot 1440px (`tmp/comp-*` vs `tmp/proto-*`).
- **Regressão = A (recomendada, aceita):** estender `design_system`/`home_view`/`battle_view`/`layout_test`, **sem tocar `open_design_contract`**.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Termina em Revisor (2c, S7, teto 3 rodadas) → **PARAR** p/ validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (linha 0080 + "Próxima sessão") | commit `Sessao 0080: refinamento concluido — ...` |
| 1 | **red→green — C1 + C2 (body + topnav)** — regra base `body` no bloco ODS (delimitador `0080`) + `layout.erb` (CTA `.btn` + Voltar ao time); criar `test/convergence_0080_test.rb` + estender `design_system_test.rb`/`layout_test.rb` | `./scripts/test test/convergence_0080_test.rb test/design_system_test.rb test/layout_test.rb` + suíte + lint 0; commit `Passo 1: base body global + topnav com CTA btn e Voltar ao time` |
| 2 | **red→green — C3 (roster)** — `team.erb:37-58` em grid 2-col + nível + Gerenciar, ▲▼ preservados; estender `home_view_test.rb` | `./scripts/test test/convergence_0080_test.rb test/home_view_test.rb` + suíte + lint 0; commit `Passo 2: roster em grid com nivel e Gerenciar, reorder preservado` |
| 3 | **red→green — C4 (pcard)** — re-marcação completa de `pokemon_list_item.erb` espelhando `home-team.html`; estender `home_view_test.rb` | `./scripts/test test/convergence_0080_test.rb test/home_view_test.rb` + suíte + lint 0; commit `Passo 3: pcard re-marcado espelhando o prototipo` |
| 4 | **red→green — C5 (podium)** — meio do `.podium` em `.card` (`battle.erb:40`); estender `battle_view_test.rb` | `./scripts/test test/convergence_0080_test.rb test/battle_view_test.rb` + suíte + lint 0; commit `Passo 4: podium com meio envolvido em card` |
| 5 | **red→green — G1/G3 (regressão + docs)** — suíte + lint 0 + `check_docs` + `checar-sessao 0080` | `./scripts/test` + `./scripts/lint` + `./scripts/check_docs` + `./scripts/checar-sessao 0080`; commit `Passo 5: regressao e docs — convergencia visual fechada` |
| — | **Fase 2 concluída** → **Revisor (2c)** até `Aprovado` (teto 3, senão S3) → **PARAR**, aguardar **validação 3**. Não marcar Done, não preencher §7, não commitar conclusão. | — |

## 7. Validação (executada pelo usuário — S2)

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 (body global) | | | pendente |
| C2 (topnav) | | | pendente |
| C3 (roster) | | | pendente |
| C4 (pcard) | | | pendente |
| C5 (podium) | | | pendente |
| G1 (sem regressão) | | | pendente |
| G2 (só visual) | | | pendente |
| G3 (docs + revisão) | | | pendente |
| M1 (screenshots 1440px) | — | | pendente |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário. **Ao fim da fase 2, PARAR na fase 2 — não preencher esta seção, não marcar Done, não commitar conclusão sem a validação do usuário (fase 3).**

> **Alteração formal S3 (2026-09-10) — C1 reprovado na prática pelo usuário:** fundo segue branco + fontes serifadas no navegador, apesar de C1 verde em teste. Causa: `views/layout.erb:1` começava com `<html>` nu, sem `<!DOCTYPE html>` (protótipos `open-design/*.html` começam com `<!doctype html>`) — console acusa Quirks Mode e as regras do bloco ODS (`body{background:var(--bg)...}` em `public/style.css`, bloco `Convergencia 1:1 (0080)`) não se aplicam (computed body = transparent/Times apesar de served==file); possível contribuição de cache (`/style.css` sem cache-busting — revalidar em contexto isolado, sem cache). **C1 reaberto** + novo **C1b (doctype):** `GET /` (full page) deve começar com `<!DOCTYPE html>` e `<html lang="pt-BR">` como nos protótipos — prova em `test/layout_test.rb` `test_full_page_starts_with_doctype` (red confirmado antes do fix: body começava com `<html>`; green após). Fix mínimo: 2 linhas em `views/layout.erb` (`<!DOCTYPE html>` + `lang="pt-BR"`), sem tocar em mais nada. Tabela S2 acima mantida vazia — **revalidação é do usuário (fase 3)**, incluindo M1 em contexto isolado (ausência do aviso de Quirks Mode + fundo/fontes do ODS).

## 8. Observações

- **Sessão 0081 registrada (item 5, decisão B modal-only — NÃO implementar na 0080):** `_center`/`_mart` + rotas `GET /team/center|mart` viram **modal-only** (padrão overlay híbrido da 0076). Esboço de critérios da 0081 (a fechar no refinamento dela): C1 center modal-only (cura/custo no overlay, sem página própria); C2 mart modal-only (compra/venda no overlay, sem página própria); G sem regressão (suíte + lint 0, contratos `data-od-id` intactos); M screenshot 1440px dos dois modais.
- **Fila (novo deslizamento, seção 5):** 0077 home → 0078 battle → 0079 history → **0080 convergência visual** → **0081 center-mart-modal-only** → 0082 escritas atômicas → 0083 CSRF → 0084 respiro.
- **Referência stale:** `REQUIREMENTS.md:716-717` ainda aponta "0080 escritas atômicas → 0081 CSRF → 0082 respiro" — atualizar no refinamento da 0082 (fora desta sessão, RNF-04).
- **Leitura exata antes de editar:** ERB `not_tracked` no grafo — confirmar `layout.erb:19`, `team.erb:37-58`, `pokemon_list_item.erb:1-25`, `battle.erb:40` no arquivo antes do Passo 1.
- **Fase 2 executada (2026-09-10, TDD red→green):** C1-C5 verdes nos passos 1-4 (`3fb5532`, `a37fee0`, `68f94c2`, `26ada4f`); `test/battle_routes_test.rb:20` atualizado no passo 5 (codificava o `active`-texto que C2 remove — `pokemon_routes_test.rb:368` já refutava o antigo); suíte **1085/5291** verde; `check_docs` + `checar-sessao 0080` verdes. **PARADO antes da fase 3** — sem Done, sem §7, sem commit de conclusão.

## 9. Gotchas / Lições (memória — S6, preencher na 3)

- (preencher na validação)
