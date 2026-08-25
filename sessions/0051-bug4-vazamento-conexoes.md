# Sessão 0051 — BUG-4: vazamento de conexões PG em produção (ConnectionRegistry)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-25 |
| Implementação | **Concluída** — passos 1–3 em 2026-08-25 (suíte 755/2404, lint 0) |
| Validação | **Done** — executada pelo usuário em 2026-08-25 (tabela da seção 7) |

---

## 1. Objetivo

Impedir que o app **acumule conexões PG em produção** ("too many clients", limite 100
do PostgreSQL): liberar as conexões da thread ao fim de cada request e **capear** o
`ConnectionRegistry` com evicção (LRU, preferindo threads mortas), preservando o
isolamento por thread (0044).

## 2. Contexto (estado atual — diagnóstico)

- `lib/connection_registry.rb` — registra **uma conexão por (repositório, `thread_id`)**:
  `connection_for(owner, thread_id, db_url)` cria `PG.connect` e guarda em `@entries`
  (mutex). A única limpeza é **`close_all!`**, chamada só no `after_teardown` do Minitest
  (`test/test_helper.rb:24`) — em **produção nunca roda**.
- 7 repositórios + `seed_team.rb` usam `connection_for(self, Thread.current.object_id, @db_url)`
  (ex.: `lib/team_repository.rb:248`). São singletons compartilhados pelas threads do
  Puma (`server.rb` → `run!`); cada request toca vários repositórios na thread da request.
- **Observado no benchmark da 0050 (2026-08-25):** após ~50 requests (sequenciais, curl),
  o app chegou a **80 conexões no `pokedex`** (`pg_stat_activity`) → somado ao limite 100
  do PG, derrubou a suíte com "too many clients already" (workaround `docker compose stop web`).
  Causa: `Puma threads × repos` sem liberação — conexões nunca fecham.
- O isolamento por thread (0044) **deve ser preservado**: conexão exclusiva por
  (repositório, thread) evita a corrupção de protocolo ("message type while idle") de uma
  conexão compartilhada sob concorrência.

## 3. Escopo

### Produção

- `lib/connection_registry.rb`:
  - `MAX_CONNECTIONS` — teto global (default **30**, via `ENV["PG_MAX_CONNECTIONS"]`);
    entrada do registro ganha `last_used_at` (relógio monotônico) e `thread` (o objeto).
  - `connection_for`: bump `last_used_at` no hit; no miss, **evicção** quando `size >=
    MAX_CONNECTIONS` — fecha a entrada de **thread morta** (se houver) ou a **LRU**,
    removendo-a antes de criar a nova.
  - `release_current_thread!` — fecha e remove **todas** as entradas da thread atual
    (mesma chave `Thread.current.object_id`). `close_all!` preservado (testes/exit).
- `server.rb` — **`after { ConnectionRegistry.release_current_thread! }`**: ao fim de cada
  request, a thread libera suas conexões (próximo request na mesma thread reconecta —
  custo ~ms). Bounds o pico a (requests concorrentes × repos) e o teto `MAX_CONNECTIONS`
  cobre o caso de pico de concorrência.

### Testes

- `test/connection_registry_test.rb`:
  - `test_release_current_thread_closes_and_removes_entries` — registra 2 repos na thread,
    `release_current_thread!` → `size == 0` e conexões `finished?`.
  - `test_caps_total_connections_with_lru_eviction` — enche além do teto (threads falsas
    distintas) → `size <= MAX_CONNECTIONS`; a conexão menos usada foi fechada.
  - `test_eviction_prefers_dead_threads` — thread morta evictada antes da LRU viva.
  - Existentes seguem verdes (registra/close_all/mede contagem de conexões abertas).
- `test/battle_routes_test.rb` (ou novo em `connection_registry_test` via `Rack::Test`) —
  **C3**: após um request em rota que toca repositórios (ex. `GET /` ou `GET /battle`),
  `ConnectionRegistry.size == 0` (o `after` liberou a thread).

### Fora de escopo (não abrir)

- Pool de conexões com checkout/checkin por operação (refactor dos 7 repositórios) —
  desnecessário p/ o caso real (baixa concorrência) e grande.
- Trocar Puma por outro servidor; configurar threads do Puma; pgbouncer.
- Reduzir `max_connections` do PG (config de infra, não do app).
- Resto do QA (Q2/Q3/Q5), GL-2, fila (J2/J4/D4/M2).

## 4. Critérios de aceite

### Resultado

- [ ] **C1 — `ConnectionRegistry#release_current_thread!` fecha e remove as entradas da
      thread atual** — prova: `test/connection_registry_test.rb`
      (`test_release_current_thread_closes_and_removes_entries`).
- [ ] **C2 — Registro tem teto `MAX_CONNECTIONS` com evicção** (thread morta primeiro,
      senão LRU) — prova: `test/connection_registry_test.rb`
      (`test_caps_total_connections_with_lru_eviction`,
      `test_eviction_prefers_dead_threads`).
- [ ] **C3 — App libera as conexões da thread ao fim de cada request** (`after` no
      `server.rb`) — prova: `test/battle_routes_test.rb`
      (`test_request_releases_thread_connections`) + manual (`pg_stat_activity` não
      acumula após requests; suíte roda com o `web` ativo).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (751 runs/2391 asserts)** + novos
      testes e lint 0 em **todo** green; commit obrigatório por passo; 0 regressão.
- [ ] Isolamento por thread preservado (0044): cada request usa conexões exclusivas da
      sua thread; sem gems novas / sem mudança de schema / sem `rubocop:disable`.
- [ ] `REQUIREMENTS.md` (limitação marcada) + `SESSIONS.md` + `draft-auto-battler.md`
      (BUG-4 corrigido) atualizados no mesmo escopo do passo docs; *status de validação*
      só após o usuário validar (S4).

> **S1:** cada critério acima aponta o teste que o prova (arquivo/nome Minitest).
> Sem teste automatizado → `manual` explícito.

## 5. Decisões de refinamento (fechadas com o usuário)

- **2026-08-25 — BUG-4 vira 0051** (escolha do usuário após validar a 0050).
- **2026-08-25 — Fix: liberação por request + teto global.** `after` no `server.rb`
  chama `release_current_thread!` (fecha as conexões da thread ao fim de cada request) e
  o registry ganha `MAX_CONNECTIONS` (30, env `PG_MAX_CONNECTIONS`) com **evicção LRU
  preferindo thread morta**. Preteridos: pool por operação nos 7 repositórios (refactor
  grande, desnecessário p/ baixa concorrência); só `close_all!` periódico (sem cobertura
  do pico de concorrência); configurar threads do Puma (muda comportamento do app).
- **2026-08-25 — Trade-off da evicção documentado:** fechar a LRU sob pico de
  concorrência (todos ativos) tem risco teórico de fechar conexão em uso; mitigado por
  preferir threads mortas + a liberação por request torna as conexões curtas. Caso real
  (concorrência baixa) não chega perto do teto.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (S4) | commit `Sessao 0051: refinamento concluido — ...` |
| 1 | C1 — `release_current_thread!` no `ConnectionRegistry` (fecha/remove entradas da thread) | suíte verde + lint 0, commit `Passo 1:` |
| 2 | C2 — `MAX_CONNECTIONS` + evicção (thread morta primeiro, senão LRU) | suíte verde + lint 0, commit `Passo 2:` |
| 3 | C3 — `after` no `server.rb` libera a thread + teste de rota (`ConnectionRegistry.size == 0` pós-request) | suíte verde + lint 0, commit `Passo 3:` |
| 4 | **Docs:** REQUIREMENTS.md (limitação do vazamento marcada corrigida + roadmap), SESSIONS.md (0051 fase 2 + próximas), draft-auto-battler.md (BUG-4 executado) | suíte verde + lint 0, commit `Passo 4:` |
| — | **Fase 2 concluída** → **PARAR** para validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Concluída em 2026-08-25 — validada pelo usuário** *(S2: uma linha por critério).*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 release da thread | `./scripts/test test/connection_registry_test.rb` | — (componente puro) | ok |
| C2 teto + evicção LRU | `./scripts/test test/connection_registry_test.rb` | — (componente puro) | ok |
| C3 liberação por request | `./scripts/test test/battle_routes_test.rb` | app de pé: `pg_stat_activity` **estável em 14 conexões** no `pokedex` após ~18 requests (antes: 80 e subindo); suíte verde **com o `web` ativo** (755/2404) | ok |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

- Reconfirmar o baseline da suíte na implementação (751/2391 da 0050) e rodá-la **com o
  `web` ativo** ao final (a fix permite a suíte conviver com o app).
- Depois de implementar, validar com benchmark manual: `pg_stat_activity` deve ficar
  estável (~dezenas baixas) após vários requests, e a suíte roda verde com o `web` up.
- O `after` roda também nos testes de rota (Rack::Test) — libera a thread a cada request;
  não afeta `TestDatabase` (usa `with_db` próprio, fora do registry).