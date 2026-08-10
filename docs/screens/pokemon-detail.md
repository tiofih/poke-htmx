## Tela: Pokémon — Detalhe   (fragmento `#pokemon`)

Renderizada por `GET /pokemon/:poke_id` (clique na sprite/nome no add, na lista do time).

```
┌──────────────────────────────────────────┐
│ [sprite]                                 │
│ bulbasaur  [grass] [poison]              │ ← tipos
│                                           │
│ HP: 45                                    │
│ Attack: 49                                │
│ Defense: 49                               │
│ Sp.Atk: 65                                │
│ Sp.Def: 65                                │
│ Speed: 45                                 │
│                                           │
│ [sprite] ivysaur  (evolução)             │ ← evolutions (se houver)
│ [sprite] venusaur (evolução)             │
│                                           │
│        [ Add to Team ]                    │
│        [ Fechar ]                         │
└──────────────────────────────────────────┘
```

```yaml
fragment: "#pokemon"
blocks:
  - id: detail-sprite
    type: sprite, source: @pokemon
  - id: detail-name
    type: text, source: @pokemon.name
  - id: detail-types
    type: list, loop: @pokemon.types
    children:
      - type: badge, source: type
  - id: detail-stats
    type: list, loop: @pokemon.stats
    children:
      - type: text, source: "<stat.name>: <stat.value>"
  - id: detail-evolutions
    type: list, loop: @pokemon.evolutions, visible: not evolucoes.vazias
    children:
      - type: sprite, source: evolution
      - type: text, source: evolution.name
  - id: add-form
    type: form, action: post /team, target: "#team"
    fields:
      - type: input, name: pokeName, type: hidden, value: @pokemon.name
    children:
      - type: button, text: "Add to Team"
  - id: close
    type: button, text: "Fechar", action: get /pokemon/close, target: "#pokemon"
```

**Notas:** `@pokemon.evolutions` é `[]` quando não há evolução (bloco oculto).
`Fechar` renderiza `pokemon_close.erb` (fragmento vazio) — limpa o alvo.