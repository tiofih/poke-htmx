# Sessão 0069 — resolver-batalha (B5: "Batalhar" resolve a batalha inteira — fim das rodadas manuais)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-09-02 (D1–D5 fechadas) |
| Implementação | **Pendente** |
| Validação | **Pendente** (executada pelo usuário) |

---

## 1. Objetivo

"Batalhar" resolve a batalha inteira num único request: novo `BattleService#resolve` loopa todas as rodadas no servidor (com teto contra loop infinito), debita itens de **todas** as rodadas, aplica `finish_effects` **uma única vez** e devolve o log **completo**; a UI revela o log rodada a rodada com **animação CSS local** (fade/slide-in escalonado, `prefers-reduced-motion`), **sem polling/SSE e sem novo request**. Fim das rodadas manuais (ideia B5 de `draft-auto-battler.md:694-702`; reforço G4 de `draft-playtest-changelog.md:318` e do `playtest-03-gameplay.md:65`).

## 2. Contexto (estado atual — diagnóstico)

- **`BattleService#advance`** (`lib/battle_service.rb:394-403`): `engine.play_round` → `debit_used_items(user_id, engine)` → `finish_effects` **se cruzou `finished?`** (guarda `finishing = !engine.finished?`) → `battle_payload`. Rota `POST /battle/play` (`server.rb:1103`) → `advance_battle` (`server.rb:924-930`) → `settings.battle.advance(current_user)` → `expose_battle_result` + `erb :battle`.
- **Gotcha do débito de itens** — `BattleServiceFinalization#debit_used_items` (`lib/battle_service.rb:205-210`) usa `items_used_in_round` (`212-215`) que seleciona **só** `entry[:round] == engine.rounds` (a rodada corrente). Num loop de N rodadas num único request, reusar `advance` debitaria apenas a **última** rodada — itens de poções/seguráveis/use_stone das rodadas anteriores ficariam no inventário.
- **`finish_effects`** (`lib/battle_service.rb:432-440`): `record_finished_battle` + `grant_finished_xp` + `grant_finished_money` + `apply_evolution_and_learning` + `rebuild_display_team` + `persist_finished_hp` — toda a economia de fim de batalha concentrada na **transição única** para `finished?` (guardas já existentes: `test_battle_play_grants_xp_once_on_transition_to_finished`, `test_battle_finish_persists_hp_only_once`, `test_battle_play_after_finish_does_not_duplicate_battle_record`).
- **`battle_payload`** (`lib/battle_service.rb:442-451`): `engine` + `xp_gained`/`money_gained` (só se `finished?`) + `evolution_news`/`learned_news`.
- **Log** — `BattleLogPresenter#entries` (`lib/battle_log_presenter.rb:13-15`) com `DEFAULT_LIMIT = 3` (esconde rodadas antigas; `test_returns_only_last_three_rounds` + `test_default_limit_is_three` em `test/battle_log_presenter_test.rb`; `test_battle_log_drops_rounds_older_than_three` em `test/battle_routes_test.rb:421`).
- **UI** — `views/battle.erb:74-75`: botão **"Jogar"** `hx-post="/battle/play"` `hx-target="#battle-view"` `hx-swap="innerHTML"` `hx-indicator="#battle-loading"` (testes `test_battle_fragment_has_play_button` `:160` e `test_battle_play_button_has_local_hx_indicator` `:170`); `views/team.erb:23`: link **"Batalhar"** (`/battle`).
- **`BattleEngine#battle`** (`lib/battle_engine.rb:157-164`): loop `until finished?` com contador **local** `rounds` via `play_round!` — **não atualiza `@rounds`** → `items_used_in_round` não acharia `entry[:round] == engine.rounds`; retorna `BattleResult` (sem `debit_used_items`/`finish_effects`/`battle_payload`); **35 callers** (rankings, seeds, etc.) — **fica intocado** (ver §8).
- Batalha por usuário com HP/estado persistidos (0049, D2/Eco-2): `engine = @battles.fetch(user_id)` na registry, `play_round` muta o engine em memória entre requests.
- Baseline: suíte **983/3819**, lint 0 (0068 validada 2026-08-31). Frescor do grafo 2026-09-02T22:38Z — `lib/battle_service.rb`, `server.rb`, `test/battle_service_test.rb`, `test/battle_routes_test.rb` sem gap registrado; `views/battle.erb` `not_tracked` (fonte conferida via read).

## 3. Escopo

### Produção

- `lib/battle_service.rb` — novo **`resolve(user_id)`**: loopa `play_round` **atualizando `@rounds`**, debita itens **por rodada** (correção do gotcha `items_used_in_round`), roda `finish_effects` **uma vez** ao cruzar `finished?`, **teto de 100 rodadas** (força fim contra loop infinito teórico), retorna `battle_payload`. `advance` permanece (sem callers novos; usado pela regressão).
- `lib/battle_log_presenter.rb` — **log completo**: novo modo (ex.: `entries_all` ou `limit:` param) devolvendo todas as rodadas; `DEFAULT_LIMIT = 3` preservado para compatibilidade (`test_default_limit_is_three`).
- `server.rb` — `POST /battle/play` (1103) passa a resolver tudo: `advance_battle` (924-930) chama `settings.battle.resolve(current_user)`; sem rota nova (mesmo fragmento `#battle-view`).
- `views/battle.erb` — **remover** o botão "Jogar" por rodada; **só "Batalhar"** dispara o `POST /battle/play`; classes de animação para revelar o log rodada a rodada.
- `public/style.css` — **animação CSS local** (fade/slide-in escalonado por entrada do log) + `prefers-reduced-motion` (a11y); sem polling/SSE e sem novo request.

### Testes

- `test/battle_service_test.rb` — `resolve`: resolve até `finished?`, teto 100, débito de itens de todas as rodadas, `finish_effects` 1× (XP/money guard).
- `test/battle_routes_test.rb` — `POST /battle/play` resolve tudo num request; log completo no fragmento; botão "Batalhar" presente / "Jogar" ausente; regressões (XP/money/record/HP once; invalidação/fainted/game over).
- `test/battle_log_presenter_test.rb` — modo completo (todas as rodadas); `DEFAULT_LIMIT` preservado.
- **Atualizar** testes que assumem 1 rodada/request ou limite 3: `test_battle_play_advances_one_round_and_refreshes_fragment` (`:201`), `test_battle_log_drops_rounds_older_than_three` (`:421`), `test_battle_fragment_has_play_button` (`:160`), `test_battle_play_button_has_local_hx_indicator` (`:170`), `test_returns_only_last_three_rounds`/`test_default_limit_is_three` (battle_log_presenter).

### Fora de escopo (não abrir)

- **Animação de painéis/HP/barras e projéteis** durante a resolução — a 0069 anima só o **log**; painéis/HP ficam para o **0063 juice** e a ideia C2 (animações nos ataques, `draft-auto-battler.md:704`).
- **Polling/SSE/streaming** da resolução — decisão fechada: resolução num único request.
- **Mudanças na economia** (XP/dinheiro/recompensas) — `finish_effects` 1× preservado; ajustes de valores/curvas seguem para sessão futura dedicada.
- **Persistência do log de batalha em DB** — hoje o log é derivado do engine em memória; persistir rodadas fica como ideia futura.
- **Mecânica de batalha em si** — `BattleEngine#battle` e o motor intocados.
- → Todos anotados no `draft-auto-battler.md` (RNF-04 — ver §8).

## 4. Critérios de aceite

### Resultado

- [ ] **C1 — `POST /battle/play` resolve a batalha inteira num único request** (todas as rodadas até `finished?`, sem cliques adicionais) — prova: `test/battle_routes_test.rb` (novo `test_battle_play_resolves_entire_battle_in_one_request`).
- [ ] **C2 — Itens automáticos (poções/seguráveis/use_stone) debitados de TODAS as rodadas**, não só da última (correção do gotcha `items_used_in_round`) — prova: `test/battle_service_test.rb` (novo `test_resolve_debits_items_from_all_rounds`) + regressão `test/battle_routes_test.rb` (`test_battle_play_debits_used_item_and_shows_heal_log`).
- [ ] **C3 — Recompensas (XP/dinheiro) concedidas UMA única vez** na transição para finalizada (`finish_effects` guardado: record + XP + money + evolução/aprendizado + rebuild + persist HP) — prova: `test/battle_routes_test.rb` (reuso `test_battle_play_grants_xp_once_on_transition_to_finished` + `test_battle_play_grants_money_once_on_transition_to_finished` + `test_battle_finish_persists_hp_only_once` + `test_battle_play_after_finish_does_not_duplicate_battle_record`) + `test/battle_service_test.rb` (`test_grant_finished_xp_guard_prevents_double_grant`).
- [ ] **C4 — Teto de rodadas (100 → força fim)** contra loop infinito teórico — prova: `test/battle_service_test.rb` (novo `test_resolve_stops_at_round_cap`).
- [ ] **C5 — Log completo**: todas as rodadas visíveis no estado final (limite 3 fora do caminho do resolve) — prova: `test/battle_log_presenter_test.rb` (novo `test_entries_all_returns_every_round`) + `test/battle_routes_test.rb` (novo `test_battle_log_shows_all_rounds_after_resolve`).
- [ ] **C6 — Botão manual "Jogar" removido; existe apenas "Batalhar"** — prova: `test/battle_routes_test.rb` (novo `test_battle_fragment_has_battle_button_and_no_play_button`, substitui `test_battle_fragment_has_play_button`/`test_battle_play_button_has_local_hx_indicator`).
- [ ] **C7 — Regressão: invalidação por add/remove/move, fainted mid-batalha, game over/spiral preservados** — prova: testes existentes verdes (`test/battle_routes_test.rb`: `test_removing_member_resets_prepared_battle` + `test_battle_blocked_when_all_hp_zero` + `test_finished_battle_shows_game_over_and_restart_when_broke`; `test/battle_service_test.rb`: `test_invalidate_clears_active_battle`) + `manual` na validação (navegador: add/remove/move invalida a batalha preparada; time todo `fainted?` bloqueia; spiral mostra banner Vender/Recomeçar).
- [ ] **C8 — UI revela o log rodada a rodada com animação CSS local** (fade/slide-in escalonado), sem polling/SSE e sem novo request, com `prefers-reduced-motion` (a11y) — prova: **`manual`** (inspeção visual via `./scripts/run` + navegador: clique em "Batalhar", rodadas aparecem escalonadas; com `prefers-reduced-motion` ativo, sem animação) + presença das classes de animação coberta pelo teste de C6.

### Garantias — teste que prova (S1)

| Critério | Teste que prova | Manual |
| --- | --- | --- |
| G1 (suíte+lint) | `./scripts/test` suíte completa (baseline 983/3819 + novos) + `./scripts/lint` 0 por green | — |
| G2 (sem gem/sem schema/API stub) | `git diff -- Gemfile db/` vazio + fake da API (sem rede — `test/poke_api_http_test.rb`) | — |
| G3 (S4/S5) | `./scripts/check_docs` + `./scripts/checar-sessao 0069` + `SESSIONS.md` atualizado no refinamento | — |

> **S1:** cada critério acima aponta o teste que o prova. C8 sem teste automatizado → `manual` explícito + evidência esperada. Baseline suíte 983/3819 da 0068.

## 5. Decisões de refinamento (fechadas com o usuário em 2026-09-02)

- **D1 — Resolução híbrida (A escolhida):** `POST /battle/play` resolve **todas as rodadas num único request** no servidor (novo `BattleService#resolve`); a UI revela o log **rodada a rodada com animação CSS local** (fade/slide-in escalonado), **sem polling/SSE e sem novo request**. Alternativas preteridas: (B) N requests htmx sequenciais (um por rodada — mantém o atrito do G4); (C) SSE/streaming (complexidade desnecessária para um log pequeno em memória).
- **D2 — Botão manual removido (A escolhida):** só existe "Batalhar" na UI; o "Jogar" por rodada sai (`views/battle.erb:74-75`). Alternativa preterida: manter "Jogar" como fallback (resolveria 1 rodada e exigiria novo clique — contradiz B5).
- **D3 — Log completo (A escolhida):** todas as rodadas visíveis no estado final; `BattleLogPresenter` ganha modo completo (`DEFAULT_LIMIT = 3` preservado para compat). Alternativa preterida: manter limite 3 (esconderia o desenrolar da batalha no resultado).
- **D4 — Economia preservada (A escolhida):** recompensas (XP/dinheiro) concedidas **uma única vez** na transição para finalizada (`finish_effects` guardado); fainted mid-batalha, game over/spiral, invalidação por add/remove/move — tudo preservado (C3/C7).
- **D5 — Correção do débito multi-rodada (A escolhida):** `resolve` debita itens automáticos de **todas** as rodadas (gotcha: `items_used_in_round` em `lib/battle_service.rb:212-215` seleciona só `round == engine.rounds`); **`BattleEngine#battle` (157-164) fica intocado** — 35 callers e contador `@rounds` local não atualizado (ver §8).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Parar ao fim da fase 2 e aguardar validação do usuário. P=pequena (2-3 passos) — sessão M (5-7 passos).

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (tabela + "Próxima sessão") + anotação do fora de escopo no `draft-auto-battler.md` (RNF-04) | commit `Sessao 0069: refinamento concluido — resolver batalha (B5), criterios e plano TDD fechados` |
| 1 | **red→green — C4+C1 núcleo `resolve` com teto** — `lib/battle_service.rb` novo `resolve(user_id)`: loopa `play_round` **atualizando `@rounds`** até `finished?` (ou teto 100 → força fim), `finish_effects` 1× quando cruzar, retorna `battle_payload`; `test/battle_service_test.rb` novos `test_resolve_plays_until_finished` + `test_resolve_stops_at_round_cap` | `./scripts/test test/battle_service_test.rb -n /resolve/` + suíte + lint 0; commit `Passo 1: BattleService#resolve loopa rodadas ate finished com teto de 100` |
| 2 | **red→green — C2 débito multi-rodada** — corrigir o gotcha: `resolve` debita itens de **todas** as rodadas (coletar `:item` de todo o log / por rodada, não só `round == engine.rounds`); `test/battle_service_test.rb` novo `test_resolve_debits_items_from_all_rounds` (poção usada na rodada 1 e 3 → 2 itens debitados) + regressão `test/battle_routes_test.rb` `test_battle_play_debits_used_item_and_shows_heal_log` | `./scripts/test test/battle_service_test.rb test/battle_routes_test.rb -n /debits|resolve/` + suíte + lint 0; commit `Passo 2: resolve debita itens automaticos de todas as rodadas (gotcha items_used_in_round)` |
| 3 | **red→green — C5 log completo + rota resolve (C1/C3)** — `lib/battle_log_presenter.rb` modo completo (`entries_all`/`limit:`); `server.rb` `POST /battle/play` → `resolve` (via `advance_battle`); `test/battle_log_presenter_test.rb` novo `test_entries_all_returns_every_round` (+ `DEFAULT_LIMIT` preservado); `test/battle_routes_test.rb` novos `test_battle_play_resolves_entire_battle_in_one_request` + `test_battle_log_shows_all_rounds_after_resolve`; **atualizar** `test_battle_play_advances_one_round_and_refreshes_fragment`/`test_battle_log_drops_rounds_older_than_three`/`test_returns_only_last_three_rounds`; reuso regressões XP/money/record/HP once (C3) | `./scripts/test test/battle_log_presenter_test.rb test/battle_routes_test.rb -n /resolve|rounds|entries_all|xp|money|hp/` + suíte + lint 0; commit `Passo 3: POST /battle/play resolve tudo num request e o log completo sai do limite 3` |
| 4 | **red→green — C6+C8 botão + animação** — `views/battle.erb`: remover "Jogar", botão **"Batalhar"** único (mesmo `hx-post`), classes de animação por entrada do log; `public/style.css` fade/slide-in escalonado + `prefers-reduced-motion`; `test/battle_routes_test.rb` novo `test_battle_fragment_has_battle_button_and_no_play_button` (substitui `test_battle_fragment_has_play_button`/`test_battle_play_button_has_local_hx_indicator`) | `./scripts/test test/battle_routes_test.rb -n /battle_button|play_button/` + suíte + lint 0; C8 visual → `manual` na validação; commit `Passo 4: botao Jogar removido (so Batalhar) + revelacao do log com animacao CSS escalonada e prefers-reduced-motion` |
| 5 | **red→green — C7 regressão completa + docs** — suíte completa (baseline 983/3819 + novos) verde: invalidação (`test_removing_member_resets_prepared_battle`), fainted (`test_battle_blocked_when_all_hp_zero`), game over/spiral (`test_finished_battle_shows_game_over_and_restart_when_broke`), `test_invalidate_clears_active_battle`; lint 0; `REQUIREMENTS.md`/`SESSIONS.md` no escopo docs (status de validação só após usuário — S4) | `./scripts/test` completa + `./scripts/lint` 0 + `./scripts/check_docs`; commit `Passo 5: regressao invalidação/fainted/game over preservada (resolve nao altera economia nem motor) + docs` |
| — | **Fase 2 concluída (5 passos)** → **Revisor (2c)**: loop Implementador↔Revisor até veredito `Aprovado` (teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar Done, não preencher a seção 7, não commitar conclusão. | — |

## 7. Validação (executada pelo usuário)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 resolve tudo num request | `test/battle_routes_test.rb` `test_battle_play_resolves_entire_battle_in_one_request` | `./scripts/run` + navegador: 1 clique em "Batalhar" leva ao resultado final | |
| C2 débito multi-rodada | `test/battle_service_test.rb` `test_resolve_debits_items_from_all_rounds` | — | |
| C3 recompensa 1× | `test_battle_play_grants_xp_once_on_transition_to_finished` + `test_battle_play_grants_money_once_on_transition_to_finished` + `test_battle_finish_persists_hp_only_once` | — | |
| C4 teto de rodadas | `test/battle_service_test.rb` `test_resolve_stops_at_round_cap` | — | |
| C5 log completo | `test/battle_log_presenter_test.rb` `test_entries_all_returns_every_round` + `test_battle_log_shows_all_rounds_after_resolve` | — | |
| C6 só "Batalhar" | `test/battle_routes_test.rb` `test_battle_fragment_has_battle_button_and_no_play_button` | — | |
| C7 regressão invalidação/fainted/game over | `test_removing_member_resets_prepared_battle` + `test_battle_blocked_when_all_hp_zero` + `test_finished_battle_shows_game_over_and_restart_when_broke` + `test_invalidate_clears_active_battle` | add/remove/move invalida; time todo fainted bloqueia; spiral mostra banner Vender/Recomeçar | |
| C8 animação CSS escalonada | — (presença das classes via C6) | `./scripts/run` + navegador: rodadas aparecem escalonadas; `prefers-reduced-motion` desliga a animação | |
| G1 suíte+lint | `./scripts/test` (baseline 983/3819 + novos) + `./scripts/lint` 0 | — | |
| G2 sem gem/schema/API stub | `git diff -- Gemfile db/` vazio + fake da API | — | |
| G3 S4/S5 | `./scripts/check_docs` ok + `./scripts/checar-sessao 0069` ok | — | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.

## 8. Observações

- **Gotcha `items_used_in_round` (`lib/battle_service.rb:212-215`):** seleciona `entry[:round] == engine.rounds` — num loop de N rodadas num único request, `engine.rounds` avança e o débito pegaria só a última rodada. O `resolve` precisa coletar itens de **todas** as rodadas (varredura do log inteiro ou coleta incremental por rodada).
- **Por que NÃO reusar `BattleEngine#battle` (`lib/battle_engine.rb:157-164`):** o contador `rounds` é **local** ao método (`play_round!` não atualiza `@rounds`) → `items_used_in_round` não acharia `entry[:round] == engine.rounds`; `battle` retorna `BattleResult` e **não passa** por `debit_used_items`/`finish_effects`/`battle_payload` (economia não seria aplicada); e tem **35 callers** (rankings/seeds/derivações) — não tocar. O caminho é o `BattleService#resolve` novo, espelhando o fluxo do `advance`.
- **Regra de parada:** ao concluir a fase 2 (TDD) com veredito do Revisor `Aprovado`, **PARAR** e aguardar a validação do usuário (fase 3); não marcar Done, não atualizar status de validação em `REQUIREMENTS.md`/`SESSIONS.md`, não commitar a conclusão (AGENTS.md).
- **Fora de escopo anotado no draft (RNF-04):** animação de painéis/HP (0063 juice / C2), polling/SSE, mudanças na economia, persistência do log em DB, mecânica de batalha — bloco novo no `draft-auto-battler.md` (§ Encerramento).
- **Fila após 0069:** **0063 juice** → Onda 3 Estabilidade (race add, escritas atômicas, CSRF, respiro — numeração desliza após a 0069) — a critério do usuário.
- Anotações fora do fluxo (não abrir nesta sessão): `BattleLogPresenter` modo completo com `DEFAULT_LIMIT` preservado (compat com o histórico/ranking); testes de rota que usam `play_until_finish` (`test/battle_routes_test.rb:748`) continuam válidos (multi-request ainda funciona — `advance` intacto).

## 9. Gotchas / Lições (memória — S6)

- `items_used_in_round` (`lib/battle_service.rb:212-215`) filtra `entry[:round] == engine.rounds` — em resolução multi-rodada num único request, só a última rodada seria debitada; coletar o log inteiro ou por rodada no `resolve`.
- `BattleEngine#battle` (`lib/battle_engine.rb:157-164`) usa contador `rounds` **local** (`play_round!`), não atualiza `@rounds` — reusá-lo quebraria o débito de itens e a contabilização; `BattleService#resolve` (que usa `play_round` + atualização de `@rounds`) é o caminho, com `BattleEngine` intocado (35 callers).
- `BattleLogPresenter::DEFAULT_LIMIT = 3` — o log completo exige **modo explícito** (não mudar o default silenciosamente; `test_default_limit_is_three` existe e o histórico/ranking dependem do limite).
- Reuso do guard de transição única (`finishing = !engine.finished?` do `advance`) no loop do `resolve` — `finish_effects` roda **uma vez**; as guardas de XP/money/record/HP já testadas continuam valendo.

### Gotchas da implementação (fase 2, 2026-09-02)

- **`./scripts/test -n` não aceita `|` no regex do filtro** — o rake quebra o `TESTOPTS` no `|` (`sh: 1: resolve/: not found`); usar um único token de regex (`-n /resolve/` cobre `test_resolve_*`) ou rodar os filtros em chamadas separadas.
- **`./scripts/test` com pipe (`| tail`) aborta de forma intermitente** (consumer fecha o pipe cedo + `pipefail`) — redirecionar para arquivo (`> /tmp/x.out`) é estável.
- **Entradas de log de item do engine real têm `attacker_index`** — fakes de engine para teste de débito precisam incluir `attacker_index`; sem ele, `members[nil]` estoura `TypeError: no implicit conversion from nil to integer` em `consume_used_item` (`lib/battle_service.rb:218`).
- **A resposta do play que resolve difere do play seguinte** — `learned_news`/`evolution_news` só aparecem na transição (`finish_effects` → news; play após o fim → `empty_news`). Teste de idempotência não pode comparar bytes do fragmento; comparar estado (rodada final/HP).
- **Testes de rota que assumiam 1 rodada/request podem "passar por coincidência"** — o log completo contém `Rodada 1`/`Rodada 2` (entradas do log), mascarando semânticas antigas; conferir nome/intenção, não só o resultado do assert.
- **`BattleEngine#initialize` tem `items:` default `{}`** — engine direto (sem `items:`) nunca usa poção; útil para provar "sem item usado → sem débito" no caminho do `resolve`.
- **Débito multi-rodada sem tocar o gotcha** — chamar `debit_used_items(user_id, engine)` **dentro** do loop logo após cada `play_round` faz `engine.rounds` apontar para a rodada recém-jogada, e o `items_used_in_round` existente (que filtra `round == engine.rounds`) passa a coletar todas as rodadas sem reescrever o método (mesmo padrão do `advance`).