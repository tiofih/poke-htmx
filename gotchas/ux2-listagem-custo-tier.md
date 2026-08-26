# Gotchas — UX-2 (custo/tier na listagem)

## Paralelismo já existente evita N fetches
`load_pokemon_page` já faz `Parallelizer.map(@page_names) { find }` em batch 24. O badge reaproveita `pokemon.evolutions` desse batch para `line_tier = max(rating_for(member))` — sem novo fetch. Adicionar `Parallelizer` extra para custo quebraria ordem e lotaria threads.

## Fallback evolutions vazio → [name]
`find` isolado (sem `with_all_names`) pode retornar `evolutions = []`. Sem fallback `chain && !chain.empty? ? chain : [name]`, `line_tier_for` mapeava `[]` para `:F` e todo poke virava 20. Garantir fallback no `evolution_chain_names`.

## Moves pode ser nil na listagem fria
`PokeApiFake.moves_for(name)` ou cache frio pode retornar `nil`. `PokemonRating#rate(pokemon, moves:)` e `PokemonRatingCache#rating_for` devem coagir `moves || []` antes de `sort_by`/`map`, senão `NoMethodError` na listagem com `PAGE_SIZE 36`.

## Rating injetável evita rede em teste
`Server.set :rating_source` (default `PokemonRatingCache`) permite fake determinístico nome→tier em `test/pokemon_list_cost_test.rb`. Sem isso, a suíte de 826 testes tocaria rede a cada render de lista.

## OOB preserva badges
`oob_pokemon_list` chama `load_pokemon_page` → `build_pokemon_costs`, então `POST /team`, `DELETE /team` e `POST /journey/restart` re-renderizam `#pokemon-list` com `poke-cost` + `data-tier` já no payload `hx-swap-oob="true"`. Não esquecer de popular `@pokemon_costs` antes do OOB.

## CSS por data-tier não quebra grid
`[data-tier="S|A|B|C|D|F"]` com `display:inline-block` mantém o grid 6×6 (Onda 3). Cor + `restricted` itálico + `◆` são sutis — conferir contraste manual, não só por teste.
