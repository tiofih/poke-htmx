## Tela: Pokémon — Adicionar ao time   (fragmento `#pokemon`)

Renderizada por `GET /pokemon?name=` (opção do select da lista) — `_pokemon.erb_`.

```
┌──────────────────────────────────────────┐
│ ┌──────────────────────────────────────┐ │
│ │ [sprite]  bulbasaur                  │ │ ← nome e sprite são links → detalhe
│ │ (hidden: pokeName)                   │ │
│ │        [ Add to Team ]               │ │ ← post /team → atualiza #team
│ └──────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

```yaml
fragment: "#pokemon"
blocks:
  - id: add-form
    type: form
    action: post /team, target: "#team"
    fields:
      - type: input, name: pokeName, type: hidden, value: @pokemon.name
    children:
      - id: add-link-name
        type: link, text: @pokemon.name, action: get /pokemon/<@pokemon.number>, target: "#pokemon"
      - id: add-link-sprite
        type: link, action: get /pokemon/<@pokemon.number>, target: "#pokemon"
        children:
          - type: sprite, source: @pokemon
      - id: add-submit
        type: button, text: "Add to Team"
```

**Notas:** mesmo fragmento vira o "cartão" de adicionar; sem aviso/erro próprio aqui
(o retorno do `POST /team` re-renderiza `#team` com `@notice`).

---

## Desenho alvo — card de adicionar (análise UI/UX 2026-08-22; ref: `docs/draft-backlog.md` §2.2)

```
┌──────────────────────────────────────────┐
│ ┌──────────────────────────────────────┐ │
│ │ [sprite alt="bulbasaur"]  bulbasaur │ │ ← alt + lazy (novo)
│ │        [ Adicionar ao time ]        │ │ ← copy pt-BR + estados (novo)
│ └──────────────────────────────────────┘ │
└──────────────────────────────────────────┘
```

```yaml
fragment: "#pokemon" (alvo)
deltas:
  - sprite: loading=lazy, alt="<@pokemon.name>"                          (novo)
  - add-submit: copy "Adicionar ao time"; estados como na listagem       (novo)
      in-team: "No time ✓" disabled; full: desabilitado com aviso
```

**Notas do alvo:** mesmos dados/estados definidos para a listagem — um só contrato
de estados do botão entre lista, card e detalhe.