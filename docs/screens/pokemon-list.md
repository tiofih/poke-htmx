## Tela: Lista de Pokémon   (fragmento `#pokemon-list`)

```
┌──────────────────────────────────────────┐
│ [⚠ aviso, se houver]                    │
│                                          │
│ Iniciais            (só com busca vazia) │
│ [sprite] bulbasaur   [Add to Team]       │
│ [sprite] charmander  [Add to Team]       │
│ ... (27 iniciais gen 1–9)                │
│                                          │
│ [sprite] pokemon1    [Add to Team]       │
│ [sprite] pokemon2    [Add to Team]       │
│ ... (20 itens por página)                │
│                                          │
│  ← Anterior   Página 1 de N   Próxima → │
└──────────────────────────────────────────┘
```

```yaml
fragment: "#pokemon-list"
refresh: get /pokemons?offset=<offset>&q=<q>   # paginação e filtro
blocks:
  - id: notice
    type: notice, source: @notice
  - id: starters
    type: list, loop: @starters               # só quando @q vazio
    title: "Iniciais"
    item:
      - type: link, action: get /pokemon/<pokemon.number>, target: "#pokemon"
        children:
          - type: sprite, source: pokemon
          - type: text, source: name
      - type: form, action: post /team, target: "#team"
        fields: { pokeName: name }
        button: "Add to Team"
  - id: items
    type: list, loop: @items                  # página corrente (20)
    item:
      - type: link, action: get /pokemon/<pokemon.number>, target: "#pokemon"
        children:
          - type: sprite, source: pokemon
          - type: text, source: name
      - type: form, action: post /team, target: "#team"
        fields: { pokeName: name }
        button: "Add to Team"
  - id: pagination
    type: panel
    children:
      - type: link, text: "← Anterior",
          action: get /pokemons?offset=<offset-20>&q=<q>, target: "#pokemon-list"
          visible: offset > 0
      - type: text, source: "Página <page> de <total>"
      - type: link, text: "Próxima →",
          action: get /pokemons?offset=<offset+20>&q=<q>, target: "#pokemon-list"
          visible: offset + 20 < total
```

**Fontes de dados:** `@items` (pares nome→`Pokemon` da página), `@starters`
(27 iniciais gen 1–9 quando `@q` vazio), `@page[:total]`, `@limit` (20),
`@offset`, `@q`, `@notice`. Sprite/nome linkam o detalhe (`GET /pokemon/:number`,
alvo `#pokemon`); o botão **Add to Team** faz `POST /team` com `pokeName`
(alvo `#team`). O enriquecimento sprite/número acontece na rota (`find` +
`Parallelizer`) — o contrato do gateway (`paginate` → nomes) não muda.
Navegação por teclado nativa (Tab/Enter nos links) — sem JS custom.

**Só formas base + iniciais fixos no topo (ajuste S3 — 2026-08-22):** a listagem
exibe apenas o 1º estágio de cada linha evolutiva (`base_form?(name)` no gateway;
evoluções como raichu, ivysaur, charmeleon não aparecem) e **exclui os 27
iniciais** (já fixos no bloco "Iniciais" — sem duplicação). A paginação continua
paginando nomes do pool (`offset` por 20) — uma página pode listar menos itens
quando contém evoluções/iniciais. Falha de rede no predicado esconde o item
(fail-closed).
