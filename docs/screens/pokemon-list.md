## Tela: Lista de Pokémon   (fragmento `#pokemon-list`)

```
┌──────────────────────────────────────────┐
│ [⚠ aviso, se houver]                    │
│                                          │
│ Iniciais            (só com busca vazia) │
│ [sprite] bulbasaur   [Add to Team]       │
│ [sprite] charmander  [Add to Team]       │
│ ... (27 iniciais gen 1–9)                │
│                                          │
│ [sprite] pokemon1    [Add to Team]       │
│ [sprite] pokemon2    [Add to Team]       │
│ ... (20 itens por página)                │
│                                          │
│  ← Anterior   Página 1 de N   Próxima → │
└──────────────────────────────────────────┘
```

```yaml
fragment: "#pokemon-list"
refresh: get /pokemons?offset=<offset>&q=<q>   # paginação e filtro
blocks:
  - id: notice
    type: notice, source: @notice
  - id: starters
    type: list, loop: @starters               # só quando @q vazio
    title: "Iniciais"
    item:
      - type: link, action: get /pokemon/<pokemon.number>, target: "#pokemon"
        children:
          - type: sprite, source: pokemon
          - type: text, source: name
      - type: form, action: post /team, target: "#team"
        fields: { pokeName: name }
        button: "Add to Team"
  - id: items
    type: list, loop: @items                  # página corrente (20)
    item:
      - type: link, action: get /pokemon/<pokemon.number>, target: "#pokemon"
        children:
          - type: sprite, source: pokemon
          - type: text, source: name
      - type: form, action: post /team, target: "#team"
        fields: { pokeName: name }
        button: "Add to Team"
  - id: pagination
    type: panel
    children:
      - type: link, text: "← Anterior",
          action: get /pokemons?offset=<offset-20>&q=<q>, target: "#pokemon-list"
          visible: offset > 0
      - type: text, source: "Página <page> de <total>"
      - type: link, text: "Próxima →",
          action: get /pokemons?offset=<offset+20>&q=<q>, target: "#pokemon-list"
          visible: offset + 20 < total
```

**Fontes de dados:** `@items` (pares nome→`Pokemon` da página), `@starters`
(27 iniciais gen 1–9 quando `@q` vazio), `@page[:total]`, `@limit` (20),
`@offset`, `@q`, `@notice`. Sprite/nome linkam o detalhe (`GET /pokemon/:number`,
alvo `#pokemon`); o botão **Add to Team** faz `POST /team` com `pokeName`
(alvo `#team`). O enriquecimento sprite/número acontece na rota (`find` +
`Parallelizer`) — o contrato do gateway (`paginate` → nomes) não muda.
Navegação por teclado nativa (Tab/Enter nos links) — sem JS custom.

**Só formas base + iniciais fixos no topo (ajuste S3 — 2026-08-22):** a listagem
exibe apenas o 1º estágio de cada linha evolutiva (`base_form?(name)` no gateway;
evoluções como raichu, ivysaur, charmeleon não aparecem) e **exclui os 27
iniciais** (já fixos no bloco "Iniciais" — sem duplicação). A paginação continua
paginando nomes do pool (`offset` por 20) — uma página pode listar menos itens
quando contém evoluções/iniciais. Falha de rede no predicado esconde o item
(fail-closed).

---

## Desenho alvo — listagem (análise UI/UX 2026-08-22; ref: `docs/draft-backlog.md` §2.2)

```
┌──────────────────────────────────────────────────┐
│ Time inicial: ▮▮▮▮▯▯ 4/6   ← progresso (novo)   │
│ [ Buscar Pokémon ............ ]  12 resultados   │ ← contagem (novo)
│                                                  │
│ Iniciais — escolha entre os 27 (gen 1–9)        │ ← microcopy (novo)
│ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│ │[sp] bub. │ │[sp] cha. │ │[sp] squ. │           │ ← grid 3 colunas (novo)
│ │[Adicionar]│           │          │            │
│ └──────────┘ └──────────┘ └──────────┘          │
│ ┌──────────┐ ┌──────────┐ ┌──────────┐          │
│ │[sp] pok1 │ │[sp] pok2 │ │ ...      │           │ ← pool (formas base)
│ │[No time ✓]│           │ [Adicionar]│          │ ← estado do botão (novo)
│ └──────────┘ └──────────┘ └──────────┘          │
│                                                  │
│ Nenhum Pokémon encontrado para "zzz"           │ ← estado vazio (novo)
│  ← Anterior    Página 1 de N    Próxima →      │
└──────────────────────────────────────────────────┘
```

```yaml
fragment: "#pokemon-list" (alvo)
deltas:
  - id: journey-progress (novo)
    type: badge/bar, source: "Time <n>/6", visible: jornada não iniciada
    cta: link "Montar time" → âncora da lista (quando <6)
  - id: search-meta (novo)
    children:
      - type: text, source: "<total> resultado(s)" quando q não vazio
      - type: empty-state, text: "Nenhum Pokémon encontrado para '<q>'"
          visible: itens vazio && q não vazio   (substitui lista silenciosa)
  - id: starters (alvo)
    title: "Iniciais — 27 disponíveis (gen 1–9)"
  - id: items (alvo)
    layout: grid responsivo (2–3 colunas) de cartões
    item:
      - sprite com loading=lazy + alt="<nome>"
      - add-button states:
          default: "Adicionar ao time"
          in-team: "No time ✓", disabled (requer @team na rota — nota impl)
          full: desabilitado + aviso quando time = 6
  - copy: pt-BR ("Anterior"/"Próxima" mantidos; botões "Adicionar")
```

**Notas do alvo:** estados do botão Add exigem expor a composição atual do time no
render da listagem (ex.: `@team_names`); progresso n/6 reutiliza `JourneyService`.
Nada disso altera contratos do gateway.

**Caminho B executado (sessão 0042, 2026-08-24):** em vez do contador/strip apenas
na listagem, a **Lista e o Time foram unificados na mesma página** (`GET /`):
busca + lista à esquerda e **painel do time à direita** (`#team-view`, contador
"Time n/6" + membros com reordenar/remover + Center/Mart gated). A página `/team`
deixou de existir (404 em navegação direta; `GET /team` permanece como fragmento
htmx interno). O nav perdeu o link "Time". Estados do botão Add implementados
(default "Adicionar ao time" / "No time ✓" desabilitado quando no time / todos
desabilitados quando o time está cheio). Ver `sessions/0042-onda1-jornada-visivel.md`.
