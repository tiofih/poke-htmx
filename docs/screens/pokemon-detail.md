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

---

## Desenho alvo — detalhe (análise UI/UX 2026-08-22; ref: `docs/draft-backlog.md` §2.3)

```
┌──────────────────────────────────────────┐
│ [sprite alt="pikachu"]                   │ ← alt + lazy (novo)
│ pikachu                                  │
│ [eletric]                                │ ← chip com cor por tipo (novo)
│ HP 35 · Attack 55 · ...                  │
│ Evoluções:                               │
│   [sp] raichu  → link p/ detalhe        │ ← evoluções clicáveis (novo)
│        [ Adicionar ao time ]            │ ← copy pt-BR + estados
│ [ Fechar ]  (devolve foco ao item)      │ ← foco de volta (novo)
└──────────────────────────────────────────┘
```

```yaml
fragment: "#pokemon" (alvo, detail)
deltas:
  - sprite: alt="<@pokemon.name>", loading=lazy                          (novo)
  - type-chips: cor temática por tipo (paleta fixa em style.css)         (novo)
  - evolutions:
      cada item vira link action: get /pokemon/<evolution.number>,
      target: "#pokemon"                                                 (novo)
  - add-submit / close: copy "Adicionar ao time"/"Fechar"; mesmos estados
      de botão da listagem; Fechar devolve foco/scroll ao item de origem  (novo)
```

**Notas do alvo:** evoluções já chegam como `Pokemon` (`find` no parsing) — os links
usam `number`; sem mudança de contrato. Paleta de tipos é CSS estático.