## Tela: Gerenciar time   (fragmento `#team` — manage)

Renderizada por `GET /team/manage` e `POST /team/:id/moves`.

```
┌──────────────────────────────────────────────┐
│ Gerenciar time                               │
│ [⚠ aviso, se houver]                        │
│                                              │
│ #1 [sprite]  bulbasaur       [▲] [▼]        │
│    ☑ tackle   ☐ growl  ...  [Salvar golpes] │ ← checkbox moves
│ #2 [sprite]  pikachu         [▲] [▼]        │
│    ☐ thunderbolt ...         [Salvar golpes] │
│                                              │
│ [← Voltar]                                  │
└──────────────────────────────────────────────┘
```

```yaml
fragment: "#team"
refresh: get /team/manage
blocks:
  - id: manage-title
    type: text, source: "Gerenciar time"
  - id: notice
    type: notice, source: @notice
  - id: manage-members
    type: list, loop: @team
    children:
      - type: badge, source: member.slot
      - type: link, action: get /pokemon/<member.number>, target: "#team"
        children:
          - type: sprite, source: member
      - type: text, source: member.name
      - type: button, text: "▲", action: post /team/<member.id>/move new_slot=member.slot-1
      - type: button, text: "▼", action: post /team/<member.id>/move new_slot=member.slot+1
      - id: moves-form
        type: form, action: post /team/<member.id>/moves, target: "#team"
        fields:
          - type: input, name: moves, type: checkbox, loop: @available_moves[member.id],
              checked: member.moves.include?(nome)
        children:
          - type: button, text: "Salvar golpes"
  - id: back
    type: link, text: "← Voltar", action: get /team, target: "#team"
```

**Notas:** `@available_moves` é um mapa `{ member.id => [nomes] }`; checado conforme
`member.moves`. A rota valida máx. 4 golpes (`MAX_MOVES_PER_POKEMON`) e nomes disponíveis.