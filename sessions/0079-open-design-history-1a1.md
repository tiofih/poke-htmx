# Sessão 0079 — open-design-history-1a1 (resíduo history: curadoria fina 1:1 do `history.html`)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — escolhas do usuário em 2026-09-09 (fatiamento por tela, deslizamento 0077-0079→resíduo / 0080-0082→estabilidade, fidelidade híbrida, backend thin listado, S1 com 1 teste novo + extensões — ver seção 5) |
| Implementação (fase 2, TDD) | **TDD concluído** — Passos 1-2 verdes (escopo 35/565, lint 0 no escopo) + docs; **aguardando Revisor S7. PARAR — sem Done, sem §7, sem commit de conclusão** |
| Validação (fase 3) | Pendente — **fase do usuário; ao fim da fase 2, PARAR e aguardar** |

---

## 1. Objetivo

Aplicar a **curadoria fina 1:1** do protótipo `open-design/history.html` (13KB) sobre `history.erb` + `history_page.erb` — base pronta na 0075 (`.pos-card`/`.stat-chip`, `rank-list`/`rank-row`, `history-list`/`history-row`) — conferindo classe a classe o que falta (cópia mais literal onde não há legado, adaptação mínima onde há), com **backend thin listado e sem migração**.

## 2. Contexto (estado atual — diagnóstico)

- **0075 Done** (base history pronta, suíte 1025/4402 na época): `.pos-card` (badge + 3× `.stat-chip.win/.loss/.draw` + fallback nil), `ul.rank-list>li.rank-row` (`.rank-bar>span` ∝ `wins/total` + `.you`), `ul.history-list>li.history-row` (`.result-badge` + `.history-main` + `.history-date` dd/mm HH:MM), vazio `notice--info` intacto.
- **Resíduo = curadoria fina:** `history.html` tem só 13KB — diffar 1:1 contra as views e portar o que faltar (detalhes de tipografia/espaçamento/badge que a 0075 não cobriu); onde não há legado, copiar literal; onde há, adaptar preservando htmx (`#history-view`) e `data-od-id`.
- **CSS:** `public/style.css` (35KB) tem o bloco ODS com seções por sessão; **CSS novo entra ANTES da linha `fim`**, com delimitador próprio `0079` (edição paralela sem conflito com 0077/0078).
- **⚠️ `public/style.css` está DIRTY no git** (diff grande, ~1129+/1003- — verificado no refinamento): o implementador deve **conferir/stash antes de editar o CSS** (`git diff -- public/style.css`, `git stash push -- public/style.css` se for trabalho alheio) e **NÃO commitar `style.css` junto sem revisar**.
- **Fila (deslizamento, seção 5):** 0077 home → 0078 battle → **0079 history** → 0080 escritas atômicas → 0081 CSRF → 0082 respiro.

## 3. Escopo

### Produção

- **Views (curadoria 1:1, htmx/contratos preservados):** `history.erb` + `history_page.erb` — diffar contra `history.html` e portar o faltante (classes/detalhes não cobertos na 0075); `#history-view`, `data-od-id`, vazio `notice--info` intactos.
- **`public/style.css` (só dentro do bloco ODS, ANTES da linha `fim`, com delimitador próprio `0079`):** classes do `history.html` aplicáveis ao faltante, aditivas.
- **Backend thin listado (sem migração/schema/gems/services):** ajustes só no que a curadoria exigir para exibir dado já disponível (`render_history`/`load_history_data` como referência; sem mudar presenter/retorno).

### Testes

- **Novo:** `test/history_curation_test.rb` (C1: `test_history_matches_prototype` — asserts 1:1 do faltante).
- **Estender (cirúrgico):** `test/design_system_test.rb` (classes 0079 no bloco), `test/history_view_test.rb` (detalhes curados), `test/history_routes_test.rb` (só se quebrar — meta: verde sem edição).

### Fora de escopo (não abrir — RNF-04)

- Home (0077); battle (0078); ranking/posição novos, mudar `render_history`/`load_history_data`; identidade `?as=`, CSRF, escritas atômicas → 0080/0081; erro-status, respiro → 0082; CD.

## 4. Critérios de aceite

### Resultado (S1 — cada critério aponta o teste que o prova)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| C1 curadoria 1:1: `history.erb` + `history_page.erb` conferem com `history.html` classe a classe (pos-card/chips, rank-row/barra/`.you`, history-row/badge/data, vazio intacto) | `test/history_curation_test.rb` `test_history_matches_prototype` (novo) + `test/history_view_test.rb` estendido | pendente |
| C2 CSS 0079 no bloco: classes do `history.html` aplicáveis ao faltante, aditivas, ANTES da linha `fim`, com delimitador próprio `0079` | `test/design_system_test.rb` `test_design_system_history_curation_classes` (estendido) | pendente |

### Garantias

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| G1 sem regressão — suíte completa (baseline **1057/4900** + novos) + lint 0; `style.css` DIRTY conferido/stash antes de editar (não commitar alheio) | `./scripts/test` + `./scripts/lint` + `git status -- public/style.css` | pendente |
| G2 backend só no listado (§3) — sem migração/schema/gems/services; testes sem rede | `git diff --stat -- db/ Gemfile*` vazio + revisão S7 confere | pendente |
| G3 S4/S5 + revisão — `SESSIONS.md` + `check_docs` + `checar-sessao 0079` verdes; revisor S7 `Aprovado` antes da 3 | `./scripts/check_docs` + `./scripts/checar-sessao 0079` + veredito do Revisor | pendente |

### Manual

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| M1 history no navegador (posição/ranking/batalhas/vazio, ≤920px sem overflow-x) | `manual` (`./scripts/run`, `/history`) | pendente |

> **S1:** cada critério acima aponta o teste que o prova (arquivo + método); o único critério puramente manual é **M1**. **Ao fim da fase 2 (suíte + lint verdes, revisor S7 `Aprovado`), PARAR e aguardar a validação do usuário — não marcar Done, não preencher a seção 7, não commitar conclusão.**

## 5. Decisões de refinamento (fechadas com o usuário em 2026-09-09 — prevalecem sobre o mapa)

- **Fatiamento por tela (escolhida):** 0079 = history (curadoria fina, base 0075 pronta).
- **Deslizamento (escolhida):** resíduo vira 0077-0079; antigas 0077 escritas atômicas→**0080**, 0078 CSRF→**0081**, 0079 respiro→**0082**.
- **Fidelidade híbrida (escolhida):** cópia mais literal onde não há legado; adaptação mínima (htmx/`data-od-id` preservados) onde há.
- **Backend thin listado sem migração (escolhida):** só o que a curadoria exigir para exibir dado disponível; sem schema/gems/services.
- **S1 (escolhida):** 1 arquivo Minitest novo (`history_curation_test.rb`) + extensões cirúrgicas.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Termina em Revisor (2c, S7, teto 3 rodadas) → **PARAR** p/ validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (linha 0079 + "Próxima sessão") | commit `Sessao 0079: refinamento concluido — ...` (**sem** `public/style.css`, que está dirty) |
| 1 | **red→green — C2-css (bloco 0079)** — conferir/stash o dirty do `style.css`, anexar classes ANTES da linha `fim` com delimitador `0079`, estender `design_system_test.rb` | `./scripts/test test/design_system_test.rb` + suíte + lint 0; commit `Passo 1: classes history no bloco ODS (delimitador 0079), aditivo` |
| 2 | **red→green — C1 (curadoria 1:1)** — diffar views × `history.html`, portar o faltante; criar `test/history_curation_test.rb` (`test_history_matches_prototype`) + estender `history_view_test.rb` | `./scripts/test test/history_curation_test.rb test/history_view_test.rb test/history_routes_test.rb` + suíte + lint 0; commit `Passo 2: curadoria fina history 1:1 (pos-card/rank-row/history-row)` |
| 3 | **red→green — G1/G3 (regressão + docs)** — suíte + lint 0 + `check_docs` + `checar-sessao 0079` | `./scripts/test` + `./scripts/lint` + `./scripts/check_docs` + `./scripts/checar-sessao 0079`; commit `Passo 3: regressao e docs — residuo history fechado` |
| — | **Fase 2 concluída** → **Revisor (2c)** até `Aprovado` (teto 3, senão S3) → **PARAR**, aguardar **validação 3**. Não marcar Done, não preencher §7, não commitar conclusão. | — |

## 7. Validação (executada pelo usuário — S2)

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 (curadoria 1:1) | | | pendente |
| C2 (CSS 0079 no bloco) | | | pendente |
| G1 (sem regressão) | | | pendente |
| G2 (backend listado) | | | pendente |
| G3 (docs + revisão) | | | pendente |
| M1 (history visual) | — | | pendente |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.

## 8. Observações

- **`public/style.css` DIRTY (~1129+/1003-):** conferir/stash antes de editar; nunca commitar junto sem revisar (Passo 1).
- **Menor sessão do resíduo:** base 0075 pronta — o trabalho é diffar 1:1 e portar só o faltante; se nada faltar, C1 vira teste de trava (contrato) + registro explícito.
- **Fila:** 0077 home → 0078 battle → 0079 history → **0080 escritas atômicas** → 0081 CSRF → 0082 respiro.
- **Fase 2 executada (2026-09-09, TDD red→green):** Passo 1 (C2 — bloco `History 1:1 (0079)` + `.card--tight` ANTES da linha `fim`, teste em `design_system_test.rb`) e Passo 2 (C1 — `history.erb` sem inline, `test/history_curation_test.rb` novo + `history_view_test.rb` estendido; `server.rb` intacto — backend já supria tudo). Escopo: 35 runs/565 asserts verdes; lint 0 no escopo (19 offenses pré-existentes em `scripts/sweep-balance.rb`, fora do escopo, intocadas).
- **Paralelismo 0077/0078:** o dirty do `style.css` era reformat geral (spaces→tabs), não revertido; o commit `9b421c4` (Passo 1 da 0078) levou o arquivo com o bloco 0079 intacto dentro — nada perdido. `SESSIONS.md`/`REQUIREMENTS.md` e arquivos da 0077/0078 intocados.
- **G1 parcial por WIP alheio:** suíte completa em 2026-09-09 deu 1068/4496 com 72F+64E — tudo fora do escopo (team_manage/journey/battle), com WIP não-commitado da 0078 na árvore (`views/battle.erb`, `test/battle_view_test.rb`, `test/battle_end_states_test.rb` untracked) durante as runs; `team_manage_test.rb` sozinho já erra (7E) sem interseção com este diff. Re-verificar suíte cheia com árvore limpa antes da validação.

## 9. Gotchas / Lições (memória — S6, preencher na 3)

- **Implementador (fase 2):** `./scripts/test -n /regex/` funciona, mas o `tail` mostra só o trace do rake — usar `grep -E "runs,"` para o placar. RuboCop `Style/RegexpLiteral` exige `%r{}` quando a regex contém `"` (padrão local já usa `%r` em `history_view_test.rb` — seguir o arquivo vizinho). `style.css` com reformat inteiro no diff: anexar o bloco e **não** dar `git add` nele (o commit alheio posterior carrega o bloco junto — conferir com `grep -c` depois). Suíte cheia sob sessões paralelas na mesma árvore/DB mente: travar o veredito no escopo (arquivos tocados) + `check_docs` + `checar-sessao`, e registrar o ruído alheio com prova (diff não-commitado, teste alheio isolado).
