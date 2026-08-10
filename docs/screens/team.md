## Tela: Time   (fragmento `#team`)

Renderizada por `GET /team`, `POST /team`, `DELETE /team`, `POST /team/:id/move`.

```
┌──────────────────────────────────────────┐
│ [⚠ aviso, se houver]                    │
│ #1 [sprite]  bulbasaur    [▲] [▼]      │
│ #2 [sprite]  pikachu      [▲] [▼]      │
│ #3 [sprite]  charmander   [▲] [▼]      │
│               (sprite/nome → detalhe)   │
│ [ Remove from Team ]  por Pokémon       │
└──────────────────────────────────────────┘
```

```yaml
fragment: "#team"
refresh: get /team
blocks:
  - id: notice
    type: notice, source: @notice
  - id: members
    type: list, loop: @team
    children:
      - type: badge, source: member.slot
      - type: link, action: get /pokemon/<member.number>, target: "#pokemon"
        children:
          - type: sprite, source: member
      - type: link, text: member.name, action: get /pokemon/<member.number>, target: "#pokemon"
      - type: button, text: "▲", action: post /team/<member.id>/move new_slot=member.slot-1
      - type: button, text: "▼", action: post /team/<member.id>/move new_slot=member.slot+1
      - type: form, action: delete /team, target: "#team"
        fields:
          - type: input, name: id, type: hidden, value: member.id
        children:
          - type: button, text: "Remove from Team"
```

**Notas:** as setas ✓/▼ só aparecem para slots com vizinho movível na UI (rota valida);
`POST /:id/move` re-renderiza a lista reordenada.