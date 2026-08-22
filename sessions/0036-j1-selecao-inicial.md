# Sessão 0036 — J1: seleção inicial de time (fim do dropdown + tela de entrada da jornada)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-19 (confirmado J1 como próxima sessão; escopo, lista base, seleção, marcador da jornada, sprite e bloqueio) |
| Implementação | **Concluída** (passos 0–6 em 2026-08-21 — suíte/lint verdes) |
| Validação | **Em ajuste (S3)** — feedback do usuário em 2026-08-22 reabriu o critério da listagem (ver seção 5-A); revalidação pendente |

---

## 1. Objetivo

**J1 — seleção inicial de time** (3ª da ordem fechada em 2026-08-18 — ver
`draft-auto-battler.md:418-427`): **fim do dropdown** da listagem e **tela de entrada
da jornada**. No lugar do `<select>` de `#pokemon-list` (RF-01/sessão 0006), uma
**lista clicável** (sprite + nome + botão de Add por item) para **escolher e montar o
time inicial de 6** e seguir a jornada. A jornada **bloqueia Batalha, Poke Mart e
Poke Center** até o time inicial de 6 estar montado.

**Escopo fechado pelo usuário (2026-08-19):**
1. **Fim do dropdown** — `#pokemon-list` vira lista de itens clicáveis (sprite + nome
   → detalhe `GET /pokemon/:poke_id`; botão próprio → `POST /team`), mantendo a busca
   paginada; navegação por teclado nativa (Tab/Enter nos links) — sem JS custom (RNF-01).
2. **Lista base: pool total paginado + destaque às iniciais** — a lista paginada cobre
   o pool completo; um bloco **"Iniciais"** (as 9 iniciais de gen 1–3) aparece no topo
   quando a busca está vazia.
3. **Seleção por URL e botão próprio** — nome (e sprite) = link para o detalhe
   (`GET /pokemon/:poke_id`, RF-06); botão **Add to Team** separado por item
   (`POST /team` com `pokeName`).
4. **Tela de entrada da jornada** — **Batalha, Poke Mart e Poke Center bloqueados**
   até o time inicial de 6 estar montado; marcador persistido em **`user_state`
   (tabela por usuário) + derivado do tamanho do time**.
5. **Lista com sprite, 20/página** — cada item mostra sprite + nome + Add; a paginação
   da listagem passa de 100 para **20 itens por página** (custo de rede aceito: 20
   `find` por página, paralelizados e cacheados por P1).

## 2. Contexto (estado atual — diagnóstico)

- `views/pokemon_list.erb` renderiza um `<select name="name" id="pokemons">` com ≤100
  `<option>` + controles "Anterior/Próxima" + "Página X de Y" (RF-01/sessão 0006) —
  alvo htmx `#pokemon-list` (`index.erb:12` embute `erb :pokemon_list` na carga).
- Gateway: `PokeApi#paginate(offset:, limit:, query:)` devolve `{names:, total:}` —
  **nomes apenas, sem sprite/número** (`poke_api_http.rb:27-31`); `find(name)` devolve
  `Pokemon` com `number`+`sprite` (`poke_api_http.rb:33-42`), cacheado (E1-B/P1).
- Rotas: `GET /` (`render_index`, `server.rb:49-55`) e `GET /pokemons`
  (`render_pokemons_list`, `server.rb:57-63`) usam `settings.api.paginate`.
- Gate atual de batalha: `BattleService#prepare` → `:empty_team` → fragmento "Forme seu
  time para batalhar." (`server.rb:200-217`) — só bloqueia time **vazio**; time parcial
  batalha normalmente.
- Poke Mart (`POST /mart/buy`) e Poke Center (`POST /team/heal`) operam para **qualquer**
  time não-vazio (Eco-2/Eco-3).
- Testes de rota de battle/mart/heal montam times de **1–3 membros** e funcionarão
  bloqueados pela jornada → **migração necessária** (helper `start_journey`).
- Sem tabela de estado de usuário hoje; identidade é `session[:user_id]` (RF-05) com
  `?as=` para validação (0025).

## 3. Escopo

### Produção

| Arquivo | Mudança |
| --- | --- |
| `db/migrations/0036_add_user_state.sql` (novo) | `CREATE TABLE IF NOT EXISTS user_state (user_id TEXT PRIMARY KEY, journey_started BOOLEAN NOT NULL DEFAULT false)` — idempotente, sem `TRUNCATE`. |
| `lib/user_state_repository.rb` (novo) | `started?(user_id)` → bool; `mark_started(user_id)` → upsert true; padrão dos demais repositórios (conexão única, `WHERE user_id`). |
| `lib/journey_service.rb` (novo) | `started?(user_id)` = `user_state.started? || team.all(user_id).size >= 6` (tabela **+ derivado do time**); `mark_started(user_id)`; `mark_started_when_full(user_id)` (persiste ao chegar a 6). |
| `server.rb` | `set :user_state` + `set :journey` (deps); `render_index`/`render_pokemons_list` com `PAGE_SIZE = 20`, `@items` (page names → `find` via `Parallelizer`) e `@starters` (9 slugs → `find`) quando `q` vazio; `render_battle_fragment` com gate de jornada; `heal_team`/`buy_from_mart` com gate (no-op + notice); `add_team_member` marca jornada ao chegar a 6; expõe `@journey_started` onde `team.erb` é renderizado. Constantes `PAGE_SIZE = 20` e `STARTER_SLUGS` (9 iniciais). |
| `views/pokemon_list.erb` | Substitui o `<select>` por `<ul>` de itens: sprite + nome (links `hx-get="/pokemon/:number"` no alvo `#pokemon`) + form Add (`hx-post="/team"` com `pokeName`); bloco **"Iniciais"** no topo quando `q` vazio; paginação 20/página mantendo `offset`/`q`. |
| `views/index.erb` | Remove o `<label>` que referenciava o select; mantém input `q` + `#pokemon-list` (embute a lista clicável). |
| `views/team.erb` | Blocos Poke Center e Poke Mart renderizados **apenas quando `@journey_started`**; aviso de jornada quando time inicial incompleto. |

### Testes

- Novos: `test/user_state_repository_test.rb` (started? default false, mark_started,
  isolamento por usuário), `test/journey_service_test.rb` (derivado do time com 6 sem
  flag; flag sozinha libera; flag OU tamanho; `mark_started_when_full` a partir de 6).
- Novos de rota: lista clicável (sprite + nome → detalhe + form Add), 20/página
  ("Página 1 de 13" com 250 nomes), destaques "Iniciais" (9 itens quando `q` vazio),
  gates (batalha/mart/heal bloqueados sem jornada; time de 6 sem flag libera;
  `POST /team` ao 6º membro marca `user_state`), `team.erb` sem Center/Mart antes da jornada.
- Migração: `ServerTestHelpers`/`TestSupport` ganham `start_journey(user_id)`
  (`UserStateRepository#mark_started`); testes de battle/mart/heal/team que assumiam
  time parcial sem jornada passam a iniciar a jornada no setup; testes de paginação
  (100/página, `select`) reescritos para o novo contrato (20/página, lista clicável).
- Fakes/stubs intactos (`PokeApiStub.with_find` para resolver nomes → Pokemon).

### Fora de escopo (RNF-04 — não abrir)

- JN-2, J3, JN-1, JN-5 e demais JN/J (próximas da fila).
- D4 (draft temático) e J4 (nome na entrada).
- Bloquear Histórico (ficou fora do bloqueio — decisão do usuário: só Batalha + Mart +
  Center).
- Mudar o contrato de `paginate` (nomes) — o enriquecimento com sprite/número fica na
  rota via `find` + `Parallelizer`, sem tocar o gateway.
- Migração destrutiva de dados (nada de `TRUNCATE`).

## 4. Critérios de aceite

### Resultado

- [ ] **Fim do dropdown:** `GET /pokemons` (e `GET /`) devolve lista clicável — por item:
      sprite + nome como links `hx-get="/pokemon/:number"` no alvo `#pokemon` (RF-06) e
      um form `hx-post="/team"` com `pokeName` (Add); **sem `<select>`/`<option>`**;
      sem `<html>` no fragmento.
- [ ] **Pool total paginado 20/página, só formas base** *(alterado em 2026-08-22 — S3
      5-A)*: a lista cobre o pool completo com `limit: 20` ("Página X de Y" correto,
      ex. 250 nomes → "Página 1 de 13"), controles Anterior/Próxima mantendo `offset`
      e `q`, filtro por substring preservado — e exibe **apenas formas base**
      (1º estágio de cada linha evolutiva; evoluções ocultas).
- [ ] **Destaque "Iniciais":** com `q` vazio, o topo mostra o bloco "Iniciais" com os
      **27 iniciais de gen 1–9** *(alterado em 2026-08-22 — S3 5-A)* — cada uma com
      sprite + nome → detalhe + Add; **iniciais não reaparecem na listagem do pool**
      (sem duplicação); com `q` não-vazio, o bloco some (0 regressão do filtro).
- [ ] **Tela de entrada da jornada — gate:** `GET /battle`, `POST /mart/buy` e
      `POST /team/heal` devolvem fragmento amigável (200, sem ação) enquanto a jornada
      não iniciou; `POST /team` que completa o 6º membro **marca a jornada** (`user_state`
      persistido) e libera Batalha/Mart/Center a partir daí.
- [ ] **Marcador = tabela + derivado do time:** usuário com time de **6 membros mas sem
      flag** (legado/seed) já é considerado com jornada iniciada; flag persistida libera
      mesmo se o time encolher depois; isolamento por usuário (jornada de um não afeta
      outro).
- [ ] **`team.erb` coerente com a jornada:** antes de iniciar, os blocos Poke Center e
      Poke Mart não aparecem no fragmento `#team` (aviso de jornada no lugar); após
      iniciar, aparecem (0 regressão Eco-2/Eco-3).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (586 runs/1787 asserts)** + novos
      testes e lint 0 em **todo** green; commit obrigatório por passo; 0 regressão
      RF-01..RF-18/Eco (rotas migradas pela trava da jornada).
- [ ] Sem novas gems; testes sem rede (`PokeApiStub.with_find`/`with_all_names`);
      `Parallelizer` reusado (P1) para o enriquecimento dos itens; sem `rubocop:disable`.
- [ ] `REQUIREMENTS.md` (roadmap item 24/25 — J1 executado; status `Planejada` até
      validação), `SESSIONS.md` (0036 em fase 2 + próximas JN-2→J3→JN-1) e
      `draft-auto-battler.md` (J1 executado) atualizados no mesmo escopo do passo docs;
      *status de validação* só após o usuário validar.

### Critério → teste que o prova (S1)

| Critério | Teste (arquivo/nome) |
| --- | --- |
| Fim do dropdown (lista clicável) | `test/pokemon_routes_test.rb` — itens com sprite+nome→detalhe+Add, sem `<select>` (novos `test_index_renders_clickable_list`/`test_pokemons_renders_clickable_list`) |
| Pool total 20/página, só formas base | `test/pokemon_routes_test.rb` — 20 itens, "Página 1 de 13", Anterior/Próxima, filtro (reescritos) + `test_pokemons_omits_evolved_forms_from_list` |
| Destaque "Iniciais" | `test/pokemon_routes_test.rb` — bloco com 27 iniciais gen 1–9 quando `q` vazio; some com filtro; `test_pokemons_excludes_starters_from_pool_list` |
| Gate da jornada (battle/mart/heal) | `test/battle_routes_test.rb`/`test/mart_routes_test.rb`/`test/team_routes_test.rb` — fragmento 200 sem ação antes da jornada; liberado após iniciar |
| `POST /team` ao 6º marca jornada | `test/team_routes_test.rb` — `user_state.journey_started = true` ao completar 6 |
| Marcador tabela + derivado do time | `test/journey_service_test.rb` — time 6 sem flag libera; flag persiste após encolher; `test/user_state_repository_test.rb` — isolamento |
| `team.erb` sem Center/Mart antes da jornada | `test/team_routes_test.rb` — sem "Poke Center"/"Poke Mart" antes; com após |
| Garantias (baseline, lint, sem gem/rede/disable) | suíte completa `./scripts/test` + `./scripts/lint` |

## 5. Decisões de refinamento (fechadas com o usuário)

- **J1 confirmado como próxima sessão (0036)** após a 0035 (P1) validada — ordem da
  fila mantida: J1 → JN-2 → J3 → JN-1 → organizar o resto.
- **Fim do dropdown com tela de entrada da jornada:** além de trocar o `<select>` por
  lista clicável, a montagem do time inicial de 6 é a **porta de entrada** — Batalha,
  Poke Mart e Poke Center ficam bloqueados até lá (decisão do usuário em 2026-08-19).
- **Lista base = pool total + destaque "Iniciais":** a listagem paga o pool completo
  (busca paginada preservada); o bloco "Iniciais" (9 slugs fixos de gen 1–3) dá o
  destaque temático. Decisão do usuário.
- **Seleção por URL + botão próprio:** nome/sprite viram link para o detalhe (RF-06,
  `GET /pokemon/:poke_id`); Add é botão dedicado por item (`POST /team`). Sem JS custom
  (RNF-01) — Tab/Enter nativos nos links (seleção por teclado).
- **Marcador da jornada = tabela de usuário + derivado do tamanho do time:** nova
  tabela `user_state` (persistida) **e** regra derivada `team.size >= 6`; a flag é
  persistida quando o time completa 6 (marca no `POST /team`), e usuários legados/seed
  com 6 já estão liberados. Decisão do usuário (combina persistência + derivação).
- **Lista com sprite, 20/página:** cada item exibe sprite; para limitar o custo de
  rede, a página passa de 100 → 20 itens (20 `find` paralelos por página, cache P1).
  Decisão do usuário.
- **Bloqueio = Batalha + Mart + Center** (Histórico fica livre). Decisão do usuário.
- **Sem mudança de contrato do gateway:** `paginate` continua devolvendo nomes; o
  enriquecimento (sprite/número) acontece na rota via `find` + `Parallelizer` (reuso P1).
- **Ordem sugerida:** `user_state` + `JourneyService` → gates de rota (battle/mart/heal)
  + marcação no add → `team.erb` (Center/Mart gated) → lista clicável 20/página →
  destaques "Iniciais" → migração/regressão → docs.

## 5-A. Alteração de critério em validação (S3 — 2026-08-22)

- **Feedback do usuário (fase 3, 2026-08-22):** "a listagem deve incluir apenas
  pokémon iniciais, sem evoluções".
- **Interpretação aprovada pelo usuário:** **formas base de todo o pool** — a listagem
  mantém o pool paginado, mas mostra apenas o **1º estágio de cada linha evolutiva**
  (pikachu sim, raichu não; bulbasaur sim, ivysaur/venusaur não).
- **Reabertos/alterados:** critério "Pool total paginado 20/página" passa a exigir o
  filtro de formas base na listagem; critério→teste correspondente atualizado.
  Bloco "Iniciais" permanece inalterado (os 9 são formas base). Demais critérios
  mantidos.
- **Escopo técnico adicional:** predicado **`base_form?(name)`** no gateway (espécie é
  a raiz da própria cadeia evolutiva — `pokemon-species` + `evolution-chain`),
  implementado em `PokeApiParsing`, delegado em `PokeApiCache`, suportado no
  `PokeApiFake`; a rota filtra os itens da página antes de renderizar.
- **Comportamento acordado:** paginação continua paginando **nomes do pool**
  (`offset` por 20) — uma página pode listar menos itens quando contém evoluções;
  falha de rede no predicado esconde o item (**fail-closed**, só base confirmada
  aparece). Custo extra aceito: chamadas de espécie+cadeia por nome, cacheadas
  (E1-B/P1). Revalidação pelo usuário ao fim do ciclo.
- **Ajustes complementares do mesmo feedback (2026-08-22):**
  1. **Iniciais = todas as gerações (27, gen 1–9)** — o bloco fixo passa de 9
     (gen 1–3) para os 27 iniciais base: bulbasaur/charmander/squirtle,
     chikorita/cyndaquil/totodile, treecko/torchic/mudkip, turtwig/chimchar/piplup,
     snivy/tepig/oshawott, chespin/fennekin/froakie, rowlet/litten/popplio,
     grookey/scorbunny/sobble, sprigatito/fuecoco/quaxly.
  2. **Iniciais não reaparecem na listagem do pool** — como são fixos no topo,
     `STARTER_SLUGS.include?(name)` exclui o nome antes do enriquecimento
     (sem duplicação entre bloco e lista).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo de sessão com critérios e plano fechados | commit `Sessao 0036: refinamento concluido — J1 (selecao inicial): fim do dropdown (lista clicavel 20/pagina + destaques iniciais), tela de entrada da jornada (gate battle/mart/center ate time de 6, marcador user_state + derivado do time)` |
| 1 | **`user_state` + `JourneyService`:** `red` — `test/user_state_repository_test.rb` (started? false; mark_started persiste; isolamento) e `test/journey_service_test.rb` (time 6 sem flag libera; flag sozinha libera; `mark_started_when_full` persiste só ao chegar a 6). `green` — migração `0036` + `UserStateRepository` + `JourneyService` | suíte completa verde + lint 0, commit `Passo 1:` |
| 2 | **Gates de rota + marcação no add:** `red` — `GET /battle`, `POST /mart/buy` e `POST /team/heal` sem jornada → fragmento 200 sem ação (aviso); `POST /team` ao completar 6 → `user_state.journey_started = true`; com jornada iniciada → comportamento atual (batalha abre, compra/curar executam). `green` — `render_battle_fragment`/`heal_team`/`buy_from_mart` com gate; `add_team_member` chama `mark_started_when_full`; helper `start_journey` nos testes | suíte completa verde + lint 0, commit `Passo 2:` |
| 3 | **`team.erb` gated:** `red` — `GET /team` sem jornada não exibe "Poke Center"/"Poke Mart" (aviso de jornada no lugar); com jornada exibe (0 regressão Eco-2/3). `green` — `@journey_started` onde `team.erb` é renderizado + condicionais na view | suíte completa verde + lint 0, commit `Passo 3:` |
| 4 | **Lista clicável 20/página:** `red` — `GET /`/`GET /pokemons` com sprite+nome→detalhe+Add, sem `<select>`/`<option>`, 20 itens/página ("Página 1 de 13" com 250), Anterior/Próxima, filtro preservado (testes de paginação reescritos). `green` — `PAGE_SIZE = 20` + `@items` via `Parallelizer`+`find` + `pokemon_list.erb`/`index.erb` | suíte completa verde + lint 0, commit `Passo 4:` |
| 5 | **Destaque "Iniciais":** `red` — com `q` vazio o bloco "Iniciais" (9 slugs gen 1–3) aparece no topo com sprite+nome→detalhe+Add; com filtro some. `green` — `STARTER_SLUGS` + `@starters` (quando `q` vazio) + bloco na view | suíte completa verde + lint 0, commit `Passo 5:` |
| 6 | **Docs:** `REQUIREMENTS.md` (roadmap item 24/25 — J1 executado, status `Planejada` até validação), `SESSIONS.md` (0036 fase 2 + próximas JN-2→J3→JN-1), `draft-auto-battler.md` (J1 executado), `docs/screens/pokemon-list.md` (wireframe da lista clicável) | suíte verde + lint 0, commit `Passo 6:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar `Done`/commitar conclusão antes. |

## 7. Validação (executada pelo usuário)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| Fim do dropdown (lista clicável) | `./scripts/test -n /clickable_list/` | `GET /` sem `<select>`; clique no nome abre detalhe; botão Add monta o time | |
| Pool total 20/página | `./scripts/test -n /Página 1 de 13/` | listagem mostra 20 itens com sprite + paginação 20 | |
| Destaque "Iniciais" | `./scripts/test -n /iniciais/` | bloco "Iniciais" com 9 slugs no topo (busca vazia) | |
| Gate da jornada (battle/mart/heal) | `./scripts/test -n /journey/` | antes de 6: Batalha/Mart/Center mostram aviso e não executam | |
| `POST /team` ao 6º marca jornada | `./scripts/test -n /journey/` | ao adicionar o 6º, Batalha/Mart/Center liberam | |
| Marcador tabela + derivado do time | `./scripts/test -n /journey_service/` | seed com time de 6 já batalha sem flag | |
| `team.erb` sem Center/Mart antes da jornada | `./scripts/test -n /journey/` | fragmento `#team` sem Poke Center/Mart até iniciar | |
| Garantias RNF | suíte completa + `./scripts/lint` | rotas com fakes verdes; docs consistentes | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

- **Próximas sessões (ordem fechada 2026-08-18):** após J1 → JN-2 (golpes em lista) →
  J3 (ranking S–F) → JN-1 (telas próprias) → organizar o resto (JN-3, JN-4, JN-5, J2,
  J4, D4). A 0036 é a 3ª da fila (Respiro 2 = 0033 e D1 parcial = 0034 já concluídos;
  0035 P1 entrou no lugar de J1 e foi validada em 2026-08-19).
- **Migração de testes:** os testes de battle/mart/heal hoje montam time parcial; a
  trava da jornada exige `start_journey(user_id)` no setup desses casos — o critério
  "0 regressão" cobre a migração, não a remoção de cobertura.
- **Custo de rede aceito (decisão do usuário):** 20 `find` por página + 9 iniciais,
  paralelizados (`Parallelizer`) e cacheados (E1-B/P1) — 1ª carga quente, demais com
  cache.
- **Candidato futuro:** a lista clicável de J1 é a base visual do gameloop (JN-5) e do
  draft temático (D4) — não abrir agora (RNF-04).
