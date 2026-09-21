# Sessão 0090 — cta-oob

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-09-21 |
| Implementação | **Pendente** |
| Validação | **Pendente** (revisão do PR — modo PR ativo) |

> Reprodução: manual
> E2E: nao
>
> Detalhe: sem seed — roteiro usa o time local via UI (§7, R1/R2). Harness e2e existe mas sem cobertura nova: critérios provados por Minitest no corpo do POST + roteiro manual no corpo do PR; e2e existente apenas segue verde.

---

## 1. Objetivo

O CTA "Batalhar" (gate + hint) do cabeçalho passa a atualizar via OOB nas rotas que mexem no time — sem F5, nos dois sentidos (T5 do `TODO.md`).

## 2. Contexto (estado atual — diagnóstico)

- `views/layout.erb:20-37` — lógica do gate (0083, C1): `cta_gated = @can_battle == false` (nil-safe p/ layout compartilhado); hint com 3 copies (`@game_over` / time vazio / precisa de cura); markup do CTA em `layout.erb:36-37` sem id estável.
- `@can_battle` vem de `journey.battle_ready?` (`server.rb:1041`, via `load_journey_state`); rotas com layout compartilhado deixam nil → CTA normal.
- Precedente do padrão: `#nav-badge` atualizado via OOB (`server.rb:621`, `hx-swap-oob="innerHTML"`); modais usam `.sub(... 'hx-swap-oob="outerHTML"')` (`server.rb:762,801,805`).
- Rotas que mexem no time: `POST /team` (`server.rb:1257`, outcomes add e budget-blocked), `DELETE /team` (`1261`), `POST /team/heal` (`1237`), `POST /mart/buy|sell` (`1293-1294`), `POST /journey/restart` (`1304`).
- Testes existentes: `test/layout_test.rb` (gate/hint no GET, ex. `test_battle_cta_gated_hint`), `test/team_routes_test.rb`, `test/modal_routes_test.rb` (heal), `test/journey_routes_test.rb`, `test/mart_routes_test.rb`.
- A pill de `views/team.erb:20-23` (4 estados: danger/empty/ready/stale) **não** muda.

## 3. Escopo

### Produção

- Novo partial `views/_cta_slot.erb` com slot de id estável (`#cta-slot`) contendo o CTA + hint (markup movido de `layout.erb:36-37`, lógica intacta); `layout.erb` passa a renderizá-lo.
- As 5 rotas anexam o fragmento `hx-swap-oob="outerHTML"` nas respostas; antes de emitir, popular o estado de jornada (`@can_battle`/`@team_size`/`@game_over`) — OOB com ivar vazio rende CTA errado (lição `gotchas/ux2-listagem-custo-tier.md`).

### Testes

- Estender arquivos existentes (sem arquivo novo): `test/team_routes_test.rb` (C1 add + budget-blocked, C2 delete), `test/modal_routes_test.rb` (C3 heal), `test/journey_routes_test.rb` (C4 restart), `test/mart_routes_test.rb` (C5 buy/sell). Cada teste assevera o estado do CTA **no corpo do POST**, não só no GET /.

### Fora de escopo (não abrir)

- Lógica do gate, copies do hint e os 4 estados da pill/0083 (M1); schema/migrações; e2e novo; dependências novas; T3/T4 e T1/T2 do `TODO.md`.

## 4. Critérios de aceite

### Resultado

- [ ] **C1** — `POST /team` (add e budget-blocked) inclui `#cta-slot` OOB com estado correto — prova: `test/team_routes_test.rb` (testes novos) + roteiro manual R1.
- [ ] **C2** — `DELETE /team` idem — prova: `test/team_routes_test.rb` (testes novos) + roteiro manual R1.
- [ ] **C3** — `POST /team/heal` idem — prova: `test/modal_routes_test.rb` (testes novos) + roteiro manual R2.
- [ ] **C4** — `POST /journey/restart` idem — prova: `test/journey_routes_test.rb` (testes novos) + roteiro manual R2.
- [ ] **C5** — `POST /mart/buy` e `POST /mart/sell` idem — prova: `test/mart_routes_test.rb` (testes novos) + roteiro manual R2.

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (1185/6332 da 0089)** + novos testes e lint 0 em **todo** green; commit obrigatório por passo; 0 regressão.
- [ ] Sem dependência nova / sem mudança de schema / testes sem rede / sem supressão de lint injustificada.
- [ ] `REQUIREMENTS.md` + `SESSIONS.md` atualizados no mesmo escopo do passo docs; *status de validação* só após o usuário validar revisando o PR (S4).
- [ ] **M1** — os 4 estados da pill/0083 inalterados — prova: testes existentes (`test/layout_test.rb`, asserts da pill).

> **S1:** cada critério acima aponta o teste que o prova. Roteiros manuais R1/R2 vão ao corpo do PR (E2E: nao).

## 5. Decisões de refinamento (fechadas com o usuário em 2026-09-21)

- **D1 — extração: (A) partial `views/_cta_slot.erb` + OOB `outerHTML`** — padrão `nav-badge` que o projeto já usa. Preteridas: (B) string inline no `server.rb` (markup no Ruby); (C) re-render do header inteiro (payload maior, mais risco).
- **D3 — asserts: estender os arquivos de rota existentes**, sem arquivo novo. Preterido: `test/cta_oob_test.rb` dedicado.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `Sessao 0090: refinamento concluido — ...` |
| 1 | Partial `#cta-slot` + OOB em `POST`/`DELETE /team` (C1, C2, inclui budget-blocked) | suíte verde + lint 0, commit `Passo 1:` |
| 2 | OOB em `POST /team/heal` + `POST /journey/restart` (C3, C4) | suíte verde + lint 0, commit `Passo 2:` |
| 3 | OOB em `POST /mart/buy\|sell` (C5) + M1 | suíte verde + lint 0, commit `Passo 3:` |
| — | **Fase 2 concluída** → corpo do PR (`sessions/pr/0090-pr-body.md`, `checar-pr`) → **Revisor (2c)** até `Aprovado` + `CORPO DO PR: publicável` (teto 3 rodadas, senão S3) → `abrir-pr 0090` → **PARAR** (fase 3 = revisão do PR). | `> PR: <url>` na §7 |

## 7. Validação (revisão do PR pelo usuário)

**Pendente.**

Roteiros manuais (vão ao corpo do PR):
- **R1:** home com time vazio → add 1 membro → CTA destrava **sem F5**; remove o membro → CTA volta a "Monte seu time" **sem F5**.
- **R2:** com time cheio e HP baixo → curar no Center → CTA destrava **sem F5**; comprar/vender no Mart e recomeçar a jornada atualizam gate + hint **sem F5**.

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 | `./scripts/test test/team_routes_test.rb` | R1 (add) | |
| C2 | `./scripts/test test/team_routes_test.rb` | R1 (remove) | |
| C3 | `./scripts/test test/modal_routes_test.rb` | R2 (curar) | |
| C4 | `./scripts/test test/journey_routes_test.rb` | R2 (restart) | |
| C5 | `./scripts/test test/mart_routes_test.rb` | R2 (mart) | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.

## 8. Observações

- Na sequência: `T3`/`T4` (achados `low` da rodada 3 da 0089) e `T1`/`T2` (flake do `SeedScriptsTest`, `db:setup` destrutivo).
- Cassettes não commitados em `test/cassettes/` (D5 da 0089, VCR acumulando episódios) — fora deste escopo.

## 9. Gotchas / Lições (memória — S6)

- *(a preencher na fase 2 — candidata: OOB do CTA exige estado de jornada populado na rota POST, como `@pokemon_costs` no OOB da lista.)*

<!-- sdd-pr:bloco -->
> **Modo PR ativo (`--with-pr`).** Bloco anexado pelo instalador. Para desligar o modo, remova
> este bloco junto com o bloco `SDD/PR` do `AGENTS.md` e os scripts `checar-pr`/`abrir-pr`.

## Declarações do modo PR (fechadas no refinamento)

Logo **abaixo** da tabela de `## Status`, escreva as duas linhas — e feche-as na fase 1, não
depois:

> Reprodução: seed|script|manual|nao-aplicavel
> E2E: sim|nao

- `Reprodução` responde: *como um terceiro chega ao estado inicial do teste?* Havendo script de
  seed/fixture no projeto, use `seed` ou `script` e cite o comando. Sem caminho automatizado,
  `manual`; sem cenário de estado a montar, `nao-aplicavel` **com a justificativa na mesma
  linha**.
- `E2E` responde: *o comportamento observável desta sessão tem teste de ponta a ponta?* Havendo
  harness, `sim`. Não havendo, `nao` — e então cada critério observável registra `manual` (S1) e
  o roteiro manual vai para o corpo do PR.

O `./scripts/checar-pr` confere que o `**Estado inicial:**` do corpo do PR bate com o valor
declarado aqui.

## A linha `Validação` do Status

No modo PR ela se refere à **revisão do PR**, não a uma execução local do usuário. Continua
`Pendente` até o usuário validar revisando o PR.

## Onde entra o link do PR (seção 7)

Ao abrir o PR (fim da fase 2, após o veredito `Aprovado`), registre na seção `## 7. Validação`:

> PR: <url>

A tabela por critério (S2) só é preenchida **depois do merge**. Um PR por sessão; o merge é do
usuário. Ajuste pedido na revisão reabre o critério (S3) e **atualiza o PR** — não abre um
segundo.
<!-- /sdd-pr:bloco -->
