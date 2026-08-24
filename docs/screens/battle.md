## Tela: Batalha   (fragmento `#battle`)

Renderizada por `GET /battle` (setup), `POST /battle/play` (avançar round),
`GET /battle/close` (limpar alvo). Em `battle.erb`.

Cenário com `@message` (time vazio ou falha de preparação):

```
┌──────────────────────────────────────────┐
│ [⚠ @message]                            │
└──────────────────────────────────────────┘
```

Cenário com `@engine`:

```
┌──────────────────────────────────────────┐
│ Batalha                                  │
│ Rodada N                                  │
│ ┌───────────────────┐  ┌───────────────┐ │
│ │ Seu Time          │  │ Oponente       │ │
│ │ [sprite] poke HP  │  │ [sprite] poke  │ │
│ │   • tackle PP     │  │   • move PP    │ │
│ └───────────────────┘  └───────────────┘ │
│ Seu Time: pikachu usou thunderbolt em    │
│   squirtle — 42 de dano                  │ ← log do round atual
│ [ Jogar ]  ou  [ Novo confronto ]        │
│ Vencedor: Seu Time    (se finished)      │
└──────────────────────────────────────────┘
```

```yaml
fragment: "#battle"
blocks:
  - id: message
    type: notice, source: @message
    visible: sem engine
  - id: engine
    visible: com engine
    children:
      - type: text, source: "Batalha"
      - type: text, source: "Rodada <@engine.rounds>"
        suffix: " — Fim de batalha" se finished
      - id: player-pane
        type: panel, title: "Seu Time"
        children:
          - id: fighters
            type: list, loop: @engine.teams[0]
            children:
              - type: sprite, source: poke
              - type: text, source: "<poke.name> — HP <poke.hp_current>/<poke.hp_max>"
              - type: list, loop: poke.moves, children:
                  - type: text, source: "<move.name> — PP <move.pp>"
      - id: opponent-pane
        type: panel, title: "Oponente"
        children: <igual ao player-pane, com @engine.teams[1]>
      - id: battle-log
        type: list, loop: entradas do round atual (entry[:round] == rounds)
        children:
          - type: text, source: "<lado>: <attacker_name> usou <move|move_type> em <target_name> — <damage> de dano" (+ " — KO!")
      - id: controls
        type: panel
        children:
          - type: button, text: "Jogar",
              action: post /battle/play, target: "#battle"   , visible: nao finished
          - type: button, text: "Novo confronto",
              action: get /battle,       target: "#battle"   , visible: finished
      - id: winner
        type: text, source: "Vencedor: <Seu Time|Oponente>", visible: finished
```

**Notas:** lado do atacante = `entry[:attacker]` (0 ⇒ "Seu Time", 1 ⇒ "Oponente").
`get /battle/close` re-renderiza `battle_close.erb` (vazio) — limpa o alvo.

---

## Desenho alvo — batalha (análise UI/UX 2026-08-22; ref: `draft-ui-ux.md` §2.6)

```
┌─────────────────────────────────────────────────────┐
│ Batalha — Rodada N                                  │
│ ┌─ Seu Time ────────┐ ┌───────────────┐ ┌─ Oponente ─┐│
│ │ [sp] pikachu      │ │  [ Jogar ⏳ ] │ │ [sp] squirtle│
│ │ HP ▮▮▮▮▯ 150/200  │ │ Log da rodada:│ │ HP ▮▮▯▯▯ 80/200│
│ │ tackle PP 25 · ...│ │ (últimas 3)   │ └─────────────┘│
│ └───────────────────┘ └───────────────┘               │
│ Seu Time à esquerda · controles centralizados + log ao│
│ centro · Oponente à direita · Itens: Poção ×2 no time │
│ Vencedor: ... — recompensas agrupadas                 │
└─────────────────────────────────────────────────────┘
```

```yaml
fragment: "#battle" (alvo)
layout: 3 colunas (grid fixo, tela cheia)
  - coluna esquerda: painel Seu Time (@engine.teams[0]) + estoque Itens:
  - coluna central: controles centralizados (Jogar/Novo confronto + hx-indicator) +
    log das últimas 3 rodadas (mais recente no topo) + fim de batalha (vencedor,
    recompensas, evoluções/aprendizados)
  - coluna direita: painel Oponente (@engine.teams[1])
deltas:
  - id: fighter-partial (novo)
    partial: um único partial de painel para player/opponent (fim da duplicação);
             presenter formata linhas (ref: draft-arquitetura-design-patterns)
  - id: hp-bars (novo)
    type: barra visual por membro (<hp_current>/<hp_max> como percent)
  - id: battle-log (alvo)
    scope: últimas N rodadas (ex.: 3), mais recente no topo — dados já existem
           em @engine.log; hoje a UI filtra só a rodada corrente
  - id: play-button (novo)
    state: "Jogar" com indicador de loading (hx-indicator) enquanto avança
  - id: rewards (alvo)
    group: XP + dinheiro numa linha; evoluções/aprendizados como listas próprias
```

**Notas do alvo:** nenhum contrato novo — log completo e níveis/HP já estão no
engine; mudanças são view/presenter + CSS. Gate pré-jornada permanece (fragmento
amigável); o progresso n/6 do shell reduz a chegada tardia ao gate.