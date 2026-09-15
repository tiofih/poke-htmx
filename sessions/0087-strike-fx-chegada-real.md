# Sessão 0087 — Efeitos de golpe: projétil com chegada real (borda→borda do alvo) e gate por container query

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-09-15 (D1b, D2c, D3b, D4, D5, D6a) |
| Implementação (fase 2, TDD) | **Pendente** |
| Validação (fase 3) | **Pendente** (executada pelo usuário) |

---

## 1. Objetivo

O projétil de golpe deixa o teto direcional (0086/C9) e passa a ter **chegada real**: o `.shot` viaja da coluna do atacante até a **borda próxima do card alvo**, dentro de uma **track dedicada** do `.arena`, e o gate do travel deixa de ser `@media (min-width: 900px)` para ser um `@container` que lê a largura real da arena (3 colunas) — CSS-only, sem JS além do htmx.

## 2. Contexto (estado atual — diagnóstico)

- **`.shot` hoje vive dentro do card**: produtor único `views/_fighter_panel.erb:14`, dentro de `li.fighter`, gated por `juice_data[:shooting]`. Os dois caminhos de render passam por `_fighter_panel` — render completo (`views/battle.erb:49`/`:226`) e OOB do strike (`server.rb` `strike_battle` :1081-1088 → `strike_oob` :1090-1096 → `strike_hp_oob` :1098-1101 → `strike_side_oob` :1138-1147 → `views/_strike_fighters.erb:1`). CSS não move elemento entre colunas do grid — por isso o nó precisa sair do card (D3b).
- **`.arena`** = `views/battle.erb:44`; filhos: `span#jx-gates` :45, `div.battle-column[data-side=0]` :46-60, `div.podium` :62-221, `div.battle-column[data-side=1]` :223-228.
- **`server.rb` `strike_gates` :1117-1127** já calcula `shot => attack` e `result[:entry]` já carrega `from_side`/`to_side`/`move_type` — o OOB do shot não precisa de dado novo, só de novo fragmento.
- **CSS**: `.arena` `public/style.css:600-605` (gap 32px :59/:603), `--fx-travel: 40vw` :942, keyframes `juice-shot-ltr` :1565 / `-rtl` :1576, gate `@media (min-width: 900px)` :2442-2455, `.shot` base :982-992 (`display:none`), `.fighter{position:relative}` :648, `.arena` colapsa para 1 coluna em `@media (max-width: 980px)` :607-611 — logo **900–980px era o buraco real**: o gate antigo deixava travel ativo em coluna única.
- **Duplicação real é a ENTRADA DE LOG** (`views/battle.erb:195-210` vs `views/_strike_log_entry.erb:3-18`), não o projétil; `_strike_log_entry.erb` **não muda nesta sessão**.
- Base: 0086 (juice CSS-only, C9 projétil direcional, C15 gate 900px); playtest/review retroativo de 2026-09-14 (timing/geometria do projétil).

## 3. Escopo

### Produção

- **`views/_fighter_panel.erb`** — remove o nó `.shot` do card (:14).
- **Novo fragmento OOB do `.shot`** — track dedicada, filha direta do `.arena`, emitida por um fragmento novo em `server.rb` (`strike_oob`, :1090-1096); carrega `data-from-side`/`data-to-side`/`data-move-type` (C2).
- **`views/battle.erb`** — `.arena` ganha a track do `.shot` no render completo.
- **`public/style.css` (bloco ODS `0086`)** — `.arena` ganha `container-type: inline-size`; o gate do travel vira `@container`; `--fx-travel: calc(35cqi + 42px)`; keyframes consomem a var (sem distância hardcoded).
- **Sem engine/regras/economia/rotas de domínio**: só view + CSS + o fragmento OOB.

### Testes

- `test/battle_strike_routes_test.rb` — OOB do shot na track (C1/C2).
- `test/battle_routes_test.rb#test_battle_fragment_marks_juice_targets` (:312-337) — deixa de afirmar `class="shot"` dentro do card (:332) e passa a afirmar a track do `.arena` (C1).
- `test/style_responsive_test.rb` — `test_shot_travel_disabled_below_900px` (:337-362) reescrito para `@container` + `container-type: inline-size` (C3/C4); `test_fx_contract_vars_declared` (:428-437) deixa de pinar `40vw` e passa a pinar `calc(35cqi + 42px)` (C5).
- `e2e/specs/battle-log.spec.ts` — novo teste medindo a chegada real no destino (C4/C6), além do `reduced motion` (:84).

### Fora de escopo (não abrir)

- JS point-to-point (hard-out da 0086), segunda estratégia de golpe (D6a), mudanças na entrada de log (`_strike_log_entry.erb`), engine/regras/economia/rotas de domínio, migrações.

## 4. Critérios de aceite

### Resultado (S1 — cada critério aponta o teste que o prova)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| C1 o `.shot` vive na track dedicada do `.arena` (filha direta) e **não** dentro do card do lutador | `test/battle_strike_routes_test.rb` (novo teste do OOB do shot) + `test/battle_routes_test.rb` `test_battle_fragment_marks_juice_targets` (:312-337, reescrito — hoje afirma `class="shot"` :332 no render completo) | pendente |
| C2 o OOB do strike carrega `data-from-side`/`data-to-side`/`data-move-type` no shot | `test/battle_strike_routes_test.rb` (novo teste do OOB do shot) | pendente |
| C3 o gate do travel é `@container` no `.arena` (com `container-type: inline-size`) e não `@media (min-width: 900px)` | `test/style_responsive_test.rb` `test_shot_travel_disabled_below_900px` (:337-362, reescrito) + novo assert de `container-type: inline-size` | pendente |
| C4 a faixa 900–980px (single-column) deixa de ter travel ativo | `test/style_responsive_test.rb` (assert de presença do `@container`) + `e2e/specs/battle-log.spec.ts` (novo teste do gate por container) | pendente |
| C5 `--fx-travel: calc(35cqi + 42px)` e nenhuma distância hardcoded nos keyframes | `test/style_responsive_test.rb` `test_fx_contract_vars_declared` (:428-437, hoje pina o literal `40vw`) | pendente |
| C6 chegada real medida no destino (borda próxima do alvo) | `e2e/specs/battle-log.spec.ts` (novo teste medindo `getBoundingClientRect`/translate computado; hoje :84 só checa reduced motion) | pendente |
| C7 a cor por tipo continua chegando ao `.shot` a partir do `.arena` (18 regras `#jx-gates`) | `test/style_responsive_test.rb` `test_move_type_color_reaches_shot_from_arena` (:407-424) | pendente |
| C8 o sync shot/impacto é preservado (`impacto == approach + travel`; `shake == impacto`) | `test/style_responsive_test.rb` `test_shake_synced_to_impact_instant` (:444-486) | pendente |
| C9 o `.shot` segue classe ODS com guard de reduced motion | `test/design_system_test.rb` `test_design_system_battle_juice_reduced_motion` (:101-120) | pendente |

### Garantias (RNF)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| G1 suíte completa + lint 0 em todo green (baseline preservado + novos testes) | `./scripts/test` + `./scripts/lint` | pendente |
| G2 nenhum JS novo além do htmx (CSS-only) | `git diff --stat -- public/ views/` (sem `.js` novo) | pendente |
| G3 `DESIGN.md` sem hex cru / sem componente paralelo | revisão de diff (`manual`) + `test/design_system_test.rb` | pendente |

> **S1:** cada critério acima aponta o teste que o prova (arquivo + método). **Ao fim da fase 2 (suíte + lint verdes, Revisor S7 `Aprovado`), PARAR e aguardar a validação do usuário — não marcar Done, não preencher a seção 7, não commitar conclusão.**

## 5. Decisões de refinamento (fechadas com o usuário — 2026-09-15)

- **D1b — travel alcança a borda próxima do card alvo** (chegada real, não teto direcional): substitui o contrato da 0086/C9 ("teto direcional por `data-side`, sem ponto-a-ponto").
- **D2c — o gate do travel deixa de ser `@media (min-width: 900px)`** e passa a `@container` no `.arena` (`container-type: inline-size`), acompanhando o estado real de 3 colunas. Motivo: o `.arena` colapsa em `@media (max-width: 980px)`, então 900–980px era single-column com travel ativo.
- **D3b — o nó `.shot` sai de dentro do card** (`views/_fighter_panel.erb:14`) para uma **track dedicada**, filha direta de `.arena`, emitida por um fragmento OOB novo.
- **D4 — `--fx-travel: calc(35cqi + 42px)`** (borda→borda; grid `1fr 1.06fr 1fr`, gap 32px). Alternativa preterida: manter `40vw`.
- **D5 — verificação de valor por e2e medindo o destino**: asserts CSS estáticos não resolvem `cqi`; a prova de geometria é e2e.
- **D6a — `data-strategy` permanece default-only**: extensibilidade = forma do hook (já testada); segunda estratégia é YAGNI.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Termina em Revisor (2c, S7, teto 3 rodadas) → **PARAR** p/ validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados (sem `SESSIONS.md`/backlog/commit, por ordem da tarefa) | arquivo criado em `sessions/0087-strike-fx-chegada-real.md` |
| 1 | **red→green — C1/C2 (track + OOB do shot)** — reescreve `test/battle_routes_test.rb#test_battle_fragment_marks_juice_targets` para a track do `.arena` e adiciona o teste do OOB em `test/battle_strike_routes_test.rb`; tira o `.shot` de `_fighter_panel.erb` e cria a track + fragmento OOB em `server.rb`/`battle.erb` | `./scripts/test test/battle_strike_routes_test.rb test/battle_routes_test.rb` + lint 0; commit `Passo 1:` |
| 2 | **red→green — C3/C4 (gate por container)** — `container-type: inline-size` no `.arena` e troca do `@media (min-width: 900px)` por `@container`; reescreve `test_shot_travel_disabled_below_900px` + assert de `container-type` | `./scripts/test test/style_responsive_test.rb` + lint 0; commit `Passo 2:` |
| 3 | **red→green — C5 (travel por cqi + keyframes)** — `--fx-travel: calc(35cqi + 42px)`; keyframes passam a consumir a var (sem `40vw`) e `test_fx_contract_vars_declared` deixa de pinar `40vw` | `./scripts/test test/style_responsive_test.rb` + lint 0; commit `Passo 3:` |
| 4 | **red→green — C7/C9 (cor de tipo + reduced motion)** — fiação `data-move-type` → `.shot` pela track/`#jx-gates` e guard de reduced motion; `test_move_type_color_reaches_shot_from_arena` + `test_design_system_battle_juice_reduced_motion` | `./scripts/test test/style_responsive_test.rb test/design_system_test.rb` + lint 0; commit `Passo 4:` |
| 5 | **red→green — C6 (chegada real e2e)** — novo teste em `e2e/specs/battle-log.spec.ts` medindo o destino (`getBoundingClientRect`/translate computado) + gate por container | `e2e/specs/battle-log.spec.ts` + lint 0; commit `Passo 5:` |
| 6 | **red→green — C8/G1-G3 (sync + limpeza)** — reexecuta `test_shake_synced_to_impact_instant`; suíte total + lint 0 + `./scripts/check_docs`; diff sem `.js` novo | `./scripts/test` + `./scripts/lint` + `./scripts/check_docs`; commit `Passo 6:` |
| — | **Fase 2 concluída** → **Revisor (2c)**: loop Implementador↔Revisor até veredito `Aprovado` (teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3). | — |

## 7. Validação (executada pelo usuário)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 | `./scripts/test test/battle_strike_routes_test.rb test/battle_routes_test.rb` | inspecionar `.shot` na track do `.arena` | |
| C2 | `./scripts/test test/battle_strike_routes_test.rb` | inspecionar os `data-*` no OOB | |
| C3 | `./scripts/test test/style_responsive_test.rb -n /test_shot_travel_disabled_below_900px/` | inspecionar `@container`/`container-type` no CSS | |
| C4 | `./scripts/test test/style_responsive_test.rb` + e2e | redimensionar 900–980px e observar flash-only | |
| C5 | `./scripts/test test/style_responsive_test.rb -n /test_fx_contract_vars_declared/` | inspecionar `--fx-travel` no computed style | |
| C6 | e2e `battle-log.spec.ts` | observar a chegada do projétil na borda do alvo | |
| C7 | `./scripts/test test/style_responsive_test.rb -n /test_move_type_color_reaches_shot_from_arena/` | observar cor do projétil por tipo | |
| C8 | `./scripts/test test/style_responsive_test.rb -n /test_shake_synced_to_impact_instant/` | observar shake no instante do impacto | |
| C9 | `./scripts/test test/design_system_test.rb -n /test_design_system_battle_juice_reduced_motion/` | com reduced motion, sem travel | |
| G1 | `./scripts/test` + `./scripts/lint` | — | |
| G2 | `git diff --stat -- public/ views/` (sem `.js` novo) | — | |
| G3 | `./scripts/test test/design_system_test.rb` | revisar `DESIGN.md`/diff por hex cru | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.
>
> **S3 2026-09-15 — reaberturas declaradas (reaprovação pendente na fase 3 da 0087):**
> - **C15 da 0086 (gate do travel)** muda de semântica: `@media (min-width: 900px)` → `@container` no `.arena`. A garantia "flash-only abaixo do breakpoint" nunca foi verdadeira na faixa 900–980px; a reaprovação é do usuário na validação desta sessão.
> - **C9 da 0086 (projétil direcional)** muda de teto direcional para **chegada real na borda do alvo** (D1b/D3b) — mesmo contrato, geometria nova.
> - **C13 da 0086 (sync)** não muda de semântica; se a 0087 redefinir a aritmética de duração do projétil, o teste deve ser reexecutado na fase 3.

### Progresso da implementação (fase 2 — TDD)

- **Passo 5 (C6/D5 — chegada real e2e):** dois testes novos em
  `e2e/specs/battle-log.spec.ts` — `projectile reaches the target card border
  (cqi travel measured live)` (arena ancorada em 1200px num viewport 1600px para
  discriminar `cqi` de `vw`; mede o translate computado do `.shot` contra a borda
  do card alvo nas duas direções) e `container gate disables projectile travel
  below 981px`. Implementado e verde; commit `Passo 5:` `222d918`.
- **Defeito de geometria descoberto nos Passos 1–4:** a track do projétil entrou
  no fluxo do grid como 4º item e deslocava as 3 colunas; em RTL o `.shot` caía
  fora da tela (x≈−497). Correção mínima neste passo: `.arena{position:relative}`
  + `.shot-track{position:absolute;inset:0;pointer-events:none}` (fora do fluxo),
  com ancoragem por lado `.shot[data-from-side="0"|"1"]{left:…}`.
- **Ruído de swap no teste do gate:** `getComputedStyle(el).display` pode voltar
  `""` (não `"none"`) quando a locator casa o nó **já destacado** pela troca OOB do
  htmx — no Chromium `connected:false` devolve string vazia. Trocado por
  `expect.poll` (tolera a janela de swap; um gate quebrado devolveria `"block"`
  até o timeout). 10/10 verdes com `--repeat-each=5`.
- **Observação (pré-existente — não é regressão deste passo):** 4 testes do mesmo
  arquivo já estão vermelhos neste ambiente — `round headers…`,
  `reduced-motion disables juice`, `auto toggle chains…` e
  `consumption and reward copy` — todos falhando em `buildTeamOfSix`
  (`e2e/specs/battle-log.spec.ts:17`) porque o 6º add bloqueia com
  "Orçamento insuficiente".
- Suíte completa **1173 runs / 6159 assertions, 0 failures / 0 errors / 0 skips**;
  lint **0 offenses** em 136 arquivos.
- **PARADA (regra do AGENTS.md):** registro apenas do Passo 5; nada marcado como
  `Concluída` e nenhuma alegação de validação — a fase 3 é do usuário.
- **Passo 6 (C8/G1–G3 — sync + limpeza):** `test_shake_synced_to_impact_instant`
  reexecutado — verde (1 run, 21 assertions, 0 failures). Suíte total **1173 runs /
  6159 assertions, 0 failures / 0 errors / 0 skips**; `./scripts/lint` **0 offenses**
  em 136 arquivos; `./scripts/check_docs` **ok** (docs consistentes). G2: diff do
  intervalo da sessão `0637cb6..HEAD` toca só `public/style.css` + ERBs
  (`views/_fighter_panel.erb`, `views/_jx_shot.erb`, `views/battle.erb`), **nenhum
  `.js` novo**. Nenhum arquivo temporário de e2e restante (`e2e/specs/` limpo).
- **PARADA:** fase 2 encerra aqui; a validação (fase 3) é do usuário — nada marcado
  como `Concluída` e nenhuma alegação de validação neste arquivo.
- **Passo 7 (reabertura na validação — garantia estrutural + guarda de layout):**
  a fase 3 (usuário) reproduziu ao vivo o defeito de fluxo do Passo 1: a track era
  filho **direto** do `.arena` (grid de 3 colunas) e só o `position:absolute` do
  Passo 5 a mantinha fora do fluxo — sem essa regra ela virava 4º item e deslocava
  as colunas (time ao centro, podium à direita, oponente abaixo-esquerda; 4 itens em
  fluxo, medidos ao vivo). A correção deixa de ser só estilística: a track passou
  para dentro do `.battle-column[data-side="0"]` (static), então não pode mais ser
  item do grid. **O `.podium` foi descartado como container**: ele é
  `position:sticky`, logo viraria o containing block da track e a track mediria só
  a coluna central (verificado ao vivo: `offsetParent` vira `podium` e o rect
  encolhe ao rect do podium) — o `.battle-column` é static e mantém
  `offsetParent === .arena`, com geometria idêntica. A guarda que faltava é um teste
  e2e novo (`arena keeps 3 in-flow columns and an out-of-flow projectile track`) que
  mede ao vivo, em 1600px e 900px: `.arena` com exatamente 3 filhos em fluxo
  (2 colunas + `.podium` sticky, que é in-flow; só `absolute`/`fixed` saem) e
  `#jx-shot-track` com `position:absolute` e fora do `.arena` como filho. Prova de
  capacidade de vermelho: (a) `.shot-track{position:static}` → falha
  `Expected: "absolute" / Received: "static"`; (b) track de volta como filho direto
  → falha `Expected: false / Received: true` no `trackDirectChild`. Verde após
  reverter. Suíte **1173 runs / 6159 assertions, 0 failures / 0 errors / 0 skips**;
  lint **0 offenses** em 136 arquivos. Os 4 verefos pré-existentes de
  `buildTeamOfSix` ("Orçamento insuficiente") seguem vermelhos — não tocados.

## 8. Observações

- **Não tocado nesta tarefa (por ordem):** `sessions/0086-battle-log-juice.md`, `SESSIONS.md`, `docs/draft-backlog.md`, commits.
- **A implementação PARA na fase 2** — a validação (fase 3) é do usuário; nada aqui deve ser marcado como Concluída antes disso.
- **Leitura exata antes de editar:** confirmar `views/_fighter_panel.erb`, `views/battle.erb:44-228`, `server.rb` `strike_oob`/`strike_side_oob` e os trechos de `public/style.css` citados em §2 no arquivo antes do Passo 1.
- **CSS:** só dentro do bloco ODS, ANTES da linha `fim`, com delimitador próprio `0086` (a sessão reusa o bloco).
- **Dúvida aberta:** se o `@container` exigir nome (`container-name`) para não colidir com outros containers, decidir no Passo 2 com o menor seletor que prove o gate.

## 9. Gotchas / Lições (memória — S6)

A preencher na validação (fase 3): resolução de `cqi` contra o container do `.arena`, gate `@container` vs colapso em `@media (max-width: 980px)`, e medição de geometria por e2e.
