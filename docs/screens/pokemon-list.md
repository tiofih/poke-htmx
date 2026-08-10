## Tela: Lista de Pokémon   (fragmento `#pokemon-list`)

```
┌──────────────────────────────────────────┐
│ [⚠ aviso, se houver]                    │
│ [ ... ▼ ]  ← select dispara #pokemon    │
│                                          │
│  ← Anterior   Página 1 de N   Próxima → │
└──────────────────────────────────────────┘
```

```yaml
fragment: "#pokemon-list"
refresh: get /pokemons?offset=<offset>&q=<q>   # paginação
blocks:
  - id: notice
    type: notice, source: @notice
  - id: pokemon-select
    type: select, name: name
    options: @page[:names]            # cada option renderiza o nome
    action: get /pokemon, target: "#pokemon", trigger: change
  - id: pagination
    type: panel
    children:
      - type: link, text: "← Anterior",
          action: get /pokemons?offset=<offset-100>&q=<q>, target: "#pokemon-list"
          visible: offset > 0
      - type: text, source: "Página <page> de <total>"
      - type: link, text: "Próxima →",
          action: get /pokemons?offset=<offset+100>&q=<q>, target: "#pokemon-list"
          visible: offset + 100 < total
```

**Fontes de dados:** `@page[:names]`, `@page[:total]`, `@offset`, `@q`, `@notice`.
O `<select>` muda o alvo `#pokemon` (opção dispara `GET /pokemon?name=`).