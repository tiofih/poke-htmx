# Draft — Design system mínimo (tokens) (2026-08-22)

> **Fora do fluxo.** Anotação para embasar as ondas de UI da análise
> (`draft-ui-ux.md` §5) e os desenhos alvo em `docs/screens/`. Zero edição de
> código; valores propostos, decisão final no refinamento da onda que os usar.
> Base atual: sakura.css (CDN) + `public/style.css` (86 linhas).

---

## 1. Severidades de notice (substitui o vermelho único `.notice`)

| Token | Uso | Cor proposta |
| --- | --- | --- |
| `notice-info` | avisos neutros (jornada n/6, histórico vazio) | cinza/azul `#4a69bd` em fundo neutro |
| `notice-success` | confirmações (salvo, comprado, curado) | verde `#2e7d32` |
| `notice-warning` | atenção (saldo insuficiente, item indisponível) | âmbar `#b26a00` |
| `notice-error` | falhas reais (não encontrado, erro de rede) | vermelho `#b00` (atual) |

Regra: mapear cada `@notice` existente a uma severidade na onda 0.

## 2. Paleta por tipo (chips do detalhe)

Paleta consolidada dos 18 tipos (referência visual clássica), texto branco:

fire `#f08030` · water `#6890f0` · grass `#78c850` · electric `#f8d030` (texto escuro)
ice `#98d8d8` · fighting `#c03028` · poison `#a040a0` · ground `#e0c068` (escuro)
flying `#a890f0` · psychic `#f85888` · bug `#a8b820` · rock `#b8a038`
ghost `#705898` · dragon `#7038f8` · dark `#705848` · steel `#b8b8d0` (escuro)
fairy `#ee99ac` · normal `#a8a878`

Tipos com fundo claro usam texto escuro (`electric`, `ground`, `steel`, `ice`) —
contraste AA.

## 3. Barras de HP/PP e progresso

| Token | Regra | Cor |
| --- | --- | --- |
| `bar-hp` alta | ≥ 50% | verde `#2e7d32` |
| `bar-hp` média | 20–49% | âmbar `#b26a00` |
| `bar-hp` baixa | < 20% | vermelho `#b00` |
| `bar-pp` | mesmo limiar por golpe | idem, trilha mais clara |
| `progress-journey` | "Time n/6" pré-jornada | primária sakura (teal) |

Trilha das barras: `#eee`; raio 4px; altura 8px (HP) / 6px (PP).

## 4. Forma (cartões, grid, espaçamento)

- Cartão de listagem/detalhe: raio **6px**, borda `1px solid #ddd`, padding
  `12px` — alinha com `.battle-pane` existente.
- Grid da listagem: `repeat(auto-fill, minmax(180px, 1fr))`, gap `12px`.
- Espaçamento: escala base 4px (usar 8/12/16/24 nos blocos; hoje há `1.5em`
  soltos que padronizam para 24px).
- Botão desabilitado ("No time ✓"/time cheio): opacidade 0.6 + `cursor: not-allowed`.

## 5. Acessibilidade (requisito transversal)

- Foco visível em todos os interativos (`outline` padrão reforçado).
- `alt="<nome>"` em todo sprite; `aria-label` nos botões ▲▼/↑↓.
- Alvos de toque ≥ 40×40px nos cartões/botões do grid.
- Indicador de loading global: barra fina no topo via `[aria-busy]`/`hx-indicator`.

## 6. Copy pt-BR (padrão único)

Adicionar ao time · Remover do time · Salvar golpes · Curar · Comprar · Buscar
Pokémon… · Anterior/Próxima · Fechar. Estados: "No time ✓", "Time cheio",
"Nenhum Pokémon encontrado para '<q>'".
