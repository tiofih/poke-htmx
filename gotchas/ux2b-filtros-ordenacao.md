# Gotchas — UX-2b filtros/ordenação/alinhamento (0057)

## find vs detail — tipos/tier sempre vazios se usar find
`PokeApiHttp#find` devolve só name/sprite/number (sem types/stats/evolutions). Filtrar tipo via `find(...).types` sempre dá [] → lista vazia. Stub `with_find` injetava types e mascarava. Usar `detail` ou endpoint `/type` para tipo, e `detail` para rating/tier.

## rating_source precisa de detail
`PokemonRatingCache` com `fetcher: ->{find}` calcula tier F para todos (stats=[]). Na 0057 tiers/custo/sort ficaram quebrados até trocar para `detail || find`. Cache stale de 988×F com TTL 7d travou — foi preciso `rm tmp/pokemon_rating_cache.json`.

## OOB de filtros quebra foco da busca
Enviar `hx-swap-oob` de `#filter-controls` em todo `GET /pokemons` re-renderiza o `<input q>` a cada `keyup delay:300ms` e faz perder foco. Condicionar OOB só quando `type/generation/tier/cost/sort` param presente; `q`/paginação sozinhas não devem fazer OOB. Limpar ainda precisa OOB.

## Tipo via /type é O(1), geração/tier ainda varrem
`pokemon_names_by_type` via `/type/rock` evita N finds e resolveu p95 2.5min → <1s. Geração/tier/cost ainda varrem base_form? + detail por lote 24; primeiro filtro tier frio ainda é caro (detail por membro da cadeia). Próximo passo: índice similar ou cap `max_candidates`.

## Persistência e paginação com filtros
`session[:list_filters]` guarda type/generation/tier/cost/sort e é restaurado quando sem params; `standard_pagination?` (q vazio && !filter && !sort) decide se `next_offset` é 9 ou 36. Sem isso paginação volta 9 com filtro e quebra OOB.
