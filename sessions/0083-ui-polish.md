# Sessão 0083 — ui-polish (polimento visual: header gate, filtros, pills, pcard)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — roteamento confirmado em 2026-09-10 (visual-only; diagnósticos: layout.erb:20, _filter_controls overflow, team.erb:18, pcard-meta, pill stale; playtest mediums T-playtest) |
| Implementação (fase 2, TDD) | Pendente |
| Validação (fase 3) | Pendente — **fase do usuário; ao fim da fase 2, PARAR e aguardar** |

---

## 1. Objetivo

Polimento visual das telas home/team/battle — header gate do CTA Batalhar, labels + contagem nos filtros, pills de time vazio/stale, posição do botão adicionar no pcard — **sem tocar backend/motor/economia, regras, rotas, nem migrações**. Full reload preservado.

## 2. Contexto (estado atual — diagnóstico)

- `views/layout.erb:20` — CTA Batalhar sem gate visual (habilitado mesmo sem time válido; T-diagnóstico).
- `views/_filter_controls` — overflow em viewport estreita, sem labels/count visível (T-diagnóstico).
- `views/team.erb:18` — pill de slot vazio sem estado empty dedicado (T-diagnóstico).
- `pcard-meta` — layout sem flex, botão adicionar fora de posição; pill com estado stale (T-diagnóstico).
- Playtest mediums: confirmar remoção, labels de filtro, legenda, copy (fora do gate crítico, entram como copy/labels nesta sessão).
- Base: 0080 (convergência visual), 0060–0062 (responsivo), 0059 (remover 1-clique).

## 3. Escopo

### Produção (visual-only)

- **`views/layout.erb`** — gate visual do CTA Batalhar (estado disabled + hint quando time inválido/vazio).
- **`views/_filter_controls.erb` + `public/style.css` (bloco ODS, delimitador `0083`)** — labels, contagem de resultados, fix de overflow.
- **`views/team.erb`** — pill empty dedicada (:18) + estilo pill stale.
- **`views/pokemon_list_item.erb` + CSS** — `.pcard-meta` em flex, posição do botão adicionar.
- **Copy/labels/legenda + confirmação de remoção** (playtest mediums, só texto/título/atributo, sem mudar fluxo).

### Testes

- View/system tests por critério (ver §4); regressão: `test/layout_test.rb`, `test/home_view_test.rb`, `test/battle_view_test.rb`.

### Fora de escopo (não abrir)

- Regras de negócio (gate funcional, custo, economia, motor); rotas/verbos/CSRF/escritas atômicas; migrações/schema/gems; modal heal (0082); full reload → HTMX parcial.

## 4. Critérios de aceite

### Resultado (S1 — cada critério aponta o teste que o prova)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| C1 header gate: CTA Batalhar exibe estado disabled + hint quando time inválido/vazio; habilitado quando válido | `test/layout_test.rb` `test_battle_cta_gated_hint` (novo; view test) | pendente |
| C2 filtros com labels + count: `_filter_controls` com labels visíveis, contagem de resultados e sem overflow em 360px | `test/home_view_test.rb` `test_filter_labels_count_no_overflow` (novo; system test 360px) | pendente |
| C3 pills empty/stale: `team.erb:18` pill empty dedicada + estilo pill stale distinguível | `test/home_view_test.rb` `test_team_empty_stale_pills` (novo; view test) | pendente |
| C4 pcard add position: `.pcard-meta` em flex com botão adicionar posicionado conforme protótipo | `test/home_view_test.rb` `test_pcard_meta_flex_add_position` (novo; view test) | pendente |

### Garantias

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| G1 sem regressão — suíte completa + lint 0 | `./scripts/test` + `./scripts/lint` | pendente |
| G2 escopo contido — só views + CSS bloco `0083`; sem mudança de regra/rota/migração | `git diff --stat -- lib/ db/ config/` vazio + revisão S7 confere | pendente |
| G3 docs + revisão — `checar-sessao 0083` verde; revisor S7 `Aprovado` antes da 3 | `./scripts/checar-sessao 0083` + veredito do Revisor | pendente |

> **S1:** cada critério acima aponta o teste que o prova (arquivo + método). Playtest mediums (confirm remoção, labels, legenda, copy) cobertos como asserts de texto nos testes de C1–C3. **Ao fim da fase 2 (suíte + lint verdes, revisor S7 `Aprovado`), PARAR e aguardar a validação do usuário — não marcar Done, não preencher a seção 7, não commitar conclusão.**

## 5. Decisões de refinamento (fechadas, sem reabrir)

- **Rota 0083 = UI polish visual-only:** header gate + filtros + pills + pcard; full reload mantido.
- **Gate é visual:** C1 não cria regra nova — só reflete estado existente do time.
- **Filtros:** labels + count + fix overflow (360px sem scroll-x).
- **Pills:** empty dedicada + stale distinguível, só classe/texto.
- **Playtest mediums** entram como copy/labels, sem mudar fluxo de remoção.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Termina em Revisor (2c, S7, teto 3 rodadas) → **PARAR** p/ validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo (sem `SESSIONS.md`/backlog/commit, por ordem da tarefa) | arquivo criado em `sessions/0083-ui-polish.md` |
| 1 | **red→green — C1 (header gate)** — CTA Batalhar disabled + hint; novo `test_battle_cta_gated_hint` | `./scripts/test test/layout_test.rb` + suíte + lint 0; commit `Passo 1: header gate do CTA Batalhar` |
| 2 | **red→green — C2 (filtros labels+count)** — labels + count + overflow fix; novo `test_filter_labels_count_no_overflow` | `./scripts/test test/home_view_test.rb` + suíte + lint 0; commit `Passo 2: filtros com labels e contagem` |
| 3 | **red→green — C3 + C4 (pills + pcard)** — pills empty/stale + pcard-meta flex; novos `test_team_empty_stale_pills`, `test_pcard_meta_flex_add_position` | `./scripts/test test/home_view_test.rb` + suíte + lint 0; commit `Passo 3: pills e posicao do adicionar` |
| 4 | **red→green — G1/G2/G3 (regressão + docs)** — suíte + lint 0 + `checar-sessao 0083` | `./scripts/test` + `./scripts/lint` + `./scripts/checar-sessao 0083`; commit `Passo 4: regressao e docs — ui polish` |
| — | **Fase 2 concluída** → **Revisor (2c)** até `Aprovado` (teto 3, senão S3) → **PARAR**, aguardar **validação 3**. Não marcar Done, não preencher §7, não commitar conclusão. | — |

## 7. Validação (executada pelo usuário — S2)

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 (header gate) | | | pendente |
| C2 (filtros labels+count) | | | pendente |
| C3 (pills empty/stale) | | | pendente |
| C4 (card add position) | | | pendente |
| G1 (sem regressão) | | | pendente |
| G2 (escopo contido) | | | pendente |
| G3 (docs + revisão) | | | pendente |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário. **Ao fim da fase 2, PARAR na fase 2 — não preencher esta seção, não marcar Done, não commitar conclusão sem a validação do usuário (fase 3).**

## 8. Observações

- **Não tocado nesta tarefa (por ordem):** demais arquivos, commits.
- **Leitura exata antes de editar:** ERB `not_tracked` — confirmar `layout.erb:20`, `team.erb:18`, `_filter_controls`, `pcard-meta` no arquivo antes do Passo 1.
- **CSS:** só dentro do bloco ODS, ANTES da linha `fim`, com delimitador próprio `0083`.

## 9. Gotchas / Lições (memória — S6)

A preencher na validação (fase 3): gate visual vs regra, overflow de filtros em 360px, pill stale vs empty.
