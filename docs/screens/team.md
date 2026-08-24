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

**Caminho B executado (sessão 0042, 2026-08-24):** `GET /team` **não é mais página
própria** — em navegação direta devolve **404**; continua como **fragmento htmx
interno** (requisição com `HX-Request`) renderizado dentro de `#team-view` na
**página unificada `GET /`** (2 colunas: Lista à esquerda, Time à direita). O contador
"Time n/6" aparece no topo do fragmento quando a jornada não começou. O add na lista
(`POST /team`) devolve mini-status **+ `#team-view` com `hx-swap-oob`** (painel
reflete o novo membro na mesma tela). O nav não tem mais link "Time". Ver
`sessions/0042-onda1-jornada-visivel.md`.

---

## Desenho alvo — time (análise UI/UX 2026-08-22; ref: `draft-ui-ux.md` §2.4)

Pré-jornada:

```
┌──────────────────────────────────────────┐
│ Time inicial: ▮▮▮▮▯▯ 4/6                │ ← progresso + CTA (novo)
│ Faltam 2 Pokémon — [Montar time]        │
└──────────────────────────────────────────┘
```

Pós-jornada:

```
┌──────────────────────────────────────────────┐
│ [aviso]                                      │
│ #1 [sp alt] bulbasaur   HP ▮▮▮▯▯ 150/200    │ ← barra de HP (novo)
│    [↑][↓]  [Remover] (com confirmação)     │ ← aria-label + confirm (novo)
│ ── Poke Center ──  ── Poke Mart ──          │ (gated, como hoje)
└──────────────────────────────────────────────┘
```

```yaml
fragment: "#team" (alvo)
deltas:
  - id: journey-block (novo)
    visible: jornada não iniciada
    children:
      - type: progress, source: "Time <n>/6" (barra + contagem)
      - type: link, text: "Montar time", action: âncora #pokemon-list
      - copy: "Faltam <6-n> Pokémon para iniciar a jornada"
  - id: members (alvo)
    children:
      - hp-bar: barra visual <hp_current>/<hp_max> (percent)             (novo)
      - move-buttons: "↑"/"↓" com aria-label="Subir/Descer <nome>"       (novo)
      - remove-button:
          text: "Remover do time"
          hx-confirm: "Remover <nome> do time?"                          (novo)
```

**Notas do alvo:** progresso n/6 e barras de HP usam dados já presentes nos renders
(`@team` com progresso); `hx-confirm` é atributo htmx nativo (sem JS custom).
Poke Center/Mart continuam gated pela jornada.