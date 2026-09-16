# Sessão 0078 — open-design-battle-1a1 (resíduo battle: `battle.html` + end-states + results-desktop → fim de `battle.erb`/`_fighter_panel`)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — escolhas do usuário em 2026-09-09 (fatiamento por tela, deslizamento 0077-0079→resíduo / 0080-0082→estabilidade, fidelidade híbrida, backend thin listado, S1 com 1 teste novo + extensões — ver seção 5) |
| Implementação (fase 2, TDD) | **Verde** — Passos 1-4 commitados (9b421c4, 924e5b6, 4604ee9, 39f3de6) + ajustes da revisão S7 (814b722); escopo 0078 verde, suíte completa 1180/6208 com 0 falhas — ver §8 |
| Validação (fase 3) | Pendente — **fase do usuário; ao fim da fase 2, PARAR e aguardar** |

---

## 1. Objetivo

Portar o **resíduo da batalha** dos protótipos `open-design/battle.html` (30KB), `battle-end-states.html` (30KB) e `battle-results-desktop.html` (17KB) — **nunca portados** — para o **fim de `battle.erb`** (`result`/`rewards`/`ctas`: `res-screen`/`state-card`/mini-arena) em **fidelidade híbrida** (adaptação preservando o htmx onde há legado 0074/0076, cópia mais literal onde não há legado), com `BattleService.resolve` (`lib/battle_service.rb:407-420`) / `finish_effects` (`:449-457`) e `expose_battle_result` (`server.rb:1015-1022`) como **leitura apenas**.

## 2. Contexto (estado atual — diagnóstico)

- **0076 Done** (onda open-design fechada, baseline **1057/4900**, lint 0): `battle.erb` tem `result`/`rewards`/`ctas` no ODS; **falta** `res-screen`/`state-card`/mini-arena dos protótipos de fim de batalha (preparado/andamento cobertos na 0074, **fim/game-over nunca portados**: `battle-end-states.html` + `battle-results-desktop.html`).
- **Leitura apenas:** `BattleService.resolve` (`:407-420`) + `finish_effects` (`:449-457`) e `ServerBattleActions.expose_battle_result` (`:1015-1022`) — o fim de batalha só **lê** o resultado exposto; sem mudar motor/economia/XP.
- **CSS:** `public/style.css` (35KB) tem o bloco ODS com seções por sessão; **CSS novo entra ANTES da linha `fim`**, com delimitador próprio `0078` (edição paralela sem conflito com 0077/0079).
- **⚠️ `public/style.css` está DIRTY no git** (diff grande, ~1129+/1003- — verificado no refinamento): o implementador deve **conferir/stash antes de editar o CSS** (`git diff -- public/style.css`, `git stash push -- public/style.css` se for trabalho alheio) e **NÃO commitar `style.css` junto sem revisar**.
- **Fila (deslizamento, seção 5):** 0077 home → **0078 battle** → 0079 history → 0080 escritas atômicas → 0081 CSRF → 0082 respiro.

## 3. Escopo

### Produção

- **Views (re-marcar, htmx/contratos preservados):** fim de `battle.erb` (+`res-screen`/`state-card`/mini-arena cobrindo vitória/derrota/empate/game-over) + fim de `_fighter_panel.erb` (o que o end-state exigir); `#battle-view` (swap de `POST /battle/play`/`/battle/new`), `data-side`, juice 0063/0074 e `data-od-id` 0076 intactos.
- **`public/style.css` (só dentro do bloco ODS, ANTES da linha `fim`, com delimitador próprio `0078`):** classes dos 3 protótipos aplicáveis ao fim de batalha, aditivas.
- **Backend thin listado (sem migração/schema/gems/services; `resolve`/`finish_effects`/`expose_battle_result` só leitura):** ajustes só no que o markup novo exigir para exibir o resultado já exposto (ex.: flag/rotulo de estado final); **nenhuma mudança de motor, economia, XP ou ordem de efeitos**.

### Testes

- **Novo:** `test/battle_end_states_test.rb` (C1–C2: `test_battle_end_states`, `test_results_desktop`).
- **Estender (cirúrgico):** `test/design_system_test.rb` (classes 0078 no bloco), `test/battle_view_test.rb` (fim de batalha), `test/battle_routes_test.rb` (asserts de fim/game-over já existentes, só se quebrar — meta: verde sem edição).

### Fora de escopo (não abrir — RNF-04)

- Home (0077); history (0079); motor de batalha (`BattleEngine`), economia/XP, `resolve`/`finish_effects` (leitura apenas); identidade `?as=`, CSRF, escritas atômicas → 0080/0081; erro-status, respiro → 0082; CD.

## 4. Critérios de aceite

### Resultado (S1 — cada critério aponta o teste que o prova)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| C1 end-states: fim de `battle.erb` com `res-screen`/`state-card` cobrindo vitória/derrota/empate/game-over (CTAs Novo confronto/Center/Mart + restart game-over intactos) | `test/battle_end_states_test.rb` `test_battle_end_states`, `test_battle_end_states_defeat`, `test_battle_end_states_draw`, `test_battle_end_states_game_over`, `test_lost_follows_fainted_not_rounded_hp` + `test/battle_routes_test.rb` (fim/game-over) | verde (fase 2) |
| C2 **reescrito na revisão S7**: mini-arena + `rewards` (XP/dinheiro) dentro de `.result-card`, no padrão `battle-end-states.html`; header único (`state-pill`) sem a variante `res-top`; juice/`data-side`/`#battle-view` preservados | `test/battle_end_states_test.rb` `test_results_card_rewards` (substitui `test_results_desktop`) | verde (fase 2 + revisão S7) |
| C3 CSS 0078 no bloco: classes do protótipo `battle-end-states.html` aplicáveis ao fim de batalha, aditivas, ANTES da linha `fim`, com delimitador próprio `0078` | `test/design_system_test.rb` `test_design_system_battle_end_states_classes` (classes + assert do delimitador `0078` + ausência de regra órfã) | verde (fase 2) |

### Garantias

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| G1 sem regressão — suíte completa + lint 0; `style.css` DIRTY conferido/stash antes de editar (não commitar alheio) | `./scripts/test` + `./scripts/lint` + `git status -- public/style.css` | verde — suíte completa **1180 runs/6208 assertions/0 falhas** e lint **0 offenses** (medido em 2026-09-16, HEAD `814b722`); escopo 0078 sem falhas (as "8 falhas alheias" registradas na fase 2 eram do dirty da 0077 e **não se reproduzem** no HEAD — ver §8) |
| G2 backend só no listado (§3) — `resolve`/`finish_effects`/`expose_battle_result` intocados (leitura); sem migração/schema/gems/services; testes sem rede | `git diff -- lib/battle_service.rb` vazio (ou só leitura) + `git diff --stat -- db/ Gemfile*` vazio + revisão S7 confere | verde (fase 2: `git diff --stat -- db/ Gemfile*` vazio; `server.rb` intocado) |
| G3 S4/S5 + revisão — `SESSIONS.md` + `check_docs` + `checar-sessao 0078` verdes; revisor S7 `Aprovado` antes da 3 | `./scripts/check_docs` + `./scripts/checar-sessao 0078` + veredito do Revisor | parcial (docs verdes; Revisor pendente) |

### Manual

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| M1 fim de batalha no navegador (vitória/derrota/empate/game-over + rewards + CTAs, ≤920px sem overflow-x) | `manual` (`./scripts/run`, `/battle` até o fim) | pendente |

> **S1:** cada critério acima aponta o teste que o prova (arquivo + método); o único critério puramente manual é **M1**. **Ao fim da fase 2 (suíte + lint verdes, revisor S7 `Aprovado`), PARAR e aguardar a validação do usuário — não marcar Done, não preencher a seção 7, não commitar conclusão.**
>
> **S3 — alteração de critério na revisão S7 (2026-09-16):** C2 era "mini-arena + `rewards` no padrão `battle-results-desktop.html`" e C3 citava "os 3 protótipos". Como os dois protótipos de fim são **variantes alternativas** (não composição), a variante `res-top`/`state-title` do `battle-results-desktop.html` foi descartada e as células foram reescritas para o que de fato se entrega (`battle-end-states.html`); pendente de reaprovação do usuário na validação.

## 5. Decisões de refinamento (fechadas com o usuário em 2026-09-09 — prevalecem sobre o mapa)

- **Fatiamento por tela (escolhida):** 0078 = battle (inclui os 2 protótipos de fim nunca portados).
- **Deslizamento (escolhida):** resíduo vira 0077-0079; antigas 0077 escritas atômicas→**0080**, 0078 CSRF→**0081**, 0079 respiro→**0082**.
- **Fidelidade híbrida (escolhida):** adaptação preservando htmx onde há legado (0074/0076), cópia mais literal onde não há legado (end-states/results-desktop).
- **Backend thin listado, motor só leitura (escolhida):** `resolve`/`finish_effects`/`expose_battle_result` não mudam; sem schema/gems/services.
- **S1 (escolhida):** 1 arquivo Minitest novo (`battle_end_states_test.rb`) + extensões cirúrgicas.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Termina em Revisor (2c, S7, teto 3 rodadas) → **PARAR** p/ validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (linha 0078 + "Próxima sessão") | commit `Sessao 0078: refinamento concluido — ...` (**sem** `public/style.css`, que está dirty) |
| 1 | **red→green — C3-css (bloco 0078)** — conferir/stash o dirty do `style.css`, anexar classes ANTES da linha `fim` com delimitador `0078`, estender `design_system_test.rb` | `./scripts/test test/design_system_test.rb` + suíte + lint 0; commit `Passo 1: classes battle-end-states/results-desktop no bloco ODS (delimitador 0078), aditivo` |
| 2 | **red→green — C1 (end-states)** — re-marcar fim de `battle.erb` (`res-screen`/`state-card` × 4 estados) + thin listado; criar `test/battle_end_states_test.rb` (`test_battle_end_states`) | `./scripts/test test/battle_end_states_test.rb test/battle_routes_test.rb` + suíte + lint 0; commit `Passo 2: fim de batalha no ODS (res-screen/state-card, 4 estados)` |
| 3 | **red→green — C2 (results-desktop)** — mini-arena + `rewards` no padrão desktop; `test_results_desktop` + estender `battle_view_test.rb` | `./scripts/test test/battle_end_states_test.rb test/battle_view_test.rb` + suíte + lint 0; commit `Passo 3: rewards/mini-arena no padrao results-desktop` |
| 4 | **red→green — G1/G3 (regressão + docs)** — suíte + lint 0 + `check_docs` + `checar-sessao 0078` | `./scripts/test` + `./scripts/lint` + `./scripts/check_docs` + `./scripts/checar-sessao 0078`; commit `Passo 4: regressao e docs — residuo battle fechado` |
| — | **Fase 2 concluída** → **Revisor (2c)** até `Aprovado` (teto 3, senão S3) → **PARAR**, aguardar **validação 3**. Não marcar Done, não preencher §7, não commitar conclusão. | — |

## 7. Validação (executada pelo usuário — S2)

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 (end-states 4 estados) | | | pendente |
| C2 (results-desktop) | | | pendente |
| C3 (CSS 0078 no bloco) | | | pendente |
| G1 (sem regressão) | | | pendente |
| G2 (backend listado/motor leitura) | | | pendente |
| G3 (docs + revisão) | | | pendente |
| M1 (fim de batalha visual) | — | | pendente |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.

## 8. Observações

- **Rodada de correção da revisão S7 (2026-09-16) — commit `814b722`:** endereça os achados 2M/5B do `reviews/review-2026-09-16T20-25-33-0078.md`. (A-1, decisão de composição) os dois protótipos de fim são **variantes alternativas**: ficou só a `state-card` do `battle-end-states.html` (com seu `state-head` + pill, `mini-arena`, `result-card` com rewards/CTAs) e a `res-top`/`state-title` do `battle-results-desktop.html` foi removida — `reviews`/M1 julgavam os dois blocos juntos como duplicata visível. (A-2) `rewards` ficam dentro do `.result-card` (posição do `battle-end-states.html`), o assert vacuoso virou ancorado no elemento (`test_results_card_rewards`) e as regras `.state-title*` saíram por não ter consumidor. (A-3) 7 regras órfãs removidas do bloco 0078 (`.res-top`, `.res-top-left`, `.res-top .ctas`, `.state-title h2/.rewards/.rewards strong`, `.side-title`); o bloco segue aditivo e dentro do delimitador. (A-4) `frow.lost` passou a derivar de `poke.fainted?` (hp 1/300 arredondava para 0% e marcava derrotado sem estar caído). (A-5) C1 cita os 4 métodos de estado; C3 ganhou assert do delimitador `/* === Battle 1:1 (0078)`. (A-6) Status/G1 atualizados para a árvore atual: **suíte completa 1180/6208/0 falhas + lint 0** (as "8 falhas alheias" da fase 2 eram do dirty da 0077 e não reproduzem no HEAD). (A-7) os 6 asserts duplicados do Passo 3 (`4604ee9`, que só tocou teste — o C2 de produção saiu no Passo 2 `924e5b6`) foram removidos de `test/battle_view_test.rb`; a cobertura vive em `test/battle_end_states_test.rb`.
- **`public/style.css` DIRTY (~1129+/1003-):** conferir/stash antes de editar; nunca commitar junto sem revisar (Passo 1).
- **Fase 2 executada em 2026-09-09 (paralelismo com 0077/0079):** o dirty do `style.css` era reformat espaços→tabs do lint universal (sem mudança funcional) — conferido via `git diff`, bloco 0078 anexado antes da linha `fim` e commitado no Passo 1; o bloco `Home 1:1 (0077)` entrou depois no working tree (não commitado por esta sessão).
- **Suíte total 1070/5088 com 8 falhas fora de escopo:** todas em `test/team_routes_test.rb` (7) + `test/mart_routes_test.rb` (1), que renderizam `views/_center.erb`/`views/_mart.erb` — arquivos dirty da 0077 em meio ao red dela (markup novo `heal-list`/`heal-item` vs. asserts antigos). Nenhuma falha em battle/design/history; escopo 0078 100% verde. Não tocar nesses arquivos (RNF-04, escopo 0077).
- **DB de teste compartilhado (`pokedex_test`) + suítes paralelas = cross-talk:** durante a fase 2, duas suítes paralelas truncavam/preenchiam as mesmas tabelas — sintomas: `PG::TRDeadlockDetected` no TRUNCATE, `DuplicateError`/`TeamFullError` no `fill_team` do setup, e "battle did not finish" (time esvaziado no meio do teste). Resolveu esperando as suítes paralelas terminarem; reruns limpos passaram.
- **`resolve` em engine já finalizada é seguro:** `BattleService.resolve` (`lib/battle_service.rb:407-420`) sai do loop imediatamente e retorna payload com news vazio — padrão para forjar derrota/empate/game-over nos testes (`battles.set` + `POST /battle/play`).
- **`@engine.winner` pode ser `nil` (empate, ambos zerados):** o markup antigo (`winner.zero?`) estouraria; o novo deriva `end_state` com `nil` → `draw` (pill `state-pill draw` nova, única regra CSS fora dos protótipos).
- **Fragmento battle (`layout: false`) não contém `#battle-view`:** só `hx-target="#battle-view"` — asserção corrigida no `test_results_desktop`.
- **Lint:** 0 offenses no escopo (`test/`, `server.rb`, `lib/`); 19 offenses pré-existentes em `scripts/sweep-balance.rb` (commit `14588c4`, fora de escopo, não tocar).
- **`resolve`/`finish_effects`/`expose_battle_result` são leitura:** qualquer necessidade de mudar o motor vira anotação (RNF-04), não escopo.
- **Fila:** 0077 home → 0078 battle → **0079 history** → 0080 escritas atômicas → 0081 CSRF → 0082 respiro.

## 9. Gotchas / Lições (memória — S6, preencher na 3)

- **Suítes paralelas no mesmo `pokedex_test` corrompem umas às outras** (deadlock no TRUNCATE, duplicatas no setup, batalha que "não termina"). Em paralelismo com outras sessões, rodar a suíte só quando as paralelas terminarem — ou aceitar reruns. (gotchas/paralelismo-suite-compartilhada)
- **`BattleService.resolve` com engine finalizada retorna payload com news vazio** — forjar end-states em teste = `battles.set(engine finalizada)` + `POST /battle/play`. Sem backend, sem stub extra.
- **`winner` nil = empate é real no motor** (`BattleEngine#winner` retorna nil com ambos zerados); view antiga assumia não-nil. Qualquer markup de fim de batalha precisa do ramo draw.
- **Fragmento htmx (`layout: false`) não tem o alvo `#battle-view`** — assert de contrato htmx em fragmento usa `hx-target`, nunca `id`.
- **VCR grava cassettes por classe de teste** (`test/cassettes/BattleEndStatesTest/`, ~570KB cada — type-effectiveness via API no `resolve`); convenção do repo é commitar.
