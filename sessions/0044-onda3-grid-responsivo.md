# Sessão 0044 — Onda 3 UX: estrutura (grid responsivo da listagem + largura cheia do Histórico)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-24 |
| Implementação | **Concluída** — passos 1–3 em 2026-08-24 (suíte 693/2196, lint 0) |
| Validação | **Pendente** (executada pelo usuário) |

---

## 1. Objetivo

Entregar a parte **pendente da Onda 3 de UX (estrutura)** do `draft-ui-ux.md` §5:
**grid responsivo da listagem** (2–3 colunas em cards) corrigindo o **bug visual do
item** (sprite+nome+botão alinhados, fim do grande espaço em branco) e a
**largura cheia nas demais telas** — na prática, a página do **Histórico**
(`/history`), única página própria que ainda sofre o `max-width: 38em` do sakura
(Lista/Detalhe/Manage já estão dentro da `/` em largura cheia desde a 0042).
Tokens do `draft-design-system.md` §4 (grid `repeat(auto-fill, minmax(180px, 1fr))`,
gap 12px; card raio 6px / borda `#ddd` / padding 12px). **CSS puro** — sem gems,
sem lib JS, sem mudança de schema, sem mudança de markup/rotas.

## 2. Contexto (estado atual — diagnóstico)

- `views/layout.erb:10` — body class atual: `page-battle` (`/battle`) e `page-list`
  (`/`); **não existe `page-history`** → `GET /history` página própria sofre o
  `max-width: 38em` do sakura (anotação 0041 §8: largura cheia das demais telas
  "fica para onda futura"; 0042 resolveu só a Lista/`/`).
- `views/pokemon_list.erb:10,16` — `<ul class="pokemon-list starters">` (itens
  `starter-item`) e `<ul class="pokemon-list">` (itens `list-item`); **sem grid** —
  itens empilham 1 por linha (draft-ui-ux §2.2: "sem grid — itens empilham 1 por
  linha, lista longa").
- `views/pokemon_list_item.erb:1-6` — `<li>` com `<a>` (img inline + nome) + `<form>`
  (botão Add). **Bug visual (draft-ui-ux §2.2, anotado 2026-08-22):** img `inline`
  dentro do `<a>` + whitespace → grande espaço em branco entre o ícone e o nome;
  sem estilos de item/card/grid.
- `public/style.css` — já tem `.list-team-grid` (2 colunas, largura cheia),
  `body.page-battle`/`body.page-list` (`max-width: none`), tokens das barras HP/PP
  e dos botões desabilitados; **não tem** regras de `.pokemon-list` (grid) nem de
  `.list-item`/`.starter-item` (card).
- Testes existentes: `test/pokemon_routes_test.rb`
  (`test_index_page_uses_full_width_list_body_class` assert `class=" page-list"`,
  `test_pokemons_renders_clickable_list` assert `class="pokemon-list"`) e
  `test/history_routes_test.rb` (`test_history_page_renders_full_page_with_history_view`
  renderiza `/history` sem assert de body class). Baseline: suíte **692 runs/2193
  asserts**, lint 0.

## 3. Escopo

### Produção

- `views/layout.erb` — body ganha a classe `page-history` para
  `request.path == "/history"` (espelho de `page-list`/`page-battle`).
- `public/style.css` —
  - `.pokemon-list` (listagem comum **e** `.starters`): grid responsivo —
    `display: grid; grid-template-columns: repeat(auto-fill, minmax(180px, 1fr));
    gap: 12px; list-style: none;` (colapsa sozinho para 1 coluna em viewport
    estreito).
  - `.list-item`/`.starter-item`: **card** — `border: 1px solid #ddd;
    border-radius: 6px; padding: 12px; display: flex; flex-direction: column;
    align-items: center; gap: 8px;` com sprite `display: block`, nome e botão —
    corrige o bug visual do espaço em branco.
  - `body.page-history { max-width: none; }` — largura cheia do Histórico
    (espaçamento/`max-width` das seções internas herdado).

### Testes

- `test/history_routes_test.rb` — **novo** `test_history_page_uses_full_width_body_class`:
  `get "/history", {}, user_session("user-a")` → assert `class=" page-history"` no
  body (espelho de `test_index_page_uses_full_width_list_body_class`).
- Estrutura da listagem (`class="pokemon-list"`, `class="list-item"`) já coberta por
  `test/pokemon_routes_test.rb` — sem teste novo de markup para o grid.

### Fora de escopo (não abrir)

- JN-3, JN-4, JN-5, J2, J4, D4; P2 (perf da 1ª batalha ~2min).
- Grid/estilo de Detalhe e Manage (são **fragmentos** dentro da `/`, já em largura
  cheia desde 0042); Batalha já é 3 colunas em largura cheia desde 0041.
- Mudança de markup/rotas/contratos (`pokemon_list_item.erb`, gateway, repositórios,
  `TeamRepository`/`BattleService`/`JourneyService` intactos).
- Paleta por tipo dos chips (draft-design-system §2), copy nova, toast/juice
  (draft-ui-ux §4 "Juice").

## 4. Critérios de aceite

### Resultado

- [x] **C1 — Grid responsivo da listagem em cards**: `#pokemon-list`/`.pokemon-list`
      (comum e starters) em grid de cards (auto-fill, mín. 180px, gap 12px), itens
      `list-item`/`starter-item` com sprite+nome+botão alinhados — fim do grande
      espaço em branco do bug visual. Estrutura preservada (`<ul class="pokemon-list">`,
      `<li class="list-item">`) — prova: `manual` (visual; CSS puro — conferir em
      desktop ~2–3 colunas e em ~720px colapsando para 1 coluna) +
      `test/pokemon_routes_test.rb` (`test_pokemons_renders_clickable_list`).
- [x] **C2 — Largura cheia do Histórico**: `GET /history` (não-htmx) renderiza
      `<body class="page-history">` → `body.page-history { max-width: none }` —
      prova: `test/history_routes_test.rb` (`test_history_page_uses_full_width_body_class`).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (692 runs/2193 asserts)** + novo
      teste e lint 0 em **todo** green; commit obrigatório por passo; 0 regressão.
- [ ] Sem gems novas / sem mudança de schema / testes sem rede / sem `rubocop:disable`
      *(CSS-only).*
- [ ] `REQUIREMENTS.md` + `SESSIONS.md` + `draft-ui-ux.md` (Onda 3 marcada)
      atualizados no passo docs; status de validação só após o usuário validar (S4).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste automatizado →
> escrever `manual` explícito + a evidência manual esperada.

## 5. Decisões de refinamento (fechadas com o usuário)

- **2026-08-24 — Próxima sessão = Onda 3 UX (estrutura: grid responsivo da
  listagem + largura cheia restante)** — preteridos: JN-3, JN-4, JN-5, J2, J4, D4,
  P2 (perf). Escolha do usuário nesta sessão.
- **2026-08-24 — Grid responsivo em cards, CSS puro**, seguindo `draft-design-system.md`
  §4 (`repeat(auto-fill, minmax(180px, 1fr))`, gap 12px; card raio 6px / borda
  `#ddd` / padding 12px, alinhado ao `.battle-pane` existente) — preterido: manter
  1 coluna, ou adicionar lib JS de grid.
- **2026-08-24 — Fix do bug visual do item junto do grid** (sprite `block`, card
  flex column) — preterido: adiar.
- **2026-08-24 — Largura cheia aplicada só ao Histórico** (página própria restante;
  Lista/Detalhe/Manage já cobertos pela `/` em largura cheia desde 0042; Batalha
  3 colunas desde 0041) — preterido: aplicar `max-width: none` em todas as rotas.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (S4) | commit `Sessao 0044: refinamento concluido — ...`; `./scripts/checar-sessao 0044` + `./scripts/check_docs` |
| 1 | C2 — teste novo `test_history_page_uses_full_width_body_class` (red) → `page-history` no body (`layout.erb`) + `body.page-history { max-width: none }` (green) | suíte verde + lint 0, commit `Passo 1:` |
| 2 | C1 — CSS do grid responsivo da listagem (`.pokemon-list` grid auto-fill + cards `.list-item`/`.starter-item`) — prova manual | suíte verde + lint 0, commit `Passo 2:` |
| 3 | **Docs:** `REQUIREMENTS.md` (roadmap — Onda 3 executada), `SESSIONS.md`, `draft-ui-ux.md` (Onda 3 marcada) | suíte verde + lint 0, commit `Passo 3:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 — grid responsivo da listagem em cards | `test/pokemon_routes_test.rb` (`test_pokemons_renders_clickable_list` — estrutura) | `/` em desktop: cards 2–3 colunas com sprite+nome+botão alinhados (sem espaço em branco); em ~720px colapsa para 1 coluna | |
| C2 — largura cheia do Histórico | `test/history_routes_test.rb` (`test_history_page_uses_full_width_body_class`) | `/history` em tela cheia (não mais 38em centralizado) | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

- Grid/estilo de Detalhe e Manage ficam de fora: são fragmentos dentro da `/` (já em
  largura cheia desde 0042). Batalha não muda (3 colunas desde 0041).
- Prova do grid é `manual` (CSS puro não é coberto por Minitest) — S1 exige `manual`
  explícito; a estrutura de markup da listagem continua coberta por teste existente.
- `body.page-history` segue o mesmo padrão de `page-list`/`page-battle` (layout.erb:10).
- Fila após 0044: JN-3, JN-4, JN-5, J2, J4, D4 e P2 (perf da 1ª batalha ~2min) como
  candidatas — a critério do usuário.