# Sessão 0088 — Projétil slot-a-slot: saída no slot do atacante e chegada no slot do alvo (eixos x e y)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-09-15 (D1a, D2a, D3a, D4a, D5, D6a, D7a, D8) |
| Implementação (fase 2, TDD) | **Pendente** |
| Validação (fase 3) | **Pendente** (executada pelo usuário) |

---

## 1. Objetivo

O projétil de golpe deixa de viajar de uma **caixa de time** para a outra e passa a sair do **slot do pokémon atacante** e chegar ao **slot do pokémon alvo**, nos eixos x **e** y, como *progressive enhancement* sobre o rail CSS entregue e validado na 0087 (que continua sendo o fallback).

## 2. Contexto (estado atual — diagnóstico)

- **O rail de 0087 funciona e chega no eixo x**: `span.shot-track#jx-shot-track` é `absolute; inset:0; pointer-events:none`, hoje aninhado em `.battle-column[data-side="0"]` (logo `offsetParent === .arena`); o `.shot` viaja por `--fx-travel: calc(35cqi + 42px)` no keyframe `translate(calc(100% + var(--fx-travel)), 0)`. Ponto de partida é sempre a borda da **coluna**, não o slot — no eixo y o projétil não se move.
- **O índice do slot existe no engine e é descartado**: `BattleEngine::BattleActions#log_entry` (`lib/battle_engine.rb:94-104`) não serializa `attacker_index`; `#attack_action_for` (:131-138) já tem `attacker_index`/`target_team_index`, e `#target_for` (:266-269) descarta o `target_index`. **Precedente a espelhar**: `#item_action` (:127) **já loga `attacker_index`**, provado em `test/battle_engine_test.rb:356-372` e consumido em `lib/battle_service.rb:218`.
- **A ordem das `li` no DOM é o índice do time**: `views/battle.erb:59`/`:236` e `server.rb:1151-1154` (`each_with_index`). `views/_fighter_panel.erb:3` já recebe `idx`, mas emite só `data-side`/`data-od-id` — o slot não chega ao DOM real (só o índice de delay).
- **Presenters e markup**: `BattleJuicePresenter#from_side/to_side` (`lib/battle_juice_presenter.rb:41-49`); `BattleLogPresenter#format_entry` (`lib/battle_log_presenter.rb:52-60`); `views/_jx_shot.erb` emite `data-from-side`/`data-to-side`/`data-move-type`, tanto no render completo (`views/battle.erb`, região da arena ~:46-56) quanto no OOB `server.rb` `strike_shot_oob` (~:1136-1146).
- **Geometria**: `.fighters` é grid e a altura de linha vem do conteúdo (`public/style.css:639-645`), sem `grid-auto-rows`; card KO não sai do fluxo (`.fighter.fainted` = `opacity`, `:982-984`) → **índices estáveis**; as duas listas começam no mesmo Y (`align-items:start`, `:607`). CSS puro **não** deriva o Y do slot hoje.
- **`anchor()` não alimenta `transform`** → anchor positioning está descartado para animar o travel.
- **RNF-01 sem exceção registrada (ainda)**: `views/layout.erb:37-54` **já** embarca ~17 linhas de JS ligadas a eventos htmx — a afirmação do draft de que a 0088 seria "o primeiro script além do htmx" é **falsa** e será corrigida na reabertura formal (D8).
- Estado agora: entrega da 0087 validada (chegada real no eixo x); pendência registrada em `docs/draft-backlog.md:171-179`.

## 3. Escopo

### Produção

- **`lib/battle_engine.rb`** — `log_entry` (:94-104) passa a serializar `attacker_index`/`target_index` no strike entry, espelhando o precedente de `#item_action` (:127); `#target_for` (:266-269) deixa de descartar `target_index`.
- **`lib/battle_log_presenter.rb`** e **`lib/battle_juice_presenter.rb`** — expõem `from_slot`/`to_slot` com **guarda** quando a chave não existe (fakes montados à mão nos testes não têm a chave).
- **`views/_fighter_panel.erb`** — emite o slot do lutador no DOM (hoje recebe `idx` e não usa).
- **`views/_jx_shot.erb`** + **`views/battle.erb`** + **`server.rb`** (`strike_shot_oob`, ~:1136-1146) — markup carrega `data-from-slot`/`data-to-slot` nos **dois** caminhos de render.
- **`public/style.css`** — keyframe passa a `translate(calc(100% + var(--fx-travel)), var(--fx-dy))`; `--fx-dy` default `0` (fallback = rail de 0087 intacto).
- **`views/layout.erb`** — **exceção estreita e formal ao RNF-01**: um handler inline que, após o swap OOB, mede `getBoundingClientRect()` dos slots e escreve `--fx-dy` inline no `.shot`. Sem libs, sem polling, sem SSE, sem framework (precedente: `layout.erb:37-54` já tem JS de htmx).

### Testes

- `test/battle_engine_test.rb` — `test_log_entries_carry_full_action_shape_and_rounds` (:133-145) e o teste de `target_strategy` novo (C2); espelhar o precedente de item (:356-372).
- `test/move_engine_test.rb:120-130` — lista de chaves do entry (C1).
- `test/battle_log_presenter_test.rb` (:115-124, :129-146) e `test/battle_juice_presenter_test.rb` — `from_slot`/`to_slot` + guarda (C3).
- `test/battle_strike_routes_test.rb#test_strike_oob_moves_shot_into_arena_track` (:191-205) e `test/battle_routes_test.rb#test_battle_fragment_marks_juice_targets` (:312-345) — `data-from-slot`/`data-to-slot` (C4).
- `test/battle_view_test.rb#test_battle_fighter_cards_carry_side_and_step_delay` (:297-309) — slot no card (C5).
- `test/design_system_test.rb#test_design_system_battle_juice_reduced_motion` e `test/style_responsive_test.rb` — fallback/reduced motion/coluna única (C8/C9).
- `e2e/specs/battle-log.spec.ts` — teste novo medindo o par ordenado (x, y) do destino, teste sem JavaScript e teste de coluna única; o pin atual (`:248-250`, `tx≈472±2`) é reescrito como par (C6/C7/C9).

### Fora de escopo (não abrir)

- Rota CSS por índice de slot (aritmética, exigiria altura de card uniforme); anchor positioning; trocar o rail; qualquer lib/framework/JS além do handler único.

## 4. Critérios de aceite

### Resultado (S1 — cada critério aponta o teste que o prova)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| C1 o strike entry carrega os índices do atacante e do alvo | `test/battle_engine_test.rb#test_log_entries_carry_full_action_shape_and_rounds` (:133-145, hoje compara lista de chaves **e** hash exato → red esperado) + `test/move_engine_test.rb:120-130` (lista de chaves → red esperado) + espelho de `test/battle_engine_test.rb:356-372` | pendente |
| C2 a seleção de alvo (`target_strategy`) tem teste próprio, antes de confiar no `target_index` serializado | novo teste em `test/battle_engine_test.rb` | pendente |
| C3 o presenter expõe `from_slot`/`to_slot` e tolera a ausência da chave | `test/battle_log_presenter_test.rb` (:115-124 e :129-146, devem seguir verdes) + `test/battle_juice_presenter_test.rb` | pendente |
| C4 o markup do shot carrega `data-from-slot`/`data-to-slot` nos dois caminhos de render | `test/battle_strike_routes_test.rb#test_strike_oob_moves_shot_into_arena_track` (:191-205, estendido) + `test/battle_routes_test.rb#test_battle_fragment_marks_juice_targets` (:312-345) | pendente |
| C5 os cards de lutador expõem o slot | `test/battle_view_test.rb#test_battle_fighter_cards_carry_side_and_step_delay` (:297-309, estendido) | pendente |
| C6 com JS o projétil chega ao **slot do alvo** em x **e** y | `e2e/specs/battle-log.spec.ts` (teste novo medindo o par ordenado; o pin de `tx≈472±2` vira par) | pendente |
| C7 sem JS o rail CSS da 0087 continua funcionando (fallback) | `e2e/specs/battle-log.spec.ts` (novo teste com JavaScript desabilitado no contexto) | pendente |
| C8 reduced motion mantém o comportamento atual (sem regressão nova) | `test/design_system_test.rb#test_design_system_battle_juice_reduced_motion` + e2e | pendente |
| C9 coluna única (<981px) segue no-op (sem travel, sem erro de JS) | guarda e2e `arena keeps 3 in-flow columns and an out-of-flow projectile track` + `test/style_responsive_test.rb` | pendente |

### Garantias (RNF)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| G1 suíte completa (baseline 1173+ runs) + lint 0 em todo green | `./scripts/test` + `./scripts/lint` | pendente |
| G2 JS confinado ao handler único em `views/layout.erb` (sem lib/polling/SSE), registrado como exceção ao RNF-01 | `git diff --stat` + revisão de diff (`manual`) | pendente |
| G3 `DESIGN.md` respeitado (sem hex cru, sem componente paralelo) | revisão de diff (`manual`) + `test/design_system_test.rb` | pendente |

> **S1:** cada critério acima aponta o teste que o prova (arquivo + método). **Ao fim da fase 2 (suíte + lint verdes, Revisor S7 `Aprovado`), PARAR e aguardar a validação do usuário — não marcar Done, não preencher a seção 7, não commitar conclusão.**

## 5. Decisões de refinamento (fechadas com o usuário — 2026-09-15)

- **D1a — rota JS medido**: após o swap OOB, medir `getBoundingClientRect()` dos slots e escrever `--fx-dy` inline no `.shot`; o keyframe passa a `translate(calc(100% + var(--fx-travel)), var(--fx-dy))`. Alternativas preteridas: aritmética CSS por índice de slot (exigiria altura de card uniforme) e anchor positioning (`anchor()` não alimenta `transform`).
- **D2a — exceção estreita e formal ao RNF-01**: um handler inline em `views/layout.erb` (precedente: `layout.erb:37-54` **já** embarca ~17 linhas de JS ligadas a eventos htmx; a afirmação do draft de que seria "o primeiro script além do htmx" é falsa e será corrigida). Sem libs, sem polling, sem SSE, sem framework.
- **D3a — serializar os índices** (`attacker_index`/`target_index`) no strike entry, espelhando o precedente de `#item_action`; presenter expõe `from_slot`/`to_slot` com guarda quando a chave não existe (fakes montados à mão não têm a chave); markup `data-from-slot`/`data-to-slot` nos **dois** caminhos de render.
- **D4a — o rail CSS atual é o fallback** quando não há JS, em reduced motion ou em coluna única.
- **D5 — coluna única (<981px)**: no-op explícito, garantia de 0087 preservada.
- **D6a — e2e mede x e y** (destino = slot do alvo); o pin atual (`e2e/specs/battle-log.spec.ts:248-250`, `tx≈472±2`) é reescrito como par ordenado.
- **D7a — criar teste de seleção de alvo (`target_strategy`)** antes de confiar em `target_index` serializado.
- **D8 — reaberturas formais registradas (S3)** na 0087 e no RNF-01 (exceção ao "sem JS"); **outro agente as escreve** — esta sessão apenas as declara e **não** edita `sessions/0087*`, `REQUIREMENTS.md` nem `docs/draft-backlog.md`.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit `Passo N: ...`. Termina em Revisor (2c, S7, teto 3 rodadas) → **PARAR** p/ validação do usuário. Ordem ajustável apenas se o template/`checar-sessao` exigir — e cada passo diz quais testes mudam.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `Sessao 0088: refinamento concluido — ...` |
| 1 | **red→green — C1**: `log_entry`/`target_for` serializam `attacker_index`/`target_index`; vermelhos as duas asserções de chave em `test/battle_engine_test.rb` (:133-145) e `test/move_engine_test.rb` (:120-130) | suíte verde + lint 0; commit `Passo 1:` |
| 2 | **red→green — C2/C3**: teste de `target_strategy` novo + `from_slot`/`to_slot` no presenter com guarda | `./scripts/test test/battle_engine_test.rb test/battle_log_presenter_test.rb test/battle_juice_presenter_test.rb` + lint 0; commit `Passo 2:` |
| 3 | **red→green — C4/C5**: `data-from-slot`/`data-to-slot` nos dois caminhos de render + slot nos cards de lutador | `./scripts/test test/battle_strike_routes_test.rb test/battle_routes_test.rb test/battle_view_test.rb` + lint 0; commit `Passo 3:` |
| 4 | **red→green — C6/D2a/D4a**: handler JS em `layout.erb` medindo os slots + keyframe com `--fx-dy`; fallback intacto | `./scripts/test` + lint 0; commit `Passo 4:` |
| 5 | **red→green — C7/C8/C9**: e2e x/y + sem-JS + reduced motion + coluna única; pin `tx≈472±2` vira par ordenado | `e2e/specs/battle-log.spec.ts` + lint 0; commit `Passo 5:` |
| 6 | **verificação final — G1/G2/G3**: suíte total + lint 0 + `./scripts/check_docs`; diff sem lib/polling/SSE; `DESIGN.md` sem hex cru | `./scripts/test` + `./scripts/lint` + `./scripts/check_docs`; commit `Passo 6:` |
| — | **Fase 2 concluída** → **Revisor (2c)**: loop Implementador↔Revisor até veredito `Aprovado` (teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3). | — |

## 7. Validação (executada pelo usuário)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 | `./scripts/test -n /carry_full_action_shape/` | entrada de log com índices | |
| C2 | `./scripts/test -n /target_strategy/` | — | |
| C3 | `./scripts/test test/battle_log_presenter_test.rb` | — | |
| C4 | `./scripts/test test/battle_strike_routes_test.rb -n /shot_into_arena_track/` | inspecionar `data-from-slot`/`data-to-slot` | |
| C5 | `./scripts/test test/battle_view_test.rb -n /fighter_cards_carry/` | inspecionar o card | |
| C6 | e2e `battle-log.spec.ts` (par ordenado) | observar saída/chegada nos slots | |
| C7 | e2e com JavaScript desabilitado | desabilitar JS e repetir o golpe | |
| C8 | `./scripts/test test/design_system_test.rb -n /reduced_motion/` | com reduced motion, sem travel | |
| C9 | e2e guarda de coluna única + `test/style_responsive_test.rb` | redimensionar <981px | |
| G1 | `./scripts/test` + `./scripts/lint` | — | |
| G2 | `git diff --stat` | revisar diff por lib/polling/SSE | |
| G3 | `test/design_system_test.rb` | revisar `DESIGN.md`/diff por hex cru | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.
>
> **S3 2026-09-15 — reaberturas declaradas por esta sessão (registradas por outro agente):**
> - **RNF-01 (sem JS)** ganha **exceção estreita** para o handler único em `views/layout.erb` (D2a) — o precedente de `layout.erb:37-54` já existia sem exceção registrada.
> - **garantia "sem JS novo" da 0087 (G2)** muda de semântica: passa a admitir o handler medidor do D2a.
> - A afirmação do draft (`docs/draft-backlog.md:171-179`) de que a 0088 seria "o primeiro script além do htmx" é **falsa** e deve ser corrigida nessa reabertura.

## 8. Observações

- **PARADA obrigatória (regra do AGENTS.md):** a implementação PARA na fase 2 (suíte + lint verdes, Revisor S7 `Aprovado`); a validação (fase 3) é do **usuário**. Nada marcado como `Concluída`, nenhuma alegação de validação, nenhum commit de conclusão.
- **Não editar nesta sessão:** `sessions/0087-*`, `REQUIREMENTS.md`, `docs/draft-backlog.md` (as reaberturas S3 são escritas por outro agente).
- **Riscos a vigiar:** ordem dos dois fragmentos OOB (`#jx-shot-track` e `#jx-gates`) — medir **depois** do swap certo; leitura forçada de layout a cada golpe (aceitável nesta escala); reduced motion mostrando ponto estático na origem (igual a hoje); fakes de teste sem as chaves novas (é o motivo da guarda em `from_slot`/`to_slot`).
- **Leitura exata antes de editar:** confirmar `lib/battle_engine.rb:94-138`, `views/_fighter_panel.erb`, `views/_jx_shot.erb`, `server.rb` `strike_shot_oob`, `views/layout.erb:37-54` e o bloco ODS do projétil no arquivo antes do Passo 1.
- **Dúvida aberta:** garantir que `--fx-dy` inline não seja sobrescrito pelo CSS do bloco ODS (ordem/especificidade) — decidir no Passo 4 com o menor seletor que prove.

### Progresso Passo 5 (2026-09-15) — origem medida, gap do Passo 4 fechado

- **Descoberta do duplo disparo:** `htmx:afterSettle` dispara **por nó OOB** (`#jx-shot-track` e `#jx-gates`), então `placeShot()` roda 2x por golpe. A 2ª execução media o `.shot` **já deslocado** pelo `--fx-ox` da 1ª (rect transformado), o que corrompia o cálculo. Correção: medir a base por **layout** (`shot.offsetLeft/offsetTop` + rect do pai) em vez do rect do próprio `.shot` — idempotente entre execuções.
- **Erros medidos (e2e, arena 1200):** com o fix de origem, o centro do projetil no keyframe `from` ficou a **≈0,25px em x e ≈0,45px em y** do centro do card do atacante (era **190,6px** de erro de origem no Passo 4); o keyframe `to` pousou a **≈0,45px em y** do centro do card do alvo (era **259,6px**). Tolerância assertada: `< 2px` em x e y.
- **Fechamento de C6:** o e2e agora mede o **par ordenado** (saída no slot do atacante **e** chegada no slot do alvo), o pin antigo `tx ≈ 472 ± 2` virou par ordenado contra os centros reais dos cards; o critério C6 deixa de ter o gap de origem declarado no Passo 4.
- **Evidência:** 4 e2e novos verdes (`projectile leaves`, `container gate`, `reduced motion keeps`, `without JavaScript`); `./scripts/lint` 0 offenses; `./scripts/test` **1180 runs, 6219 assertions, 0 failures**; mutação de controle (remover o fallback `, 0` dos dois `from`) deixa `test_fx_contract_vars_declared` **vermelho** (1 failure, mensagem "keyframe juice-shot-ltr parte do offset de origem medido"), restaurado verde. Commit `4ede63b`.
- **Reds pré-existentes (não tocados):** os 4 testes que usam `buildTeamOfSix` (`round headers`, `reduced-motion disables juice`, `auto toggle`, `consumption and reward copy`) falham no helper — `#nav-badge` para em `5/6` com o time caro (orçamento do seed). Fora do escopo do Passo 5.
- **Sem** `Concluída`/validação: fase 3 é do usuário (regra do AGENTS.md); `SESSIONS.md` não foi tocado.

### Progresso Passo 6 (2026-09-15) — verificação final G1/G2/G3

- **G1:** `./scripts/test` → **1180 runs, 6219 assertions, 0 failures, 0 errors, 0 skips** (seed 11791, 112,5s); `./scripts/lint` → **136 files inspected, no offenses detected**; `./scripts/check_docs` → `ok> docs consistentes (SESSIONS.md <-> sessions/ <-> 'Próxima sessão')`.
- **G2 (JS confinado):** o único `<script>` de `views/` é `views/layout.erb:37-93` — o handler inline do D2a (39 linhas adicionadas pela 0088, um `document.addEventListener("htmx:afterSettle", placeShot)`); `views/layout.erb:7` é o CDN do htmx (pré-existente). `public/` só contém `style.css` (nenhum asset `.js`). Grep por `EventSource|WebSocket|setInterval|sendBeacon|XMLHttpRequest|new Function|eval(` em `views/` + `public/` → **nenhum**; grep por `onclick=`/`onload=`/`onsubmit=` em `views/` → nenhum; diff de `views/layout.erb` sem novo `src=`/`import`/`require` (nenhuma dependência nova).
- **G3 (DESIGN.md):** nenhuma linha adicionada em `public/style.css` na 0088 usa hex cru, `rgb()` ou `hsl()`; os offsets entram como custom properties (`--fx-ox`/`--fx-oy`/`--fx-dy`) consumidas pelos keyframes com fallback, sem componente paralelo; `test/design_system_test.rb` verde na suíte total.
- **e2e (recorde):** `cd e2e && npx playwright test specs/battle-log.spec.ts` (chrome headless, app docker em `:3000`) → **5 verdes / 4 vermelhos**; verdes: `projectile leaves the attacker slot and reaches the target slot (measured pair)`, `container gate disables projectile travel below 981px`, `reduced motion keeps the projectile without travel`, `without JavaScript the 0087 rail remains`, `arena keeps 3 in-flow columns and an out-of-flow projectile track`. Os 4 vermelhos são os **pré-existentes** do helper `buildTeamOfSix` (`round headers`, `reduced-motion disables juice`, `auto toggle`, `consumption and reward copy` — `#nav-badge` para em `5/6`), fora do escopo e não tocados.
- **Sem** `Concluída`/validação: fase 3 é do usuário (regra do AGENTS.md); `SESSIONS.md` não foi tocado.

## 9. Gotchas / Lições (memória — S6)

Preenchido na validação (fase 3) — alimenta `memory_write_page` em `gotchas/`.
