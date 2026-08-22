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

---

## Desenho alvo — gerenciar time (análise UI/UX 2026-08-22; ref: `draft-ui-ux.md` §2.5)

> Alvo alinhado ao JN-2 (golpes em lista) — a troca de checkboxes por lista é
> sessão própria (0037, refinamento pendente); o restante é cosmético.

```
┌──────────────────────────────────────────────────────┐
│ Gerenciar time                                       │
│ ┌─ Cartão do membro (#1 bulbasaur) ───────────────┐ │
│ │ [sp alt] bulbasaur   Nível 5        [↑] [↓]    │ │ ← card + aria (novo)
│ │ Golpes (máx. 4):                                │ │
│ │  ┌──────────────────────────────────────────┐  │ │
│ │  │ ✓ tackle      ✓ growl       ☐ vinewhip  │  │ │ ← lista clicável (JN-2)
│ │  └──────────────────────────────────────────┘  │ │
│ │  [Salvar golpes]                                │ │
│ │ Item: [ select ]  Segurável: [ select ]         │ │ (como hoje)
│ └─────────────────────────────────────────────────┘ │
│ ... (um cartão por membro; grid quando couber)      │
│ [← Voltar]                                          │
└──────────────────────────────────────────────────────┘
```

```yaml
fragment: "#team" (alvo)
deltas:
  - id: member-card (novo)
    layout: um cartão por membro; sprite com alt; ↑/↓ com aria-label
  - id: moves-list (alvo JN-2)
    type: lista de seleção (item clicável com marcação), no lugar de checkboxes
    constraints: máx. 4 selecionados; golpes acima do nível bloqueados (D1)
    action: post /team/<member.id>/moves (validação idêntica à atual)
  - copy: "Salvar golpes" mantido; rótulos pt-BR nos selects de item
```

**Notas do alvo:** validação/rota não mudam (limite 4 + gating por nível da 0034);
o desenho antecipa o formato acordado para o JN-2 sem abri-lo agora (RNF-04).