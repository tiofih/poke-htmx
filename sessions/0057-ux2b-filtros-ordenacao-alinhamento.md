# Sessão 0057 — UX-2b: filtros avançados + ordenação + alinhamento lista↔time

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões ratificadas pelo usuário em 2026-08-26 (D1 A, D2 A2, D3 B, D4 A, D5 C, D6 B) |
| Implementação | **Pendente** — aguardando fase 2 (TDD) |
| Validação | **Pendente** — aguardando validação do usuário (fase 3 — parar na fase 2) |

---

## 1. Objetivo

Entregar **UX-2b — filtros avançados, ordenação e alinhamento da página `/`** como continuidade da 0056: filtros combináveis **tipo + geração + custo/tier** (extraídos do batch 24, reuso de `PokeApiCache`/`TeamBudget`), **ordenação por custo/tier**, **botão "limpar filtros"**, **persistência dos filtros em sessão** e **alinhamento visual lista↔time** (largura/altura/rolagem coerentes), tudo **server-side** e combinável com busca e paginação on-demand (`PAGE_SIZE` 36).

## 2. Contexto (estado atual — antes do código)

- **Listagem hoje (pós-0056):** `GET /` (`render_index` → `load_pokemon_page` em `server.rb:78-102`) monta `@starters` (27 iniciais gen 1–9) + `@items` (comuns base-form via `Parallelizer` batch 24, `base_form?` em `PokeApiParsing`) e renderiza `pokemon_list.erb` → `pokemon_list_item.erb`. A 0056 adicionou badge `poke-cost` com tier da linha + custo (`PokemonRatingCache` via `settings.rating_source` + `TeamBudget.cost_for` + `evolution_restricted?`, `line_tier` = máximo da cadeia via `pokemon.evolutions`, `build_pokemon_costs` em `server.rb:179-193`, `span.poke-cost[data-tier]` em `public/style.css`). Não há filtros além da busca por nome (`q`), nem ordenação, nem persistência; o grid é 6×6 (Onda 3) e o layout é 2 colunas (`list-team-grid` em `views/index.erb`/`public/style.css:258-276`).
- **M2/TeamBudget já entregue (0055):** tabela **S=120/A=70/B=55/C=40/D=30/F=20**, `BUDGET 450`, `S_LIMIT 3`, `cost_for(line_tier:, restricted:)` (restrito = metade floor), `line_tier` via `rating_for` (TTL 7d, `PokemonRatingCache` injetável via `Server.set :rating_source`). A mesma fonte serve os filtros/ordenação da lista.
- **O que falta (REQUIREMENTS.md ~641, draft-auto-battler.md UX-2):** "filtros além da busca — tipo, geração, custo, ranking combináveis com busca e paginação" + "alinhar a caixa da lista com a caixa do time" + "exibir ranking/custo" (este último foi a 0056). Esta sessão cobre **os dois itens restantes**, com a reconciliação D2/D5: ordenação por custo/tier e persistência entram nesta sessão (ao contrário do fora enxuto da 0056).
- **Geração ainda não exposta:** `Pokemon` tem `types`/`stats`/`evolutions` mas não `generation`; a species da PokéAPI traz `generation.url` (`/api/v2/generation/<n>/`) — novo método `generation_for(name)`/`pokemon_generation` no gateway (mesmo padrão `evolution_restricted?`, com `pokemon_data` + `fetch_chain_data`/species, cacheado via `PokeApiCache`) resolve sem fetch extra por item do batch quando acoplado ao `Parallelizer`.
- **Paginação atual:** `PAGE_SIZE = 36`, página 1 = 27 starters + 9 comuns, páginas 2+ = 36 comuns, `fetch_commons`/`collect_base_forms`/`base_form_names` em `server.rb:115-141` com scan em lotes 24 e `commons_window`/`fetch_commons` sem total (próximo lote sob demanda). Busca filtra `fetch_all_names` por substring de `q`. Filtros precisam ser aplicados **server-side, antes de paginar** (filtrar o pool de base-forms já resolvido no batch, depois paginar/ordenar), para que `PAGE_SIZE` continue cheio e combinável com `q`.

## 3. Escopo

### Produção

- `server.rb` (`ServerListActions`): estender `load_pokemon_page` para **derivar atributos de filtro/ordenação no batch 24 antes de paginar** e **filtrar/ordenar server-side**:
  - Derivação por Pokémon exposto (reuso da 0056): `types` já em `pokemon.types`, `generation` via novo `settings.api.generation_for(name)` (ou `pokemon_generation`, extrai `generation.url` → `1..9`, com fallback `nil`), `line_tier` via `line_tier_for(pokemon)` (máximo da cadeia via `rating_for`, como na 0056) e `cost` via `TeamBudget.cost_for(line_tier:, restricted: evolution_restricted?)`. Tudo no mesmo `Parallelizer.map` do `build_pokemon_costs` ou enriquecendo `@items`/`@starters` antes do filtro.
  - Filtros combináveis (AND) via query params `type`, `generation`, `tier`, `cost` (ex.: `cost_max` ou bucket, a fechar na fase 2; `tier` = S/A/B/C/D/F; `type` = 1 dos 18 tipos; `generation` = 1..9): filtrar o pool de candidatos base-form **antes** de fatiar a janela de paginação — i.e., escanear `common_candidates` em lotes 24, resolver cada lote em `pokemon` e aplicar predicados, acumulando até `offset+PAGE_SIZE` filtrados, depois fatiar. Compatível com `q` (busca substring) já em `common_candidates`.
  - Ordenação por custo/tier: param `sort` (ex.: `cost_asc`/`cost_desc`/`tier_desc`/`tier_asc`, default por número Pokédex/ordem de `fetch_all_names`); quando presente, ordenar o pool filtrado por `cost` (ou `TIER_ORDER`) antes de paginar; tier usa `TIER_ORDER = %i[F D C B A S]` já em `server.rb:348`.
  - Persistência: guardar/restaurar filtros em `session[:list_filters]` (Sinatra `session` já com `session[:user_id]`): em `render_pokemons_list`/`load_pokemon_page`, quando params de filtro/ordenação vierem, escrever em `session[:list_filters]`; quando vierem vazios mas a sessão tiver valores, restaurar como defaults (sem sobrescrever `q`/`offset` explícitos). `GET /` hidrata os controles com `session[:list_filters]`. Decisão D5 C: **persistência entra, não é fora**.
  - Paginação on-demand preservada: `PAGE_SIZE = 36`, página 1 = 27 starters + 9 comuns (quando sem filtro/ordenação que quebre a regra de starters — ver observação), páginas 2+ = 36 comuns; `previous_offset`/`next_offset` continuam calculados sobre a janela filtrada/ordenada (sem total; "Página X" + próximo lote sob demanda).
- `lib/gateways/poke_api_parsing.rb` (ou `poke_api.rb` interface): novo `generation_for(name)`/`pokemon_generation(name)` — retorna `1..9` via `pokemon_data(name)` → `species.url` → `http_get(species_url).dig("generation","url")` (regex `generation/(\d+)`), `nil` se falhar; `rescue Faraday::Error, JSON::ParserError` → `nil`. Paridade: adicionar ao fake/adapter e ao `gateway_interface_test`.
- `lib/pokemon.rb` (opcional): expor `generation` como atributo derivado quando `generation_for` já estiver resolvido no server (não persistido no DB; apenas enrich em memória para o filtro).
- `views/index.erb` + `views/pokemon_list.erb`: controles de filtro **acima** da lista (dentro de `#pokemon-list` ou como `hx-include` externo):
  - `select[name=type]` (18 tipos + "Todos"), `select[name=generation]` (1..9 + "Todas"), `select[name=tier]` (S/A/B/C/D/F + "Todos"), `select[name=cost]` ou `cost_max` (buckets ≤20/30/40/55/70/120, ou faixa), `select[name=sort]` (Padrão / Custo ↑ / Custo ↓ / Tier S→F / Tier F→S), e botão **"Limpar filtros"** (link `hx-get="/pokemons?offset=0&q=&type=&generation=&tier=&cost=&sort="` com `hx-target="#pokemon-list"` que também limpa `session[:list_filters]`).
  - Controles com `hx-get="/pokemons" hx-target="#pokemon-list" hx-swap="innerHTML" hx-include=".list-state, .filter-state"` (ou `closest form`) e `hx-trigger="change"`; a busca `q` por `keyup changed delay:300ms` passa a incluir `hx-include=".filter-state"` para compor filtros+busca; paginação (`Anterior`/`Próxima`) preserva `q` + filtros + `sort` na querystring.
  - `div.filter-state` / `div.list-state` com `hidden` inputs de `offset`/`q`/`type`/`generation`/`tier`/`cost`/`sort` para OOB de `#pokemon-list` após `POST /team`/`DELETE /team` (como já faz `oob_pokemon_list`) e após `POST /journey/restart`.
- `views/pokemon_list_item.erb`: sem mudança estrutural (badge já de 0056); `oob_pokemon_list` em `ServerTeamActions#oob_pokemon_list` passa a re-hidratar `session[:list_filters]` + params para que o OOB preserve filtros/ordenação/busca/paginação após mutações do time.
- `public/style.css` (ou `views/layout.erb` inline mínimo): **alinhamento lista↔time** — ajustar `list-team-grid` para larguras/alturas coerentes das duas caixas da `/` no desktop (ex.: `list-column` e `team-column` com `align-items: start`, `min-height`/`max-height` e `overflow-y: auto` harmonizados, gap 1.5em preservado), sem quebrar o grid 6×6 nem o breakpoint ≤720px (colunas empilham em 1 coluna). Os badges/cores por tier da 0056 seguem inalterados.

### Testes

- `test/pokemon_list_filters_test.rb` (novo, ou `test/list_routes_test.rb` se o padrão local preferir — criar se inexistir): cobertura sem rede via **stubs/fakes determinísticos** (mesmo padrão da 0056/M2: `Server.set :rating_source` com `FakeListRating` nome→tier, `PokeApiStub.with_find` + `with_generation`/`with_types` stubados, `generation_for` fake 1..9, `TeamBudget` real para custo).
  - Filtros por tipo, por geração, por tier, por custo e **combinações** (AND) com `q` e entre si; paginação com filtros (PAGE_SIZE 36, página 1 = 27+9 filtrados, páginas 2+ = 36 filtrados); busca preservada; sem rede; OOB de `#pokemon-list` após `POST /team`/`DELETE /team` preserva filtros/ordenação; ordenação por custo/tier (asc/desc, S→F/F→S) ordena o window filtrado antes de paginar; persistência em `session[:list_filters]` (segundo request sem params restaura filtros; `limpar filtros` zera sessão e query); `manual` para alinhamento/rolagem/cores visuais (ver C4).
- Critérios → teste fechados em S1 (ver §4); C4 inclui verificação `manual` para alinhamento/rolagem coerentes e cores do badge, e testes automatizados para ordenação/persistência/limpar.

### Fora de escopo (não abrir)

- **Busca por habilidade/moves** ou por texto além de substring de `name` — fica só `q` por nome (como hoje) combinável com os novos filtros.
- **Paginação com total** (contagem total de filtrados) — mantém "Página X" + próximo lote sob demanda, como na Onda 3.
- **Ordenação por nome/stats além de custo/tier** — nesta sessão só custo/tier (D2 A2); outras ordenações ficam fora.
- **Q5 / race no add / escritas atômicas / CSRF / identidade `?as=` / CI / `pry` / M1 pedras no Mart / regra "vida zerada não pode ser removido" / J2 / J4 / D4 / Poke Center flutuante / itens de evolução aleatórios no Mart / "batalhar resolve a batalha inteira" / animações nos ataques** — limitações e ideias já anotadas em `REQUIREMENTS.md`/drafts, fora desta sessão (RNF-04). Ver Observações para o que esta sessão **tirou** da lista de fora (ordenação e persistência).
- **Persistir custo por membro** (custo segue derivado do time atual, como no M2/0056) e **filtros no histórico/batalha** (só na lista da `/`).

## 4. Critérios de aceite

### Resultado

- [ ] **C1 (filtros tipo + geração combináveis com busca):** `GET /` e `GET /pokemons` aceitam `type` (um dos 18 tipos) e `generation` (1..9) combináveis entre si e com `q` (substring por nome da busca, incluindo hint de base-form/starter quando só casa com não-base); sem filtro, lista segue paginada por `PAGE_SIZE` 36. — prova: `test/pokemon_list_filters_test.rb` (`test_filters_by_type` + `test_filters_by_generation` + `test_filters_combined_type_and_generation_with_search` — cada um com `FakeListRating` + `PokeApiStub`/`FakeApi` com `types`/`generation` stubados, sem rede).
- [ ] **C2 (filtros custo/tier combináveis — line_tier = máx. da cadeia + metade restrito):** `tier` (S/A/B/C/D/F) e `cost` (bucket/≤ custo, ex.: `cost_max` ou `cost` que mapeia para `TIER_COST` com metade quando `evolution_restricted? == true`) filtram o pool já derivado no batch 24 via `rating_source.rating_for` (máximo da cadeia) + `TeamBudget.cost_for(line_tier:, restricted:)` + `evolution_restricted?`; combináveis entre si e com C1/`q`; cadeia ramificada (Eevee-like) prova que o tier da linha é o **máximo** dos ramos com `rating_for` stubado nome→tier, e caso restrito prova **metade floor**; botão **"Limpar filtros"** remove `type`/`generation`/`tier`/`cost`/`sort`/`q` (query vazia + `session[:list_filters]` limpa, lista volta ao padrão). — prova: `test/pokemon_list_filters_test.rb` (`test_filters_by_tier` + `test_filters_by_cost` + `test_filter_cost_uses_line_tier_and_restricted_half` + `test_filters_combined_tier_cost_type_generation` + `test_clear_filters_button_resets_list`).
- [ ] **C3 (paginação/busca/OOB preservados e sem rede):** paginação on-demand (`PAGE_SIZE` 36, página 1 = 27+9 quando aplicável, páginas 2+ = 36) e busca por nome (`q`) e hint de base-form continuam funcionando **com** filtros/ordenação ativos; `POST /team` e `DELETE /team` re-renderizam `#pokemon-list` via `oob_pokemon_list` preservando filtros+busca+paginação+ordenação; **sem rede** (rating/cadeia/tipos/geração por stubs/fakes determinísticos, reuso do `rating_source` injetável via `Server.set`, `PokeApiStub` sem Faraday, como no M2/0056). — prova: `test/pokemon_list_filters_test.rb` (`test_pagination_with_filters_and_search_preserved` + `test_oob_after_add_preserves_filters_and_sort` + `test_without_network`).
- [ ] **C4 (ordenação + persistência + alinhamento lista↔time):** ordenação por custo/tier (`sort` ex.: `cost_asc`/`cost_desc`/`tier_desc`/`tier_asc`) ordena o pool filtrado **antes** de paginar (tier usa `TIER_ORDER`/`TIER_COST`); filtros + ordenação **persistem em `session[:list_filters]`** (segundo `GET /pokemons` sem params restaura a última seleção; `limpar filtros` zera a sessão); **alinhamento lista↔time** — caixas da `/` no desktop com largura/altura/rolagem coerentes (sem overflow quebrado, sem quebrar grid 6×6 nem breakpoint 720px), badges/cores por tier preservados; visual conferido. — prova: `test/pokemon_list_filters_test.rb` (`test_ordering_by_cost_and_tier_sorts_before_pagination` + `test_filters_persisted_in_session` + `test_pagination_preserves_sort`) + **manual** (conferido visualmente via `./scripts/run`: controles de filtro/ordenação + botão limpar, ordenação visível, persistência entre navegações sem params, e alinhamento/rolagem coerentes das colunas da `/` com `data-tier`).

### Garantias (RNF)

- [ ] **G1:** suíte completa verde após cada passo + lint 0 em todo green; commit obrigatório por passo; 0 regressão fora do escopo (paginação/busca/add/OOB/hint/batalha/gameloop seguem verdes via fakes de rating/geração default).
- [ ] **G2:** sem gems novas / sem mudança de schema / testes sem rede (rating/cadeia/tipos/geração por stubs/fakes; reuso do `rating_source` injetável via `Server.set`; manter o padrão local de RuboCop em testes).
- [ ] **G3:** `SESSIONS.md` atualizado no commit do refinamento (S4); status de validação só após o usuário validar (fase 3 — parar na fase 2 e aguardar).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste automatizado → `manual` explícito + evidência esperada (ver C4).

## 5. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Parar ao fim da fase 2 e aguardar validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (tabela + "Próxima sessão") | commit `Sessao 0057: refinamento concluido — UX-2b filtros/geracao/custo/tier + ordenacao e alinhamento lista↔time, criterios e plano TDD fechados` |
| 1 | **red→green — filtro por tipo** (C1 parcial): `server.rb` filtra `type` (1 dos 18) server-side no `load_pokemon_page` (derivar `types` no batch 24, filtrar antes de paginar, reusar `Parallelizer`, `type` AND `q`), controles `select[name=type]` com `hx-get/hx-include/hx-target="#pokemon-list"` e `hx-trigger="change"`, paginação preserva `type`; sem rede (stub de `types`) | `./scripts/test test/pokemon_list_filters_test.rb -n /filters_by_type/`; suíte completa + `./scripts/lint` 0; commit `Passo 1: filtro por tipo na listagem (server-side, combinavel com busca)` |
| 2 | **red→green — filtro por geração** (C1 completo): novo `generation_for(name)` no gateway (species `generation.url` → 1..9, `rescue` → `nil`, paridade no fake/interface) + `server.rb` filtra `generation` combinável com `type`+`q` (mesmo scan filtrado antes de paginar), `select[name=generation]` 1..9 com `hx-include` | `./scripts/test test/pokemon_list_filters_test.rb -n /filters_by_generation|combined_type_and_generation/`; suíte + lint 0; commit `Passo 2: filtro por geracao (1..9) combinavel com tipo e busca` |
| 3 | **red→green — filtros custo/tier + botão limpar** (C2): `tier`/`cost` server-side (line_tier = máx. da cadeia via `rating_source.rating_for` + `TeamBudget.cost_for` + `evolution_restricted?`, metade floor quando restrito; `tier` filtra por tier da linha, `cost` filtra por `cost ≤ cost_max` ou bucket), todos combináveis (`type`+`generation`+`tier`+`cost`+`q`), botão **"Limpar filtros"** (`hx-get` query vazia + limpeza de `session[:list_filters]`) | `./scripts/test test/pokemon_list_filters_test.rb -n /filters_by_tier|filters_by_cost|line_tier_and_restricted|clear_filters/`; suíte + lint 0; commit `Passo 3: filtros por custo e tier (line_tier max cadeia + metade restrito) e botao limpar` |
| 4 | **red→green — ordenação + persistência + alinhamento** (C3/C4): `sort` (`cost_asc`/`cost_desc`/`tier_desc`/`tier_asc`, default por número) ordena pool filtrado antes de paginar (usa `TIER_ORDER`/`TIER_COST`); `session[:list_filters]` guarda/restaura `type`/`generation`/`tier`/`cost`/`sort` (segundo request sem params restaura; limpar zera sessão); `#pokemon-list` OOB pós `POST/DELETE /team`/`restart` preserva filtros+sort+paginação; `public/style.css` alinha `list-column`↔`team-column` (largura/altura/rolagem coerentes, breakpoint 720px preservado); `C3` sem rede + OOB + `manual` visual | suíte completa + lint 0; commit `Passo 4: ordenacao por custo/tier, persistencia em sessao e alinhamento lista-time` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar Done, não preencher a seção 7, não commitar conclusão. | — |

## 5-A. Ajuste S3 2026-08-26 — validação reprovou C1 e C3 (hotfix)

**Data:** 2026-08-26 — report do usuário: filtro `type=rock` => 2.5min e lista vazia.

**C1 reaberto (tipo vazio):** `ServerListActions#filtered_base_forms` em `server.rb:305` usava `settings.api.find(name)` e filtrava por `pokemon.types`; porém `PokeApiHttp#find` (`lib/gateways/poke_api_http.rb:36`) retorna `Pokemon.new(name:, sprite:, number:)` sem `types`/`evolutions` (só `detail` traz). Logo `types == []` e `select` nunca casava => lista vazia. Tests passavam porque `PokeApiStub.with_find` injeta `types` no fake, mascarando o bug real. Também degradava `line_tier_for` (depende de `evolutions` via `pokemon.evolutions`).

**C3 reaberto (performance p95 2.5min):** filtros de baixa cardinalidade (rock) varrem `common_candidates` full-scan (~1300 nomes) batendo `base_form?` + `find`/`generation_for` + `line_tier` sequencialmente por batch 24 sem cap; ordenação faz full-scan similar. Mitigação já prevista como risco em revisão.

**Plano de correção (executado neste hotfix, aguardando revalidação do usuário):**
1. Filtrar tipo via endpoint `/type/:name` (`PokeApiTypes#fetch_type_json` já existente) com novo `pokemon_names_by_type(type)` (extrai `json["pokemon"].map{dig("pokemon","name")}`) e cache em `PokeApiCache` + `PersistentJsonStore`; interseção `Set.new(type_names)` com `base_names` em `filtered_base_forms`, evitando N `find`s.
2. Onde `types`/`evolutions`/`stats` são necessários, usar `settings.api.detail` (cacheado) em vez de `find` — `sort_names`, bloco `tier`/`cost` em `filtered_base_forms` e `evolution_chain_names`/`line_tier_for` passam a preferir `detail` mantendo `find` só para sprite.
3. `PokeApiFake`/`PokeApiStub` expõem `pokemon_names_by_type` com `with_type_names`/`with_pokemon_names_by_type`; testes simulam `PokeApiHttp` real (`find` minimal sem `types`) e provam que filtro rock funciona via endpoint; `test_filters_by_type` segue verde via novo caminho e sem rede.
4. Performance: com interseção O(1) o caso rock evita N fetches; primeira carga fria ainda paga `base_form?` mas warm cache reduz p95; documentado como limitação aceita. Alternativa futura (cap de varredura) anotada fora deste hotfix.

**Status:** C1 reaberto e C3 reaberto em 2026-08-26; correção em `Passo 4b` desta sessão; aguardando segunda validação (fase 3) e reaprovação do usuário — **não marcar Done** até validação.

**Ajuste 2026-08-26 — limpar filtros não resetava dropdowns (hotfix 4c):**

Bug: `Limpar filtros` (`hx-get="/pokemons?offset=0&q=&type=&generation=&tier=&cost=&cost_max=&sort="` com `hx-target="#pokemon-list"`) resetava a lista mas os `select`s continuavam com o valor anterior — `views/index.erb` tinha os controles **fora** de `#pokemon-list` (`div.filter-controls` sem `id`), então o `hx-swap` só trocava a lista.

Fix: `views/index.erb` → `div` dos controles ganha `id="filter-controls"` e extrai para `views/_filter_controls.erb`; `ServerListActions#render_pokemons_list` passa a concatenar `oob_filter_controls` em **todo** `GET /pokemons` (`<div id="filter-controls" hx-swap-oob="innerHTML">#{erb :_filter_controls}</div>`) hidratando `@type/@generation/@tier/@cost_max/@sort` já normalizados (quando clear, `nil` → `Todos os tipos` / `Todas as gerações` / `Todos os tiers` / `Qualquer custo` / `Padrão` com `selected`). Sempre OOB (não só no clear) para manter selects sincronizados com sessão e `q`.

Prova: `test/pokemon_list_filters_test.rb#test_clear_filters_resets_dropdowns` — `GET /pokemons type=rock generation=1` devolve OOB com `id="filter-controls" hx-swap-oob` + `value="rock" selected` e `value="1" selected`; `GET /pokemons` clear (`type="" generation="" …`) devolve OOB com `Todos os tipos selected`/`Todas as gerações selected`/`Todos os tiers selected`/`Qualquer custo selected`/`Padrão selected` e sem `rock selected`. `test/pokemon_routes_test.rb` ajustado para exigir `id="filter-controls"` + `hx-swap-oob` em `GET /pokemons`.

Status: hotfix **Passo 4c** em 2026-08-26; suíte verde + lint 0; aguarda revalidação do usuário — **não marcar Done** até validação (S3).

**Ajuste 2026-08-26 — tiers/custo/sort sempre F e ordenação random (hotfix 4d):**

Bug: tiers/custo/sort dependem de `line_tier_for` → `settings.rating_source.rating_for(name)` → `PokemonRatingCache` com `fetcher: ->(name) { settings.api.find(name) }` (`server.rb:1066`). `PokeApiHttp#find` retorna `Pokemon` sem `stats`/`types`/`moves` (só `name`/`sprite`/`number`), logo `PokemonRating.rate` calcula `weighted_stats([])=0` → `score 0` → `tier :F` para todos. Então filtro `tier=S/A/B` retorna vazio, `tier=F` retorna tudo, custo (derivado do tier via `TeamBudget.cost_for`) também errado (`F=20` sempre), `sort` por `tier`/`cost` fica random (todos `F`/`20`). Tests passavam porque `FakeListRating` injeta `tier` determinístico, mascarando o bug real. Antes da 0057, `M2`/`0056` já usavam mesmo `fetcher`, mas não tinham filtro `tier` — bug latente que só apareceu agora com filtros.

Fix:
1. `server.rb` `set :rating_source` → `fetcher: ->(name) { settings.api.detail(name) || settings.api.find(name) }` (mantém `moves_fetcher` igual). `detail` traz `stats`/`types`/`evolutions` via `pokemon_data` + `pokemon_attributes`, logo `PokemonRating.rate` calcula `score` real e `tier` correto.
2. `filtered_base_forms` bloco `tier`/`cost` e `sort_names` já usavam `detail` (feito em `4b`) — mantidos, mas agora `rating` também correto, então filtro `tier` retorna resultados reais.
3. Cache stale: `tmp/pokemon_rating_cache.json` continha `988` entradas todas `F` (e `tmp/test_pokemon_rating_cache.json` `186` com `184 F`) — TTL `7d` manteria `F` por dias. Invalidado no hotfix: `rm tmp/pokemon_rating_cache.json tmp/test_pokemon_rating_cache.json` (recriado vazio e reaquecido no próximo filtro `tier`/`sort`; primeira carga fria paga `detail` por membro da cadeia, depois `<1s` quente via `PokeApiCache` + `PokemonRatingCache`).
4. TDD: `test/rating_detail_hotfix_test.rb` — `test_rating_for_uses_detail_not_find` (prova `find` minimal → `F`, `detail` rico → `S`), `test_tier_filter_uses_detail_rating_not_find` (integração `GET /pokemons tier=S/A/B` + `sort` com `detail` rico) e `test_server_default_rating_uses_detail_hotfix` (prova que `Server.settings.rating_source` via `detail` dá `S`; falha antes do fix com `find`, passa depois). `PokeApiStub.with_detail` + `with_find` minimal simulam `PokeApiHttp` real.

Prova: `test/rating_detail_hotfix_test.rb` verde; `test/pokemon_list_filters_test.rb` segue verde (usa `FakeListRating`); suíte completa `851` testes `+ lint 0`. `filtered_base_forms`/`sort_names` já auditados.

Status: hotfix **Passo 4d** em 2026-08-26; suíte verde + lint 0; aguarda revalidação do usuário — **não marcar Done** até validação (S3).

## 6. Decisões de refinamento (fechadas com o usuário em 2026-08-26)

- **D1 — Objetivo/foco (A — UX-2b filtros avançados + alinhamento lista↔time, continuidade da 0056):** fecha o ciclo UX-2: a 0056 exibiu custo/tier na lista, esta entrega filtros/ordenação/persistência e alinha as caixas da `/`. Alternativas preteridas: B — só alinhamento sem filtros (deixaria a lista sem discovery com o orçamento M2) e C — só filtros sem alinhamento (a página em 2 colunas seguiria desbalanceada).
- **D2 — Escopo exato (A2 — A1 expandido: filtros tipo+geração+custo/tier + ordenação por custo/tier + botão "limpar filtros"):** todos os filtros do bloco UX-2 (REQUIREMENTS.md 641) no mesmo ciclo, combináveis com busca e paginação, com ordenação por custo/tier e ação de limpar. Alternativas preteridas: A1 enxuto — só tipo+geração sem custo/tier/ordenação/limpar (a lista com 0056 já mostra custo, mas não filtraria por ele, frustrando o M2) e A3 — filtros + busca por habilidade/moves (exige tocar `effective_against`/`moves_for` e amplia o scan).
- **D3 — Critérios S1 (B — 4 critérios granulados):** C1 tipo+geração, C2 custo+tier (max cadeia + metade restrito), C3 paginação/busca/OOB/sem rede, C4 alinhamento/ordenação/persistência com parte `manual` para visual — o contrato S1 aponta teste concreto por critério (ver §4), `manual` explícito onde não há teste automatizado. Alternativa preterida: A — 3 critérios enxutos (aglutinaria tipo+geração com custo/tier em um só, perdendo rastreabilidade quando um filtro quebra e outro não).
- **D4 — Design técnico (A — server-side filtering no `load_pokemon_page`):** derivar `types`/`generation`/`line_tier`/`cost` no batch 24 (reuso de `PokeApiCache`/`TeamBudget`/`evolution_restricted?`), filtrar **antes** de paginar e ordenar antes de fatiar, controles com `hx-get`/`hx-include`/`hx-target="#pokemon-list"` e paginação on-demand `PAGE_SIZE` 36 preservada. Alternativas preteridas: B — filtro client-side via JS (quebraria RNF-01 htmx-first e o OOB) e C — filtrar após paginar (página ficaria incompleta e paginação mentiria).
- **D5 — Fora de escopo (C — abrangente, com ordenação + persistência IN-SCOPE):** ao contrário do enxuto recomendado (que deixaria ordenação e persistência fora), esta sessão **INCLUI** ordenação por custo/tier e persistência de filtros em `session[:list_filters]`; portanto os dois itens **saem** da lista de fora e entram no escopo (§3). Continua **fora**: busca por habilidade/moves, paginação com total, Q5/race/escritas atômicas/CSRF/CI/`pry`, M1 pedras no Mart, regra "vida zerada não pode ser removido", J2/J4/D4, Poke Center flutuante, itens de evolução aleatórios no Mart, "batalhar resolve a batalha inteira", animações nos ataques — todos já anotados no `REQUIREMENTS.md`/drafts (RNF-04).
- **D6 — Tamanho/Plano TDD (B — 4 passos granulares):** P1 tipo, P2 geração, P3 custo/tier (+ limpar), P4 ordenação+persistência+alinhamento/`manual` — cada passo com red→green→suíte+lint 0→commit; ao fim da fase 2, **parar** e aguardar validação do usuário. Alternativa preterida: A — 3 passos (comprimia tipo+geração num só passo, escondendo regressão de um filtro no outro).

## 7. Validação (executada pelo usuário — fase 3)

*(Fase 3 — executada pelo usuário. Registro por critério, um resultado por linha — S2.
Ajuste de validação = alteração formal de critério com data e reaprovação — S3.)*

| Critério | Evidência automatizada | Evidência manual | Resultado |
| --- | --- | --- | --- |
| C1 (tipo+geração combináveis com busca) | — | — | — |
| C2 (custo/tier combináveis, max cadeia + metade restrito + limpar) | — | — | — |
| C3 (paginação/busca/OOB preservados, sem rede) | — | — | — |
| C4 (ordenação+persistência+alinhamento) | — | — | — |
| G1 (suíte + lint) | — | — | — |
| G2 (sem gems/schema, sem rede) | — | — | — |
| G3 (S4/S5) | — | — | — |

**Validação 2026-08-26 (S3):** usuário reprovou **C1** (filtro `type=rock` retornou vazio) e **C3** (p95 2.5min) — ver **§5-A** para causa (`find` sem `types`) e plano via `/type` endpoint + `detail`. Critérios **C1 e C3 reabertos** em 2026-08-26; correção no `Passo 4b` desta sessão; aguarda **segunda validação** do usuário (reaprovação S3) — não marcar Done até então.

**Suíte executada na validação:** — (primeira validação falhou; segunda pendente após hotfix)

## 8. Observações

- **Geração:** derivada da species (`generation.url` → `(\d+)`), como `evolution_restricted?` já faz com `species_url`+`chain`; cache via `PokeApiCache` existente e `PokemonRatingCache` não precisa mudar. Fakes de teste retornam `1..9` determinísticos por nome, sem Faraday. Se a geração vier `nil` (espécie sem `generation`), o Pokémon não passa no filtro de geração específico.
- **Starters vs. filtros:** quando houver filtro/ordenação ativo, os 27 starters **não** são destacados à parte (mesmo pool filtrado/ordenado); sem filtros, mantém-se a regra da Onda 3 — página 1 = 27 starters + 9 comuns. A observar na fase 2 se o destaque com `generation=1` + `type` esvazia a página 1 (aceito: paginação continua paginando sobre o filtrado).
- **Custo do filtro:** cada candidato filtrado paga `rating_for` por membro da cadeia no miss (como na 0056) + `generation_for`/`types`; mitigado pelo `PokeApiCache` e pelo cache persistente de rating aquecido pela varredura de oponentes (0050) e por `generation_for` memoizado — aceito, mesmo trade-off da 0056.
- **Ordenação e tier:** `tier_desc` ordena `S→F` (custo 120→20), `tier_asc` `F→S`; `cost_asc`/`cost_desc` ordenam por `TeamBudget` já com metade restrita, então um `S` restrito (60) pode ficar entre `B` e `A` — comportamento intencional (o preço exibido é o que filtra/ordena).
- **Persistência:** `session[:list_filters]` é por `user_id` (mesma sessão do Sinatra já isolada por usuário, como `TeamRepository`); não toca `user_state`/`wallet`/DB. Limpar filtros faz `session.delete(:list_filters)` + redirect/`hx-get` com query vazia.
- **OOB:** `POST /team` (`oob_pokemon_list`) e `DELETE /team` (`remove_team_member`) já re-hidratam `session[:list_filters]` + params para o OOB de `#pokemon-list`; `POST /journey/restart` com `list_state_present?` também refresca o OOB com o estado filtrado/ordenado.
- **Gotchas duráveis** do M2/0056 (paridade de interface do gateway, choke point do `PokemonRatingCache`, trigger já parseado, `TIER_ORDER`/`TeamBudget::TIER_COST`) seguem em `gotchas/m2-custo-gateway-e-rating.md` e valem aqui; adicionar `generation_for` ao mesmo gotcha quando fechar a fase 2.
- **Fora de escopo lembrado (D5 C):** ordenação por custo/tier e persistência **saíram** da lista de fora e entraram no escopo; todo o resto de D5 (Q5/race/escritas atômicas/CSRF/CI/`pry`/M1/J2/J4/D4/Poke Center flutuante/itens evolução aleatórios/"batalhar resolve tudo"/animações) segue fora, anotado no `REQUIREMENTS.md`/drafts (RNF-04) para sessões futuras.
- **Resíduo da 0056:** `moves || []` no `PokemonRatingCache`/`PokemonRating` + fallback `evolution_chain_names` evitando `[]→:F` — preservado; filtros reutilizam `line_tier_for`/`evolution_chain_names` sem duplicar.
