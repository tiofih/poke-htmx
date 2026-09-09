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

---

## Desenho alvo — shell (análise UI/UX 2026-08-22; ref: `docs/draft-backlog.md` §2.1)

```
┌──────────────────────────────────────────────────┐
│ Poké-HTMX   [Lista] [Time] [Batalha] [Histórico] │ ← seção ativa com destaque
│             Time: ▮▮▮▮▮▮ n/6   (⏳ carregando…) │ ← badge de progresso + indicador
├──────────────────────────────────────────────────┤
│ [ Buscar Pokémon ................. ]            │
│ #pokemon-list / #pokemon / #team / ...          │
└──────────────────────────────────────────────────┘
```

```yaml
screen: shell (alvo)
blocks:
  - id: nav (alvo)
    children:
      - type: link, text: Lista, action: get /battle/close → limpa #battle
      - type: link, text: Time, action: get /team/manage, target: "#team"
      - type: link, text: Batalha, action: get /battle, target: "#battle"
      - type: link, text: Histórico, action: get /history, target: "#history"
      - active-state: classe .active no item da seção corrente (novo)
      - progress-badge:
          source: "Time <n>/6", visible: jornada não iniciada        (novo)
          done: "✓ Time completo" após iniciar                      (novo)
  - id: loading-indicator (novo)
    type: hx-indicator global — barra/spinner discreto em todo request htmx
  - id: panel-cleanup (alvo)
    rule: cada link do nav limpa os painéis não-alvo (fim do span hack)
  - id: copy (alvo)
    rule: rótulos e placeholders em pt-BR ("Buscar Pokémon…")
```

**Notas do alvo:** o badge n/6 usa os mesmos dados do gate (`JourneyService`) —
exige expor `@journey_started`/tamanho do time no render do índice. Indicador de
carregamento é CSS puro + `hx-indicator` (RNF-01 mantido).