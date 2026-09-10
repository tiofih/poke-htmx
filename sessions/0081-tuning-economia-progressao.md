# Sessão 0081 — tuning-economia-progressao (reconciliar progressão + conter inflação)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — escolhas do usuário em 2026-09-10 (objetivo B, escopo B, critérios A, P1-A, P2-A, P3-A, esteira oponente A, tamanho A — ver seção 5) |
| Implementação (fase 2, TDD) | Pendente |
| Validação (fase 3) | Pendente — **fase do usuário; ao fim da fase 2, PARAR e aguardar** |

---

## 1. Objetivo

Reconciliar a progressão (XP real via `xp_for`/`level_for_xp`, fim do bypass `grant_levels` e da ilusão 25x do sweep) e conter a inflação (derrota sem nível, cura escalando com o nível médio) — **sem tocar visual, oponente, TeamBudget nem migrações destrutivas**.

## 2. Contexto (estado atual — diagnóstico recebido, sem re-derivação)

- **Ritmo real nv1→5 em 2 vitórias** via `grant_levels` direto; o sweep mede o caminho morto `xp_for` (ilusão 25x) — a curva real (`ExperienceCurve`) virou display.
- **Economia inflacionária:** drains não escalam, `lose=+1` igual a `draw=+1` (derrota premia como empate).
- **Oponente:** esteira fora desta sessão (só documentar o impacto).
- Base: 0067 (nível 5 inicial + `RewardRule#levels_for` win +2/draw +1/lose +1 via `grant_levels`); 0065 (bloqueio total da cura, `preview_cost`, `cost_per_hp` 0.5/HP).

## 3. Escopo

### Produção

- **`lib/reward_rule.rb`** — `lose_levels` 0 (P1-A).
- **`lib/heal_cost_policy.rb` + `lib/heal_service.rb`** — custo da cura escala com o nível médio do time (P2-A).
- **`lib/progression_repository.rb` + `lib/battle_service.rb`** — reconciliação real via `xp_for`/`level_for_xp` (P3-A; fim do bypass `grant_levels` no caminho de recompensa).
- **`scripts/sweep-balance.rb`** — mede o caminho real reconciliado (fim da ilusão 25x).

### Testes

- `test/reward_rule_test.rb` (C1), `test/heal_cost_policy_test.rb` + `test/heal_service_test.rb` (C2), `test/progression_repository_test.rb` + `test/battle_service_test.rb` (C3) + saída do sweep como evidência.

### Fora de escopo (não abrir — RNF-04)

- Visual (views/CSS/juice); oponente (`OpponentGenerator`, banda, pool — só documentar); `TeamBudget`/orçamento 450; migrações destrutivas (sem reescrever XP/nível histórico); cura parcial (0065 mantém bloqueio total); CSRF/escritas atômicas/respiro.

## 4. Critérios de aceite

### Resultado (S1 — cada critério aponta o teste que o prova)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| C1 derrota sem nível: `RewardRule#levels_for(:lose)` = 0 (draw segue +1, win +2) | `test/reward_rule_test.rb` `test_levels_for_lose_is_zero` (novo; `test_levels_for_draw_is_one`/`test_levels_for_win_is_two` como regressão) | pendente |
| C2 cura escala com nível: custo total = `policy.cost(missing_hp, average_level)` — time de nível médio maior paga mais pelo mesmo HP faltante; `preview_cost` acompanha; bloqueio total mantido | `test/heal_cost_policy_test.rb` `test_cost_scales_with_average_level` (novo) + `test/heal_service_test.rb` `test_heal_charges_scaled_cost` (novo) | pendente |
| C3 reconciliação real: `grant_finished_xp` concede XP via `xp_for`/`level_for_xp` (nível derivado da curva, sem `grant_levels` no caminho de recompensa); nv1→5 exige o nº real de vitórias; sweep mede o caminho real | `test/progression_repository_test.rb` `test_grant_recalculates_level_when_crossing_curves` (existente, regressão) + `test/battle_service_test.rb` `test_finished_win_grants_curve_xp` (novo) + saída de `scripts/sweep-balance.rb` como evidência | pendente |

### Garantias

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| G1 sem regressão — suíte completa + lint 0 | `./scripts/test` + `./scripts/lint` | pendente |
| G2 escopo contido — sem migração destrutiva; visual/oponente/TeamBudget intocados | `git diff --stat -- db/ views/ public/ lib/opponent_generator.rb lib/team_budget.rb` vazio + revisão S7 confere | pendente |
| G3 S4/S5 + revisão — `SESSIONS.md` + `check_docs` + `checar-sessao 0081` verdes; revisor S7 `Aprovado` antes da 3 | `./scripts/check_docs` + `./scripts/checar-sessao 0081` + veredito do Revisor | pendente |

> **S1:** cada critério acima aponta o teste que o prova (arquivo + método). Não há critério puramente manual nesta sessão. **Ao fim da fase 2 (suíte + lint verdes, revisor S7 `Aprovado`), PARAR e aguardar a validação do usuário — não marcar Done, não preencher a seção 7, não commitar conclusão.**

## 5. Decisões de refinamento (escolhas do usuário em 2026-09-10 — fechadas, sem reabrir)

- **Objetivo = B (reconciliar progressão + conter inflação):** nem só ritmo (A) nem só economia (C) — os dois juntos, numa sessão.
- **Escopo = B médio:** `reward_rule`, `heal_cost_policy`/`heal_service`, `progression_repository`/`battle_service`, sweep + testes; fora: visual, oponente, TeamBudget, migrações destrutivas.
- **Critérios = A granulares:** C1 lose→`reward_rule_test`, C2 cura→heal tests, C3 XP/sweep→progression+battle tests (em vez de um critério único).
- **P1 = A:** `lose_levels` 0 (derrota não dá nível; draw segue +1).
- **P2 = A:** cura escala com o nível médio do time (drain que acompanha a progressão).
- **P3 = A:** reconciliação real via `xp_for`/`level_for_xp` (fim do bypass `grant_levels` no caminho de recompensa; curva volta a ser fonte da verdade).
- **Esteira oponente = A (fora, documentar):** impacto no `OpponentGenerator`/banda registrado em §8, sem código.
- **Tamanho = A (1 sessão):** tudo nesta sessão, sem fatiar.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Termina em Revisor (2c, S7, teto 3 rodadas) → **PARAR** p/ validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (linha 0081 + "Próxima sessão") | commit `Sessao 0081: refinamento concluido — ...` |
| 1 | **red→green — C1 (derrota sem nível)** — `lose_levels` 0 em `lib/reward_rule.rb`; novo `test_levels_for_lose_is_zero` em `test/reward_rule_test.rb` | `./scripts/test test/reward_rule_test.rb` + suíte + lint 0; commit `Passo 1: derrota sem nivel (lose_levels 0)` |
| 2 | **red→green — C2 (cura escala com nível médio)** — `cost(missing_hp, average_level)` em `lib/heal_cost_policy.rb` + `heal_service`/`preview_cost` acompanham, bloqueio total mantido; novos `test_cost_scales_with_average_level` + `test_heal_charges_scaled_cost` | `./scripts/test test/heal_cost_policy_test.rb test/heal_service_test.rb` + suíte + lint 0; commit `Passo 2: custo da cura escala com o nivel medio` |
| 3 | **red→green — C3 (reconciliação real)** — `grant_finished_xp` via `xp_for`/`level_for_xp` (fora `grant_levels` do caminho de recompensa) em `lib/progression_repository.rb` + `lib/battle_service.rb`; novo `test_finished_win_grants_curve_xp`; `scripts/sweep-balance.rb` mede o caminho real | `./scripts/test test/progression_repository_test.rb test/battle_service_test.rb` + sweep + suíte + lint 0; commit `Passo 3: recompensa via curva real, fim do bypass` |
| 4 | **red→green — G1/G2/G3 (regressão + docs)** — suíte + lint 0 + `check_docs` + `checar-sessao 0081` | `./scripts/test` + `./scripts/lint` + `./scripts/check_docs` + `./scripts/checar-sessao 0081`; commit `Passo 4: regressao e docs — tuning de economia e progressao` |
| — | **Fase 2 concluída** → **Revisor (2c)** até `Aprovado` (teto 3, senão S3) → **PARAR**, aguardar **validação 3**. Não marcar Done, não preencher §7, não commitar conclusão. | — |

## 7. Validação (executada pelo usuário — S2)

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 (derrota sem nível) | | | pendente |
| C2 (cura escala com nível) | | | pendente |
| C3 (reconciliação real) | | | pendente |
| G1 (sem regressão) | | | pendente |
| G2 (escopo contido) | | | pendente |
| G3 (docs + revisão) | | | pendente |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário. **Ao fim da fase 2, PARAR na fase 2 — não preencher esta seção, não marcar Done, não commitar conclusão sem a validação do usuário (fase 3).**

## 8. Observações

- **Impacto no oponente (esteira A — só documentado, sem código):** ritmo real mais lento (nv1→5 em mais vitórias) atrasa `average_player_level` → banda e `opponent level` sobem mais devagar; dreno maior da cura escala o custo do ciclo batalha→center. O `OpponentGenerator` não é tocado — reavaliar a banda só depois da validação desta sessão.
- **Colisão de numeração:** a sessão 0080 §8 reservava informalmente a 0081 para `center-mart-modal-only` (item 5) — **esta 0081 (tuning) prevalece por decisão do usuário**; o modal-only desliza para a 0082 (a registrar no refinamento dela; fila: 0077 home → 0078 battle → 0079 history → 0080 convergência → **0081 tuning** → 0082 center-mart-modal → 0083 escritas atômicas → 0084 CSRF → 0085 respiro).
- **Sem migração destrutiva:** times/XP existentes preservados; a curva reconciliada vale para ganhos futuros (migração retroativa segue fora).
