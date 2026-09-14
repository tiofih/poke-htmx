# Juice + Loop Attack Plan — poke-htmx — 2026-09-13 (read-only plan, no code change)

> Source task: `sessions/0086-battle-log-juice.md` — Refinamento Concluída (2026-09-10 routing CSS-only+texto; S3 flips 09-11/09-12), Implementação Pendente, Validação Pendente (user phase). This file is the NEW detailed attack plan only. No existing files edited.
> Grounding: `lib/battle_juice_presenter.rb:1-90` (whole file, 90 lines) · `reviews/ui-feel-juice-2026-09-13.md:1-18` · `reviews/loop-core-2026-09-13.md:1-57` · `reviews/loop-flow-nano-2026-09-13.md:1-10` · skill `animate-css-skill/SKILL.md:1-80` (selection guide + speed/delay/threshold/RTL) · base done: `sessions/0063-juice.md` (validada 2026-09-08), `sessions/0069-resolver-batalha.md` (validada 2026-09-02), `sessions/0048-jn5-gameloop.md` (validada 2026-08-25).

## 1. What the open task is (found first)

`0086-battle-log-juice.md:1-9` — open + pending: log legível por rodada (chronological R1-topo, header + anchors) + juice CSS-only polish + consumo/recompensa visível em texto + pacing tiered + effect-sync/modal + per-aspect modules/toggles + stepped rounds server + AUTO via `HX-Trigger` + strike-flow append-only + directional projectile + target-card shake + move-type color + fx contract + impact sync + reduce-final + <900px flash-only. 15 criteria C1-C15 + G1 (`§4:45-67`), pedra fundamental append-only (`§5:73-83`, decreto 2026-09-12: Batalhar > strike > linha > efeito > HP > próximo > modal, 1 strike = 1 linha), teto direcional atacante→alvo por `data-side` sem ponto-a-ponto (D1/D2 `§5:86-89`), shake por-lutador gated `data-jx-shake` (gate já emitido `server.rb:1125`, D3), `move_type` via `outcome_fields` (`battle_log_presenter.rb:62-64` ← `battle_engine.rb:97`) nos dois renders (`battle.erb:195-199` + `_strike_log_entry.erb`, D4), paleta `--t-*` reuse + `data-strategy="strike"` default + vars `--fx-color/--fx-travel/--fx-shake`. Hard outs (`§3:39`): sem engine/economia/regras/rotas-verbos/CSRF/migrações/schema/gems, sem JS/polling/SSE, projétil <900px proibido (D5-0063 mantido). Plan in file: Passos 1-4 + 23-28 (`§6:101-113`); Passo 22 em voo em paralelo — não reutilizar o número.

## 2. Current-state synthesis (why this order)

- **Presenter (`battle_juice_presenter.rb:6-90`):** puro, sem engine. `initial_hp = final + dano − cura` replay (`:14-16,53-69`), `fighter_juice` → `{initial_hp, damaged, ko, shooting, damage_taken}` (`:21-28`), `css_classes` 1:1 com hooks `is-hit/fainted/is-attacking` (`:32-39`), `from_side/to_side` com fallback item=self (`:41-49`). Bom: sem estado extra, testável. Falta (ui-feel §gaps): sem tiers de importância (`damage_taken` exposto mas sem `juice: :small/:large/:ko`), sem trauma/hit-stop (reservar p/ CSS-only), juice não-transiente se `is-hit` não voltar ao rest.
- **Loop (`loop-core:40-57` + `loop-flow-nano`):** `0069` já fechou o minimal fix (Resolver batalha, 1 clique → payoff). Restam os atritos que 0086 ataca: resolve-treadmill virou replay-stagger (C4/C5), heal-tollbooth vira copy clara participação-vs-vitória (C3), derrota-paga-quase-igual vira legibilidade de causa (nano fix: 1-line why + next counter no log/reward), flat-curve vira cor por tipo + shake/shot sincronizados (leitura de counter-play sem mudar economia).
- **CSS-only constraint (htmx, no JS):** tudo via `data-*` + custom props (`--log-delay` por índice, `--step-delay` line→effect→line, `--log-total` gating modal, `--fx-*` contrato) + `hx-post advance` / `HX-Trigger` chain p/ AUTO + OOB `_strike_log_entry.erb` append-only + `#battle-log` sempre renderizado mesmo vazio (C8). Animate.css skill é vocabulário, não dependência: mapear para keyframes locais existentes (não linkar CDN salvo pedido explícito do usuário, `SKILL.md:17`).

## 3. CSS-only idea map (from `SKILL.md:23-56`, adapted to htmx/no-JS)

| 0086 need | Animate.css pick (local keyframes, same feel) | Speed/delay rule |
|---|---|---|
| Log line reveal R1–R3 / R4–R9 / R10+ (C4) | `fadeInUp` (lines), `fadeInLeft` stagger em headers de round | R1–3 `animate__slow`-feel 1s, R4–9 default 0.5s, R10+ `animate__faster` 0.2s; `animate__delay-*` por `data-log-index`; botão Pular desliga (`animation: none`) |
| Effect sync line→effect→line (C5) | `zoomIn animate__fast` (fx token `.fx`), `pulse` no HP | `--step-delay` por linha; modal `zoomIn/bounceIn` entrance, `zoomOut` exit — gated `--log-total`, cap `min(acc,3s)` |
| Shot atacante→alvo (C9, ≥900px) | `slideIn` direcional (2 keyframes ltr/rtl por `data-side`) | `animate__fast` 800ms; `<900px` flash-only (`flash animate__faster` no alvo) |
| Shake só no alvo (C10) | `shakeX` (dano) / `headShake` (KO iminente) por-lutador | `animate__faster` 500ms no instante do impacto (`--log-delay`); arena fora |
| Cor por tipo (C11/C12) | `heartBeat/tada` sparing no chip + `data-move-type` → `--fx-color` de `--t-*` | fallback sem tipo; `data-strategy="strike"` default p/ extensão futura |
| Banner vitória/derrota + news (C3 reuse 0063) | vitória `tada/jackInTheBox`, derrota `fadeIn`, erro `shakeX` | `bounceIn` entrance; copy participação (`fadeIn`) vs vitória — só texto |
| Toast/add, toggles (C6) | `slideInRight/bounceInRight` notificação | `animate__faster`; `data-jx` gates (aggregates OFF, log/fx/chip/modal timed) |
| Reduced-motion (C2/C14) | tudo `none` | bloco final `!important`, ÚLTIMA regra do stylesheet, cobre travel/shake/novos seletores; probe `getComputedStyle().animationName === 'none'` (não `getAnimations()`) |

Threshold/RTL (`SKILL.md:58-80`): irrelevante p/ battle (sem scroll-trigger); manter substituições RTL prontas se `dir="rtl"` aparecer (slideInLeft↔Right etc.).

## 4. Rules of engagement (do not violate)

- SDD S1: cada slice aponta teste (arquivo + método); sem teste → `manual` explícito. S2: validação é tabela por critério (usuário, fase 3). S3: ajuste = reabrir critério + data + reaprovação. S4/S5: `SESSIONS.md` + `./scripts/check_docs` + `./scripts/checar-sessao 0086` no refinamento/validação — este plano não toca docs de status. S6: handoff + gotchas no Revisor Aprovado, sem validação, sem commit de conclusão. S7: loop Implementador↔Revisor até `Aprovado`, teto 3 → S3. Validação = usuário; ao fim da fase 2 PARAR.
- Comandos só via `./scripts/*` (`test`, `lint`, `check_docs`, `checar-sessao`, `levantar-*`); nunca `rake`/`rubocop` no host. `git diff --stat -- lib/battle_engine.rb lib/battle_service.rb db/` deve ficar vazio (toque aprovado só em `lib/battle_log_presenter.rb` p/ `move_type`, C11). Views `not_tracked` no grafo — confirmar via read antes de editar (na execução, não aqui). Bloco CSS só ODS com delimitador `0086`, ANTES da linha `fim`; reduced-motion DEPOIS de tudo.
- Slice discipline: 1 slice = 1 commit `Passo N:` + suíte + lint 0; cada slice roda sozinho (red→green provado pelo seu teste + regressão citada). Não reabrir D1–D8 (0063), D1–D5 (0069), pedra fundamental, nem C1-flip chronological / C4-C9 S3s.

## 5. Attack order — thin vertical slices (feasibility order)

**Slice A — C1 log legível por rodada (base de tudo).** `battle.erb` + `_fighter_panel` mínimo: headers `data-round`, R1-topo chronological, cada entrada ligada à rodada + âncoras. Presenter só leitura/formatação (round já no entry). Tests: `test/battle_log_presenter_test.rb#test_entries_grouped_by_round_chronological` + `e2e/specs/battle-log.spec.ts#round headers chronological`. Verify: `./scripts/test test/battle_log_presenter_test.rb` + e2e + lint 0. Por quê primeiro: C4/C5/C7/C8/C11 lêem contra esta ordem; sem ela stagger/sync/append testam ordem errada.

**Slice B — C3 consumo/recompensa em texto (valor sem economia).** Strings/kinds existentes: "usou 1 X — restam N" (+ `last_unit`) e "participação: +N XP/+N◒" vs vitória. Tests: `test_item_entries_with_stock_expose_remaining_and_last_unit` + `test_item_entry_without_stock_keeps_legacy_copy` + e2e `consumption and reward copy`. Verify idem. Sem mudar valores; fecha o nano fix "reward clarity = skill payoff".

**Slice C — C2 polish + reduced-motion por último (guarda a11y).** Bloco `0086`: tiers `damage_taken → juice :small/:large/:ko` como `data-*`/classes (fecha gap 1 ui-feel) + eased tween (overshoot pop, ease-out settle, gap 2) + stack 2-3 canais por evento flash+shake+number (gap 6) + trauma-decay visual-only + hit-stop 60-120ms só KO/large com input preservado (gaps 3-4, CSS `animation-delay`/freeze curta) + transiência `is-hit`→rest / `fainted` end-state (gap 5). Media query `reduce` por último/`!important`. Tests: `test/style_responsive_test.rb#test_juice_reduced_motion_disables_all` + e2e `reduced-motion disables juice`. Fazer agora (não por último no sentido de deixar p/ fim do projeto — mas como último passo CSS dentro do slice) p/ não mascarar regressão visual dos slices seguintes.

**Slice D — C4 pacing tiered + Pular.** `--log-delay` por `data-log-index` (1s/0.5s/0.2s) + botão Pular (desliga animação). Tests: `test_log_tiered_pacing_delays` (lê CSS) + view `data-log-index`/Pular + e2e `tiered pacing + skip`. Dead-path note: p/ rounds frescos via `advance`, stagger cumulativo vira legado/carga inicial.

**Slice E — C7 stepped rounds servidor + AUTO (loop jogável).** `POST advance` 1 round/"Próxima rodada"; `JOGAR-AUTO` ON encadeia via `HX-Trigger` até `finished`. Tests: `test_advance_steps_single_round_until_finished` + `test_auto_toggle_chains_advance_via_hx_trigger` + e2e. Maior risco (rota/server) — isolado aqui; C8 depende dele.

**Slice F — C8 strike-flow append-only + C5 effect-sync/modal.** Ordem Batalhar>golpe>linha>efeito>HP>modal; `#battle-log` sempre presente (mesmo vazio); `--step-delay` + modal gated `--log-total`. Tests: `test_strike_appends_single_line_in_order` + view `#battle-log` vazio + `test_effect_sync_step_delay` + view `result modal gated --log-total` + e2e ambos. Fecha pedra fundamental + nano "why/next-counter" (1-line cause no log + counter no reward — texto, sem economia).

**Slice G — C6 módulos por aspecto + toggles.** log/fx/chip/modal por aspecto + `data-jx` (aggregates OFF, timed). Tests: `test_per_aspect_modules_with_toggles` + `test_aggregates_off_per_aspect_timed` + view `data-jx` + e2e. Depois de F p/ modularizar o que F estabilizou.

**Slice H — C11/C12 tipo + contrato (único toque aprovado fora de view/css).** `outcome_fields` expõe `move_type` + `data-move-type`/`data-strategy="strike"` nos dois renders + 18 tipos→`--t-*` + fallback + `--fx-color/--fx-travel/--fx-shake`. Tests: `test_outcome_fields_exposes_move_type` + `test_battle_log_entries_carry_move_type` + `test_battle_log_entries_carry_strategy_default_strike` + `test_move_type_colors_map_to_type_palette` + `test_fx_contract_vars_declared`. Verify: presenter + view + style + lint 0.

**Slice I — C9+C10+C13+C15 fx direcional sincronizado.** `.shot` travel por `data-side` (2 keyframes, gated `data-jx-shot`, só `@media min-width:900px`) + shake por-lutador gated `data-jx-shake` (arena fora; gate já em `server.rb:1125`, sem server change) + shake no instante do impacto (`--log-delay`). Tests: `test_shot_travels_attacker_to_target_directional` + `test_shake_hits_target_card_not_arena` + `test_strike_shake_gate_emitted_on_damage` + `test_shake_synced_to_impact_instant` + `test_shot_travel_disabled_below_900px` + e2e direção/ordem. Depois de H (usa `--fx-*` + `data-move-type`).

**Slice J — C14 reduce-final + G1 regressão.** Bloco reduce `!important` como ÚLTIMA regra cobrindo novos seletores + suíte completa + lint 0 + diff engine/service/db vazio. Tests: `test_reduce_covers_new_fx_selectors_last` + e2e probe + `./scripts/test` + `./scripts/lint`. → Revisor (2c) até `Aprovado` → PARAR p/ validação usuário (C5-0063-style `manual` via `./scripts/run`, viewports ≥900/<900, `prefers-reduced-motion: reduce`).

## 6. Slice → criterion trace (S1-ready)

A→C1 · B→C3 · C→C2 · D→C4 · E→C7 · F→C8+C5 · G→C6 · H→C11+C12 · I→C9+C10+C13+C15 · J→C14+G1. Nenhum slice toca engine/economia/rotas-verbos/schema/gems/JS; único backend permitido: H (`battle_log_presenter` leitura). Números de Passo: continuar de onde 0086 parou (não reutilizar 22); sugerir A=1..J=10 na execução ou mapear p/ 1-4+23-28 do arquivo — decisão do implementador no Passo 0.

## 7. Risks + mitigations

- Cascata reduce (achado crítico playtest-0063): mitigado em C/J (última regra + `!important` + probe `getComputedStyle`).
- Newest-first→chronological confusão: mitigado em A (headers + anchors R1-topo, T114).
- Débito/itens opacos + reward-na-derrota: mitigado em B (stock + participação-vs-vitória, sem valores).
- Stagger morto p/ fresh rounds: esperado em D/E (documentar dead path, manter p/ carga inicial).
- Projétil ilegível <900px: mitigado em I (flash-only, D5-0063).
- `outcome_fields` derruba tipo hoje: mitigado em H (D4, dois renders).
- Parallel Passo 22 collision: não reutilizar número; J checa `git log` antes do commit final.
