# Sessão 0056 — UX-2: custo e tier na listagem da GET / (M2)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões ratificadas pelo usuário em 2026-08-26 (todas A) |
| Implementação | **Pendente** |
| Validação | **Pendente** |

---

## 1. Objetivo

Exibir **custo e tier de cada Pokémon na listagem da `GET /`** para montar o time ciente do preço do M2.

## 2. Contexto (estado atual — antes do código)

- **Listagem hoje:** `GET /` (`render_index` → `load_pokemon_page` em `server.rb:78-101`) monta `@starters` (27 iniciais) + `@items` (comuns base-form via `Parallelizer` batch 24) e renderiza `pokemon_list.erb` → `pokemon_list_item.erb` (sprite + nome + botão Add). Nenhum custo/tier aparece; a decisão acontece às cegas.
- **M2 (0055) já entregue:** `TeamBudget` (`lib/team_budget.rb`) com tabela **S=120/A=70/B=55/C=40/D=30/F=20**, `BUDGET 450`, `S_LIMIT 3`, `cost_for(line_tier:, restricted:)` (restrito = metade, floor), `fits?` e `s_limit_ok?`; `evolution_restricted?(name)` no gateway (trigger ≠ level-up); `line_tier` = **máximo dos tiers da cadeia** via `PokemonRatingCache#rating_for` (TTL 7d, `PokemonRatingCache` injetável via `Server.set :rating_source`, mesmo cache da varredura de oponentes em `BattleService`). O add (`POST /team`) já bloqueia por teto/orçamento; o painel do time mostra custo/orçamento/S. O que falta é **espelhar o preço na lista**.
- **Fonte de rating na listagem:** o batch de `Parallelizer.map(@page_names) { find }` já traz `pokemon.evolutions` (todos os membros da cadeia, `poke_api_parsing.rb` flatten_chain) — o tier da linha sai de `rating_for` sobre esses nomes **sem fetch extra**. A mesma fonte de rating do M2 (injetável, fake determinístico em teste) serve a lista.
- **Ideias de encerramento (REQUIREMENTS.md ~641, `draft-auto-battler.md` UX-2):** "exibir ranking/custo dos pokes na lista" + "filtros além da busca" + "alinhar caixa da lista com a do time". Esta sessão cobre **apenas o primeiro item** (custo/tier na listagem); filtros avançados e alinhamento ficam para sessão futura (0057), anotados fora do fluxo (RNF-04).

## 3. Escopo

### Produção

- `views/pokemon_list_item.erb`: badge inline ao lado do nome/sprite com custo e tier da linha:
  `<span class="poke-cost" data-tier="B">B · 55</span>`; quando `evolution_restricted? == true`, exibir **metade** (ex.: B 55 → 27) com ícone indicador de restrição (ex.: `◐`/`◆` ou classe `restricted`). Cor por tier via CSS (atributo `data-tier`).
- `server.rb` (`ServerListActions`): em `load_pokemon_page`, após resolver `@items`/`@starters`, **derivar custo e tier por Pokémon exposto** para o partial (ex.: `@pokemon_costs`/`@pokemon_tiers` ou enrich nos pares `[name, pokemon]` com `cost`/`tier`/`restricted?`), reusando `PokemonRatingCache` (`settings.rating_source`) + `TeamBudget.cost_for` + `api.evolution_restricted?`; `line_tier` = máximo dos `rating_for` dos nomes de `pokemon.evolutions` (já disponíveis no batch 24, sem fetch extra). Fallback: tier `F` se `rating_for` vazio.
- `public/style.css` (ou `views/layout.erb` inline mínimo): cores por tier via `[data-tier="S"]` etc. (S/A/B/C/D/F), alinhamento do badge sem quebrar o grid 6×6 (Onda 3) nem o botão Add.

### Testes

- `test/list_routes_test.rb` (ou `test/pokemon_list_test.rb` — criar se inexistir): listagem renderiza custo e tier por Pokémon; cobre cadeia ramificada (Eevee-like) provando `line_tier` = máximo da cadeia com `rating_for` stubado, e caso restrito com metade; paginação/busca preservadas e sem rede (stubs/fakes determinísticos).
- Critérios → teste fechados em S1 (ver §4); C3 inclui verificação `manual` para alinhamento/cores/OOB visual.

### Fora de escopo (não abrir)

- **Filtros avançados** (tipo, geração, custo, ranking combináveis com busca e paginação) — sessão futura (0057) anotada em `REQUIREMENTS.md`/draft.
- **Alinhamento lista ↔ time** (largura/altura/rolagem coerentes das caixas da `/`) — sessão futura.
- **Ordenação por custo/tier** na listagem.
- **Persistir custo** por membro (custo segue derivado do time atual, como no M2).
- **Q5 / race no add / escritas atômicas / CSRF / CI / pry / M1 pedras / regra vida zerada** — limitações técnicas já anotadas, fora desta sessão.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 (listagem mostra custo e tier por Pokémon):** a `GET /` (e `GET /pokemons` fragmento) renderiza para cada Pokémon da lista um badge com **tier da linha** e **custo** (`S·120` etc.), com `data-tier` para cor; restrito mostra metade + indicador. — prova: `test/list_routes_test.rb` (`test_pokemon_list_shows_cost_and_tier` ou nome equivalente em `pokemon_list_test.rb`).
- [ ] **C2 (custo da lista = TeamBudget por linha):** o custo exibido é `TeamBudget.cost_for(line_tier: max_tier_da_cadeia, restricted: evolution_restricted?)` — cadeia ramificada paga pelo **maior tier da cadeia** e restrito paga **metade (floor)**. Prova com cadeia ramificada stubada e `rating_for` determinístico nome→tier. — prova: `test/list_routes_test.rb` (`test_pokemon_list_cost_uses_line_tier_and_restricted_half` ou `test_list_cost_from_chain_max_with_half_for_restricted`).
- [ ] **C3 (paginação/busca preservadas e sem rede + visual):** paginação on-demand (PAGE_SIZE 36, página 1 = 27+9) e busca por nome continuam funcionando; testes **sem rede** (rating e cadeia por stubs/fakes, como no M2); badge **alinhado**, **cores por tier** e **OOB de `#pokemon-list` pós add/remove** conferidos visualmente. — prova: `test/list_routes_test.rb` (`test_pokemon_list_pagination_and_search_preserved` e `test_pokemon_list_without_network`) + **manual** (conferir visualmente com `./scripts/run`: alinhamento do badge, cores por tier, OOB da lista após `POST /team`/`DELETE /team`).

### Garantias (RNF)

- [ ] **G1:** suíte completa verde após cada passo + lint 0 em todo green; commit obrigatório por passo; 0 regressão fora do escopo (paginação/busca/add existentes seguem verdes via fake de rating default).
- [ ] **G2:** sem gems novas / sem mudança de schema / testes sem rede (rating e cadeia por stubs/fakes; reuso do `rating_source` injetável via `Server.set`); manter o padrão local de RuboCop em testes.
- [ ] **G3:** `SESSIONS.md` atualizado no commit do refinamento (S4); status de validação só após o usuário validar (fase 3 — parar na fase 2 e aguardar).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste automatizado → `manual` explícito + evidência esperada (ver C3).

## 5. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (tabela + "Próxima sessão") | commit `Sessao 0056: refinamento concluido — UX-2 custo/tier na listagem (M2), criterios e plano TDD fechados` |
| 1 | **red→green** — `server.rb` + `pokemon_list_item.erb`: badge inline `poke-cost` com `data-tier` + derivação de custo/tier por Pokémon exposto (C1 vermelho primeiro: listagem sem badge → com badge via `rating_source` + `TeamBudget` + `evolution_restricted?`, line_tier = máx. da cadeia via `evolutions` do batch) | `./scripts/test test/list_routes_test.rb -n /shows_cost_and_tier/`; suíte completa + `./scripts/lint` 0; commit `Passo 1: badge de custo e tier na listagem via TeamBudget e line_tier da cadeia` |
| 2 | **red→green** — regra de metade para restrito + cadeia ramificada (C2): `evolution_restricted?` metade (floor) + prova de ramo máximo (Eevee-like) com `rating_for` stubado nome→tier | `./scripts/test test/list_routes_test.rb -n /line_tier_and_restricted/`; suíte + lint 0; commit `Passo 2: custo da lista considera max da cadeia e metade para restricao de evolucao` |
| 3 | **red→green** — paginação/busca/OOB + estilo (C3): preservar `PAGE_SIZE` 36, busca e `oob_pokemon_list` após add/remove; CSS por tier (`[data-tier]`) e alinhamento; sem rede (fakes determinísticos) + manual visual | suíte completa + lint 0; commit `Passo 3: paginacao e busca preservadas, cores por tier e OOB da lista` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar Done, não preencher a seção 7, não commitar conclusão. | — |

## 6. Decisões de refinamento (fechadas com o usuário em 2026-08-26 — todas A)

- **D1 — Escopo (A — UX-2 puro):** exibir custo e tier **na listagem da `GET /`** (M2). Q5 (2 cliques no remover) e filtros avançados ficam **fora**, como sessão 0057 futura. Alternativa preterida: incluir Q5/filtros no mesmo escopo (acoplaria bug UX a feature de balanceamento e estouraria o tamanho).
- **D2 — Onde exibir (A — badge inline no `pokemon_list_item.erb`):** `<span class="poke-cost" data-tier="B">B · 55</span>` ao lado do nome/sprite; restrito mostra metade + ícone e `data-tier` alimenta cor via CSS. Alternativa preterida: coluna própria na grade (quebraria o grid 6×6 da Onda 3) ou tooltip (esconderia o preço).
- **D3 — Critérios S1 (A — 3 critérios enxutos):** C1 listagem mostra custo/tier; C2 custo = `TeamBudget` por linha (máx. cadeia + metade se restrito); C3 paginação/busca preservadas e sem rede + manual visual. Alternativa preterida: granularizar em critérios por tier/ramificação/OOB (inflaria a S2 sem ganho de cobertura).
- **D4 — Fonte técnica (A — reuso do M2):** `PokemonRatingCache` (`rating_source` via `Server.set`, TTL 7d) + `TeamBudget.cost_for` + `api.evolution_restricted?`; `line_tier` = máx. da cadeia via `find(name).evolutions` já disponíveis no `Parallelizer` batch 24, **sem fetch extra**. Alternativa preterida: novo serviço de precificação ou fetch dedicado por Pokémon (duplicaria cache e latência).
- **D5 — Fora de escopo (A — enxuto):** filtros avançados, alinhamento lista↔time, ordenação por custo/tier, persistir custo, Q5/race/escritas atômicas/CSRF/CI/pry, M1 pedras, regra vida zerada — todos preteridos nesta sessão (anotados no `REQUIREMENTS.md`/draft, RNF-04).
- **D6 — Tamanho (A — 4 passos TDD):** refinamento + 3 greens (badge/derivação → metade/ramo → paginação/OOB/estilo). Alternativa preterida: 5+ passos com filtros/ordenação no mesmo ciclo.

## 7. Validação (executada pelo usuário)

*(Fase 3 — executada pelo usuário. Registro por critério, um resultado por linha — S2.
Ajuste de validação = alteração formal de critério com data e reaprovação — S3.)*

| Critério | Evidência automatizada | Evidência manual | Resultado |
| --- | --- | --- | --- |
| C1 (listagem mostra custo e tier) | `test/list_routes_test.rb` → `test_pokemon_list_shows_cost_and_tier` | — | — |
| C2 (custo = TeamBudget por linha, máx. cadeia + metade restrito) | `test/list_routes_test.rb` → `test_pokemon_list_cost_uses_line_tier_and_restricted_half` | — | — |
| C3 (paginação/busca preservadas, sem rede + visual) | `test/list_routes_test.rb` → `test_pokemon_list_pagination_and_search_preserved` / `test_pokemon_list_without_network` | Conferir alinhamento do badge, cores por tier e OOB da lista com `./scripts/run` (**manual**) | — |

## 8. Observações

- **Latência na listagem fria:** cada Pokémon exposto na página paga `rating_for` por membro da cadeia no miss (`detail` + `moves_for`); mitigado pelo `PokeApiCache` existente e pelo cache persistente de rating aquecido pela varredura de oponentes (0050) — aceito em D4, como no M2.
- **Famílias ramificadas (Eevee):** o tier da linha considera **todos** os membros da cadeia — o badge reflete o melhor ramo, combinando com o desconto de restrição (restrito = metade do melhor ramo). Quando M1 entrar, revisitar o desconto.
- **Testes de rota existentes** que renderizam a lista passam a precisar do fake de rating default (barato) para não tocar rede — previsto no passo 1 (G1 cobre a regressão), mesmo padrão do M2 no `POST /team`.
- **OOB da lista:** `POST /team` e `DELETE /team` já re-renderizam `#pokemon-list` via `oob_pokemon_list` (Onda 1) para reativar/desabilitar botões Add — o badge continua consistente após mutações do time.
- **Filtros avançados e alinhamento** ficam para a 0057 (UX-2b) — anotados no `REQUIREMENTS.md` e no `draft-auto-battler.md` (RNF-04), sem abrir escopo aqui.
- **Gotchas duráveis** do M2 (paridade de interface do gateway, choke point do `PokemonRatingCache`, trigger já parseado) seguem registrados em `gotchas/m2-custo-gateway-e-rating.md` e valem para esta sessão.
