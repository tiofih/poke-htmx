# Sessão 0086 — battle-log-legível + juice-polish (log por rodada, reduced-motion, consumo/recompensa visível)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — roteamento confirmado em 2026-09-10 (CSS-only + texto; sem engine/economia; base T18 sketch + T20 playtest a11y: newest-first inicial, flip p/ chronological em S3 2026-09-11, reduced-motion por último) |
| Implementação (fase 2, TDD) | **Concluída** — Passos 1–32 verdes (suíte 1171 runs / 0 failures; lint 0 offenses); validada em 2026-09-14 |
| Validação (fase 3) | **Concluída** — fase 3 (usuário) em 2026-09-14: aprovação em bloco ("mas está validado"), nenhum critério `nok`; C1–C15 + G1 → `ok` (§7) |

---

## 1. Objetivo

Log de batalha legível por rodada (chronological R1 no topo, cabeçalho de round + âncoras) + polish do juice CSS-only (fix `prefers-reduced-motion` por último) + consumo/recompensa visível em texto — **sem tocar engine, economia, regras, rotas, nem migrações**.

## 2. Contexto (estado atual — diagnóstico)

- `views/battle.erb` — log renderiza do último round para o primeiro com `--log-delay` inverso (0069/0063); sem cabeçalho de rodada, leitura confusa (playtest-0063 hardcore §leitura).
- `public/style.css` — bloco `@media (prefers-reduced-motion: reduce)` em L301-316, **antes** das regras de juice (L328+) → mesma especificidade, regra posterior vence, `animation: none` sobrescrito; só `.battle-log__entry` desliga (playtest-0063 achado crítico).
- Consumo de itens em batalha opaco: só badge "já usou item", sem "usou 1 Poção (restam N)" (playtest-0063 🟡5).
- Recompensa-na-derrota confusa: "Vencedor: Oponente" seguido de "ganhou 20 XP e 40" lendo como vitória (playtest-0063 🟡6).
- Base: 0016 (texto C1), 0063 (juice CSS-only validado), 0069 (stagger `--log-delay`); T18 sketch define marcação alvo.

## 3. Escopo

### Produção (CSS + texto-only)

- **`views/battle.erb` (+ `_fighter_panel.erb` mínimo)** — cabeçalho por rodada (`data-round`), ordem chronological R1 no topo, âncoras de round; texto de consumo ("usou 1 X — restam N") e de recompensa ("participação: +N XP / +N◒" vs vitória) só via strings/kinds existentes.
- **`public/style.css` (bloco ODS, delimitador `0086`)** — polish do juice + fix reduced-motion **por último** (mover media query para o fim ou `!important`/especificidade, sem quebrar `battle-log-in` da 0069).
- **Presenters existentes** (`battle_log`/`juice`) — só leitura/formatação para expor round/consumo já presente no entry; sem mudar shape do log nem motor.

### Testes

- Presenter tests (log/juice) + style test + e2e por critério (ver §4); regressão: suíte completa + lint.

### Fora de escopo (não abrir)

- Engine (`BattleEngine#battle`), economia/XP/dinheiro valores, regras/gate, rotas/verbos/CSRF, migrações/schema/gems, JS/polling/SSE, projétil <900px (D5 A da 0063 mantido).

## 4. Critérios de aceite

### Resultado (S1 — cada critério aponta o teste que o prova)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| C1 log legível por rodada: cabeçalho de round + `data-round`, chronological R1 no topo, cada entrada associada à sua rodada | `test/battle_log_presenter_test.rb` `test_entries_grouped_by_round_chronological` (novo) + `e2e/specs/battle-log.spec.ts` `round headers chronological` (novo) | pendente |
| C2 juice CSS-only + reduced-motion: keyframes/polish só em CSS; `prefers-reduced-motion: reduce` desliga **todos** os juice (media query por último) | `test/style_responsive_test.rb` `test_juice_reduced_motion_disables_all` (novo; lê CSS) + e2e `reduced-motion disables juice` | pendente |
| C3 consumo/recompensa visível: texto "usou 1 X (restam N)" + distinção participação vs vitória, sem mudar valores | `test/battle_log_presenter_test.rb` `test_item_entries_with_stock_expose_remaining_and_last_unit` + `test_item_entry_without_stock_keeps_legacy_copy` + `e2e/specs/battle-log.spec.ts` `consumption and reward copy` | pendente |
| C4 pacing tiered CSS-only: reveal por linha R1–3=1s, R4–9=0.5s, R10+=0.2s via `--log-delay` por índice + botão "Pular" (desliga animação) | `test/style_responsive_test.rb` `test_log_tiered_pacing_delays` (novo; lê CSS: tiers + skip) + view test `data-log-index`/botão Pular + e2e `tiered pacing + skip` | pendente |
| C5 effect-sync + result-modal: efeitos sincronizados por linha (line→effect→line via `--step-delay`) + resultado como modal após log total (gated `--log-total`) | `test/style_responsive_test.rb` `test_effect_sync_step_delay` (novo; lê CSS: `--step-delay`) + view test `result modal gated --log-total` + e2e `effect sync + result modal` | pendente |
| C6 módulos por aspecto + toggles: log/fx/chip/modal modularizados por aspecto + toggles `data-jx` (aggregates OFF, log/fx/chip/modal timed) | `test/battle_log_presenter_test.rb` `test_per_aspect_modules_with_toggles` (novo) + `test/style_responsive_test.rb` `test_aggregates_off_per_aspect_timed` (novo; lê CSS) + view test `data-jx` + e2e `per-aspect toggles` | pendente |
| C7 rounds passo-a-passo no servidor + toggle JOGAR-AUTO: cada "Próxima rodada" avança 1 round via servidor (`POST advance`); JOGAR-AUTO ligado encadeia `advance` via `HX-Trigger` até `finished`; stagger cumulativo CSS (C2/C4) vira dead path p/ rounds frescos (só legado/carga inicial) | `test/battle_advance_test.rb` `test_advance_steps_single_round_until_finished` (novo; 1 round por POST) + `test/battle_advance_test.rb` `test_auto_toggle_chains_advance_via_hx_trigger` (novo; header `HX-Trigger`) + e2e `stepped rounds + auto toggle` | pendente |
| C8 strike-flow append-only: ordem Batalhar>golpe>linha>efeito>HP>modal (pedra fundamental §5, 1 strike=1 linha, append-only, sem reordenar); `#battle-log` sempre renderizado (mesmo vazio, T145) | `test/battle_advance_test.rb` `test_strike_appends_single_line_in_order` (novo; golpe>linha>efeito>HP) + view test `#battle-log` presente vazio + e2e `strike flow append-only` | pendente |
| C9 projétil direcional atacante→alvo: `.shot` do atacante viaja em direção à coluna inimiga (teto: direcional por `data-side`, sem ponto-a-ponto), gated por `data-jx-shot` | `test/style_responsive_test.rb` `test_shot_travels_attacker_to_target_directional` (novo; lê CSS: travel por `data-side` 0/1 + gate `data-jx-shot`) + `e2e/specs/battle-log.spec.ts` `shot direction matches attacker side` (novo; direção/ordem) | pendente |
| C10 shake no card do alvo: só o lutador atingido treme, gated por `data-jx-shake` (NÃO a arena inteira) | `test/style_responsive_test.rb` `test_shake_hits_target_card_not_arena` (novo; lê CSS: regra por-lutador, arena fora) + `test/battle_strike_routes_test.rb` `test_strike_shake_gate_emitted_on_damage` (novo; gate já emitido em `server.rb:1125`, sem server change) | pendente |
| C11 cor por tipo de golpe: `data-move-type` na entrada, 18 tipos mapeados para a paleta `--t-*` existente + fallback | `test/battle_log_presenter_test.rb` `test_outcome_fields_exposes_move_type` (novo; `outcome_fields` expõe `move_type` do entry bruto) + `test/battle_view_test.rb` `test_battle_log_entries_carry_move_type` (novo; `data-move-type` nos dois renders) + `test/style_responsive_test.rb` `test_move_type_colors_map_to_type_palette` (novo; lê CSS: 18 + fallback) | pendente |
| C12 contrato de extensibilidade: `data-move-type` + `data-strategy` (default `"strike"`), vars `--fx-color` / `--fx-travel` / `--fx-shake` | `test/battle_view_test.rb` `test_battle_log_entries_carry_strategy_default_strike` (novo; default `"strike"`) + `test/style_responsive_test.rb` `test_fx_contract_vars_declared` (novo; lê CSS: 3 vars) | pendente |
| C13 sync efeito/pacing: efeito sincronizado com a entrada que o dispara (`--log-delay`); shake no instante do impacto | `test/style_responsive_test.rb` `test_shake_synced_to_impact_instant` (novo; lê CSS: delay do shake = impacto) + e2e `battle-log.spec.ts` ordem chronological existente (C1; direção/ordem) | pendente |
| C14 reduced-motion cobre os novos seletores: bloco final `!important` continua sendo a ÚLTIMA regra do stylesheet e desliga travel/shake | `test/style_responsive_test.rb` `test_reduce_covers_new_fx_selectors_last` (novo; lê CSS: bloco final é o último + cobre novos seletores) + e2e `reduced-motion disables juice` (probe `animationName === 'none'`) | pendente |
| C15 <900px flash-only: sem travel abaixo de 900px (flash no alvo, D5 0063 mantido) | `test/style_responsive_test.rb` `test_shot_travel_disabled_below_900px` (novo; lê CSS: travel só em `@media (min-width: 900px)`) | pendente |

### Garantias

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| G1 sem regressão engine: suíte completa + lint 0; `git diff --stat -- lib/battle_engine.rb lib/battle_service.rb db/` só formatação/texto, sem lógica; `lib/battle_engine.rb` / `lib/battle_service.rb` / `db/` seguem proibidos (toque aprovado só em `lib/battle_log_presenter.rb` p/ expor `move_type`, C11) | `./scripts/test` + `./scripts/lint` | pendente |

> **S1:** cada critério acima aponta o teste que o prova (arquivo + método). **Ao fim da fase 2 (suíte + lint verdes, revisor S7 `Aprovado`), PARAR e aguardar a validação do usuário — não marcar Done, não preencher a seção 7, não commitar conclusão.**

## 5. Decisões de refinamento (fechadas, sem reabrir)

- **PEDRA FUNDAMENTAL do looping de batalha (decreto usuário 2026-09-12, append-only — não reordenar, não reinterpretar):**
  1. click Batalhar
  2. engine calcula o strike
  3. strike acontece
  4. linha aparece (1 strike = 1 linha, primitiva per-strike)
  5. efeito renderiza
  6. HP do atacado baixa
  7. próximo atacante
  8. ... repete até vencedor
  9. result modal
- T139 design + T140 stepper em voo pressupõem esta ordem; C1/C4/C5/C7 lêem-se contra ela.

- **Efeito atacante→alvo + shake no alvo + cor por tipo (S3 2026-09-12, aprovado — teto direcional, sem ponto-a-ponto):**
  - **D1:** reusa o `.shot` EXISTENTE do atacante (`.fighter.is-attacking .shot`, `public/style.css:995-1022`); travel = alongar seu `translateX` em direção à coluna inimiga.
  - **D2:** dois keyframes (ltr/rtl) selecionados pelo `data-side` do atacante (0 = coluna esquerda, 1 = coluna direita); a entrada do log já carrega `data-from-side` / `data-to-side`.
  - **D3:** hoje `[data-jx-shake]` só treme a `.arena` inteira (`style.css:2362-2365`); a regra por-lutador é o trabalho novo. O gate JÁ é emitido no dano (`server.rb:1125`) — sem server change.
  - **D4:** `lib/battle_log_presenter.rb:62-64` (`outcome_fields`) derruba o tipo; o entry bruto sempre tem `move_type` (`lib/battle_engine.rb:97`). Expõe em `outcome_fields` e renderiza `data-move-type` nos DOIS caminhos (`views/battle.erb:195-199` inicial e `views/_strike_log_entry.erb` OOB).
  - **Cor:** ALL 18 tipos reusando as MESMAS cores das tags existentes (vars `--t-*`, `public/style.css:19-36`) + fallback; gancho `data-strategy` incluído com default `"strike"`.

- **Chronological (S3 2026-09-11, flip de newest-first):** newest-first lia de trás-para-frente com pacing (report usuário 2026-09-11) → R1 no topo; legibilidade vem de cabeçalho/âncora por rodada em ordem de leitura (T114).
- **Reduced-motion por último:** fix de cascata (mover bloco para o fim / `!important`) é o último passo CSS para não mascarar regressão visual.
- **CSS-only + texto:** C2 sem JS; C3 sem mudar valores de economia — só copy a partir de dados já presentes.
- **T18 sketch** define a marcação alvo (`data-round`, classes de juice); esta sessão só executa.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Termina em Revisor (2c, S7, teto 3 rodadas) → **PARAR** p/ validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo (sem `SESSIONS.md`/backlog/commit, por ordem da tarefa) | arquivo criado em `sessions/0086-battle-log-juice.md` |
| 1 | **red→green — C1 (log por rodada)** — cabeçalhos + `data-round`, chronological R1 no topo; novos testes presenter + e2e | `./scripts/test test/battle_log_presenter_test.rb` + e2e log spec + lint 0; commit `Passo 1: log legivel por rodada` |
| 2 | **red→green — C3 (consumo/recompensa)** — copy de consumo + participação vs vitória; novos testes juice + e2e | `./scripts/test test/battle_juice_presenter_test.rb` + e2e + lint 0; commit `Passo 2: consumo e recompensa visiveis` |
| 3 | **red→green — C2 (juice + reduced-motion last)** — polish CSS bloco `0086` + media query por último; novo style test + e2e | `./scripts/test test/style_responsive_test.rb` + e2e + lint 0; commit `Passo 3: juice polish + reduced-motion` |
| 4 | **red→green — G1 (regressão)** — suíte + lint 0 + diff de engine vazio | `./scripts/test` + `./scripts/lint`; commit `Passo 4: regressao — log/juice sem tocar engine` |
| 23 | **red→green — C11/C12 (tipo exposto)** — `outcome_fields` expõe `move_type` + `data-move-type`/`data-strategy="strike"` nos dois renders (`battle.erb` + `_strike_log_entry.erb`); novos testes presenter + view (S3 2026-09-12) | `./scripts/test test/battle_log_presenter_test.rb test/battle_view_test.rb` + lint 0; commit `Passo 23: move-type e strategy no log` |
| 24 | **red→green — C9 + C15 (projétil direcional, flash-only <900px)** — travel do `.shot` por `data-side` (2 keyframes ltr/rtl, gated `data-jx-shot`), travel SÓ em `@media (min-width: 900px)`; novo style test + e2e direção | `./scripts/test test/style_responsive_test.rb` + e2e + lint 0; commit `Passo 24: projetil direcional atacante-alvo` |
| 25 | **red→green — C10 (shake no alvo)** — regra por-lutador gated `data-jx-shake` (arena fora); novo style test + routes test do gate | `./scripts/test test/style_responsive_test.rb test/battle_strike_routes_test.rb` + lint 0; commit `Passo 25: shake no card do alvo` |
| 26 | **red→green — C11/C12 (cor + contrato)** — 18 tipos → paleta `--t-*` + fallback, vars `--fx-color`/`--fx-travel`/`--fx-shake`; novos style tests | `./scripts/test test/style_responsive_test.rb` + lint 0; commit `Passo 26: cor por tipo e vars de fx` |
| 27 | **red→green — C13/C14 (sync + reduce)** — shake no instante do impacto (`--log-delay`); reduce final `!important` ÚLTIMA regra cobrindo os novos seletores; novos style tests + probe e2e | `./scripts/test test/style_responsive_test.rb` + e2e + lint 0; commit `Passo 27: sync de impacto e reduce final` |
| 28 | **red→green — G1 (regressão)** — suíte + lint 0 + diff de engine/service/db vazio | `./scripts/test` + `./scripts/lint`; commit `Passo 28: regressao — fx sem tocar engine` |
| 29 | **red→green — C11 (cor do tipo no projétil)** — `data-move-type` alcança o `.shot` pelo carrier `#jx-gates` (`.arena:has(> #jx-gates[data-move-type=…])`) | `./scripts/test test/style_responsive_test.rb test/battle_strike_routes_test.rb test/battle_view_test.rb` + lint 0; commit `9254ba4 Passo 29` |
| 30 | **red→green — C3 (copy de consumo)** — copy `"usou 1 X — restam N"` prevalece sobre a asserção legada (S3 2026-09-14, §7); doc + 2 asserções | `./scripts/test test/battle_strategy_routes_test.rb` + lint 0; commit `287743f Passo 30` |
| 31 | **red→green — #play-btn pós-modal** — fim de batalha re-troca o botão por cópia `disabled` via `hx-swap-oob="outerHTML"` | `./scripts/test test/battle_strike_routes_test.rb` + lint 0; commit `6fb9322 Passo 31` |
| 32 | **red→green — C11 (major do review round 12)** — `--fx-color` do carrier volta a vencer em `.log__entry .fx` via seletor de atributo | `./scripts/test test/style_responsive_test.rb` + lint 0; commit `147ad98 Passo 32` |
| — | **Fase 2 concluída** — Revisor (2c) até o **round 12** (`Requer ajuste`: 1 major + 3 minors, ver §7); major corrigido no Passo 32, minors no commit de doc/comentário → **PARAR**, aguardar **validação do usuário**. | — |

## 7. Validação (executada pelo usuário — S2)

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 (log por rodada) | `battle_log_presenter_test.rb` `test_entries_grouped_by_round_chronological` + e2e `battle-log.spec.ts` `round headers chronological` | Validação do usuário em 2026-09-14 | ok |
| C2 (juice + reduced-motion) | `style_responsive_test.rb` `test_juice_reduced_motion_disables_all` + e2e `reduced-motion disables juice` | Validação do usuário em 2026-09-14 | ok |
| C3 (consumo/recompensa) | `battle_log_presenter_test.rb` `test_item_entries_with_stock_expose_remaining_and_last_unit` + `test_item_entry_without_stock_keeps_legacy_copy` + e2e `consumption and reward copy` | Validação do usuário em 2026-09-14 | ok |
| C4 (pacing tiered + Pular) | `style_responsive_test.rb` `test_log_tiered_pacing_delays` + view `data-log-index`/botão Pular + e2e `tiered pacing + skip` | Validação do usuário em 2026-09-14 | ok |
| C5 (effect-sync + result-modal) | `style_responsive_test.rb` `test_effect_sync_step_delay` + view `result modal gated --log-total` + e2e `effect sync + result modal` | Validação do usuário em 2026-09-14 | ok |
| C6 (módulos por aspecto + toggles) | `battle_log_presenter_test.rb` `test_per_aspect_modules_with_toggles` + `style_responsive_test.rb` `test_aggregates_off_per_aspect_timed` + view `data-jx` + e2e `per-aspect toggles` | Validação do usuário em 2026-09-14 | ok |
| C7 (rounds servidor + AUTO) | `battle_advance_test.rb` `test_advance_steps_single_round_until_finished` + `test_auto_toggle_chains_advance_via_hx_trigger` + e2e `stepped rounds + auto toggle` | Validação do usuário em 2026-09-14 | ok |
| C8 (strike-flow append-only) | `battle_advance_test.rb` `test_strike_appends_single_line_in_order` + view `#battle-log` presente e vazio + e2e `strike flow append-only` | Validação do usuário em 2026-09-14 | ok |
| C9 (projétil direcional) | `style_responsive_test.rb` `test_shot_travels_attacker_to_target_directional` + e2e `shot direction matches attacker side` | Validação do usuário em 2026-09-14 | ok |
| C10 (shake no alvo) | `style_responsive_test.rb` `test_shake_hits_target_card_not_arena` + `battle_strike_routes_test.rb` `test_strike_shake_gate_emitted_on_damage` | Validação do usuário em 2026-09-14 | ok |
| C11 (cor por tipo) | `battle_log_presenter_test.rb` `test_outcome_fields_exposes_move_type` + `battle_view_test.rb` `test_battle_log_entries_carry_move_type` + `style_responsive_test.rb` `test_move_type_colors_map_to_type_palette` | Validação do usuário em 2026-09-14 | ok |
| C12 (contrato extensível) | `battle_view_test.rb` `test_battle_log_entries_carry_strategy_default_strike` + `style_responsive_test.rb` `test_fx_contract_vars_declared` | Validação do usuário em 2026-09-14 | ok |
| C13 (sync efeito/pacing) | `style_responsive_test.rb` `test_shake_synced_to_impact_instant` + e2e `battle-log.spec.ts` (ordem chronological) | Validação do usuário em 2026-09-14 | ok |
| C14 (reduced-motion novos seletores) | `style_responsive_test.rb` `test_reduce_covers_new_fx_selectors_last` + e2e `reduced-motion disables juice` (probe `animationName === 'none'`) | Validação do usuário em 2026-09-14 | ok |
| C15 (<900px flash-only) | `style_responsive_test.rb` `test_shot_travel_disabled_below_900px` | Validação do usuário em 2026-09-14 | ok |
| G1 (sem regressão) | `./scripts/test` (1171 runs / 6107 assertions / 0 failures) + `./scripts/lint` (136 files / 0 offenses) + `git diff --stat HEAD -- lib/battle_engine.rb lib/battle_service.rb db/` vazio | Validação do usuário em 2026-09-14 | ok |

> **Nota (2026-09-14):** a coluna **automatizada** reproduz o mapeamento critério→teste declarado em §4; a coluna **manual** registra a validação do usuário em 2026-09-14 (aprovação em bloco). Não há execução manual registrada critério a critério — os 16 resultados `ok` refletem essa aprovação única, sem evidência inventada.

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.
>
> **S3 2026-09-11 — C4 adicionado (aprovado pelo usuário):** pacing tiered line-by-line CSS-only (R1–3=1s, R4–9=0.5s, R10+=0.2s + botão Pular), implementado em c2f2c74; C1–C3 intactos.
>
> **S3 2026-09-11 — C5 adicionado (aprovado pelo usuário):** effect-sync por linha (line→effect→line via `--step-delay`, T108 4f1538c) + resultado como modal após log total (gated `--log-total`, T109 08a6d0e); C1–C4 intactos.
>
> **S3 2026-09-11 — C1 flip para chronological + modal cap + per-line fx (aprovado pelo usuário):** newest-first lia de trás-para-frente com pacing (report 2026-09-11) → chronological R1 no topo (T114 9ffeb8b); modal de resultado com cap `min(acc,3s)`; efeitos per-line via tokens `.fx` + var de arena shake (T115 aa8e2ac); C2–C5 intactos.
>
> **S3 2026-09-11 — C6 adicionado (aprovado pelo usuário):** módulos de apresentação por aspecto (log/fx/chip/modal) + toggles `data-jx` (T121 map + T122 6b00a48, aggregates OFF, log/fx/chip/modal timed); C1–C5 intactos.
>
> **S3 2026-09-11 — C7 adicionado (aprovado pelo usuário):** rounds passo-a-passo no servidor (`POST advance`, 1 round por "Próxima rodada", T129 e695cd6) + toggle JOGAR-AUTO encadeando `advance` via `HX-Trigger` até `finished` (T132 ea9de31); stagger cumulativo CSS de C2/C4 vira dead path p/ rounds frescos; C1–C6 intactos.
>
> **S3 2026-09-12 — C8 adicionado (pedra fundamental + engine touch mínimo aprovados):** strike-flow Batalhar>golpe>linha>efeito>HP>modal, append-only (§5), base T140 stepper (bb22c53) + T142 strike route (59f9f4e) + T143 botão (f83d67d) + T144 e2e (a759ff3) + T145 container sempre renderizado (041d9ed); C1–C7 intactos.
>
> **S3 2026-09-14 — C3 (copy de consumo) prevalesce sobre assert legado (autorizado pelo usuário, opção (a)):** a asserção `test/battle_strategy_routes_test.rb` `test_battle_consumes_assigned_item_and_clears_member_without_debit` esperava `"usou Pocao"` (copy legada sem o restante); alinhada à forma C3 `"usou 1 Pocao"` + `"restam 0"`. Nenhum valor/regra mudou — só a asserção (doc-only) e o texto passou a ser o do C3. C1–C15 e G1 intactos.
>
> **S3 2026-09-12 — C9–C15 adicionados (efeito atacante→alvo, shake no alvo, cor por tipo — aprovados pelo usuário):** projétil viaja do atacante em direção à coluna inimiga (teto direcional por `data-side`, sem ponto-a-ponto; D1/D2 §5) + shake SÓ no card do alvo gated `data-jx-shake` (arena fora; gate já emitido, D3) + cor por tipo (18 tipos → paleta `--t-*` + fallback; toque aprovado em `lib/battle_log_presenter.rb` p/ expor `move_type`, D4) + gancho `data-strategy` default `"strike"` + vars `--fx-color`/`--fx-travel`/`--fx-shake` + sync no impacto + reduce final segue ÚLTIMO + <900px flash-only; plano estendido em Passos 23–28 (Passo 22 em voo em paralelo, não reutilizar o número); C1–C8 intactos, G1 estendido (`battle_engine.rb`/`battle_service.rb`/`db/` proibidos).

> **S3 2026-09-14 — C11 (cor por tipo) volta ao `.log__entry .fx` + Passos 29–32 registrados:** a cor por tipo deixou o seletor de entrada e passou a ser propagada pelo carrier `#jx-gates` (`.arena:has(> #jx-gates[data-move-type=…])`, Passo 29); como `.log__entry` seguia declarando `--fx-color: var(--t-normal)`, o valor do arena ficava sombreado e o flash por linha perdia a cor — o Passo 32 devolve `--fx-color` a `.log__entry .fx` via seletor de atributo `[data-move-type="…"]`, com asserção do token por tipo. Passos 29 (projétil), 30 (copy C3 — nota acima), 31 (#play-btn desabilitado pós-modal via OOB) e 32 (fix do major) verdes. **G1 (HEAD `147ad98`):** `git diff --stat a93bdb3..HEAD -- lib/battle_engine.rb lib/battle_service.rb db/` → **vazio**; `./scripts/test` 1171 runs / 0 failures; `./scripts/lint` 0 offenses. **Revisor (2c) round 12** (`reviews/review-2026-09-14T10-08-24.md`): **Requer ajuste** — 1 major (`--fx-color` sombreado, corrigido no Passo 32 `147ad98`) + 3 minors (registro C11/Passos 29–31 e sync do doc; comentário falso do `delete` em `views/_strike_result.erb:3`), corrigidos neste commit de doc/comentário. C1–C15 e G1 intactos.

> **Validação 2026-09-14 (fase 3 — executada pelo usuário, S2):** o usuário **validou a sessão 0086 em 2026-09-14** com **aprovação em bloco** ("mas está validado"); **nenhum critério marcado `nok`**. Todos os 16 critérios (**C1–C15 + G1**) → **`ok`** (§7). **Implicitamente aceitos nesta validação:** (1) a mudança de asserção do **C3** — `"usou 1 Pocao"` + `"restam 0"` passando a prevalecer sobre a asserção legada (S3 2026-09-14, nota preservada acima) — e (2) a mudança de caminho do **C11** — cor por tipo propagada pelo carrier `#jx-gates` (Passos 29→32). Evidência de suporte: `./scripts/test` **1171 runs / 6107 assertions / 0 failures**; `./scripts/lint` **136 files / 0 offenses**; G1 diff (`lib/battle_engine.rb`, `lib/battle_service.rb`, `db/`) **vazio**; review `reviews/review-2026-09-14T10-24-59.md` **Aprovado**; commits `9254ba4`/`287743f`/`6fb9322`/`147ad98` (+ doc `39b42eb`, draft `d7a7c1e`).

> **S3 2026-09-14 — review retroativo dos Passos 21–28 (`Aprovado`) e remissão do timing do C13:** foi persistido o review retroativo de `a93bdb3..9254ba4` (Passos 21–28), veredito **`Aprovado`** (0 blocker / 1 major / 4 minor / 2 info) — `reviews/review-2026-09-14T11-56-30-retroativo-passos21-28.md`. O major é de **timing**: `--fx-shake` é constante `0s` e o shake do card dispara no `t=0` do swap, ~0,55s **antes** do impacto (o projétil tem `0.15s` de delay + `0.4s` de travel — `public/style.css:2461`), enquanto o teste de C13 só prova a **presença** do token `animation-delay: var(--fx-shake)` (`test/style_responsive_test.rb:384-393`). **C12/C13/C15 mantêm o `ok` da validação do usuário (2026-09-14)** — que foi em bloco, sem nenhum `nok`, e **NÃO é reaberta**; o `ok` repousa em evidência de presença (token/regra/ordem), não em prova de sincronia temporal. O ajuste de timing do C13 fica **remetido ao `TODO.md` T5** (shake no instante do impacto + teste que falha se o timing regredir); as dívidas menores do review (C12 `--fx-*`/`data-strategy` inerte, regra legada `.arena[data-jx-shake]` que nunca casa, teste de C15 sem contenção no `@media 900px`, `--log-delay` duplicado, `strike_side_delay` inócuo) ficam em **T6**; a lacuna de registro dos Passos 5–22 no §6 segue em **T3**. As células `ok` do §7 e o bloco Status permanecem intactos.

> **S3 2026-09-14 — C13/timing do shake reaberto por ordem do usuário (T5 do `TODO.md`) e contrato de timing redefinido:** após o review retroativo de 2026-09-14 (`reviews/review-2026-09-14T11-56-30-retroativo-passos21-28.md`, Passos 21–28), o usuário reabriu o **C13** e o contrato de timing dele pela fila do `TODO.md` (**T5**). **Novo contrato de timing:** o shake do card do alvo (`--fx-shake`) dispara no instante do impacto — **`0.55s` = `0.15s` de delay + `0.4s` de travel do projétil** (regra `.shot >= 900px`). O token deixa de ser constante `0s` e passa a ser declarado na regra que **aplica** a animação (`.arena:has(> #jx-gates[data-jx-shake="on"]) .fighter.is-hit`), porque herdar do `.arena` (ancestral) só renderia `0s`; a declaração inerte `--fx-shake` no `.log__entry[data-strategy="strike"]` (que não é ancestral do hit) foi **removida** e o valor efetivo passou a viver onde a animação é aplicada. O teste `test/style_responsive_test.rb#test_shake_synced_to_impact_instant` deixa de só provar a **presença** do token: extrai o valor de `--fx-shake` e assere `--fx-shake == travel + delay` do `juice-projectile`, falhando se qualquer um dos três números sair de sincronia. As células `ok` do §7 (C12/C13/C15) permanecem intactas — a validação do usuário de 2026-09-14 **não é reaberta**; este registro apenas documenta a alteração formal de critério (S3).

> **S3 2026-09-14 — T6a (fila do `TODO.md` ordenada pelo usuário): a linha do tempo do turno vira contrato de instantes nomeados:** o usuário ordenou a fila do `TODO.md` e o **T6** foi fatiado em **T6a** (esta entrega, Passo 34) e **T6b** (dívidas de review remanescentes — seguem abertas no `TODO.md`). O T6a substitui os literais de tempo espalhados (`0.15s`/`0.4s`/`0.55s`/`0.2s`) por um **beat base + instantes nomeados** derivados no `.arena` (bloco ODS 0086): `--beat: 0.2s`, `--t-approach: 0.15s`, `--t-travel: 0.4s`, `--t-impact: calc(var(--t-approach) + var(--t-travel))`, `--t-log: var(--beat)` e `--t-hp: calc(var(--t-impact) + var(--beat))`. As regras de log/efeito passam a `animation-delay: calc(var(--t-log) + var(--log-delay, 0s))` (os degraus do C4 seguem preservados no `--log-delay` por índice, definido no Ruby), o projétil usa `var(--t-travel)`/`var(--t-approach)`, o shake lê `--fx-shake: var(--t-impact)` e o HP baixa em `--t-hp` (≥ impacto); o grupo do botão **Pular** passou a zerar também `.fighters .bar-fill`. O teste `test/style_responsive_test.rb#test_shake_synced_to_impact_instant` deixa de só provar presença/valor solto: resolve `var`/`calc` (helpers `css_time_vars`/`resolve_css_time`) e assere a **aritmética** — `impacto == approach + travel`, `impacto == delay + duração do projétil`, `shake == impacto`, `hp >= impacto` — falhando se qualquer relação sair de sincronia. **C4 e C13 mantêm o `ok` da validação do usuário (2026-09-14)**: os degraus do C4 e o instante de impacto do C13 são preservados (muda só a expressão, que vira nomeada). Este registro documenta a **alteração formal de critério (S3)** sem reabrir a validação nem tocar as células de resultado do §7. C1–C15 e G1 intactos.

> **S3 2026-09-14 — T6b-1 (Passo 35): higiene de evidência do review retroativo (CSS + testes), sem reabrir validação:** primeira fatia do T6b resolve somente as dívidas de **CSS/teste** remanescentes do review retroativo (`reviews/review-2026-09-14T11-56-30-retroativo-passos21-28.md`); `views/`/`server.rb` ficam para o T6b-2. **(1) Hooks `data-strategy` inertes:** a regra `.log__entry[data-strategy="strike"] { --fx-travel: 40vw }` foi **removida como redundante** (não movida): o único consumidor de `--fx-travel` são os keyframes `juice-shot-ltr/rtl` aplicados ao `.shot` dentro do `.arena`, que já declara `--fx-travel: 40vw` (`.arena`, bloco ODS 0086) — e o `.log__entry` não é ancestral de `.shot`/`.fighter.is-hit`, então ali o token era inerte. O contrato **C12 permanece intacto**: o gancho `data-strategy="strike"` segue nas views e a config de `--fx-*` que alcança as animações mora no `.arena` (único ancestral comum). **(2) Regra legada morta:** removida `.arena[data-jx-shake="on"] .fighter.is-hit` (antes `public/style.css:1006`) — o atributo só existe no carrier `#jx-gates` (`views/_jx_gates.erb:1`) e o `.arena` fica estaticamente `"off"` (`views/battle.erb:44`); a regra viva é `.arena:has(> #jx-gates[data-jx-shake="on"])` (C10/C13). **(3) C15 agora prova contenção no `@media 900px`:** `test/style_responsive_test.rb#test_shot_travel_disabled_below_900px` localiza a chave de abertura do bloco e casa as chaves até a de fechamento correspondente, asserindo que `animation-name: juice-shot-ltr/rtl` está **dentro** do bloco (não apenas depois da abertura) — verificado que o teste **falha (1 run / 1 failure)** ao mover a regra para fora do `@media`. **Somente evidência/cleanup:** as células de resultado do §7 e os `ok` da validação do usuário (2026-09-14) permanecem **intactos**; C1–C15 e G1 não mudam de valor. Evidência: `./scripts/test` **1171 runs / 6123 assertions / 0 failures**; `./scripts/lint` **136 files / 0 offenses**; `./scripts/check_docs` **ok**.

> **S3 2026-09-14 — T6b-2 (Passo 36): higiene de dados do review retroativo (views/server), sem reabrir validação:** segunda e última fatia do **T6b** conclui as dívidas do review retroativo (`reviews/review-2026-09-14T11-56-30-retroativo-passos21-28.md`, achado Info) sem tocar engine/regras/rotas. **(1) `--log-delay` declarado uma só vez:** a declaração autoritativa é a do `<li class="log__entry">` — `views/battle.erb:201` (delay computado por entrada: `line_delay = (group_index * 0.25 + step_delay[entry.object_id]).round(2)`, linha 193) e `views/_strike_log_entry.erb:4` (`0s`, strike toca agora) — e as duplicatas no `span.fx` filho (`battle.erb:202`, `_strike_log_entry.erb:10`) foram **removidas**: custom properties **herdam**, então o `.fx` consumido por `.arena[data-jx-fx="on"] .log__entry .fx` (`public/style.css:2021/2026/2032`) resolve exatamente o mesmo valor. Prova nos testes ajustados (`test/battle_view_test.rb#test_battle_arena_carries_step_delay_and_per_line_fx` + `test/battle_strike_routes_test.rb#test_strike_log_entry_travels_as_main_content`): a linha ancora `style="--log-delay: <d>s"` e o `.fx` **não** declara o token; o teste de degraus (`log_chunks_with_entries`) segue medindo os valores por entrada, **inalterados**. **(2) `strike_side_delay` inócuo removido:** `server.rb` computava `{0=>0.0,1=>0.0}.merge(from=>0.0,to=>0.0)` = sempre `{0=>0.0,1=>0.0}`; consumidores verificados — `strike_side_oob` → `_strike_fighters.erb` → `_fighter_panel.erb:2` (`side_delay.fetch(side, 0)` → `--step-delay`) e nenhum teste exercita o helper. O método foi removido e o caller passa a constante `{0=>0.0,1=>0.0}` direto (o parâmetro `entry` de `strike_side_oob` caiu junto); o HTML emitido `--step-delay: 0.0s` é **byte-idêntico**. **Somente higiene:** C1–C15 e G1 não mudam de valor; as células do §7 e o `ok` da validação do usuário (2026-09-14) permanecem **intactos** — nenhum comportamento validado mudou. Evidência: `./scripts/test` **1171 runs / 0 failures**; `./scripts/lint` **0 offenses**; `./scripts/check_docs` **ok**; G1 diff vazio.

## 8. Observações

- **Não tocado nesta tarefa (por ordem):** demais arquivos, commits.
- **Pendências registradas na validação de 2026-09-14 (não silenciadas):**
  - **Cobertura de review dos Passos 21–28** — não há arquivo em `reviews/` cobrindo `8542a33..5cf6c4a`; a decisão de escopo (revisar ou registrar a dispensa) segue em aberto no `TODO.md` (T2).
  - **§6 deste arquivo** — a tabela do plano lista só os Passos 0–4 e 23–32, enquanto o Status fala em 1–32; completar a tabela ou registrar a lacuna explicitamente (aberto no `TODO.md`).
  - **Working tree sujo (fora deste commit)** — churn de cassettes VCR (incl. cassette novo de ~8900 linhas), `e2e/playwright.config.ts`, `test/pokemon_routes_test.rb` e documentos untracked na raiz (`ARCHITECTURE.md`/`GDD.md`/`PROJECT.md`), `reviews/`, `gotchas/`, `public/type-effects-lab.html` — triagem pendente.
  - **§9 Gotchas** — segue "a preencher na validação (fase 3)"; as lições do ciclo foram registradas em `gotchas/0086-round7-gotchas.md` (untracked), ainda não consolidadas aqui.
- **Leitura exata antes de editar:** ERB `not_tracked` — confirmar `battle.erb`, `_fighter_panel.erb`, bloco reduced-motion em `style.css:301-316` vs juice L328+ no arquivo antes do Passo 1.
- **CSS:** só dentro do bloco ODS, ANTES da linha `fim`, com delimitador próprio `0086`; media query de reduced-motion vai **após** todas as regras de juice.
- **Metodologia reduced-motion:** validar via `getComputedStyle(...).animationName` (`none` esperado) — `document.getAnimations()` não serve (animações 0.3–0.5s terminam e voltam `[]`).

## 9. Gotchas / Lições (memória — S6)

A preencher na validação (fase 3): cascata reduced-motion vs especificidade, chronological R1-topo com cabeçalho de round, copy de participação vs vitória.
