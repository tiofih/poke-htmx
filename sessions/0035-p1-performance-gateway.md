# Sessão 0035 — P1: performance do gateway da PokéAPI

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída — decisões do usuário em 2026-08-19 (abrir P1 no lugar de J1; estratégia "ambos"; cache em arquivo `tmp/`) |
| Implementação | Concluída — passos 1-5 verdes (TDD, 2026-08-19): suíte 586/1787, lint 0 |
| Validação | Concluída — usuário validou em 2026-08-19 (GET /battle ~38s, 2º play ~4s; tabela por critério na seção 7) |

---

## 1. Objetivo

**P1 — paralelismo + cache persistente no gateway da PokéAPI** (anotação de
performance de 2026-08-19, `draft-auto-battler.md:478-511`): reduzir o tempo de
`GET /battle` (prepare) de ~1.6min (e do finalize ~1.2min) e eliminar o **re-warm
do cache a cada reboot**, onde o fan-out **serial** de ~133 requisições HTTP à
PokéAPI (~93s @0.7s/RTT) reaquece do zero porque o `PokeApiCache` (memória, TTL
600s) é zerado a cada `docker compose down` do `scripts/reboot`.

**Estratégia decidida pelo usuário (2026-08-19):** **ambos** —
(1) **paralelizar** os fetches independentes (threads) e (2) **persistir o cache
em arquivo JSON na pasta `tmp/`** (sobrevive ao `docker compose down` via volume).

## 2. Contexto (estado atual — diagnóstico)

- **Fan-out do prepare (~133 seriais):** 6 `detail` do jogador (cada = `/pokemon`
  + species + chain + `find` por estágio ≈ 5) ≈ 30; 6 `detail` do oponente (via
  `OpponentGenerator` ≈ 24); 6 `moves_for` do jogador (pokemon + 4 moves) ≈ 30;
  6 do oponente ≈ 30; 18 `type_relations` seriais; 1 `fetch_all_names` — ≈ 93s.
  O finalize (evolução + aprendizado) soma ~36 seriais (`next_evolutions` =
  species + chain + find de evolução, `learnable_moves` + `detail` de evolução).
- **Seriais hoje:** `PokeApiHttp`/módulos chamam `Faraday.get(url)` inline em
  `pokemon_data`, `find`, `fetch_move_json`, `fetch_type_json`, species/chain;
  `PokeApiTypes#type_relations` itera os 18 tipos em loop; `OpponentGenerator#team`
  itera `team_names`; `BattleService#prepare` itera os membros (`player_team`) e
  o oponente (`opponent_team`).
- **Cache atual:** `PokeApiCache` (E1-B, `poke_api_cache.rb`) é **LRU em memória**
  (TTL 600s, máx 1000) com **hash compartilhado `@entries` sem proteção** — o
  fan-out em threads **corromperia** o LRU/evicção sem torná-lo thread-safe.
- **DB não é thread-safe no caminho paralelo:** cada repositório guarda **uma**
  `PG::Connection` (`@connection ||= PG.connect(...)`, ex.
  `team_repository.rb:246-248`); `progression.get` no prepare/finalize roda na
  mesma conexão — leituras de progresso precisam sair do caminho paralelo.
- **Persistência:** `docker-compose.yml` monta `.:/var/www/pokedex/` e
  `.gitignore` já tem `tmp/` — um arquivo `tmp/pokeapi_cache.json` persiste entre
  `docker compose down/up` sem mudança de infra.
- **Interface:** o contrato `PokeApi` (`poke_api.rb:10-19`) lista os métodos por
  adapter; `PokeApi.instance` constrói `PokeApiCache.new(PokeApiHttp.new, ...)`.
  **Nenhuma mudança de contrato** nesta sessão.

## 3. Escopo

### Produção

| Arquivo | Mudança |
| --- | --- |
| `lib/parallelizer.rb` (novo) | `Parallelizer.map(items, concurrency: 8, &block)` — pool de threads limitado (stdlib `Thread`/`Queue`), **resultados na ordem de entrada**, exceção propagada ao chamador; `concurrency: 1` = serial. Sem gem nova. |
| `lib/gateways/poke_api_cache.rb` | **Thread-safe**: lock **por chave** (held durante o miss → dedup do fetch in-flight: 2ª thread da mesma chave espera e reusa) + lock curto nas mutações do hash (`store`/`touch`/`evict_overflow`). TTL/LRU intactos (600s/1000). |
| `lib/gateways/persistent_json_store.rb` (novo) | `get(url)` → JSON parseado ou `nil`; **arquivo JSON único** `{"<url>": {"fetched_at": <float>, "value": <json>}}` com **write-through** (rewrite do arquivo + `rename` atômico); **TTL alto (7 dias**, dados quase imutáveis) com clock injetável; valor `nil`/erro **não persiste**; arquivo ausente/corrompido → cache vazio sem raise; thread-safe (lock por chave + lock de escrita). |
| `lib/gateways/poke_api_http.rb` + módulos (`poke_api_parsing.rb`, `poke_api_moves.rb`, `poke_api_types.rb`) | **Choke point único `http_get(url)`** substituindo `Faraday.get` inline (pokemon, species, chain, move, type, listagem) — mesma resposta/guards. `PokeApiHttp.new(cache_path:)` **opt-in**: com path usa o `PersistentJsonStore` (URL = chave); sem path → comportamento atual (0 regressão). |
| `lib/gateways/poke_api.rb` | Boot `PokeApi.instance` usa `PokeApiHttp.new(cache_path: ENV["POKEAPI_CACHE_PATH"] || "tmp/pokeapi_cache.json")` — contrato e ponto de injeção intactos. |
| `lib/gateways/poke_api_types.rb` | `type_relations` busca os **18 tipos em paralelo** via `Parallelizer` — mesmo retorno `{tipo => {double,half,no}}`; `TypeEffectiveness.load` intacto. |
| `lib/opponent_generator.rb` | Nova dep **`parallelizer:`** (default `Parallelizer`); `#team` mapeia candidatos em paralelo (**ordem/nomes/seed intactos** → mesmo time oponente). |
| `lib/battle_service.rb` | `prepare`: leituras de progresso (nível/HP) **pré-carregadas serialmente** (DB fora do caminho paralelo — `PG::Connection` única não é thread-safe); `player_team` (detail + moves por membro) e `opponent_team` (`moves_for` por oponente) **paralelos** via `Parallelizer`. `apply_evolution_and_learning` (finalize): **prefetch paralelo** de `next_evolutions`/`learnable_moves`/`detail` de evolução por membro; **mutações DB seriais**. Resultado idêntico ao baseline serial. |

### Fora de escopo (RNF-04 — não abrir)

- Mudança de contrato da interface `PokeApi` (métodos/assinaturas/retorno).
- Cache em Postgres/Redis (decidido: arquivo `tmp/`).
- Trocar ordem da fila (J1/JN-2/J3/JN-1 seguem após a 0035 validada).
- Mudar `scripts/reboot` (0 mudança de infra).

## 4. Critérios de aceite

### Resultado

- [x] **`Parallelizer` puro:** `Parallelizer.map` devolve resultados **na ordem de
      entrada**, executa tarefas independentes **em paralelo** (wall-time < soma
      serial, medido em teste com `sleep`), exceções **propagam** ao chamador e
      `concurrency: 1` = serial. Sem gem nova (stdlib).
- [x] **`PokeApiCache` thread-safe:** requisições concorrentes a **chaves
      distintas** rodam em paralelo sem corromper o LRU/evicção; **mesma chave**
      concorrente → **fetch único** (dedup in-flight); testes antigos
      (sequenciais) verdes **sem edição**.
- [x] **`PersistentJsonStore` em `tmp/`:** grava o arquivo JSON; **2ª instância**
      (mesmo path) carrega do disco e responde **sem rede** (Faraday stubado a
      falhar após o 1º boot); TTL 7 dias com clock injetável; **`nil`/erro não
      persiste**; arquivo ausente/corrompido → cache vazio **sem raise**;
      thread-safe (escape do `tmp` não persiste — `.gitignore` já cobre).
- [x] **Choke point `http_get`:** com `cache_path:` o `PokeApiHttp` resolve todos
      os GETs internos (pokemon, species, chain, move, type, listagem) pelo store
      (URL = chave); **sem** `cache_path:` → comportamento atual (0 regressão em
      `poke_api_http_test.rb`).
- [x] **Boot persistente:** `PokeApi.instance` aponta o cache persistente
      (`ENV["POKEAPI_CACHE_PATH"]` ou `tmp/pokeapi_cache.json`) — sobrevive a
      `docker compose down` (volume `./`); contrato e ponto de injeção intactos.
- [x] **`type_relations` paralelo:** busca os 18 tipos em paralelo e devolve a
      mesma `{tipo => {double,half,no}}`; `TypeEffectiveness.load` intacto.
- [x] **`OpponentGenerator#team` paralelo:** mesmo `team_names`/ordem/semente
      (mesmo time oponente); `fetcher` invocado por candidato; `parallelizer:`
      injetável com default preservado.
- [x] **`BattleService` paralelo:** prepare com fan-out **paralelo** (detail +
      moves dos 6 jogadores e do oponente) com **progresso DB pré-carregado
      serial** (sem acessar `PG::Connection` compartilhada em threads) e finalize
      com prefetch paralelo + mutações DB seriais; **resultados idênticos ao
      baseline serial** (mesmo time oponente, mesmo engine).

### Garantias (RNF)

- [x] Suíte completa verde com **baseline preservado (566 runs/1734 asserts)** +
      novos testes e lint 0 em **todo** green; commit obrigatório por passo;
      0 regressão RF-01..RF-18/Eco (rotas de batalha com fakes atuais verdes).
- [x] Sem novas gems (stdlib `Thread`/`Mutex`/`Queue`/`JSON`/`File`); sem mudança
      de schema; **testes sem rede** (stubs Faraday `poke_api_http_test.rb` +
      fakes + `Dir.mktmpdir`); sem `rubocop:disable`.
- [x] `REQUIREMENTS.md` (roadmap — P1 executada), `SESSIONS.md` (0035 em fase 2 +
      próximas J1→JN-2→J3→JN-1) e `draft-auto-battler.md` (anotação de performance
      — P1 executada) atualizados no mesmo escopo do passo docs; *status de
      validação* só após o usuário validar.

### Critério → teste que o prova (S1)

| Critério | Teste (arquivo/nome) |
| --- | --- |
| `Parallelizer` puro | `test/parallelizer_test.rb` — ordem de entrada, paralelismo, `concurrency: 1`, exceção propaga |
| `PokeApiCache` thread-safe | `test/poke_api_cache_test.rb` — chaves distintas em paralelo, dedup same-key, evicção |
| `PersistentJsonStore` em `tmp/` | `test/persistent_json_store_test.rb` — 2ª boot sem rede, TTL, nil/corrompido sem raise |
| Choke point `http_get` | `test/poke_api_http_test.rb` — com/sem `cache_path:` (0 regressão) |
| Boot persistente | `test/poke_api_fake_test.rb` / `test/gateway_injection_test.rb` — `PokeApi.instance` com default `tmp/` |
| `type_relations` paralelo | `test/poke_api_http_test.rb` — 18 tipos em paralelo, mesmo `{tipo => {double,half,no}}` |
| `OpponentGenerator#team` paralelo | `test/opponent_generator_test.rb` — ordem/seed e fetcher por candidato |
| `BattleService` paralelo | `test/battle_service_test.rb` — corrente ≥ 2 no prepare; resultado idêntico ao serial |
| Garantias (baseline, lint, sem gem/schema/rede) | suíte completa `./scripts/test` + `./scripts/lint` |

## 5. Decisões de refinamento (fechadas com o usuário)

- **D1 — Estratégia "ambos":** paralelismo (threads) **e** cache persistente.
  Reduz o walk-time de ~133 RTTs para a profundidade (~10–20) **e** elimina o
  re-warm a cada reboot.
- **D2 — Persistência em arquivo `tmp/`:** JSON em `tmp/pokeapi_cache.json`
  (decidido pelo usuário; sem Postgres/Redis). `.gitignore` já ignora `tmp/` e o
  volume do compose monta `./` → sobrevive ao down/up. TTL alto (7 dias) porque
  dados da PokéAPI são praticamente imutáveis (`type_relations`, `move`,
  species/evo); o LRU em memória (600s) permanece acima.
- **D3 — Sem mudança de contrato `PokeApi`:** métodos/assinaturas/`instance`
  intactos; mudanças internas ao `PokeApiHttp`/decoradores/deps novas opcionais.
- **D4 — DB fora do caminho paralelo:** `PG::Connection` única por repositório
  não é thread-safe → leituras de progresso (nível/HP) pré-carregadas **seriais**
  antes do fan-out e mutações do finalize (evolui/aprende/HP) **seriais**.
- **D5 — `PokeApiCache` vira thread-safe:** sem isso o fan-out paralelo corruptos
  o LRU. Lock por chave (dedup in-flight) + lock curto no hash. Testes antigos
  sequenciais seguem verdes sem edição.
- **D6 — Persistência em nível de URL (choke point `http_get`):** cobre os ~133
  GETs (pokemon, species, chain, move, type, listagem) sem duplicar lógica por
  método; `PokeApiHttp.new(cache_path:)` opt-in (testes sem path → 0 regressão).
- **D7 — `Parallelizer` puro via stdlib:** `Thread`/`Queue`, pool limitado,
  resultados em ordem de entrada, exceção propagada; `concurrency` default 8.
- **D8 — `OpponentGenerator`** ganha `parallelizer:` (default `Parallelizer`);
  `team_names`/seed/ordem intactos (mesmo oponente sortudo).
- **Ordem sugerida:** `Parallelizer` → cache thread-safe → store persistente +
  choke point → fonte paralela (`type_relations` + `OpponentGenerator`) →
  `BattleService` paralelo → docs.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo de sessão com critérios e plano fechados | commit `Sessao 0035: refinamento concluido — P1 (perf gateway): paralelismo de fetches (Parallelizer) + cache persistente em tmp/ (choke point http_get) — estrategia ambos decida pelo usuario` |
| 1 | **`Parallelizer` puro:** `red` — `test/parallelizer_test.rb`: ordem de entrada com blocos lentos; paralelismo real (wall-time < soma serial com sleeps); `concurrency: 1` serial; exceção propaga. `green` — `lib/parallelizer.rb` (pool de threads, resultados ordenados, exception marshaling) | suíte completa verde + lint 0, commit `Passo 1:` |
| 2 | **`PokeApiCache` thread-safe:** `red` — `poke_api_cache_test.rb`: 2 threads em chaves distintas coexistem sem corromper LRU; mesma chave concorrente (inner com sleep) → **1** chamada ao inner; evicção sob concorrência. `green` — lock por chave + lock de escrita no hash (fetch/TTL/LRU intactos) | suíte completa verde + lint 0, commit `Passo 2:` |
| 3 | **`PersistentJsonStore` + choke point:** `red` — `persistent_json_store_test.rb` (com `Dir.mktmpdir`): grava arquivo; 2ª instância responde **sem rede** (Faraday falha no 2º boot); TTL com clock fake; `nil`/erro não persiste; arquivo corrompido/ausente → vazio, sem raise. `green` — `lib/gateways/persistent_json_store.rb` + `PokeApiHttp#http_get` nos módulos (`cache_path:` opt-in) + boot `PokeApi.instance` com default `tmp/pokeapi_cache.json` (ENV override) | suíte completa verde + lint 0, commit `Passo 3:` |
| 4 | **Fonte paralela:** `red` — `poke_api_http_test.rb`: `type_relations` com Faraday stubado (sleep+contador) → 18 tipos completa/com corrente > 1; `opponent_generator_test.rb`: `parallelizer:` injetado preserva ordem/seed e invoca fetcher por candidato. `green` — `PokeApiTypes#type_relations` via `Parallelizer` + `OpponentGenerator` com dep `parallelizer:` | suíte completa verde + lint 0, commit `Passo 4:` |
| 5 | **`BattleService` paralelo:** `red` — teste do serviço com fake api lenta/contadora: no prepare, `detail`/`moves_for` concorrentes (máx corrente ≥ 2) e resultado igual ao serial; finalize com prefetch paralelo sem regressão. `green` — `player_team`/`opponent_team` via `Parallelizer` (progresso pré-carregado serial) + prefetch no `apply_evolution_and_learning` (mutações DB seriais) | suíte completa verde + lint 0, commit `Passo 5:` |
| 6 | **Docs:** `REQUIREMENTS.md` (roadmap — P1 executada), `SESSIONS.md` (0035 fase 2 + próximas J1→JN-2→J3→JN-1), `draft-auto-battler.md` (anotação de performance — P1 executada) | suíte verde + lint 0, commit `Passo 6:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar `Done`/commitar conclusão antes. |

## 7. Validação (executada pelo usuário)

**Concluída em 2026-08-19 pelo usuário.**

| Critério | Evidência automatizada | Evidência manual | Resultado |
| --- | --- | --- | --- |
| `Parallelizer` puro | `parallelizer_test.rb` (ordem, paralelismo, `concurrency: 1`, exceção) | suíte 586/1787 verde | ok |
| `PokeApiCache` thread-safe | `poke_api_cache_test.rb` (dedup same-key, chaves distintas, evicção) | suíte verde | ok |
| `PersistentJsonStore` em `tmp/` | `persistent_json_store_test.rb` (2º boot sem rede, TTL, corrompido) | `tmp/pokeapi_cache.json` criado; 2º play ~4s (cache em uso) | ok |
| Choke point `http_get` | `poke_api_http_test.rb` (com/sem `cache_path:`) | 0 regressão rotas de batalha (fakes atuais verdes) | ok |
| Boot persistente | `poke_api_fake_test.rb` / `gateway_injection_test.rb` (default `tmp/`) | 2º play ~4s (sem refetch do fan-out) | ok |
| `type_relations` paralelo | `poke_api_http_test.rb` (18 tipos, mesmo `{tipo => {double,half,no}}`) | suíte verde | ok |
| `OpponentGenerator#team` paralelo | `opponent_generator_test.rb` (ordem/seed, fetcher por candidato, `parallelizer:`) | mesmo time oponente (batalhas OK) | ok |
| `BattleService` paralelo | `battle_service_test.rb` (corrente ≥ 2 no prepare; resultado idêntico ao serial) | **`GET /battle` ~38s** (era ~93s) — fan-out paralelo | ok |
| Garantias RNF (baseline, lint 0, sem gem/schema/rede) | suíte completa `./scripts/test` (586/1787, 0 failures) + `./scripts/lint` (0 offenses) | rotas com fakes verdes | ok |
| Docs + status de validação | `check_docs` (S5) ok | roadmap REQUISITOS/SESSIONS/draft atualizados | ok |

### Progresso da implementação (fase 2 — TDD)

- **Passo 1:** `Parallelizer` verde (ordem, paralelismo, concurrency 1, exceção) — commit `9d8c850`.
- **Passo 2:** `PokeApiCache` thread-safe verde (dedup + evicção concorrente) — commit `08f25c8`.
- **Passo 3:** `PersistentJsonStore` + choke point `http_get` + boot verde — commit `8a0d8a2`.
- **Passo 4:** `type_relations` paralelo (18 tipos) + `OpponentGenerator` com `parallelizer:` verde — commit `2b52304`.
- **Passo 5:** `BattleService` paralelo verde (prepare com detail/moves em threads + finalize prefetch) — commit `4c0915c`.
- **Passo 6:** docs atualizadas — commit pendente nesta validação.
- Suíte completa **586 runs / 1787 assertions, 0 failures/errors**; lint **0 offenses**.
- **PARADA (regra do AGENTS.md):** fase 2 concluída — aguardando a validação do usuário (fase 3) antes de marcar `Done`/commitar conclusão.

## 8. Observações

- **Ordem da fila inalterada:** após a 0035 validada, segue **J1 (seleção inicial)
  → JN-2 → J3 → JN-1** → organizar o resto (JN-3, JN-4, JN-5, J2, J4, D4).
- **Previsão de ganho (esboço do draft):** prepare ~93s → poucos segundos
  (paralelo) e cache persistente elimina o re-warm a cada `scripts/reboot`.
- **`tmp/` já ignorado** (`gitignore`) e montado pelo volume `./` do compose —
  nenhuma mudança de infra.