## Tela: Shell (nav + página índice)   (fragmento — nenhum; é o HTML base)

```
┌──────────────────────────────────────────────┐
│ Poké-HTMX   [Lista] [Time] [Batalha]        │ ← nav
├──────────────────────────────────────────────┤
│ Choose a pocket monster:                     │
│ [ Filter by name ............... ]           │ ← input q → #pokemon-list
│ ┌──────────────────────────────────────────┐ │
│ │ #pokemon-list  (lista + paginação)      │ │ ← alvo
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ #pokemon   (fragmento: add/detalhe/... )│ │ ← alvo
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ #team  (hx-get /team on load)           │ │ ← alvo
│ └──────────────────────────────────────────┘ │
│ ┌──────────────────────────────────────────┐ │
│ │ #battle                                  │ │ ← alvo
│ └──────────────────────────────────────────┘ │
└──────────────────────────────────────────────┘
```

```yaml
screen: shell
blocks:
  - id: nav
    type: panel
    children:
      - type: link, text: "Lista", action: get /battle/close, target: "#battle"
      - type: link, text: "Time",  action: get /team/manage,  target: "#team"
      - type: link, text: "Batalha", action: get /battle,       target: "#battle"
  - id: search
    type: panel
    children:
      - type: text, source: "Choose a pocket monster:"
      - type: input, name: q, type: text,
          action: get /pokemons, target: "#pokemon-list", trigger: "keyup changed delay:300ms"
  - id: pokemon-list-target
    type: panel, target: "#pokemon-list"
  - id: pokemon-target
    type: panel, target: "#pokemon"
  - id: team-target
    type: panel, target: "#team"
    load: get /team
  - id: battle-target
    type: panel, target: "#battle"
```

**Notas:**
- `index.erb` embute `pokemon_list` na carga inicial; os demais alvos nascem vazios e
  são preenchidos via htmx.
- `layout.erb` envolve todas as renderizações ERB; os fragmentos usam `layout: false`.