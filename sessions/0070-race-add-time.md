# Sessão 0070 — race-no-add-do-time (Onda 3 Estabilidade: race no `add` do time)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-09-08 (D1 B, D2 A, D3 A, D4 A) |
| Implementação | **Pendente** |
| Validação | **Pendente** (executada pelo usuário) |

---

## 1. Objetivo

Corrigir a **race completa do `add`** do time: a colisão de **slot** (`(user_id, slot)`) e a de **número duplicado** (`(user_id, number)`) — ambas **check-then-insert** que lançam `PG::UniqueViolation` (HTTP 500) sob concorrência — com **um único mecanismo** no `TeamRepository#add`: `rescue PG::UniqueViolation` + **retry com re-deriva de `next_free_slot`** (até `MAX_TEAM_SIZE` tentativas), mantendo o lançamento de `TeamFullError`/`DuplicateError` após esgotar.

## 2. Contexto (estado atual — diagnóstico)

- **Baseline pós-0063:** suíte **995/3938** lint 0 (0063: `Sessão 0063` Done — validado em 2026-09-08). Onda 3 Estabilidade (0069 race add → 0070 escritas atômicas → 0071 CSRF → 0072 respiro) — **numeração deslizou** (0069 virou resolver-batalha, 0063 juice fechou a Onda 2 Economia). `SESSIONS.md:385` "**Próxima após a 0063:** Onda 3 Estabilidade (race add, escritas atômicas, CSRF, respiro — numeração desliza)".
- **Anotação em `REQUIREMENTS.md` (Limitações):** "Race no `add` do time (anotado 2026-08-20): `next_free_slot` é check-then-insert" — esta sessão atende essa limitação.
- **O bug (confirmado no código):** `lib/team_repository.rb:171-179` `add(user_id, pokemon)` faz **dois check-then-insert fora de transação**:
  1. `next_free_slot(user_id)` (`lib/team_repository.rb:241-247`) — SELECT `slot ORDER BY slot` → acha o primeiro livre em `1..MAX_TEAM_SIZE`; depois `insert_team_member` com esse `slot`. Sob corrida, duas threads leem o mesmo livre → colidem em **`(user_id, slot)`** → `PG::UniqueViolation`.
  2. `duplicate?(user_id, pokemon.number)` (`lib/team_repository.rb:249-254`) — SELECT 1 `WHERE user_id AND number`; depois INSERT. Sob corrida, duas threads inserem o mesmo `number` → colidem em **`(user_id, number)`** → `PG::UniqueViolation`.
  - Ambos os `PG::UniqueViolation` escapam do `rescue TeamRepository::TeamFullError, TeamRepository::DuplicateError` do `server.rb:557` → **HTTP 500**.
- **Fluxo de chamada:** `settings.team = TeamRepository.new` (`server.rb:1171`) — o `add` é chamado **direto** do `server.rb:555` (`settings.team.add(current_user, pokemon)` dentro de `add_team_notice`). `TeamService` **não tem método `add`**. A guarda atual (raise `TeamFullError`/`DuplicateError`) vive no **próprio repo**, resgatada no `server.rb:557` → `e.message` vira `@notice` (`add_team_success`/`budget_blocked_response` → `notice--error`).
- **Índices únicos já existem** (`db/migrations/0007_add_slot.sql`): linha 6 `CREATE UNIQUE INDEX idx_team_pokemons_user_number ON team_pokemons (user_id, number)`; linha 7 `idx_team_pokemons_user_slot ON team_pokemons (user_id, slot)`. **Não há migração a fazer** — a unicidade já é garantida pelo banco; só falta o repo lidar com a violação.
- **`MAX_TEAM_SIZE = 6`** (`lib/team_repository.rb:147`); `TeamFullError` (`:150`) / `DuplicateError` (`:151`).
- **`ConnectionRegistry` já é thread-safe** (`lib/connection_registry.rb`): **uma conexão por (repositório, thread)** — `connection_for(owner, Thread.current.object_id, @db_url)` (`:21-31`) com `Mutex` + teto `MAX_CONNECTIONS` + evicção; `release_current_thread!` (`:33`) libera no `after` de cada request. Isso permite **teste com threads reais** sem corromper o protocolo PG ("message type ... arrived from server while idle" — comentário `:7`).
- **Testes existentes** (reaproveitáveis): `test/team_repository_test.rb` `TeamAddTest` — `test_add_rejects_duplicate_number_with_duplicate_error` (`:22`), `test_add_rejects_seventh_pokemon_with_team_full_error` (`:46`), `test_add_assigns_slots_in_insertion_order_and_persists_slot` (`:56`); `test/team_routes_test.rb` — `test_post_team_when_full_returns_warning_and_keeps_six` (`:232`, assert `"Time cheio"` + 200 + `6`), `test_post_team_with_duplicate_returns_warning_and_does_not_insert` (`:249`).
- **Preservar:** `TeamRepository` segue "burro" (atomicidade é **integridade**, não regra de negócio — D2 A); comportamento/UX de `TeamFullError` ("Time cheio") e `DuplicateError` ("já está no time") **inalterados** (D3 A); `remove`/`move`/`set_moves`, schema/migrações, `lib/battle_*`/`mart_service`/`heal_service` intocados; suíte/lint verdes.

## 3. Escopo

### Produção

- `lib/team_repository.rb#add` (`:171-179`) — envolver o insert com **retry em `PG::UniqueViolation`**:
  - Loop de até `MAX_TEAM_SIZE` tentativas (ou contador configurável). Em cada tentativa: re-deriva `next_free_slot(user_id)` → se `nil`, raise `TeamFullError` (time realmente cheio); re-checa `duplicate?(user_id, pokemon.number)` → raise `DuplicateError`; senão `connection.transaction { create_progress(insert_team_member(...)) }`.
  - `rescue PG::UniqueViolation => e` → re-tenta (a violação veio da corrida, não de regra). Após esgotar as tentativas, **re-levanta** `TeamFullError`/`DuplicateError` conforme a condição final (ou o próprio `e` se não diagnosticável).
  - **Sem migração** (índices únicos já existem em `0007_add_slot.sql`).
- Nenhuma mudança em `server.rb`/views (UX preservada — D3 A), nenhuma em `TeamService`.

### Testes

- `test/team_repository_test.rb` **novos** (`TeamAddTest` ou classe `TeamAddConcurrencyTest`):
  - **C1** `test_concurrent_adds_do_not_raise` — **threads reais** no `TeamRepository`: N threads chamando `add` pro mesmo `user_id` ao mesmo tempo (barreira/latch); assert **sem exceção**, `all(user_id).size == N`, slots contíguos `1..N`.
  - **C2** `test_concurrent_add_same_number_does_not_duplicate` — 2 threads, mesmo pokemon (`number` igual); assert **1 membro** com aquele `number` (o perdedor levanta `DuplicateError`, sem 500/duplicar).
  - **C3** reaproveita `test_add_rejects_seventh_pokemon_with_team_full_error` (já existe — `TeamFullError` em time cheio) — deve continuar verde **após** o retry.
- `test/team_routes_test.rb`:
  - **C3 (rota)** `test_post_team_full_returns_error_notice` — add com 6 membros → `POST /team` devolve **200 + aviso "Time cheio"** (`notice--error`), sem 500. Pode reaproveitar/adaptar `test_post_team_when_full_returns_warning_and_keeps_six`.
  - **C4** `test_concurrent_post_team_no_500` — **2–3 threads** com `PokeApiStub.with_find` distintos pro mesmo user; `last_response.ok?` em todas, sem 500, contagem final correta.

### Fora de escopo (não abrir — RNF-04)

- **Escritas não atômicas da batalha/compra** (anotado 2026-08-20) — próxima sessão (0071 ou respiro).
- **Identidade/`?as=`/CSRF** — sessão própria.
- **Erros sem status real** (handler global) — sessão própria.
- **`pry` no boot de produção**, **CI** — sessão própria.
- **Estado transiente / migrações destrutivas** — fora.
- **Não tocar:** `remove`/`move`/`set_moves`, `db/schema.sql`/`db/migrations/*`, `lib/battle_*`, `lib/mart_service.rb`, `lib/heal_service.rb`, `Gemfile*`, `views/*`.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 adds concorrentes não lançam exceção e resultam em N membros com slots contíguos** — N `add` concorrentes pro mesmo `user_id` **não lançam exceção** e resultam em **exatamente N membros** com slots `1..N` contíguos. — prova: `test/team_repository_test.rb` `test_concurrent_adds_do_not_raise` (threads + barreira; `all(user_id).size == N`, `slots == (1..N).to_a`).
- [ ] **C2 re-add do mesmo número sob corrida não duplica nem 500** — re-add do mesmo `number` sob corrida **não duplica** nem devolve 500 (mantém `DuplicateError` pro que perde). — prova: `test/team_repository_test.rb` `test_concurrent_add_same_number_does_not_duplicate` (2 threads, mesmo pokemon; assert 1 membro com aquele `number`).
- [ ] **C3 time cheio → `TeamFullError` + aviso "Time cheio" (sem 500)** — add com 6 membros lança `TeamFullError` no repo e a rota `POST /team` devolve **200 + aviso "Time cheio"** (`notice--error`), **sem 500**. — prova: `test/team_repository_test.rb` `test_add_rejects_seventh_pokemon_with_team_full_error` (já existe) + `test/team_routes_test.rb` `test_post_team_full_returns_error_notice`.
- [ ] **C4 rota `POST /team` não devolve 500 sob corrida** — rota responde htmx normal (**200 + fragmentos**) sob corrida, sem 500. — prova: `test/team_routes_test.rb` `test_concurrent_post_team_no_500` (2–3 threads com `PokeApiStub.with_find` distintos pro mesmo user; `last_response.ok?` em todas).
- [ ] **C5 sem regressão** — suíte de team existente continua verde. — prova: suíte existente (`./scripts/test test/team_repository_test.rb test/team_routes_test.rb`) + suíte completa.

### Garantias — teste que prova (S1)

| Critério | Teste que prova | Manual |
| --- | --- | --- |
| C1 (adds concorrentes sem exceção, N membros, slots contíguos) | `test/team_repository_test.rb` `test_concurrent_adds_do_not_raise` (threads + barreira) | — |
| C2 (re-add mesmo number não duplica nem 500) | `test/team_repository_test.rb` `test_concurrent_add_same_number_does_not_duplicate` | — |
| C3 (time cheio → `TeamFullError` + aviso "Time cheio", sem 500) | `test/team_repository_test.rb` `test_add_rejects_seventh_pokemon_with_team_full_error` (já existe) + `test/team_routes_test.rb` `test_post_team_full_returns_error_notice` | — |
| C4 (rota `POST /team` sem 500 sob corrida) | `test/team_routes_test.rb` `test_concurrent_post_team_no_500` (2–3 threads + `PokeApiStub.with_find`) | — |
| C5 (sem regressão da suíte de team) | `./scripts/test` (suíte completa) + `./scripts/lint` 0 | — |
| G1 (suíte+lint) | `./scripts/test` suíte completa + `./scripts/lint` 0 em todo green; commits por passo | — |
| G2 (sem migração / sem gems / repo burro) | `git diff -- db/` vazio + `grep -rn "migration\|gem"` vazio no escopo + `TeamRepository` sem regra de negócio (só retry de integridade) | — |
| G3 (S4/S5) | `./scripts/check_docs` + `./scripts/checar-sessao 0070` + `SESSIONS.md` atualizado no refinamento | — |

- [ ] **G1:** suíte completa verde com baseline **995/3938** preservado + novos testes (C1–C4) e lint 0 em todo green; commit obrigatório por passo; 0 regressão fora do escopo (batalha/economia seguem verdes).
- [ ] **G2:** sem `db/migrations` nova (índices únicos já existem em `0007_add_slot.sql`), sem gems novas, sem rede em testes além de `PokeApiStub` quando necessário; `TeamRepository` segue burro (retry é integridade, não regra).
- [ ] **G3:** `SESSIONS.md` atualizado no commit do refinamento (S4) — tabela + "Próxima sessão"; status de validação só após usuário validar (fase 3 — parar na fase 2 e aguardar).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste → `manual` explícito + evidência esperada (não há critério manual nesta sessão). Baseline suíte **995/3938** de 0063. **Parar ao fim da fase 2 e aguardar validação do usuário (fase 3) — não marcar Done, não preencher a seção 7, não commitar conclusão.**

## 5. Decisões de refinamento (fechadas com o usuário em 2026-09-08)

- **D1 — Objetivo B (race completa do `add`):** corrigir **ambas** as colisões — **slot** (`(user_id, slot)`) **e** **número duplicado** (`(user_id, number)`), ambas check-then-insert → `PG::UniqueViolation` 500, com **um** mecanismo único. **B escolhida.** **A preterida:** só a colisão de slot (deixa o duplicado). **C preterida:** só a colisão de número (deixa o slot). Motivo: as duas são a mesma classe de bug (check-then-insert) e um único retry cobre ambas; sessões separadas duplicariam a solução.
- **D2 — Onde A (no `TeamRepository#add`):** `rescue PG::UniqueViolation` + **retry com re-deriva de `next_free_slot`** (até `MAX_TEAM_SIZE` tentativas), mantendo o lançamento de `TeamFullError`/`DuplicateError` após esgotar. **A escolhida.** **B preterida:** na rota (`server.rb`) — contamina o controller com lógica de corrida e não centraliza. **C preterida:** `TeamService#add` novo — `TeamService` não tem `add` hoje (`settings.team` é o repo, `server.rb:1171`); criá-lo seria mudar o fluxo de chamada sem ganho. Motivo: o repo é o único ponto que conhece o `add`; "burro" aqui significa **atomicidade é integridade**, não regra de negócio — o retry só lida com a corrida, não impõe regra.
- **D3 — Comportamento cheio/duplicado A (manter atual):** quem perde a corrida **re-tenta**; se o time encheu de verdade → `TeamFullError` + aviso **"Time cheio"**; se o número já estava → `DuplicateError` + **"já está no time"**. **A escolhida.** **B preterida:** mudar a UX/mensagem. Motivo: comportamento já validado; o retry só elimina o 500 que hoje vaza quando a corrida acontece.
- **D4 — Teste concorrente A (threads reais no `TeamRepository`):** N threads chamando `add` pro mesmo user ao mesmo tempo (barreira/latch); assert sem exceção, exatamente N membros, slots contíguos `1..N`. **A escolhida.** **B preterida:** simular via stub/`duplicate?` forçado — não exercita a corrida real do PG. Motivo: `ConnectionRegistry` já é thread-safe (conexão por thread), então threads reais exercitam a verdadeira colisão `(user_id, slot)`/`(user_id, number)` no Postgres.

> **Grafo obrigatório (tier Scout):** `search_graph query="TeamRepository add next_free_slot"` → `TeamRepository.add lib/team_repository.rb:171-179` + `next_free_slot 241-247` + `duplicate? 249-254`; `search_graph query="TeamRepository add callers"` → `server.rb:555` (`settings.team.add`) + `server.rb:1171` (`set :team, TeamRepository.new`); `get_code_snippet` de `TeamRepository.add`/`next_free_slot`/`duplicate?`; `check_index_coverage` em `lib/team_repository.rb`/`server.rb`/`test/team_repository_test.rb`/`test/team_routes_test.rb` → `no_recorded_issue` (best-effort).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Parar ao fim da fase 2 e aguardar validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (tabela + "Próxima sessão") | commit `Sessao 0070: refinamento concluido — race no add do time (slot+duplicado), criterios e plano TDD fechados` |
| 1 | **red→green — C1+C2 (repo concorrente)** — `test/team_repository_test.rb` `test_concurrent_adds_do_not_raise` (N threads + barreira, `all.size == N`, slots `1..N`) + `test_concurrent_add_same_number_does_not_duplicate` (2 threads mesmo pokemon → 1 membro) + implementação do **retry** no `TeamRepository#add` (loop `MAX_TEAM_SIZE`, `rescue PG::UniqueViolation`, re-deriva `next_free_slot`/`duplicate?`) | `./scripts/test test/team_repository_test.rb -n /concurrent/` + suíte + `./scripts/lint` 0; commit `Passo 1: TeamRepository#add retry em PG::UniqueViolation (slot+duplicado) via re-derivacao de next_free_slot` |
| 2 | **red→green — C3 (team full repo + rota aviso)** — confirma `test_add_rejects_seventh_pokemon_with_team_full_error` (já existe, continua verde após retry) + `test/team_routes_test.rb` `test_post_team_full_returns_error_notice` (add 6 membros → `POST /team` 200 + "Time cheio" + `notice--error`, sem 500) | `./scripts/test test/team_repository_test.rb test/team_routes_test.rb -n /seventh|team_full|full_returns/` + suíte + lint 0; commit `Passo 2: time cheio -> TeamFullError + aviso "Time cheio" sem 500 apos retry` |
| 3 | **red→green — C4 (rota concorrente sem 500)** — `test/team_routes_test.rb` `test_concurrent_post_team_no_500` (2–3 threads com `PokeApiStub.with_find` distintos pro mesmo user; `last_response.ok?` em todas, sem 500) | `./scripts/test test/team_routes_test.rb -n /concurrent_post_team/` + suíte + lint 0; commit `Passo 3: POST /team sem 500 sob corrida (resposta htmx normal)` |
| 4 | **red→green — C5 (regressão + docs)** — suíte completa + lint 0 (baseline 995/3938 preservado) + `REQUIREMENTS.md`/`SESSIONS.md` se tocar doc (limitação "Race no add" pode ser atualizada se resolvida na validação) | `./scripts/test` + `./scripts/lint` + `./scripts/check_docs` + `./scripts/checar-sessao 0070`; commit `Passo 4: regressao da suite de team e docs apos retry no add` |
| — | **Fase 2 concluída** → **Revisor (2c)**: loop Implementador↔Revisor até veredito `Aprovado` (teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar Done, não preencher a seção 7, não commitar conclusão. | — |

## 7. Validação (executada pelo usuário — S2)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 (adds concorrentes, N membros, slots contíguos) | `./scripts/test -n /test_concurrent_adds_do_not_raise/` | — | |
| C2 (re-add mesmo number não duplica) | `./scripts/test -n /test_concurrent_add_same_number_does_not_duplicate/` | — | |
| C3 (time cheio → `TeamFullError` + aviso) | `./scripts/test -n /seventh|team_full|full_returns/` | — | |
| C4 (rota sem 500 sob corrida) | `./scripts/test -n /test_concurrent_post_team_no_500/` | — | |
| C5 (sem regressão) | `./scripts/test` + `./scripts/lint` 0 | — | |
| G1 (suíte+lint) | `./scripts/test` + `./scripts/lint` 0 | — | |
| G2 (sem migração/gems/repo burro) | `git diff -- db/` vazio + grep sem gem/migração no escopo | — | |
| G3 (S4/S5) | `./scripts/check_docs` + `./scripts/checar-sessao 0070` | — | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.

## 8. Observações

- **Próxima após 0070:** Onda 3 Estabilidade — **0071 escritas atômicas** (batalha/compra) → **0072 CSRF** → **0073 respiro** (numeração desliza). Ver `SESSIONS.md:385` e o roadmap.
- **Risco do retry sem transação externa:** `TeamRepository#add` hoje faz `next_free_slot`/`duplicate?` **fora** de transação e só o INSERT dentro de `connection.transaction`. O retry re-executa do início. Não há transação envolvendo os SELECTs, então não há estado "abortado" entre tentativas **dos SELECTs** — o único ROLLBACK é o do INSERT que estourou (ver gotcha 9).
- **`PG::UniqueViolation` x outras violações:** o `rescue` deve ser **específico** de `PG::UniqueViolation` (constraint `(user_id, slot)`/`(user_id, number)`), **não** de `PG::Error` genérico — para não mascarar outros erros (ex.: FK, `NOT NULL`). Confirmar o `constraint` no `PG::UniqueViolation` se houver múltiplos índices.
- **Contagem final no C4:** com N threads distintas inserindo pokémons distintos pro mesmo user, o esperado é exatamente N membros; se duas threads caírem no mesmo `next_free_slot` e uma re-tentar, a re-deriva usa outro slot — nunca excede N (o `TeamFullError` só aparece se realmente `next_free_slot` for `nil`).
- **Dependência:** `ConnectionRegistry` já é thread-safe (`lib/connection_registry.rb:21-31`, conexão por thread + `Mutex`); o teste concorrente depende disso — se usar threads, **cada thread usa a própria conexão** (não compartilha o `@repository`'s connection state no mesmo PG connection).
- **Ajuste de nome de teste na rota:** `test_post_team_full_returns_error_notice` pode ser um **renome/adaptação** de `test_post_team_when_full_returns_warning_and_keeps_six` (já existente, assert `"Time cheio"` + 200). O implementador decide; o critério exige o assert do aviso + 200 (sem 500).

## 9. Gotchas / Lições (memória — S6)

- **Rollback antes do retry (0070):** o `PG::UniqueViolation` estoura **dentro** de `connection.transaction do ... end` (`lib/team_repository.rb:176-178`). O wrapper `pg` emite `ROLLBACK` ao sair por exceção (e re-levanta). **Confirmar que o retry re-entra num `begin` limpo** — re-rodar `next_free_slot`/`duplicate?` do início — e que a `connection` **não fica em estado abortado** entre tentativas. Após o `ROLLBACK`, a conexão volta a `idle` (transação implícita ok), então um novo `connection.transaction` funciona; se o `pg` usasse **savepoints**, o retry precisaria re-abrir o savepoint — validar no green do Passo 1.
- **`rescue` específico de `PG::UniqueViolation`:** não resgatar `PG::Error` genérico — para não engolir `NOT NULL`/`FK`/erros reais. Se houver mais de um índice único, filtrar pelo `constraint` da mensagem (ou por `result.error_field(PG::PG_DIAG_CONSTRAINT_NAME)`) para re-tentar só nas corridas de `(user_id, slot)`/`(user_id, number)`.
- **Conexão por thread (concorrência real):** `ConnectionRegistry.connection_for(owner, Thread.current.object_id, @db_url)` garante 1 conexão por thread; testes com threads **não** compartilham o mesmo `PG::Connection` — evita o "message type ... arrived from server while idle" (`lib/connection_registry.rb:7`). Não compartilhar um único `@repository` como se fosse 1 conexão.
