# Sessão 0006 — Paginação/filtro na listagem (RF-01)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída (aguardando TDD) |
| Implementação | Planejada (plano TDD abaixo) |
| Validação | Pendente (executada pelo usuário) |

---

## 1. Objetivo

Resolver a limitação **"Listagem massiva"** de RF-01: hoje `GET /` chama `PokeApi.all`
com `limit=100000`, carregando **todos** os Pokémon de uma vez no `<select>`.
A sessão 0006 adiciona: **paginação (100 por página)** com navegação
"Anterior/Próxima" + contador "Página X de Y", e **filtro por nome** (substring,
server-side com cache) — mantendo o `<select>` (RF-01) e a interação 100% htmx (RNF-01).

## 2. Contexto (estado atual)

- `lib/poke_api.rb` — `PokeApi.all` faz `GET /pokemon?limit=100000&offset=0` e
  devolve `"results"` (nome de todos os Pokémon) para popular o `<select>`.
- `server.rb` — `get "/"` chama `PokeApi.all` e renderiza `index.erb`.
- `views/index.erb` — `<select name="name" id="pokemons" hx-get="/pokemon" ...>`
  com uma `<option>` por Pokémon.
- A PokéAPI **não oferece busca parcial** por nome → o filtro busca a lista
  completa **uma vez** (cache em memória) e filtra por substring no servidor.
- Testes (RNF-04): suíte roda **sem rede** → stub em `fetch_all_names`.

## 3. Critérios de aceite

- [ ] `GET /` renderiza o `<select>` com no máximo **100 opções** (primeira página)
      e o contador "Página X de Y" (sem `limit=100000` para todas as opções).
- [ ] `GET /pokemons` (nova rota de fragmento) devolve o `<select>` com as opções
      da página corrente (`offset`, 100 por páginas) + controle "Anterior"/"Próxima"
      + contador "Página X de Y".
- [ ] `GET /pokemons?q=<texto>` filtra por substring (case-insensitive) sobre a
      lista cacheada e pagina **o resultado filtrado**; `q` vazio = lista completa.
- [ ] "Anterior" some na primeira página; "Próxima" some na última; links mantêm
      o `q` e o `offset` via `hx-get` (alvo `#pokemon-list`).
- [ ] A navegação/filtro é 100% htmx, sem JS customizado (RNF-01).
- [ ] O `<select>` continua disparando `hx-get="/pokemon"` ao trocar a opção
      (fragment add de RF-02/RF-03, sem regressão).
- [ ] Suíte completa verde (`./scripts/test`), lint verde (`./scripts/lint`) e
      **commit a cada green** (RNF-04).
- [ ] Testes sem rede: stub de `PokeApi.fetch_all_names` (novo `PokeApiStub.with_all_names`).
- [ ] `REQUIREMENTS.md` (RF-01 — paginação/filtro) e `SESSIONS.md` (0006 em
      refinamento) atualizados no mesmo escopo.

## 4. Decisões de refinamento

- **Novo dado server-side:** `PokeApi.fetch_all_names` — lista completa em cache
  (`@all_names ||= ...`), usada para paginção e filtro sem refetch.
- **Novo método:** `PokeApi.paginate(offset:, limit: 100, q: nil)` → retorna hash
  `{ names:, total: }`. Paginação local sobre a lista cacheada (corte por
  `offset/limit`); `q` filtra por `include?` case-insensitive antes do corte.
- **Rota de fragmento:** `GET /pokemons?offset=&q=` (plural, sem conflito com a
  rota `GET /pokemon` e `GET /pokemon/:poke_id`); renderiza `views/pokemon_list.erb`.
- **Alvo htmx:** `#pokemon-list` (contêiner novo em `index.erb`) com
  `hx-swap="innerHTML"`; os controles "Anterior"/"Próxima" levam
  `hx-get="/pokemons?offset=...&q=..."`.
- **Filtro:** `index.erb` ganha um `<input name="q" hx-trigger="keyup changed delay:300ms"
  hx-get="/pokemons" hx-target="#pokemon-list">`; lista e controles vivem for a do input
  (input fica fora do `#pokemon-list` para não perder o foco ao re-renderizar).
- **`GET /`:** usa `PokeApi.paginate(offset: 0)` para pré-carregar a 1ª página
  (substitui o `limit=100000`); sem paginação inicial o `<select>` nasce vazio.
- **Sem schema/DB/migração:** mudança é só em `PokeApi` + rotas + views.
- **Contador "Página X de Y":** `X = offset/limit + 1`, `Y = (total/limit).ceil`;
  `Y` mínimo 1 (total 0 → página 1 de 0 é evitada → renderiza só a mensagem vazio).

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) |
| --- | --- | --- |
| 0 | `PokeApi.paginate` pagina/slice a lista cacheada (offset/limit), retorna total; `q` filtra substring case-insensitive; offset além do fim → lista vazia sem quebrar | `lib/poke_api.rb`: `fetch_all_names` + `paginate` |
| 1 | `GET /pokemons` devolve `<select>` com ≤100 `<option>` + contador "Página 1 de Y" + link "Próxima" | rota `GET /pokemons` + `views/pokemon_list.erb` |
| 2 | offset 0 sem "Anterior"; última página sem "Próxima"; links levam `offset` e `q` corretos | view: condicionais + montagem dos `hx-get` dos controles |
| 3 | `GET /pokemons?q=pi` mostra só os que contêm "pi" e pagina o filtrado; `q` sem match → `<select>` vazio, sem erro; `q` vazio = lista completa | rota passa `q` para `paginate`; view ignora contador quando total 0 |
| 4 | `GET /` (stub) renderiza `<select>` com ≤100 opções + "Página 1 de Y" + `<input name="q" h>`; algum `PokeApi.all`/`limit=100000` não usado | `views/index.erb` (contêiner `#pokemon-list` + input filtro) + `GET /` usa `paginate` |
| 5 | sem regressão: `GET /pokemon?name=` e `POST /team` seguem funcionando (fragment add); suíte completa + lint verdes | checagem da suíte inteira + lint, sem alteração extra |
| 6 | `REQUIREMENTS.md`/`SESSIONS.md` atualizados (RF-01 paginação/filtro; 0006 em refinamento) | documento |

## 6. Observações e próximo passo

- Esta sessão resolve parcialmente a limitação RF-01 ("listagem massiva"): a UI páginas
  o `<select>` e filtra por substring. A busca parcial da PokéAPI continua sendo uma
  limitação da API (oauth via cache local).
- Próximo passo após validação: **sessão 0007** (UI: layout e estilos externo).