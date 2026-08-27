# Sessão 0060 — RESP-1 P0: viewport + grid + colapso Lista+Time (Onda UX)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-27 (D1 A, D2 A, D3 A, D4 A, D5 B) |
| Implementação | **Pendente** |
| Validação | **Pendente** (executada pelo usuário) |

---

## 1. Objetivo

Desbloquear mobile/tablet adicionando `<meta viewport>` e corrigindo o grid da listagem e o colapso `Lista+Time` — `playtest-02` P0 (RESP-1). Sem viewport o app renderiza 980px em 375; grid `repeat(6)` até 720 quebra em 768 (42px) e `list-team-grid` 1fr+22em espremido.

## 2. Contexto (estado atual — diagnóstico)

- **Baseline pós-0059:** suíte 869/3150 lint 0, `SESSIONS.md`/`check_docs` ok. `views/layout.erb:5-8` sem `viewport` (`<meta charset>` + `<title>` + htmx + sakura + `/style.css`); CDP 375 sem viewport = `innerWidth 980`, `pokemon-grid 6×77px`, `list-team-grid 531+396` — media `720/480` nunca dispara (playtest-02 §1).
- **Grid atual:** `public/style.css:30-35` `repeat(6, minmax(0,1fr))` + `@media 720→3` + `480→1`. Com viewport injetado medido: 768→6×42px inutilizável, 1024→6×85px estreito, 375→1×346px ok mas desperdiça 2col. Causa: breakpoint 720 só pega celular, tablet fica com 6 colunas em `list-column 319px`.
- **Lista+Time:** `public/style.css:258-297` `list-team-grid 1fr 22em` colapsa só em `720`; tablet 768 ainda `319+396` espremido (playtest-02 §4). `list-column`/`team-column` `max-height 78vh` + `overflow-y:auto` gera duplo scroll em desktop; `min-height 420px` deixa buraco em mobile vazio.
- **Outros:** `filter-controls` 7 filhos `flex 1 1 8em` → 375=117px 3 linhas (já anotado mas fica fora deste P0 — vira 0061), `battle-layout 3×1fr` sem breakpoint (fora — 0061), imagens `96px` sem `max-width 100%` (incluir no P0 como fix barato).
- **Preservar:** `BattleService`/`TeamService`/`PokemonRatingCache`/`PersistentJsonStore`, htmx alvos (`#pokemon-list`, `#team-view`, `#filter-controls`), `oob_pokemon_list` condicional 0059, `TeamBudget`/`page-list` largura cheia, suíte/lint verdes.

## 3. Escopo

### Produção

- `views/layout.erb` — adicionar `<meta name="viewport" content="width=device-width, initial-scale=1">` no `<head>` após `<meta charset>` (P0 bloqueante). Não tocar `<title>`/htmx/sakura/nav.
- `public/style.css` — **grid da listagem:** trocar `repeat(6)` fixo por `repeat(auto-fill, minmax(140px, 1fr))` **ou** breakpoints graduais `>1100:6 / 900:4 / 720:3 / 520:2 / 360:1` (fechar na implementação; auto-fill preferido por cobrir 768 sem regra extra). Manter `gap 12px`, `list-item`/`starter-item` intactos, corrigir bug visual já feito em 0044. Garantir `img { max-width: 100% }` nos cards para não vazar em 42px.
- `public/style.css` — **Lista+Time:** subir breakpoint de colapso `720→960` (ou 900 se 960 deixar desktop 1024 ainda 2col ok) para `list-team-grid` virar `1fr` em tablet; remover/condicionar `max-height 78vh` dupla (deixar `max-height:none` já em `<960` como hoje, ou `calc(100vh - header)` — decidir sem quebrar 0042). `team-column` `min-height auto` em mobile quando vazio é desejável mas pode ficar para 0061 se tocar layout demais — P0 foca no breakpoint.
- Sem mudar `server.rb`, `lib/**`, `views/index.erb`, `views/_filter_controls.erb`, `views/pokemon_list*.erb`, `views/battle.erb`.

### Testes

- `test/layout_test.rb` **novo** (ou `test/pokemon_routes_test.rb` se preferir não criar arquivo): `GET /` contém `<meta name="viewport" content="width=device-width, initial-scale=1">` no `<head>` (C1). Também `GET /battle` e `GET /history` herdam layout com viewport (mesmo partial).
- `test/style_responsive_test.rb` **novo** puro (sem rede, lê `public/style.css`): C2 — arquivo contém `auto-fill.*minmax(140px` **ou** contém `@media (max-width: 1100px)`/`900px`/`720px`/`520px` com `grid-template-columns` correspondentes; C3 — contém `@media (max-width: 960px)` (ou 900) com `.list-team-grid { grid-template-columns: 1fr }` e `max-height: none`/`overflow: visible` para `.list-column,.team-column`; também garante `img { max-width: 100% }` nos cards.
- Regressão: `test/pokemon_list_filters_test.rb` e `test/pokemon_list_cost_test.rb` seguem verdes (grid não quebra `hx-get`/`hx-target`/`poke-cost`/`oob_pokemon_list`); `test/team_routes_test.rb` segue verde.
- `manual` para C4 — medições CDP 375/768/1024 com viewport (sem mobile real, browser-harness `Emulation.setDeviceMetricsOverride` + `getComputedStyle`).

### Fora de escopo (não abrir)

- **Filtros drawer / `min-height 44px` toque / agrupamento `type+generation`** — fica para 0061 (RESP-1 P1).
- **Batalha 3 col empilhar <900 + barras fluidas** — 0061.
- **Duplo scroll `78vh` → `calc(100vh - header)` completo + `team-column min-height auto` refinado** — se exigir redesign, deixar para 0061; P0 só garante breakpoint.
- **Toast / juice / animações / copy pt-BR extra** — Onda 0063.
- **Economia (G1 vida zerada, G2 heal trap, G9 pool oponente)** — Onda 2 (0064+); Estabilidade (T1–T3) — Onda 3.
- Sem gems novas, sem schema, sem `rubocop:disable`.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 (viewport P0):** `GET /` (e `GET /battle`, `GET /history` via layout) responde HTML contendo `<meta name="viewport" content="width=device-width, initial-scale=1">` dentro de `<head>`. — prova: `test/layout_test.rb` (`test_layout_contains_viewport_meta` — `get "/"` + `assert_match /<meta name="viewport"[^>]*content="width=device-width,\s*initial-scale=1"/`).
- [ ] **C2 (grid auto-fill / breakpoints graduais):** `public/style.css` usa `auto-fill minmax(140px,1fr)` **ou** breakpoints `1100→6 / 900→4 / 720→3 / 520→2 / 360→1` para `.pokemon-grid`, sem `repeat(6)` fixo até 720. — prova: `test/style_responsive_test.rb` (`test_pokemon_grid_is_responsive` — leitura do arquivo, `assert_match /auto-fill.*minmax\(140px/` **ou** `assert_match /@media.*1100px.*repeat\(6/` etc.; falha se ainda `repeat(6, minmax(0,1fr))` sem auto-fill e sem 1100/900).
- [ ] **C3 (Lista+Time colapsa em 960):** `public/style.css` colapsa `.list-team-grid` para `1fr` em `max-width: 960px` (ou 900) e remove `max-height 78vh`/`overflow-y:auto` de `.list-column,.team-column` nesse breakpoint. — prova: `test/style_responsive_test.rb` (`test_list_team_grid_collapses_at_960` — `assert_match /@media.*max-width:\s*960px.*\.list-team-grid.*grid-template-columns:\s*1fr/s` + `assert_match /max-height:\s*none/`).
- [ ] **C4 (visual mobile/tablet — manual):** em 375 o app usa `innerWidth 375` (não 980), grid 1–2 col legível, card não vaza (`img max-width:100%`), filtros visíveis sem quebrar; em 768 grid 3–4 col legível (não 6×42px), Lista+Time empilhados (1fr) sem espremido `319+396`; em 1024 grid 4–6 col confortável. — prova: `manual` explícito (browser-harness CDP `Emulation.setDeviceMetricsOverride` + `getComputedStyle` + screenshots 375/768/1024; sem teste automatizado).

### Garantias (RNF)

- [ ] **G1:** suíte completa verde com baseline **869/3150** preservado + novos testes (C1–C3) e lint 0 em todo green; commit obrigatório por passo; 0 regressão (`pokemon_list_filters`/`pokemon_list_cost`/`team_routes` seguem verdes).
- [ ] **G2:** sem gems novas / sem mudança de schema / testes sem rede (C2–C3 leem arquivo, C1 usa `Rack::Test` sem `PokeApi`) / sem `rubocop:disable` novo (seguir padrão `Metrics/MethodLength` existente se precisar).
- [ ] **G3:** `SESSIONS.md` atualizado no commit do refinamento (S4) — tabela + "Próxima sessão" — e `REQUIREMENTS.md` se tocar doc; status de validação só após usuário validar (fase 3 — parar na fase 2 e aguardar).
- [ ] **G4:** sem quebrar htmx (`hx-get`/`hx-target`/`hx-swap`/`oob_pokemon_list` condicional 0059), paginação on-demand 36, filtros server-side, `TeamBudget`/`poke-cost`/`data-tier` e `Battle/History` largura cheia.

> **S1:** cada critério acima aponta o teste que o prova. Sem teste → `manual` explícito + evidência esperada (ver C4). Baseline suíte 869/3150 de 0059.

## 5. Decisões de refinamento (fechadas com o usuário em 2026-08-27)

- **D1 — Foco (A — RESP-1 P0 viewport+grid+colapso):** playtest-02 mediu blocker P0 sem viewport (375→980, media nunca dispara) e grid 6×42px em 768 injogável. Dentre UX>Economy>Stability (decisão usuário 2026-08-27), RESP-1 P0 é pré-requisito para todo UX seguinte. Alternativa preterida: B — quick-wins `pokemon.erb` aspas/nav badge (P1 barato mas não desbloqueia mobile), C — economia G1 vida zerada (P0 design mas depende de mobile legível para validar). Motivo: viewport é 1 linha e libera media-queries; grid/collapse são só CSS e validáveis por CDP sem tocar `server.rb`.
- **D2 — Design grid (A — auto-fill minmax 140px preferido):** `auto-fill` resolve 768 sem N media queries e mantém 6col em 1440 (154px) e 1col em 375 (346px) medidos. Alternativa preterida: B — só trocar breakpoints 720→960 mantendo `repeat(6)` (ainda deixa 1024 com 6×85px estreito). Motivo: auto-fill cobre espectro contínuo; se `auto-fill` introduzir 5col parcial em largura ímpar, fallback para breakpoints graduais `1100:6/900:4/720:3/520:2/360:1` é aceito na implementação.
- **D3 — Lista+Time (A — collapse 960):** `list-team-grid` 1fr+22em → 1fr em 720 deixa tablet 768 com 319px lista espremida; subir para 960 empilha em tablets. Alternativa preterida: B — manter 720 e só aumentar padding (não resolve 768). Motivo: medição 768 `319+396` prova espremido; 960 já usado como threshold do playtest-02 proposta.
- **D4 — Escopo P0 estrito:** Filtros drawer + `min-height 44px` e battle 3col ficam para 0061 para manter 0060 só `layout.erb`+`public/style.css` (zero Ruby além de teste). Alternativa preterida: C — fazer tudo em 0060 (mistura 7 controles + battle stack + toast, aumenta risco e dificulta S1). Motivo: SDD prefere 1 CSS-change por sessão; 0060 valida viewport/grid sem tocar `server.rb`.
- **D5 — Tamanho/Plano TDD (B — 3 passos + refinamento):** 0 refinamento, 1 viewport, 2 grid, 3 collapse+img+manual. Alternativa preterida: A — 2 passos (viewport+grid juntos escondem regressão), C — 5 passos (pulveriza). Motivo: cada passo com 1 arquivo alvo e suíte+lint verdes, parando na fase 2 para validação.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Parar ao fim da fase 2 e aguardar validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (tabela + "Próxima sessão") | commit `Sessao 0060: refinamento concluido — RESP-1 P0 viewport + grid auto-fill + colapso Lista+Time em 960, criterios e plano TDD fechados` |
| 1 | **red→green — C1 viewport** — `views/layout.erb` + `test/layout_test.rb` (`GET /` contém viewport meta) | `./scripts/test test/layout_test.rb -n /viewport/` + suíte completa + `./scripts/lint` 0; commit `Passo 1: viewport meta em layout.erb (width=device-width, initial-scale=1)` |
| 2 | **red→green — C2 grid responsivo** — `public/style.css` `.pokemon-grid` auto-fill / breakpoints + `test/style_responsive_test.rb` (`test_pokemon_grid_is_responsive`) | `./scripts/test test/style_responsive_test.rb -n /pokemon_grid_is_responsive/` + suíte + lint 0; commit `Passo 2: grid auto-fill minmax 140px / breakpoints graduais (768→3col legivel)` |
| 3 | **red→green — C3 collapse 960 + img max-width + C4 manual** — `public/style.css` `.list-team-grid` @960 1fr + `max-height:none` + `.list-item img max-width:100%` + evidência CDP 375/768/1024 | `./scripts/test test/style_responsive_test.rb -n /list_team_grid_collapses_at_960/` + suíte + lint 0; cdp manual 375/768/1024; commit `Passo 3: Lista+Time colapsa em 960 e cards nao vazam (manual 375/768/1024)` |
| — | **Fase 2 concluída** → **Revisor (2c)**: loop Implementador↔Revisor até veredito `Aprovado` (teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar Done, não preencher a seção 7, não commitar conclusão. | — |

## 7. Validação (executada pelo usuário)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 (viewport) | `./scripts/test test/layout_test.rb -n /viewport/` | view-source `<head>` contém viewport | |
| C2 (grid auto-fill) | `./scripts/test test/style_responsive_test.rb -n /pokemon_grid_is_responsive/` | — | |
| C3 (colapso 960) | `./scripts/test test/style_responsive_test.rb -n /list_team_grid_collapses_at_960/` | — | |
| C4 (visual 375/768/1024) | `manual` explícito | CDP 375 grid 1-2col / 768 3-4col / 1024 4-6col, Lista+Time empilhados em 768, sem vazar | |
| G1 (suíte+lint) | `./scripts/test` 869/3150+novos 0 falhas + `./scripts/lint` 0 | — | |
| G2 (sem gems/schema/rede) | stubs leitura de arquivo, Rack::Test sem PokeApi | — | |
| G3 (S4/S5) | `./scripts/check_docs` ok, `./scripts/checar-sessao 0060` ok | — | |
| G4 (sem quebrar htmx/filtros) | `./scripts/test test/pokemon_list_filters_test.rb test/pokemon_list_cost_test.rb` | — | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.

## 8. Observações

- **Roadmap novo (UX > Economia > Estabilidade) fechado em 2026-08-27, ajustado 2026-08-27 (0063 após 0068):** Onda 1 UX (0060 P0 → 0061 filtros/batalha responsivos → 0062 quick-wins contrato), Onda 2 Economia (0064 vida zerada → 0065 death spiral+game over → 0066 pool oponente → 0067 pedras+modais → 0068 resolver batalha → **0063 juice**), Onda 3 Estabilidade (0069 race add → 0070 escritas atômicas → 0071 CSRF → 0072 respiro/pry/CI/Redis). J2/J4/D4 e IA-2/3/4 ficam pós-0072. 0063 é UX/juice pós-economia.
- **Próxima após 0060:** 0061 RESP-1 P1 (filtros drawer 44px + battle 3col <900 + barras fluidas) — depende de 0060 verde.
- **Risco:** `auto-fill` pode gerar 5 col em largura ímpar; fallback para breakpoints graduais é aceito sem reabrir critério se manter C2 verde.

## 9. Gotchas / Lições (memória — S6)

{{Armadilhas, lições e erros levantados na sessão (ex.: viewport sem media, auto-fill vs repeat fixo, 960 vs 720). Alimentam o `memory_write_page` em `gotchas/` ao fechar a validação.}}

