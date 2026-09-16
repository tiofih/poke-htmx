# Sessão 0077 — open-design-home-1a1 (resíduo home: `home-team.html` → `_center`/`_mart` inner + `team_manage`/evolução + list-item/detalhe)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — escolhas do usuário em 2026-09-09 (fatiamento por tela, deslizamento 0077-0079→resíduo / 0080-0082→estabilidade, fidelidade híbrida, backend thin listado, S1 com 1 teste novo + extensões — ver seção 5) |
| Implementação (fase 2, TDD) | **Concluída em 2026-09-09** — Passos 1–5: `ea7192a` (C4/teste `home_residue_test.rb`), `a00db99` (`heal-list`/`heal-item`/`mart-name`/`item-icon`), `2671204` (`stat-grid`/`mv-row`/`evo-row`/`equip-row`), `d0832bf` (`pcard-meta`/`tag-row`), `d922add` (Passo 5 — resíduo home fechado + §9) |
| Validação (fase 3) | **Concluída** — validada pelo usuário em 2026-09-16 (C1–C4 + G1–G3 + M1 ok, sem `nok`); a validação é do usuário — nada foi autoproclamado |

---

## 1. Objetivo

Portar o **resíduo da home** do protótipo `open-design/home-team.html` (50KB, 97 classes) para as views existentes — **miolo dos modais** `_center.erb` (falta `heal-list`/`heal-item`) e `_mart.erb` (falta `mart`/`mart-name`/`item-icon`/`price`/`tabs`), **`team_manage.erb`** (falta `stat-grid`/`mv-row`/`evo-row`/`equip-row`), **`_evolution_modal.erb`** (trazer para o padrão `.modal`), **`pokemon_list_item.erb`** (falta `pcard-meta`/`name`) e **`pokemon_detail.erb`** (falta `tag-row`/`stat-grid`/`evo-row`) — em **fidelidade híbrida** (adaptação preservando o htmx onde há legado 0073/0076, cópia mais literal onde não há legado), com **backend thin listado e sem migração**.

## 2. Contexto (estado atual — diagnóstico)

- **0076 Done** (onda open-design fechada, baseline **1057/4900**, lint 0): overlay híbrido (rotas `GET /team/center|/team/mart`, `render_team_center` `server.rb:544-547`, `render_team_mart` `:549-552`), `render_team_manage` (`:535-538`), `render_evolution_modal` (`server.rb:839-846`), `render_pokemon_detail` (`:473-481`).
- **Trace inbound de `render_team_center` = 0 callers** — rotas Sinatra não viram arestas CALLS (gap conhecido do índice); validar rotas por grep/zvec-rg, não pelo grafo.
- **Falta portar (home-team.html):** `_center.erb` hoje só `team-hp`/`heal-cost` (falta `heal-list`/`heal-item`); `_mart.erb` hoje só `balance`/`inventory` (falta `mart`/`mart-name`/`item-icon`/`price`/`tabs`); `team_manage.erb` hoje só `manage-member`/`move-row` (falta `stat-grid`/`mv-row`/`evo-row`/`equip-row`); `_evolution_modal.erb` com `evolution-*` fora do padrão `.modal`; `pokemon_list_item.erb` sem `pcard-meta`/`name`; `pokemon_detail.erb` hoje só `type`/`stats`/`evolutions` (falta `tag-row`/`stat-grid`/`evo-row`).
- **CSS:** `public/style.css` (35KB) tem o bloco ODS `/* === Open Design System (0072): inicio/fim === */` com seções por sessão; **CSS novo entra ANTES da linha `fim`**, cada sessão com seu próprio delimitador (permite edição paralela sem conflito).
- **⚠️ `public/style.css` está DIRTY no git** (diff grande, ~1129+/1003- — verificado no refinamento): o implementador deve **conferir/stash antes de editar o CSS** (`git diff -- public/style.css`, `git stash push -- public/style.css` se for trabalho alheio) e **NÃO commitar `style.css` junto sem revisar**.
- **Fila (deslizamento, seção 5):** 0077-0079 = resíduo open-design por tela; antigas 0077 escritas atômicas→**0080**, 0078 CSRF→**0081**, 0079 respiro→**0082**.

## 3. Escopo

### Produção

- **Views (re-marcar, htmx preservado):** `_center.erb` (+`heal-list`/`heal-item`), `_mart.erb` (+`mart`/`mart-name`/`item-icon`/`price`/`tabs`), `team_manage.erb` (+`stat-grid`/`mv-row`/`evo-row`/`equip-row`), `_evolution_modal.erb` (padrão `.modal`, mantém `id`/close/3 estados), `pokemon_list_item.erb` (+`pcard-meta`/`name`), `pokemon_detail.erb` (+`tag-row`/`stat-grid`/`evo-row`).
- **`public/style.css` (só dentro do bloco ODS, ANTES da linha `fim`, com delimitador próprio `0077`):** classes do `home-team.html` aplicáveis ao escopo acima, aditivas.
- **Backend thin listado (sem migração/schema/gems/services):** ajustes só em `render_team_center`/`render_team_mart`/`render_team_manage`/`render_evolution_modal`/`render_pokemon_detail` para expor o dado que o markup novo exige (ex.: tipos já enriquecidos na 0076, custo/qtd já em `center_data`/`mart_data`); **nada além do listado**.

### Testes

- **Novo:** `test/home_residue_test.rb` (C1–C3: `test_center_mart_inner`, `test_manage_evolution`, `test_catalog_detail`).
- **Estender (cirúrgico):** `test/design_system_test.rb` (classes 0077 no bloco), `test/home_view_test.rb` (miolo modais + manage), `test/modal_routes_test.rb` (miolo center/mart), `test/evolution_routes_test.rb` (só se o restyle quebrar — meta: verde sem edição).

### Fora de escopo (não abrir — RNF-04)

- Battle (`battle.html`/end-states/results-desktop = 0078); history (`history.html` = 0079); identidade `?as=`, CSRF, escritas atômicas → 0080/0081; erro-status, respiro → 0082; CD; cor-de-tipo nos moves (draft pós-onda).

## 4. Critérios de aceite

### Resultado (S1 — cada critério aponta o teste que o prova)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| C1 miolo dos modais: `_center` com `heal-list`/`heal-item` (cura por membro + custo) e `_mart` com `mart`/`mart-name`/`item-icon`/`price`/`tabs` (buy+sell), overlay/rotas 0076 intactos | `test/home_residue_test.rb` `test_center_mart_inner` (novo) + `test/modal_routes_test.rb` verde | pendente |
| C2 manage + evolução: `team_manage.erb` com `stat-grid`/`mv-row`/`evo-row`/`equip-row` (golpes/itens/evoluir por membro) e `_evolution_modal` no padrão `.modal` (mantém `id` + close + 3 estados) | `test/home_residue_test.rb` `test_manage_evolution` (novo) + `test/evolution_routes_test.rb:91-135` verdes | pendente |
| C3 catálogo + detalhe: `pokemon_list_item.erb` com `pcard-meta`/`name` e `pokemon_detail.erb` com `tag-row`/`stat-grid`/`evo-row`, htmx (`hx-get`/`hx-swap`) preservado | `test/home_residue_test.rb` `test_catalog_detail` + `test_catalog_cards` (novos; o segundo cobre a metade list-item, `:103-125`) + `test/home_view_test.rb` estendido | pendente |
| C4 CSS 0077 no bloco: classes do `home-team.html` aplicáveis ao escopo, aditivas, ANTES da linha `fim`, com delimitador próprio `0077` | `test/design_system_test.rb` `test_design_system_home_residue_classes` (estendido) | pendente |

> **Correção de proveniência (2026-09-16 — registrada na rodada 1 de correção da revisão S7; NÃO é mudança de escopo):** o bloco CSS `Home 1:1 (0077)` **não** foi commitado por nenhum dos 5 commits da 0077 (`ea7192a`/`a00db99`/`2671204`/`d0832bf`/`d922add`) — ele entrou no git em `4f1538c` (2026-09-11), cuja mensagem é da **sessão 0086**. Consequência: o C4 e o verde do Passo 1 existiram apenas na **árvore de trabalho suja** (`public/style.css` não commitado), então **os SHAs da 0077 são RED numa cópia limpa** (`git show ea7192a:public/style.css | grep -c heal-list` = 0, idem `d922add`) e a série **não é bisect-clean**. No HEAD o C4 é provado por `test/design_system_test.rb::test_design_system_home_residue_classes` (bloco em `public/style.css:1816+`). Idem **G1**: o 1068/5033 do Passo 1 saiu da mesma árvore suja — sem regressão fecha-se pela suíte do **HEAD**, não pelos SHAs da 0077. **O usuário deve estar ciente disso no M1.**

### Garantias

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| G1 sem regressão — suíte completa (baseline **1057/4900** + novos) + lint 0; `style.css` DIRTY conferido/stash antes de editar (não commitar alheio) | `./scripts/test` + `./scripts/lint` + `git status -- public/style.css` | pendente |
| G2 backend só no listado (§3) — sem migração/schema/gems/services; testes sem rede | `git diff --stat -- db/ Gemfile*` vazio + revisão S7 confere | pendente |
| G3 S4/S5 + revisão — `SESSIONS.md` + `check_docs` + `checar-sessao 0077` verdes; revisor S7 `Aprovado` antes da 3 | `./scripts/check_docs` + `./scripts/checar-sessao 0077` + veredito do Revisor | pendente |

### Manual

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| M1 passada visual da home no navegador (modais center/mart, manage, catálogo, detalhe, ≤920px sem overflow-x) | `manual` (`./scripts/run`, `/`) | pendente |

> **S1:** cada critério acima aponta o teste que o prova (arquivo + método); o único critério puramente manual é **M1**. **Ao fim da fase 2 (suíte + lint verdes, revisor S7 `Aprovado`), PARAR e aguardar a validação do usuário — não marcar Done, não preencher a seção 7, não commitar conclusão.**

## 5. Decisões de refinamento (fechadas com o usuário em 2026-09-09 — prevalecem sobre o mapa)

- **Fatiamento por tela (escolhida):** 3 sessões — 0077 home (`home-team.html`), 0078 battle (`battle.html` + end-states + results-desktop), 0079 history (`history.html`).
- **Deslizamento (escolhida):** resíduo vira 0077-0079; antigas 0077 escritas atômicas→**0080**, 0078 CSRF→**0081**, 0079 respiro→**0082**.
- **Fidelidade híbrida (escolhida):** adaptação preservando htmx nas telas com legado (0073/0076), cópia mais literal onde não há legado.
- **Backend thin listado sem migração (escolhida):** só os 5 renders do §3; sem schema/gems/services.
- **S1 (escolhida):** 1 arquivo Minitest novo por tela (`home_residue_test.rb` nesta) + extensões cirúrgicas.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Termina em Revisor (2c, S7, teto 3 rodadas) → **PARAR** p/ validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (linha 0077 + "Próxima sessão") | commit `Sessao 0077: refinamento concluido — ...` (**sem** `public/style.css`, que está dirty) |
| 1 | **red→green — C4-css (bloco 0077)** — conferir/stash o dirty do `style.css`, anexar classes ANTES da linha `fim` com delimitador `0077`, estender `design_system_test.rb` | `./scripts/test test/design_system_test.rb` + suíte + lint 0; commit `Passo 1: classes home-team no bloco ODS (delimitador 0077), aditivo` |
| 2 | **red→green — C1 (miolo center/mart)** — re-marcar `_center`/`_mart` + backend thin nos 2 renders; criar `test/home_residue_test.rb` (`test_center_mart_inner`) | `./scripts/test test/home_residue_test.rb test/modal_routes_test.rb` + suíte + lint 0; commit `Passo 2: miolo center/mart no ODS (heal-list/mart/tabs)` |
| 3 | **red→green — C2 (manage + evolução)** — re-marcar `team_manage`/`_evolution_modal` + thin nos renders; `test_manage_evolution` | `./scripts/test test/home_residue_test.rb test/evolution_routes_test.rb` + suíte + lint 0; commit `Passo 3: manage/evolucao no ODS (stat-grid/mv-row/evo-row/equip-row)` |
| 4 | **red→green — C3 (catálogo + detalhe)** — re-marcar `pokemon_list_item`/`pokemon_detail`; `test_catalog_detail` + estender `home_view_test.rb` | `./scripts/test test/home_residue_test.rb test/home_view_test.rb` + suíte + lint 0; commit `Passo 4: catalogo/detalhe no ODS (pcard-meta/tag-row/stat-grid)` |
| 5 | **red→green — G1/G3 (regressão + docs)** — suíte + lint 0 + `check_docs` + `checar-sessao 0077` | `./scripts/test` + `./scripts/lint` + `./scripts/check_docs` + `./scripts/checar-sessao 0077`; commit `Passo 5: regressao e docs — residuo home fechado` |
| — | **Fase 2 concluída** → **Revisor (2c)** até `Aprovado` (teto 3, senão S3) → **PARAR**, aguardar **validação 3**. Não marcar Done, não preencher §7, não commitar conclusão. | — |

## 7. Validação (executada pelo usuário — S2)

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 (miolo center/mart) | `test/home_residue_test.rb` `test_center_mart_inner` + `test/modal_routes_test.rb` (verdes) | `http://localhost:3000/team/center` e `/team/mart` — miolo interno (`heal-list`/`heal-item`; `mart-name`/`item-icon`) e overlays, **sem** a duplicação antiga (dois blocos com mesmo título/ids `mart-tab-buy/sell`) | ok (2026-09-16) |
| C2 (manage + evolução) | `test/home_residue_test.rb` `test_manage_evolution` + `test/evolution_routes_test.rb` (verdes) | `/team/manage` (`stat-grid`/`mv-row`/`equip-row`) e `/team/<id>/evolution` (`evo-row`) | ok (2026-09-16) |
| C3 (catálogo + detalhe) | `test/home_residue_test.rb` `test_catalog_detail` + `test_catalog_cards` + `test/home_view_test.rb` (verdes) | catálogo com `pcard-meta`/`tag-row` e detalhe do Pokémon | ok (2026-09-16) |
| C4 (CSS 0077 no bloco) | `test/design_system_test.rb` `test_design_system_home_residue_classes` (bloco em `public/style.css:1816+`) | efeito visual indireto na home/modais. **Ressalva de proveniência:** o bloco CSS `Home 1:1 (0077)` entrou no git por `4f1538c` (2026-09-11, mensagem da sessão 0086) — nenhum SHA da 0077 é bisect-clean; correção registrada em §4, **não** é mudança de escopo | ok (2026-09-16) |
| G1 (sem regressão) | `./scripts/test` = **1180 runs / 6217 asserts / 0 falhas**; `./scripts/lint` = **136 arquivos / 0 offenses** (números do implementador/review, não reproduzidos nesta fase documental) | — | ok (2026-09-16) |
| G2 (backend listado) | backend só no listado declarado em §3 (sem migração/schema/gems/services); `2671204` (Passo 3) tocou `server.rb` (+12) dentro do `expose_manage_data` declarado — **legítimo**; a versão forte "nenhum commit toca `server.rb`" **não** é o que a sessão garante | — | ok (2026-09-16) |
| G3 (docs + revisão) | `./scripts/check_docs` + `./scripts/checar-sessao 0077` verdes; Revisor S7 `Aprovado` na rodada 2 (`reviews/review-2026-09-16T21-42-00-0077-rodada2.md`; rodada 1 = `reviews/review-2026-09-16T21-40-00-0077.md`) | — | ok (2026-09-16) |
| M1 (passada visual home) | — | validação do usuário em 2026-09-16 (navegador, `/team` + center/mart/manage/evolution, catálogo/detalhe, janela ≤920px sem overflow-x) | ok (2026-09-16) |

> **Ressalvas aceitas na validação (2026-09-16):** (a) `.tag-row` do bloco `0077` está **acoplada ao roster** — estiliza também `views/team.erb:38` (fora do escopo); (b) `@member_levels` (`server.rb:52-67`) faz um `progression.get` por membro em todo render de center/mart/manage e `rescue → 1` degrada falha como "Nível 1"; ambos **anotados no draft, não corrigidos**; (c) a duplicação Center/Mart histórica (introduzida em `d922add`, removida por `41adcaf`) **não** se verificava no HEAD — C1 ok no estado atual.

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.

## 8. Observações

- **`public/style.css` DIRTY (~1129+/1003-):** conferir/stash antes de editar; nunca commitar junto sem revisar (Passo 1).
- **Rotas Sinatra não aparecem no trace do grafo** (0 callers é gap do índice, não ausência de uso) — validar rotas por teste/grep.
- **Fidelidade híbrida:** onde houver legado 0073/0076, adaptar preservando htmx/ids; onde não houver, copiar o protótipo mais literalmente.
- **Fila:** 0077 home → **0078 battle** → 0079 history → 0080 escritas atômicas → 0081 CSRF → 0082 respiro.

## 9. Gotchas / Lições (memória — S6, preencher na 3)

### Fase 2 (implementação — 2026-09-09)

- **Suíte total só em one-off sem Puma:** `exec` no container `web` com o app rodando
  → OOM (137) e flakes; CI sobe só o `db`. Com `web` parado o script usa one-off
  (`docker compose run --rm`) e a total passa (1075/5204 verde).
- **Paralelismo 0078/0079 polui o banco de teste:** 2+ runners simultâneos no mesmo
  `pokedex_test` geram `TeamFullError`/`DuplicateError`, saldos dobrados e até
  `PG::TRDeadlockDetected`. Mitigações usadas: nunca `| head` em run de teste
  (orfana o rake e polui a próxima janela), sondar `ps` antes de rodar, testes novos
  com usuário próprio (`user-home-77`), verificação arquivo-a-arquivo, total só em
  janela quieta (2 totais: 1 falha ordem-dependente, depois 0).
- **`team.erb` embute `_center`/`_mart` inline:** as parciais carregavam os `h2`
  ("Poke Center"/"Poke Mart") que o `GET /team` exige; ao tirar os `h2` das parciais
  (p/ não duplicar nos modais) foi preciso pôr os títulos no `team.erb`.
- **Texto contíguo vira estrutura:** `HP 100/200` e `nome — Nível X` quebram ao separar
  label/valor em spans — 3 asserts do `team_routes_test` viraram estrutura nova;
  nos golpes manteve-se o rótulo plano (menos churn que reescrever asserts).
- **`form=` externo não é serializado pelo htmx:** select de item/segurável precisa
  ficar DENTRO do form (classe `equip-row` foi para o form).
- **`style.css` não commitado pelos commits da 0077:** o bloco `Home 1:1 (0077)` só
  entrou no git em `4f1538c` (2026-09-11), junto de um commit cuja mensagem é da
  **sessão 0086** (sweep de CSS sujo) — não é commit da 0077. Os 5 commits da 0077
  cobrem só views/testes/`server.rb`.
- **Estado real da sessão:** fase 2 concluída em 2026-09-09 (4 runs / 110 assertions
  verdes em `test/home_residue_test.rb`), mas a sessão **não passou por Revisor (S7)
  nem por validação do usuário** (não existe artefato em `reviews/`; §7 segue com as
  evidências em branco). Aguarda ambos.
- **Baseline medido (one-off, sem Puma):** 1068/5033 + 1 falha (`battle_end_states`,
  escopo 0078 em progresso paralelo); fim da fase 2: **1075/5204, 0 falhas**.
  (+7 runs: C4, C1, C2, catalog_cards, catalog_detail + 2 home_view).

### Correção pós-revisão S7 (rodada 1 — 2026-09-16; documental, sem escopo novo)

- **Proveniência do C4 (blocker do review):** o bloco CSS `Home 1:1 (0077)` foi carregado
  por `4f1538c` (2026-09-11, mensagem da sessão **0086**), não pelos 5 commits da 0077;
  `grep -c heal-list` = 0 em `ea7192a` e `d922add` → **todos os SHAs da 0077 são RED numa
  cópia limpa** (série não bisect-clean) e o verde do Passo 1/G1 veio de árvore suja. No
  HEAD o C4 é provado por `test/design_system_test.rb::test_design_system_home_residue_classes`.
  Detalhe no §4 (bloco "Correção de proveniência"). **Não mudou escopo.**
- **Duplicação removida (altas — históricas, HEAD limpo):** no estado de `d922add`,
  `views/team.erb:23-27` renderizava `_center`/`_mart` inline **e** os overlays 0076
  renderizavam os mesmos fragmentos (`_center_modal.erb:4,11`, `_mart_modal.erb:4,8`) →
  fragmento 2x, ids duplicados (`mart-tab-buy/sell`) e grupo `name="mart-tab"` compartilhado
  (clicar numa aba desmarcava a outra). A duplicação foi **removida por `41adcaf`**
  (2026-09-10) — no HEAD está correto; o C1 ("overlay/rotas 0076 intactos") **não** se
  verificava naquele estado. `views/team.erb` foi tocado fora do escopo declarado em
  `a00db99`, origem da duplicação.
- **Regra CSS órfã removida (media 1):** `.mart .muted-row` no bloco `0077` não tinha
  consumidor (o `<li>` de estoque vazio do protótipo não foi portado, e portá-lo seria
  escopo novo) → removida, aditiva e dentro do bloco. Nenhuma view usa `muted-row` e
  `test/design_system_test.rb` não a assertava.
- **`.tag-row` acoplada ao roster (media 2 — não movida):** a classe do bloco `0077` estiliza
  também `views/team.erb:38` (roster, fora do escopo). Não se moveu CSS entre blocos (risco
  alto, sem ganho); ambiguidade anotada em `docs/draft-backlog.md`.
- **`@member_levels` (media 3 — origem na própria 0077, não consertada):** introduzido no
  `expose_manage_data` por `2671204` (**Passo 3 da 0077**); `a37fee0` (sessão posterior,
  2026-09-10) **adicionou** a mesma linha em `prepare_team_fragment_data`. Faz um `progression.get` por
  membro em todo render de center/mart/manage e `rescue → 1` degrada falha como "Nível 1".
  Mantido (mudança de comportamento fora do escopo desta rodada; `server.rb` **não foi
  alterado nesta rodada de correção** — o toque da 0077 está no `expose_manage_data`,
  dentro do "thin listado" de §3) e anotado em `docs/draft-backlog.md`.
- **`filter-grid` em `4f1538c` (info — benigno):** as 4 linhas deletadas alheias eram a
  versão antiga de `.filter-grid` (`repeat(auto-fit, minmax(140px,1fr))` + `gap: .75em`),
  **substituídas na mesma edição** por `1fr 1fr` + `gap: 8px` + `margin-top: 10px`
  (`public/style.css:432-436`, exigido por `test/style_responsive_test.rb:87`) — não houve
  remoção de regra viva; nenhuma ação.
- **Higiene de teste (baixas, corrigidas com TDD leve):** o assert de `price` em
  `test/home_residue_test.rb` passou a ancorar o markup novo (`/class="num price">¥\d/`,
  falha se regredir ao legado sem cifrão); os `refute_includes "onclick"` foram movidos para
  **logo após** `assert last_response.ok?` (antes das contagens), deixando de ser guarda
  morta após asserts que abortam o método; o §4/C3 passou a citar `test_catalog_cards`.
- **`¥` do assert de price (info, rodada 2):** o `¥` de `test/home_residue_test.rb:48` veio da
  copy de `5795866` (Passo 18, 2026-09-11, **posterior à 0077**) → é guard de regressão da
  copy atual, **não** prova do port da 0077; reverter a copy do `¥` quebraria o teste com o
  port intacto. A alternativa `class="num price">` (sem o `¥`) é a versão vacuosa vetada na rodada 1 — não usar.
