# Sessão 0021 — E1-A: Gateway da PokéAPI (interface `PokeApi` + adapter real `PokeApiHttp` + adapter fake nos testes)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Em andamento — decidido com o usuário em 2026-08-10 (E1 dividida em 2 sessões: E1-A aqui, E1-B cache depois) |
| Implementação | Pendente |
| Validação | Pendente — executada pelo usuário |

---

## 1. Objetivo

**Refatorar a integração com a PokéAPI para um gateway injetável** (E1-A do
`draft-arquitetura-design-patterns.md`, item 2 da seção 2 e seção 6): hoje `lib/poke_api.rb`
é uma **classe estática** (`PokeApi.find/detail/move/...`, `extend PokeApiParsing/Moves/Types`,
caches em nível de classe) chamada pelos handlers de `server.rb`, pelo default de
`OpponentGenerator (fetcher:)` e por `TypeEffectiveness.load`. Os testes a stubeam via
**monkey-patch de método singleton** (`PokeApiStub.stub_singleton`).

Nesta sessão (E1-A) a integração vira:

- **`PokeApi` = interface** (contrato das operações do gateway) + accessor do **gateway default**
  (`PokeApi.instance` / `PokeApi.instance=`), no diretório novo `lib/gateways/`.
- **`PokeApiHttp` = adapter real** (Faraday + parsing + memoização atual), agora **por instância**,
  mesmo comportamento de hoje.
- **Adapter fake** configuravel para testes (`PokeApiFake`), substituindo o monkey-patch de
  singleton (`PokeApiStub.stub_singleton`) por **injeção** — `Server.set :api, PokeApiFake` e
  instância direta nos testes de lib.
- **Composition root** em `server.rb` (`set :api, ...`) + injeção explícita nos consumidores
  de domínio (`OpponentGenerator` fetcher, `BattleEngine` effectiveness via
  `TypeEffectiveness.load(api)`), com `default` resolvendo a `PokeApi.instance`.

**Sem mudança de comportamento** nas operações expostas (mesmas respostas, mesma robustez
nil/[]/rede do RF-18): suíte **222 runs/778 asserts** preservada, lint 0.

O **cache TTL/LRU** (decorator, decisão 9 do draft — fixos) **fica para a E1-B** (sessão
seguinte); aqui a memoização atual **permanece** (por instância, idêntica em comportamento).
Nenhum requisito funcional novo em `REQUIREMENTS.md` (é E1 = infra/cache — `E1-A`).

## 2. Contexto (estado atual — diagnóstico)

| Arquivo | Hoje | Consumidores |
| --- | --- | --- |
| `lib/poke_api.rb` | Classe estática `PokeApi` (`extend` Parsing/Moves/Types + `self.all/fetch_all_names/paginate/find/ok?`), Faraday direto, caches em classe (`@move_cache`, `@fetch_all_names`, `@type_relations`, ...) | `server.rb` (handlers/actions/helpers), `OpponentGenerator` (default `fetcher:`), `TypeEffectiveness.load`, testes |
| `test/test_helper.rb` | `PokeApiStub` com `stub_singleton` (monkey-patch de singleton + `instance_variable_set` de cache) + `with_*` | `test/server_test.rb`, `test/poke_api_test.rb` |
| `test/poke_api_test.rb` / `poke_api_move_test.rb` | Testam a **static** `PokeApi.x` + monkey-patch de `PokeApi.define_singleton_method` + patch de `Faraday.get` | — |

**Pontos de uso da static hoje** (`rg "PokeApi\\."` em lib/server):

- `server.rb`: `PokeApi.paginate` (×2), `PokeApi.find` (×2), `PokeApi.detail` (×2),
  `PokeApi.available_move_names`, `PokeApi.move`, `PokeApi.moves_for`, `PokeApi.fetch_all_names`.
- `lib/type_effectiveness.rb:11`: `TypeEffectiveness.load → from_relations(PokeApi.type_relations)`.
- `lib/opponent_generator.rb:9`: `fetcher: PokeApi.method(:detail)` (default do construtor).
- `BattleEngine` default `effectiveness: TypeEffectiveness.load` (usado só por `server.rb`;
  testes injetam `effectiveness:` sempre — cobre `battle_engine_test.rb` e `move_engine_test.rb`).

**Riscos/decisão do draft (seção 7):** "escopo do gateway é o item mais invasivo (toca todos
os pontos de uso + tests). Pode ser dividido em 2 sessões: interface+adapter, depois decorator
de cache" → **usuário decidiu 2 sessões em 2026-08-10** (E1-A esta, E1-B cache).

## 3. Critérios de aceite

### Resultado

- [ ] **`lib/gateways/poke_api.rb`**: módulo `PokeApi` = **interface** do gateway (contrato
      documentado de: `paginate`, `find`, `detail`, `available_move_names`, `move`,
      `moves_for`, `type_relations`, `fetch_all_names`) + accessor **`PokeApi.instance`/**
      `PokeApi.instance=` com default `PokeApiHttp.new` (lazy). Nenhuma chamada **estática**
      `PokeApi.<método>` de integração restante em `lib/` + `server.rb`
      (`grep 'PokeApi\.[a-z]' lib server.rb` → só `PokeApi.instance`).
- [ ] **`lib/gateways/poke_api_http.rb`**: adapter real por instância (Faraday + parsing +
      robustness nil/[] do RF-18 + memoização atual por instância); mesmo contrato/respostas
      da static de hoje. `lib/poke_api.rb` (static) **removido** ao final; módulos
      `PokeApiParsing/PokeApiMoves/PokeApiTypes` migram para `lib/gateways/`.
- [ ] **Adapter fake p/ teste** (`test/poke_api_fake.rb`): `PokeApiFake` configuravel por
      operação (`find/detail/fetch_all_names/moves_for/move/available_move_names/fetch_type_json`),
      satisfaz a interface; **removido o monkey-patch de singleton** (`PokeApiStub.stub_singleton`)
      de `test_helper.rb`.
- [ ] **Injeção em `server.rb`**: `set :api, PokeApi.instance` (default) + todas as
      ações/helpers usam `settings.api`; `OpponentGenerator` recebe `fetcher: settings.api.method(:detail)`;
      `BattleEngine` recebe `effectiveness: TypeEffectiveness.load(settings.api)`; dev-reload
      preservado (mesma mecânica da 0020).
- [ ] **Domínio**: `TypeEffectiveness.load(api = PokeApi.instance)` e default `fetcher:` do
      `OpponentGenerator` resolvem a `PokeApi.instance` (parametro explícito continua valendo
      — contrato de RF-10/RF-12 preservado).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (222 runs/778 asserts)** e lint 0 em
      **todo** green; commit obrigatório por passo; nenhuma regressão RF-01..RF-18.
- [ ] Sem novas gems, sem mudança de schema/rotas/contrato de rota; comportamento das
      operações idêntico (mesmas respostas, mesmas exceções resgatadas).
- [ ] Cache **TTL/LRU é E1-B** (fora de escopo aqui — anotado no draft e em `SESSIONS.md`);
      a memoização atual permanece, apenas como estado de instância do adapter real.
- [ ] `draft-arquitetura-design-patterns.md` (item 2 da seção 2 e seções 6/8: E1 → E1-A
      feita/em andamento + E1-B pendente) e o arquivo da sessão atualizados no mesmo escopo;
      `REQUIREMENTS.md`/`SESSIONS.md` com *status de validação* só após validação do usuário.

## 4. Decisões de refinamento

- **E1 dividida em 2 sessões (decisão do usuário, 2026-08-10):** E1-A = interface + adapter
  real + adapter fake + injeção (esta sessão); **E1-B = decorator de cache TTL/LRU fixo**
  (seguinte, remove a memoização do adapter real). Nesta sessão a memoização **fica no
  adapter real** (estado de instância) para comportamento idêntico.
- **Naming/layout (norte do draft, seção 6):** `lib/gateways/poke_api.rb` (interface) +
  `lib/gateways/poke_api_http.rb` (real, Faraday) + `test/poke_api_fake.rb` (fake). O nome
  público **`PokeApi` passa a ser a interface** (o roteador/consumidor fala com qualquer
  adapter que a implemente — o decorator da E1-B entra por composição, transparente).
- **Injeção (sem registry global espalhado):** `server.rb` usa **`settings.api`** (inject
  por `set :api`, override nos testes via `Server.set :api, PokeApiFake`). Domínio usa
  parametros explícitos com **default resolvido a `PokeApi.instance`**: `TypeEffectiveness.load(api = PokeApi.instance)`
  e `OpponentGenerator(fetcher: PokeApi.instance.method(:detail))`. Assim nenhuma chamada
  estática de integração sobrevive, e o teste default-path (sem parametro) continua válido.
- **`PokeApi.instance`** é só um *composition-root default* (lazy `PokeApiHttp.new`,
  sobrescrevivel), **não** é a "god class estática" do anti-padrão (caches moram no adapter
  instância; a troca de implementação — decorator E1-B — vira um `PokeApi.instance =` no boot).
- **Contrato das operações preservado (lição da 0020):** assinaturas públicas e formato das
  respostas (`paginate → {names:, total:}`, `find/detail → Pokemon|nil`, móveis,
  `type_relations → {tipo => {double,half,no}}`, robustez nil/[]/rede) não mudam.
- **Adapters fake × DSL de testes:** `PokeApiStub.with_*` deixa de monkey-patchar singleton e
  passa a **construir `PokeApiFake` configurado e injetar em `Server`** (com restore em
  `ensure`) — as chamadas atuais nos testes de servidor são preservadas (rewrite mechânico,
  nenhum cenário se perde); os testes de lib passam a usar instâncias diretas
  (`PokeApiHttp.new` / `PokeApiFake`).
- **Definição de red nesta sessão:** nas etapas que introduzem estrutura nova, o `red` é o
  teste novo que falha (PokeApiHttp/interface/fake inexistentes). Nas etapas de migração, o
  `red` é a suíte acusando as chamadas ainda estáticas/singleton (o `red` do passo passa a
  apontar exatamente o que falta migrar) — mesma mecânica dos respir como 0019/0020.

## 5. Plano TDD (passos)

> Cada passo = `red` → `green` (lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo de sessão com critérios e plano fechados | commit `Sessao 0021: refinamento concluido — E1-A gateway PokéAPI (interface PokeApi + adapter real PokeApiHttp + adapter fake) dividida em 2 (E1-B = cache TTL/LRU)` |
| 1 | **`PokeApiHttp` (adapter real):** movê-lo com `lib/gateways/poke_api_http.rb` como **instância** (Faraday + módulos Parsing/Moves/Types + robustez RF-18 + memoização por instância). `red`: teste novo do adapter por instância falha (classe inexistente). `green`: implementar | suíte 222/778 verde + lint 0 (static `PokeApi` ainda existe, prova de paridade) |
| 2 | **Interface `PokeApi` (`lib/gateways/poke_api.rb`):** módulo contrato + `instance`/`instance=` (default lazy `PokeApiHttp.new`). `red`: teste novo da interface falha. `green`: implementar | suíte verde + lint 0 |
| 3 | **Adapter fake p/ teste (`test/poke_api_fake.rb`):** `PokeApiFake` configuravel por operação, satisfaz a interface. `red`: teste novo do fake falha. `green`: implementar | suíte verde + lint 0 |
| 4 | **Composition root + migração prod:** `server.rb` com `set :api, PokeApi.instance` e ações/helpers via `settings.api`; `OpponentGenerator` com `fetcher: settings.api.method(:detail)`; `BattleEngine` com `effectiveness: TypeEffectiveness.load(settings.api)`; `TypeEffectiveness.load(api = PokeApi.instance)`; default do `OpponentGenerator` via `PokeApi.instance`. `red`: testes de servidor acusam static ainda nos handlers. `green`: migração | suíte verde + lint 0 (nenhuma rota muda) |
| 5 | **Migração dos testes:** `poke_api_test.rb`/`poke_api_move_test.rb` e `server_test.rb` de static + singleton p/ instâncias (`PokeApiHttp.new`) e `PokeApiFake` injetado; `PokeApiStub.stub_singleton` removido (a DSL `with_*` vira construtor do fake + swap de `Server.api`). `red`: suíte aponta `PokeApi.x`/patches faltantes. `green`: rewrite | suíte completa verde + lint 0 |
| 6 | **Remover static + docs:** apagar `lib/poke_api.rb` (static) e módulos antigos; `grep 'PokeApi\.[a-z]' lib server.rb` → só `PokeApi.instance`; atualizar `draft-arquitetura-design-patterns.md` (E1 → E1-A feito + E1-B pendente) | suíte verde + lint 0 + docs no mesmo escopo |

## 6. Validação (executada pelo usuário)

**Status: pendente.** Ao concluir a fase de implementação (passos 1–6 verdes), o agente **para**
e aguarda o feedback do usuário. Itens a verificar na validação:

- [ ] Suíte completa verde (baseline **222 runs/778 asserts** preservado).
- [ ] Lint RuboCop 0; sem `rubocop:disable` novo em produção.
- [ ] `grep 'PokeApi\.[a-z]' lib server.rb` → somente `PokeApi.instance` (sem integração estática).
- [ ] `lib/poke_api.rb` (static) removido; `PokeApiStub.stub_singleton` (monkey-patch) removido.
- [ ] `./scripts/run`: Lista/Detalhe/Time/Time-Manage/Batalha funcionando (injeção ok em dev).

## 6b. Progresso da implementação (passos 1–6)

> Preenchido durante a fase 2 (TDD). Não marcar como validado até o usuário validar.

## 7. Observações

- **E1-B (próxima sessão, pendente):** decorator `PokeApiCache` (TTL/LRU **fixos**, decisão 9
  do draft) sobre o gateway, removendo a memoização interna do `PokeApiHttp`. Entra por
  composição sobre a interface — transparente para servidor/domínio (é o motivo da injeção).
- Sequência mantida (2026-08-10): **E1-A → E1-B → D2 → D3 → Eco-1..4**.
- A suíte de rota usa stubs **sem rede**: o monkey-patch de `Faraday.get` nos testes de lib
  permanece válido para testar **PokeApiHttp** (robustez RF-18); o patch de singleton
  `PokeApi.define_singleton_method` **é removido** (adapter fake substitui).
- Injeção em testes de servidor: `Server.set :api, PokeApiFake` (override de settings no
  setup/teste, restore no `ensure`) — mesmo mecanismo do `PokeApiStub` de hoje, sem patch
  global de classe.