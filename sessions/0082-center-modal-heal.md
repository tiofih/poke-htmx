# Sessão 0082 — center-modal-heal (cura via modal + OOB de saldo)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — roteamento confirmado em 2026-09-10 (modal-only desliza da 0080 §8; diagnósticos T16 a-b; playtest T20) |
| Implementação (fase 2, TDD) | Pendente |
| Validação (fase 3) | Pendente — **fase do usuário; ao fim da fase 2, PARAR e aguardar** |

---

## 1. Objetivo

Entregar a cura do time via modal (`_center_modal` → `_center`) com motivo inline quando desabilitada e re-render de saldo + modal após curar — **sem tocar economia, oponente, visual além do modal, nem migrações**.

## 2. Contexto (estado atual — diagnóstico)

- `_center.erb:13` — form `hx-post="/team/heal"` com `hx-target="#team-view"`; botão `disabled` quando `heal_cost.zero?` ou `balance < heal_cost`, **sem motivo inline** (T20 high).
- `_center_modal.erb:8` — renderiza `_center` dentro do overlay; rota `GET /team/center/close` existe; `POST /team/heal` responde via `heal_team` (server.rb:1109) sem fechar modal nem OOB de saldo dedicado (T16 a-b).
- `team_view_oob` (server.rb:617) é o padrão OOB existente para re-render de saldo/time.
- Base: 0047 (componentes center/mart), 0028 (poke-center), 0065 (bloqueio total da cura).

## 3. Escopo

### Produção

- **`views/_center.erb`** — motivo inline no `disabled` (ex.: "time já curado" quando custo zero; "saldo insuficiente" quando `balance < heal_cost`).
- **`server.rb` (`heal_team`)** — após curar: fechar/atualizar modal + re-render de saldo via OOB (`team_view_oob`, layout false), mantendo `hx-target`/swap coerentes com o modal.
- **`views/_center_modal.erb` / `_center_slot.erb`** — ajuste mínimo de target/swap se necessário para o fluxo modal-only.

### Testes

- `test/modal_routes_test.rb` (C1), `test/team_routes_test.rb` + `test/mart_routes_test.rb` (C2) como regressão/apoio; novos asserts de motivo inline e OOB.

### Fora de escopo (não abrir)

- Regras de economia (`heal_cost_policy`/`heal_service`, valores de custo — 0081); oponente/banda; home/battle/history; CSRF/escritas atômicas/respiro; migrações; cura parcial.

## 4. Critérios de aceite

### Resultado (S1 — cada critério aponta o teste que o prova)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| C1 modal heal fecha+atualiza: `POST /team/heal` via modal fecha ou re-renderiza o modal (time curado) e re-renderiza `#team-view`; motivo inline visível quando desabilitado | `test/modal_routes_test.rb` `test_heal_via_modal_closes_and_rerenders` (novo; `test_center_modal_renders_heal_form` como regressão) | pendente |
| C2 budget OOB atualiza: após curar, saldo re-renderiza via OOB (`team_view_oob`, layout false) com novo saldo e custo | `test/team_routes_test.rb` `test_heal_rerenders_balance_oob` (novo; `test/mart_routes_test.rb` heal existente como regressão) | pendente |

### Garantias

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| G1 sem regressão — suíte completa + lint 0 | `./scripts/test` + `./scripts/lint` | pendente |
| G2 escopo contido — sem mudança de regra de custo/economia; só modal + OOB | `git diff --stat -- lib/heal_cost_policy.rb lib/heal_service.rb lib/reward_rule.rb` vazio + revisão S7 confere | pendente |
| G3 docs + revisão — `checar-sessao 0082` verde; revisor S7 `Aprovado` antes da 3 | `./scripts/checar-sessao 0082` + veredito do Revisor | pendente |

> **S1:** cada critério acima aponta o teste que o prova (arquivo + método). Motivo inline (C1) tem assert de corpo (`"já curado"` / `"saldo insuficiente"`); OOB (C2) tem assert de fragmento `team_view_oob`/saldo. **Ao fim da fase 2 (suíte + lint verdes, revisor S7 `Aprovado`), PARAR e aguardar a validação do usuário — não marcar Done, não preencher a seção 7, não commitar conclusão.**

## 5. Decisões de refinamento (fechadas, sem reabrir)

- **Rota 0082 = center-modal-heal:** modal-only desliza da reserva informal da 0080 §8 para a 0082; 0081 (tuning economia/progressão) prevalece na sua faixa — fila: … → 0080 convergência → **0081 tuning** → **0082 center-modal-heal** → 0083 escritas atômicas → 0084 CSRF → 0085 respiro.
- **Alvo modal:** `_center.erb:13` como ponto de intervenção (target/swap do form de cura); saldo via OOB `team_view_oob`.
- **Diagnósticos T16 a-b:** fechar/atualizar modal + OOB de saldo após `POST /team/heal` (sem eles o modal fica obsoleto).
- **Playtest T20 high:** motivo inline no `disabled` + re-render saldo+modal (sem motivo o jogador não entende por que não pode curar).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Termina em Revisor (2c, S7, teto 3 rodadas) → **PARAR** p/ validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo (sem `SESSIONS.md`/backlog/commit, por ordem da tarefa) | arquivo criado em `sessions/0082-center-modal-heal.md` |
| 1 | **red→green — C1 (motivo inline + modal heal)** — `_center.erb` exibe motivo quando desabilitado; `heal_team` fecha/re-renderiza modal + `#team-view`; novo `test_heal_via_modal_closes_and_rerenders` | `./scripts/test test/modal_routes_test.rb` + suíte + lint 0; commit `Passo 1: cura via modal com motivo inline` |
| 2 | **red→green — C2 (budget OOB)** — resposta do heal inclui OOB `team_view_oob` com novo saldo/custo; novo `test_heal_rerenders_balance_oob` | `./scripts/test test/team_routes_test.rb test/mart_routes_test.rb` + suíte + lint 0; commit `Passo 2: saldo via OOB apos curar` |
| 3 | **red→green — G1/G2/G3 (regressão + docs)** — suíte + lint 0 + `checar-sessao 0082` | `./scripts/test` + `./scripts/lint` + `./scripts/checar-sessao 0082`; commit `Passo 3: regressao e docs — center modal heal` |
| — | **Fase 2 concluída** → **Revisor (2c)** até `Aprovado` (teto 3, senão S3) → **PARAR**, aguardar **validação 3**. Não marcar Done, não preencher §7, não commitar conclusão. | — |

## 7. Validação (executada pelo usuário — S2)

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 (modal heal fecha+atualiza) | | | pendente |
| C2 (budget OOB atualiza) | | | pendente |
| G1 (sem regressão) | | | pendente |
| G2 (escopo contido) | | | pendente |
| G3 (docs + revisão) | | | pendente |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário. **Ao fim da fase 2, PARAR na fase 2 — não preencher esta seção, não marcar Done, não commitar conclusão sem a validação do usuário (fase 3).**

## 8. Observações

- **Não tocado nesta tarefa (por ordem):** `SESSIONS.md`, `draft-backlog`, commits.
- **Dependência de leitura da 0081:** se a 0081 mudar `heal_cost_policy`/`preview_cost`, o motivo inline (C1) e o OOB (C2) acompanham os novos valores sem redefinir regra.

## 9. Gotchas / Lições (memória — S6)

A preencher na validação (fase 3): armadilhas de target/swap no modal, OOB de saldo, motivo inline.
