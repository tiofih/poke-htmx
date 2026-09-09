## Tela: Histórico   (fragmento `#history`)

Renderizada por `GET /history`; `GET /history/close` limpa o alvo. Em `history.erb`.

```
┌──────────────────────────────────────────┐
│ Histórico de Batalhas                   │
│ [⚠ Você ainda não batalhou.]           │ ← estado vazio (quando sem dados)
│                                          │
│ Ranking global                           │
│ 1. <user_id> — 5 vitórias (8 batalhas)  │ ← hoje: UUID cru
│ ...                                      │
│ Sua posição                              │
│ Posição 2 — V:5 D:2 E:1                 │
│                                          │
│ Últimas batalhas                         │
│ • Vitória contra pikachu, eevee em     │
│   22/08/2026 14:03                       │
└──────────────────────────────────────────┘
```

```yaml
fragment: "#history"
blocks:
  - id: empty-state
    type: notice, text: "Você ainda não batalhou."
    visible: @rank vazio && @recent vazio
  - id: global-ranking
    type: list, loop: @rank (limite DEFAULT_LIMIT)
    children:
      - type: text, source: "<posição>. <user_id> — <wins> vitória(s) (<total>)"
      - highlight: classe .current quando row[:user_id] == @current_user
  - id: my-position
    children:
      - type: text, source: "Posição <@position> — Vitórias <wins> · Derrotas <losses> · Empates <draws>"
  - id: recent-battles
    type: list, loop: @recent (limite DEFAULT_LIMIT)
    children:
      - type: text, source: "<resultado> contra <opponent_names> em <dd/mm/aaaa hh:mm>"
```

**Notas:** ranking/recentes usam os limites de `BattleRepository` (`DEFAULT_LIMIT`);
`opponent_names` formata o JSONB do time oponente.

---

## Desenho alvo — histórico (análise UI/UX 2026-08-22; ref: `docs/draft-backlog.md` §2.7)

```
┌──────────────────────────────────────────────┐
│ Histórico                                    │
│ 🥇 1. Filipe — 12V (15B)   ← você           │ ← apelidos + destaque "você"
│    2. <apelido> — 9V (11B)                  │
│    3. <apelido> — 7V (10B)                  │ ← medalha/top-3 destacado (novo)
│ Sua posição: 4º — V:6 D:3 E:1               │
│                                              │
│ Últimas batalhas          [Anterior][Próxima]│ ← paginação (novo)
│ • ✅ Vitória vs pikachu, eevee — 22/08 14:03 │
│ • ❌ Derrota vs charmander…  — 21/08 09:41   │ ← ícone por resultado (novo)
└──────────────────────────────────────────────┘
```

```yaml
fragment: "#history" (alvo)
deltas:
  - id: identity (alvo)
    source: nome/apelido legível no lugar do UUID (cruza com J4 — nome na entrada);
            enquanto J4 não existe, exibir "Você" para o próprio user e UUID
            truncado para os demais
  - id: top-3 (novo)
    style: destaque visual (medalha/ordem) nas 3 primeiras posições
  - id: result-icons (novo)
    rule: ícone/rótulo colorido por resultado (vitória/derrota/empate) — usa a
          hierarquia de notices da análise global
  - id: pagination (novo)
    scope: últimas batalhas com Anterior/Próxima (offset no repositório)
```

**Notas do alvo:** apelido depende do J4; paginação precisa de suporte a offset em
`BattleRepository#recent`. Ranking continua com limite fixo até haver volume real.
