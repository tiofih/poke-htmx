# Gotchas — M2 (custo de montagem de time)

## Choke point: PokemonRatingCache
`rating_for(name)` é o ponto central do custo e da varredura de oponentes. Todo
`POST /team` faz lookups por nome da cadeia inteira. Mitigado pelo cache persistente
(TTL 7d, aquecido pelas batalhas), mas o primeiro add de uma linha fria pode demorar.
**Não remover a injeção de fonte de rating** — testes usam fake determinístico.

## Trigger já parseado na cadeia
O `stage_details` do `poke_api_parsing.rb` já lê o trigger de evolução, mas
`resolve_evolution_entries` filtra só `level-up`. Para `evolution_restricted?`,
reusar o trigger sem fetch novo — não adicionar lógica paralela que quebre a cache.

## Gateway interface parity
`evolution_restricted?` foi adicionado à interface `PokeApi` (HTTP + cache decorator +
fake). Qualquer mudança na interface exige paridade nos 3 adapters + `gateway_interface_test`.

## TeamBudget como política pura
`lib/team_budget.rb` é módulo puro (constantes + funções). Tabela, BUDGET, S_LIMIT são
constantes derivadas — sem estado, sem dependência externa. Para D4 (draft temático),
injetar modificadores via parâmetros, não mudar o módulo.

## Onde o custo entra (e onde não)
`POST /team` (add) = custo checado antes do insert. `DELETE /team` (remove) = libera
teto/orçamento. `POST /team/:id/moves` / `POST /team/:id/item` / reordenação =
**não alteram custo**. Não confundir "gerenciamento" com "montagem".

## Bug Q5 persistente
O fix da 0053 (hx-disabled-elt + DELETE idempotente) não resolveu o "2 cliques" no
remover. Investigar se o OOB do `#pokemon-list` (adicionado na 0042) está causando
re-renderização concorrente que invalida o request do 1º clique.
