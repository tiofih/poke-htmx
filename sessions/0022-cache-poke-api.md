# Sessão 0022 — E1-B: Decorator de cache de detalhes da PokéAPI (`PokeApiCache` TTL/LRU fixos)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluído — decisões do usuário em 2026-08-10 (TTL/LRU fixos: 600s / máx 1000) |
| Implementação | Concluída — passos 1–6 red→green→commit, suíte 256/849, lint 0 |
| Validação | Concluída — validado pelo usuário em 2026-08-10 |

---

## 1. Objetivo

**Mover o cache da PokéAPI do adapter real para um decorator (**E1-B** do
`draft-arquitetura-design-patterns.md`, decisão 9 do draft — TTL/LRU **fixos**, sem
configuração por tipo por ora), completando a E1 (cache de detalhes, item 2 da seção 2).**

Hoje (pós-sessão 0021) a memoização mora **dentro do adapter real `PokeApiHttp`** em
5 pontos: `@fetch_all_names`, `@move_cache`, `@pokemon_moves_cache`,
`@available_moves_cache`, `@type_relations`. O `find`/`detail` — exatamente os
detalhes que E1 quer cachear (N requests por membro em `GET /battle`/RF-06) — **não**
têm cache hoje.

Nesta sessão:

- **`PokeApiCache` = decorator** (implementa a interface `PokeApi` de `lib/gateways/poke_api.rb`)
  que envolve qualquer adapter real/fake e adiciona cache com **TTL (600s)** e **LRU
  (máx 1000 entradas)** — valores **fixos**, decisão do usuário.
- **Remove a memoização interna do `PokeApiHttp`** (e módulos `PokeApiMoves`/
  `PokeApiTypes`/`fetch_all_names`): o adapter real volta a ser estateless (busca
  sempre na fonte), e o cache passa a viver só no decorator — transparente para
  servidor/domínio (é o motivo da injeção criada na 0021).
- **Composition root**: `PokeApi.instance = PokeApiCache.new(PokeApiHttp.new,
  ttl: 600, max_entries: 1000)` no boot — `server.rb` mantém `set :api, PokeApi.instance`
  e nada muda nos consumidores (`settings.api`, `TypeEffectiveness.load(settings.api)`,
  `fetcher: settings.api.method(:detail)`).

**Sem mudança de comportamento** nas operações (mesmas respostas, mesma robustez
nil/[]/rede do RF-18): suíte **239 runs/821 asserts** preservada, lint 0. Nenhum
requisito funcional novo (é E1 = infra/cache — `E1-B`, item 20b do roadmap).
Sequência mantida: **E1-B → D2 → D3 → Eco-1..4**.

## 2. Contexto (estado atual — pós-0021)

| Ponto de memoização | Onde (hoje) | New home (E1-B) |
| --- | --- | --- |
| `fetch_all_names` (memoiza só lista não-vazia, RF-18) | `PokeApiHttp#fetch_all_names` → `@fetch_all_names` | `PokeApiCache` (chave `[:fetch_all_names]`) |
| `move(name)` (memoiza por name) | `PokeApiMoves#move` → `@move_cache[name]` | `PokeApiCache` (chave `[:move, name]`) |
| `moves_for(number)` (memoiza por number) | `PokeApiMoves#moves_for` → `@pokemon_moves_cache[number]` | `PokeApiCache` (chave `[:moves_for, number]`) |
| `available_move_names(number)` (memoiza por number) | `PokeApiMoves#available_move_names` → `@available_moves_cache[number]` | `PokeApiCache` (chave `[:available_move_names, number]`) |
| `type_relations` (memoiza a tabela) | `PokeApiTypes#type_relations` → `@type_relations` | `PokeApiCache` (chave `[:type_relations]`) |
| `find`/`detail` (sem cache hoje) | `PokeApiHttp`/`PokeApiParsing` — busca sempre | `PokeApiCache` (chave `[:find, name]` / `[:detail, poke_id]`) — **ganho do E1** |
| `paginate` | deriva de `fetch_all_names` (não cacheia combos offset/limit/query) | mantém derivado do `fetch_all_names` cacheado — não gera entrada própria |

**Decisão do draft (seção 6):** a visão-alvo lista `PokeApi + PokeApiHttp +
PokeApiCache (decorator TTL/LRU) [E1]` em `lib/gateways/`.

## 3. Critérios de aceite

### Resultado

- [ ] **`lib/gateways/poke_api_cache.rb`**: classe `PokeApiCache` que **implementa a
      interface `PokeApi`** (`paginate`, `find`, `detail`, `available_move_names`,
      `move`, `moves_for`, `type_relations`, `fetch_all_names`), recebendo `(api,
      ttl: 600, max_entries: 1000)` — o `api` é qualquer adapter que implemente a
      interface (real `PokeApiHttp` em prod, `PokeApiFake` nos testes).
- [ ] **Cache com TTL + LRU fixos**: cada entrada guarda `fetched_at`; leitura com
      `now - fetched_at >= ttl` → considerado miss e re-busca. Ao **set**, quando
      `entries.size > max_entries`, evicta a **menos recentemente usada** (LRU).
      Valores fixos `DEFAULT_TTL = 600` e `DEFAULT_MAX_ENTRIES = 1000` (sem
      configuração por tipo/operação — decisão 9).
- [ ] **Granularidade por operação + args**: chaves `[método, *args]` — `find("pikachu")`
      ≠ `detail(25)`; `move("thunder-shock")` ≠ `move("growl")` propagam suas próprias entradas.
- [ ] **Semântica de cache por robustez (RF-18)**: ops nil-produtoras (`find`, `detail`,
      `move`) guardam apenas resultado **não-nil** (falha transitória → nil na hora,
      re-tenta no próximo request — 0 regressão); `fetch_all_names` guarda apenas lista
      **não-vazia**; ops lista (`moves_for`, `available_move_names`) e `type_relations`
      cacheiam o valor retornado (TTL governa a staleness; inválida o `||=` do adapter).
- [ ] **Adapter `PokeApiHttp` perde a memoização**: `@fetch_all_names`, `@move_cache`,
      `@pokemon_moves_cache`, `@available_moves_cache`, `@type_relations` **removidos** —
      `fetch_all_names`/`move`/`moves_for`/`available_move_names`/`type_relations`
      passam a consultar a fonte a cada chamada (mesmas respostas, sem estado).
- [ ] **Composition root**: `PokeApi.instance = PokeApiCache.new(PokeApiHttp.new,
      ttl: 600, max_entries: 1000)` — via default do accessor **ou** no boot do
      `server.rb` (`set :api, PokeApi.instance` mantido); consumidores intactos
      (`settings.api`, `TypeEffectiveness.load(settings.api)`,
      `OpponentGenerator(fetcher: settings.api.method(:detail))`).
- [ ] **Testes do decorator determinísticos** (`test/poke_api_cache_test.rb`): relógio
      **injetável** (default `Process.clock_gettime(Process::CLOCK_MONOTONIC)`; testes
      passam clock fake) + api fake com contador de chamadas — cobre TTL (dentro/vencido),
      LRU (evicção da menos recente), `find`/`detail` cacheados, nil não-cacheado,
      lista não-vazia de `fetch_all_names`, chaves por operação.
- [ ] **Migração dos asserts de memoização** para o decorator: `poke_api_http_test.rb`
      (`test_fetch_all_names_memoizes_non_empty_list`), `poke_api_test.rb`
      (`test_type_relations_is_memoized`, `test_fetch_all_names_memoizes_non_empty_list`,
      `test_fetch_all_names_does_not_memoize_failure`) e `poke_api_move_test.rb`
      (`test_move_fetches_and_memoizes_by_name`, `test_moves_for_memoizes_per_number`,
      `test_available_move_names_memoizes_per_number`) passam a exercitar o
      `PokeApiCache` envolvendo um stub/fake; assertions de `instance_variable_set`
      de cache no adapter são removidos.

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (239 runs/821 asserts)** e lint 0 em
      **todo** green; commit obrigatório por passo; nenhuma regressão RF-01..RF-18.
- [ ] Sem novas gems, sem mudança de schema/rotas/contrato de rota; comportamento das
      operações idêntico (mesmas respostas, mesmas exceções resgatadas); testes sem rede.
- [ ] O decorator é **transparente para servidor/domínio** (implementa a interface);
      em testes de servidor não interfere (continuam injetando `PokeApiFake` via
      `PokeApiStub.with_gateway` → `Server.set :api`/`PokeApi.instance =`).
- [ ] `draft-arquitetura-design-patterns.md` (seções 2, 5/6/8 — E1-B feita/em andamento,
      decisão 9 aplicada com valores 600/1000) e arquivo da sessão atualizados no mesmo
      escopo; `REQUIREMENTS.md`/`SESSIONS.md` com *status de validação* só após validação do usuário.

## 4. Decisões de refinamento

- **E1 completada em 2 sessões (decisão do usuário, 2026-08-10):** E1-A = interface +
  adapter real + fake + injeção (0021, Done); **E1-B = decorator de cache TTL/LRU fixo
  (esta sessão)** remove a memoização interna do adapter real.
- **Valores fixos do cache (decisão do usuário, 2026-08-10):** `DEFAULT_TTL = 600s` (10
  min) e `DEFAULT_MAX_ENTRIES = 1000` (LRU). Sem configuração por tipo/operação por ora
  (decisão 9 do draft); defaults constantes, construtor aceita override por keyword.
- **Decorator sobre a interface (norte do draft, seção 6):** `PokeApiCache < PokeApi`
  (implementa o contrato), recebe o adapter real/fake **no construtor** — entra por
  composição, transparente; é o motivo da injeção criada na 0021.
- **Cache de robustez preservado (lição da 0018/RF-18):** nil (find/detail/move) e lista
  vazia (`fetch_all_names`) **não** entram no cache — falha transitória é re-tentada no
  próximo request (comportamento atual do adapter não piora); lista ops e tipo cacheiam
  o valor com TTL.
- **Relógio injetável no decorator** para TTD determinístico: default relógio monotônico;
  testes passam clock controlado (opcional: aceita `clock:` no construtor).
- **`PokeApiHttp` volta a ser estateless**: a memoização é uma preocupação do decorator,
  não do adapter — mesmo contrato/respostas, sem estado de instância de cache.
- **Composition root único:** `PokeApi.instance = PokeApiCache.new(PokeApiHttp.new, ...)`
  (default lazy sobrescrevível). Nenhuma chamada estática de integração nova
  (`grep 'PokeApi\.[a-z]' lib server.rb` → continua só `PokeApi.instance`).
- **Definição de red nesta sessão:** passos que introduzem o decorator → red é o teste
  novo que falha (classe inexistente). Passo de remoção da memoização → red é a suíte
  acusando o comportamento de cache ainda no adapter (asserts migram para o decorator).

## 5. Plano TDD (passos)

> Cada passo = `red` → `green` (lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo de sessão com critérios e plano fechados | commit `Sessao 0022: refinamento concluido — E1-B decorator PokeApiCache (TTL 600s / LRU 1000) remove a memoizacao do PokeApiHttp, sobre a interface PokeApi` |
| 1 | **`PokeApiCache` (TTL + delegação):** classe nova com `(api, ttl:, max_entries:)`, implementa o contrato delegando ao inner, cacheia no hit com TTL (`fetched_at`, refresh ao vencer). `red`: teste novo de hit/expiry falha (classe inexistente). `green`: implementar | suíte verde + lint 0 (baseline + novos) |
| 2 | **LRU (max_entries):** evicção da entrada menos recentemente usada ao exceder o teto. `red`: teste de evicção falha. `green`: implementar | suíte verde + lint 0 |
| 3 | **Robustez/semântica por operação:** nil de `find`/`detail`/`move` não entra; `fetch_all_names` só não-vazio; `moves_for`/`available_move_names`/`type_relations` cacheiam o valor; chaves `[método, *args]` isoladas. `red`: testes novos falham. `green`: implementar | suíte verde + lint 0 |
| 4 | **Remover memoização do adapter:** apagar `@fetch_all_names`/`@move_cache`/`@pokemon_moves_cache`/`@available_moves_cache`/`@type_relations` de `PokeApiHttp`+módulos; migrar os 7 asserts de memoização (seção 3) dos testes do adapter para `poke_api_cache_test.rb` (com stub/fake + clock). `red`: suíte acusa memoização no adapter/`instance_variable_set`. `green`: remoção + migração | suíte completa verde (baseline) + lint 0 |
| 5 | **Composition root + docs:** `PokeApi.instance` default vira `PokeApiCache.new(PokeApiHttp.new, ttl: 600, max_entries: 1000)` (boot do `server.rb`); `grep 'PokeApi\.[a-z]' lib server.rb` → só `PokeApi.instance`; `draft-arquitetura-design-patterns.md` (E1-B feita, decisão 9 valores 600/1000) | suíte verde + lint 0 + docs no mesmo escopo |

## 6. Validação (executada pelo usuário)

**Status: validado pelo usuário em 2026-08-10.**

- [x] Suíte completa verde (baseline **239 runs/821 asserts** preservado → **256 runs/849
      asserts** com os novos testes do decorator).
- [x] Lint RuboCop 0; sem `rubocop:disable` novo em produção.
- [x] `grep 'PokeApi\.[a-z]' lib server.rb` → somente `PokeApi.instance` (sem integração estática).
- [x] Adapter `PokeApiHttp` sem estado de cache (`grep 'instance_variable_set(:@'` nos pontos
      migrados → 0 nos testes de lib).
- [x] `./scripts/run`: Lista/Detalhe/Time/Time-Manage/Batalha funcionando (decorator ativo em dev).

## 6b. Progresso da implementação (passos 1–6)

> Preenchido durante a fase 2 (TDD). Não marcar como validado até o usuário validar.

- **Passo 1 — `PokeApiCache` (TTL + delegação)** ✅ commit `79110ce`: classe nova
  `lib/gateways/poke_api_cache.rb` (construtor `(api, ttl:, max_entries:, clock:)`,
  delega o contrato ao inner, cacheia `[método, *args]` com `fetched_at` e refresh ao TTL;
  `clock:` injetável default monotônico). Suíte **244/828**, lint 0.
- **Passo 2 — LRU (max_entries)** ✅ commit `df5c44c`: evicção da entrada menos rec
  utilizada ao exceder `max_entries` (ordem de recência mantida por inserção —
  `store`/`touch` re-inserem no fim; `shift` remove o LRU). Suíte **247/831**, lint 0.
- **Passo 3 — Robustez/semântica por operação** ✅ commit `17c5b64`: `find`/`detail`/`move`
  não cacheiam **nil** (falha transitória re-tentada); `fetch_all_names` não cacheia lista
  vazia (RF-18); `moves_for`/`available_move_names`/`type_relations` cacheiam o valor;
  chaves `[método, *args]` isoladas por operação e argumento. Suíte **255/851**, lint 0.
- **Passo 4 — Remover memoização do adapter** ✅ commit `13e7323`: `@fetch_all_names`/
  `@move_cache`/`@pokemon_moves_cache`/`@available_moves_cache`/`@type_relations` removidos
  de `PokeApiHttp`+`PokeApiMoves`+`PokeApiTypes` (volta a ser estateless); 7 asserts de
  memoização migrados de `poke_api_http_test`/`poke_api_test`/`poke_api_move_test` para
  `poke_api_cache_test.rb` (com `CountingApi` + `FakeClock`). Suíte **255/846**, lint 0,
  grep `instance_variable_set(:@memo…)` nos testes → 0.
- **Passo 5 — Composition root** ✅ commit `6b6cd4e`: `PokeApi.instance` default decorado —
  `PokeApiCache.new(PokeApiHttp.new, ttl: 600, max_entries: 1000)` (accessor de `poke_api.rb`);
  `PokeApiCache` expõe `inner`/`ttl`/`max_entries`; `gateway_interface_test.rb` verifica
  cache + valores fixos. Suíte **256/849**, lint 0; `grep 'PokeApi\.[a-z]' lib server.rb` →
  só `PokeApi.instance`.
- **Passo 6 — Docs** ✅ (em progresso): `draft-arquitetura-design-patterns.md` (seção 2 E1-B
  feita, seção 6 E1 implementado, decisão 9 valores 600/1000), `REQUIREMENTS.md` (limitação
  cache resolvida + roadmap 20b), `SESSIONS.md` (tabela 0022 em fase 2 + próxima sessão),
  `draft-auto-battler.md` (E1 implementado). Suíte **256/849**, lint 0.
- **Fase 2 concluída** — todos os passos red→green→commit feitos, suíte/lint verdes.
  **Validado pelo usuário em 2026-08-10** (seção 6) — sessão 0022 fechada; E1 encerrada;
  próxima: sessão 0023 (D2, XP/evolução).

## 7. Observações

- **E1-B não muda contrato de rota nem comportamento:** é infra — cache TTL/LRU sob a
  interface já injetada (norte da 0021). `GET /battle`/RF-06 passam a reutilizar
  `detail`/`moves` por até 10 min (600s) sem re-buscar na PokéAPI — principal ganho de
  volume de requests que a D2 (XP) vai amplificar.
- Sequência mantida (2026-08-10): **E1-A (done) → E1-B (esta) → D2 → D3 → Eco-1..4**.
- Valores fixos (decisão do usuário, 2026-08-10): TTL **600s**, LRU **máx 1000 entradas**.
- Draft auto-battler: o ponto "memoizar 4 moves por pokémon" (D1) e a limitação do
  REQUIREMENTS ("cache local de detalhes") são atendidos pela E1-B.