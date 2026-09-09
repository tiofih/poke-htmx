# Sessão 0076 — open-design-modals-filters (modais overlay híbrido + filtros `team=in|out` + curadoria — última da onda)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-09-09 (B, B, C, B, C, A, B, B — ver seção 5) |
| Implementação fase 2a (0076a — visível/funcional, legado intacto) | **Concluída** — 9 commits (`9867114`…`540d110`), suíte 1054/4847 0 falhas, lint 0, revisor 2c-2a **Aprovado** sem S3 |
| Validação fase 3a (0076a) | **Concluída** — validada pelo usuário em 2026-09-09 (**Done 3a**; S2 C1–C10+G1–G3 ok + M1 ok, sem S3) |
| Implementação fase 2b (0076b — limpeza/fechamento da onda) | **Implementação concluída** — 3 commits (`43404b3`…`4049381`), suíte 1057/4900 0 falhas, lint 0, `check_docs` + `checar-sessao 0076` verdes; aguarda **Revisor (2c-2b)** e depois **validação 3b** — **PARAR**, não marcar Done, não preencher §7 3b |
| Validação fase 3b (0076b) | **Pendente** — executada pelo usuário (S2, tabela da seção 7); fecha a onda |

---

## 1. Objetivo

Portar os **modais** (center/mart/membro + evolução) para **overlay híbrido** (`:target` p/ abrir + htmx p/ conteúdo, sem JS), **ligar os filtros `team=in|out`** vestidos no ODS e fechar o **contrato `data-od-id` nas 4 superfícies** + a **curadoria visual** (base fiel, tags cor por tipo com dado real, conteúdo battle/home/history) — tudo **visível/funcional com o legado intacto** (fase 2a); depois **remover sakura + CSS legado sob demanda** com os critérios de risco como rede (fase 2b), **fechando a onda open-design** (base → home → battle → history → modals-filters).

## 2. Contexto (estado atual — diagnóstico)

- **0072/0073/0074/0075 entregues** (todas validadas 2026-09-09, baseline **1025/4402**, lint 0): bloco ODS `/* === Open Design System (0072): inicio / fim === */` em `public/style.css:6–1146`; legado em `~1147–1910` (`.bar` legado `:1378`, `.add-toast` `:1586` + keyframes `:1604/:1615`, `juice-projectile` `:1573`). **Sakura ainda linkado** em `views/layout.erb:7` (fallback até esta sessão).
- **Modais hoje:** `_center.erb` (11 linhas) + `_mart.erb` (27) renderizados **inline** no `team.erb` (pós-jornada); `index.erb` tem placeholder nos Serviços ("voltam na 0076, junto com as rotas de modal `GET /team/center` e `GET /team/mart`"); `_evolution_modal.erb` (overlay real appended via `hx-target="body"`, `id="evolution-modal"`, close em `/team/:id/evolution/close`, 3 estados); `team_manage.erb` (89 linhas) com swap in-place em `#team-view` (`TeamRoutes.register_team_manage`, `server.rb:1009-1011`; `register_team`, `server.rb:1001-1003`; `htmx_request?`, `server.rb:912`). Protótipo `open-design/home-team.html:152-160` (`.overlay`/`.overlay.open`/`.modal/...`) + `:298-330` (3 overlays com `data-od-id="modal-center/modal-mart/modal-manage"`, abrir/fechar via `onclick` JS — o app **não usa JS**: abrir vira `:target`, conteúdo via htmx); guia `migration-guide.md:88` (envolver parciais em `.overlay`/`.modal` + rotas de fragmento) e `:166-167` (botões Serviços `hx-get /team/center|/team/mart` → `#center-modal|#mart-modal`).
- **Filtros hoje:** `_filter_controls.erb` (52 linhas, 6 controles `.filter-state`, **sem** select de disponibilidade, **sem** wrapper `.filter-grid`, "Limpar filtros" sem `team=`); `GET /pokemons` (`register_pokemons`, `server.rb:970-971` → `render_pokemons_list` + `oob_filter_controls`); `load_pokemon_page` (`server.rb:106-...`: `normalized_*`, `filter_active?` `:185`, `any_filter_param_present?` `:197`, `persist/restore` `:202/:219`, `build_page` `:239`, `filtered_base_forms` — o filtro `team` entra aqui via `@team_names`); **gotcha:** `load_team_names` (`server.rb:392`) roda **depois** do `build_page` — o filtro precisa dos names **antes** (reordenar no passo). `pokemon_list.erb` tem `.list-state` + paginação (propagar `team=` nos links) e `filter_controls_needs_sync?` já sincroniza o select via OOB.
- **`data-od-id` hoje:** só history (`history.erb:11/33/50`) + battle (`battle.erb:24/40/121` — `side-team`/`controls`/`side-opponent`). Faltam: shell+nav (layout), home/team (`team-pane`/`catalog`/`services`/membros), modais.
- **Tipos (base do 5d=A):** `Pokemon` já tem `types` (`lib/pokemon.rb:16`, parse em `lib/gateways/poke_api_parsing.rb:148`); `TeamRepository#all` (`lib/team_repository.rb:162`) **não retorna tipos** (sem coluna no schema `team_pokemons`) → enriquecer na rota via `settings.api.find` (rede em produção, `PokeApiStub` em teste), fail-closed `[]`. `FighterPresenter#moves` (`lib/fighter_presenter.rb:41-42`) não expõe tipo do golpe → **cor-de-tipo nos moves fica fora** (draft pós-onda, ver seção 3).
- **Gates `@message`:** `battle.erb:1-12` (`.notice`/`.gameloop-cta` + `@gate_cta/@gate_action/@gate_disabled_cta`) + `team.erb` (game-over/restart com `gameloop-cta`); âncoras `test/battle_routes_test.rb:848/861`, `test/team_routes_test.rb:715-751`, `test/evolution_routes_test.rb:91-135`.
- **Riscos da auditoria (curadoria 0076 em `docs/draft-backlog.md:183-205`):** D71 colisões `.bar`/nav/log (+D72–D76), D86 keyframes projectile fora do bloco (quebra se remover o legado), D88 toast fora do bloco, D94 filtros vs CSS (`.filter-grid` com regras no bloco `:340-351` mas **sem uso nas views**; `.filter-state` **sem CSS**), D80 inline `style="margin-bottom: 40px"` (`history.erb:33`).
- **Fila (SESSIONS.md/REQUIREMENTS.md):** 0075 Done → **0076 open-design-modals-filters** → 0077 escritas atômicas → 0078 CSRF → 0079 respiro.

## 3. Escopo

### Produção — fase 2a (0076a: visível/funcional, legado intacto; **sem remover** sakura/legado)

- **`public/style.css` (só dentro do bloco ODS):** overlay híbrido (`.overlay`/`.overlay:target`/`.modal`/`.modal-head`/`.modal-close`/`.modal-sub`/`.modal-foot`), regras `.filter-state` + uso de `.filter-grid`, tags por tipo (`.ptag/.mtag/.ftag--<tipo>` com cores), curadoria base fiel (topnav sticky/blur, botões base/secondary/hover/sm/lg/disabled, card, mono eyebrow/meta, lead, espaçamentos section/row/grid-2-1/arena/container, meter/pill/roster, tokens `--fs-*/--gap-*`; ausentes aplicáveis: sprite-tile base, pcard-meta/add, end-states, battle responsivo ≤700px) + rede D86/D88 (`@keyframes juice-projectile`, `.add-toast` + keyframes — duplicação temporária intencional).
- **Rotas fragmento (novas, thin):** `GET /team/center` + `GET /team/mart` (reusam `center_data`/`mart_data`, devolvem `.overlay:target > .modal[role=dialog]` envolvendo `_center`/`_mart` intactos).
- **Views:** botões Serviços no `index.erb` (`hx-get` → `#center-modal`/`#mart-modal`); `_evolution_modal` re-marcado no padrão overlay (mantém `id`/close/3 estados); `GET /team/manage` devolve o manage **envolvido em overlay de membro** (mesma rota, swap `body`/`beforeend` + abertura `:target`; `POST /team/:id/*` intactos); gates `battle.erb:1-12` + `team.erb` re-marcados (`.notice` + `.btn`, `gameloop-cta` → `.btn`, disabled com `title`); `data-od-id` nas 4 superfícies (§4 C4); tags (pcard via `api.find`, membro via enrichment, fighter via presenter); `_filter_controls` + select Disponibilidade (`team=in|out`) + wrapper `.filter-grid` + "Limpar filtros" com `team=`.
- **Backend mínimo e listado (quebra o invariante 0072–0075 — só esta sessão toca):** 2 rotas fragmento acima; `prepare_team_fragment_data` + `team_manage_context`/`expose_manage_data` enriquecem `types` (memo por nome via `settings.api.find`, fail-closed `[]`); `FighterPresenter#types` (só presenter); `load_pokemon_page` + `normalized_team` + `filter_active?`/`any_filter_param_present?`/`persist/restore` + names antes do `build_page`; `pokemon_list.erb` (list-state + paginação + clear com `team=`). **Sem** migração/schema/gems/services.

### Produção — fase 2b (0076b: limpeza/fechamento; **sem markup novo**)

- Remover `<link sakura>` (`layout.erb:7`); remover/escopar **sob demanda** as regras legadas que colidem com o ODS (D71–D76: `.bar` legado `:1378` e congêneres — remover, rodar suíte, **re-adicionar/corrigir o que quebrar**, com C12–C14 como rede); remover inline D80 (`history.erb:33` → classe); juice passa a partir **só do bloco** (D86/D88 fechamento); filtros 100% ODS (D94 fechamento).

### Testes

- **Novos:** `test/modal_routes_test.rb` (C1–C2), `test/open_design_contract_test.rb` (C4–C5/C14).
- **Estender:** `test/design_system_test.rb` (C2/C7/C8/C10/C11–C13), `test/home_view_test.rb` (C7/C9), `test/battle_view_test.rb` + `test/history_view_test.rb` (C9), `test/pokemon_list_filters_test.rb` (C6).
- **Editar (reconciliação listada no passo):** `test/battle_routes_test.rb` (`:848/:861` gates → `.btn`), `test/evolution_routes_test.rb` só se o restyle quebrar `:91-135` (meta: verde sem edição), `test/style_responsive_test.rb` + `test/layout_test.rb` só onde a remoção 2b atingir o alvo (lista explícita no passo; fora disso, verdes por construção).

### Fora de escopo (não abrir — RNF-04)

- Cor-de-tipo nos **moves** (exige mapeamento golpe→tipo = enriquecimento por golpe, fora do mínimo) → draft pós-onda.
- Rota por membro `GET /team/:id/manage` (manage em overlay usa a rota existente) → draft.
- `team=in|out` fora do catálogo (`/pokemons` apenas); identidade `?as=` (`server.rb:1216`), CSRF, escritas atômicas → 0077/0078; erro-status, respiro → 0079; CD (D7).

## 4. Critérios de aceite

### Resultado fase 2a — 0076a (S1 — cada critério aponta o teste que o prova)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| C1 `GET /team/center` + `GET /team/mart` devolvem `.overlay:target > .modal[role=dialog]` com o conteúdo atual (`_center` heal / `_mart` buy+sell) e os botões Serviços abrem via `hx-get` → `#center-modal`/`#mart-modal` | `test/modal_routes_test.rb` `test_center_fragment_renders_overlay_modal_with_heal_form` + `test_mart_fragment_renders_overlay_modal_with_buy_form` (novos) + `test/team_routes_test.rb:715-751` verdes (gates jornada intactos) | ok |
| C2 overlay híbrido: CSS `:target` no bloco (sem JS); `_evolution_modal` no mesmo padrão (mantém `id` + `role=dialog` + close + 3 estados + re-render no evolve); `GET /team/manage` em overlay de membro (mesma rota, todos os `POST /team/:id/*` intactos) | `test/modal_routes_test.rb` `test_overlay_opens_via_target_without_js` + `test_manage_renders_member_overlay` (novos) + `test/design_system_test.rb` `test_design_system_modal_screen_classes` (estendido) + `test/evolution_routes_test.rb:91-135` verdes | ok |
| C3 gates `@message` re-marcados (`.notice` + `.btn`/`.btn-secondary`, `gameloop-cta` → `.btn`, disabled com `title`) em `battle.erb:1-12` e `team.erb` (game-over/restart) | `test/battle_routes_test.rb:848/861` editados p/ `.btn[disabled]` + asserts game-over do time (editados, lista no passo) | ok |
| C4 contrato `data-od-id` nas 4 superfícies: shell+nav (topnav/nav/footer), home/team (`team-pane`/catalog/services/membros), battle (`side-team`/`side-opponent`/`controls` — ancorar), modais (`modal-center`/`modal-mart`/`modal-manage` + closes + ctas); history ancorado sem edição | `test/open_design_contract_test.rb` (novo, 1 método por superfície) | ok |
| C5 tags cor por tipo com dado real: `.ptags` no `pcard` (tipos do `api.find`), `.mtags` no roster/membro (enrichment §3), `.ftags` com tipos via `FighterPresenter#types`; cores `.ptag/.mtag/.ftag--<tipo>` no bloco | `test/open_design_contract_test.rb` `test_type_tags_use_real_data` (novo, com `PokeApiStub.with_find` retornando `types`) | ok |
| C6 `team=in|out` funcional: select Disponibilidade, `normalized_team` (fail-closed nil), `filter_active?`/sessão incluem `team`, filtragem por `@team_names` (names antes do `build_page`), starters ocultos com filtro ativo, `list-state` + paginação + "Limpar filtros" propagam `team=`, OOB preservado | `test/pokemon_list_filters_test.rb` `test_team_in_shows_only_members` + `test_team_out_excludes_members` + `test_team_invalid_falls_back_to_all` + `test_team_filter_persists_in_session` (estendido) | ok |
| C7 filtros vestidos no ODS (D94): `.filter-grid` no card + regras `.filter-state` no bloco + "Limpar filtros" `.btn.btn-ghost.btn-sm` com `team=` zerado + linha Arquivo/clear do guia `:178` | `test/home_view_test.rb` `test_filter_controls_wear_design_system` (novo) + `test/design_system_test.rb` (classes `.filter-grid`/`.filter-state` no bloco) | ok |
| C8 curadoria base fiel aditiva: topnav sticky/blur, botões, card, tipografia mono/lead, espaçamentos por tela, meter/pill/roster, tokens `--fs-*/--gap-*`, ausentes aplicáveis (sprite-tile, pcard-meta/add, end-states, battle ≤700px) | `test/design_system_test.rb` (asserts das classes no bloco, estendido) | ok |
| C9 conteúdo fiel por tela: battle (cabeçalho+contadores, CTAs, log, stock-items com regra), home/history (título+lead, meter acessível, catalog count/clear, pcard fiel, footer) | `test/battle_view_test.rb` + `test/home_view_test.rb` + `test/history_view_test.rb` (estendidos, edições mínimas listadas) | ok |
| C10 rede técnica 2a (D86/D88): `@keyframes juice-projectile` + `.add-toast` (+ keyframes) presentes **no bloco** (legado intacto) | `test/design_system_test.rb` `test_design_system_juice_safety_net_in_block` (novo) | ok |

### Garantias fase 2a

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| G1 sem regressão — suíte completa (baseline **1025/4402** + novos) + lint 0; legado íntegro (diff fora do bloco/rotas só aditivo) | `./scripts/test` + `./scripts/lint` + `git diff -- public/style.css` (fora do bloco só adição) | ok |
| G2 backend só no listado (§3) — sem migração/schema/gems/services; testes sem rede | `git diff --stat -- db/ Gemfile* lib/` confinado ao listado + stubs; revisão S7 confere | ok |
| G3 S4/S5 + revisão — `SESSIONS.md` + `check_docs` + `checar-sessao 0076` verdes; revisor S7 `Aprovado` antes da 3a | `./scripts/check_docs` + `./scripts/checar-sessao 0076` + veredito do Revisor | ok |

### Manual fase 2a

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| M1 modais abrir/fechar via `:target` no navegador (center/mart/membro/evolução, sem JS) + reflow ≤920px da home com filtros vestidos | `manual` (`./scripts/run`, `/` + time cheio/vazio, redimensionar ≤920px, sem overflow-x) | ok |

### Resultado fase 2b — 0076b (S1)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| C11 sem sakura: `<link sakura>` removido (`layout.erb:7`), página só com `/style.css`, autonomia do bloco ancorada | `test/design_system_test.rb` (`test_design_system_does_not_depend_on_sakura` estendido + assert sem link sakura no layout) + `test/layout_test.rb` (sem edição — não ancorava sakura) | ok |
| C12 colisões sob demanda (D71–D76 + D80): legadas colidentes removidas/escopadas (lista explícita no passo), inline `history.erb:33` → classe; o que quebrar é re-adicionado/corrigido | `test/design_system_test.rb` `test_legacy_collisions_removed` (novo: refute das 12 regras listadas fora do bloco) + `test/history_view_test.rb` `test_history_ranking_section_wears_spacing_class` (novo, D80) + reconciliação listada em `style_responsive_test.rb` (6 métodos re-apontados) + suíte verde | ok |
| C13 juice do bloco (D86/D88 fechamento): projectile/toast/animations partem só do bloco após a remoção | `test/design_system_test.rb` `test_block_carries_all_juice_keyframes` (novo) + juice asserts (C10, sem edição — provam a portabilidade) + suíte verde | ok |
| C14 filtros 100% ODS (D94 fechamento): contrato + dress verdes após a limpeza | `test/open_design_contract_test.rb` + `test/home_view_test.rb` + `test/style_responsive_test.rb` verdes (re-apontados no Passo 12, sem edição no 13) | ok |

### Garantias + manual fase 2b

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| G4 sem regressão final — suíte + lint 0; onda fecha (bloco único, legado removido) | `./scripts/test` (1057/4900 0 falhas) + `./scripts/lint` (0 nos rastreados) | ok |
| G5 docs fechamento — `SESSIONS.md` 0076 Done após a 3b + `check_docs`/`checar-sessao` verdes; handoff + gotchas (S6) | `./scripts/check_docs` + `./scripts/checar-sessao 0076` verdes na 2b; Done + handoff + gotchas de memória só após a 3b | pendente (aguarda 3b) |
| M2 passada visual completa pós-limpeza (modais, filtros, battle, history, ≤920px, sem flash sem-estilo) | `manual` (`./scripts/run`, todas as telas) | pendente |

> **S1:** cada critério acima aponta o teste que o prova (arquivo + método); os únicos critérios puramente manuais são **M1** (fase 2a) e **M2** (fase 2b). **Cada fase PARA ao fim da sua implementação (suíte + lint verdes, revisor S7 `Aprovado`) e aguarda a validação do usuário — não marcar Done, não preencher a seção 7, não commitar conclusão.**

## 5. Decisões de refinamento (fechadas com o usuário em 2026-09-09 — prevalecem sobre o mapa)

- **1B — fatiamento (escolhida):** 0076a (visível/funcional, legado intacto) + 0076b (limpeza/fechamento da onda). **Layout:** UM arquivo `sessions/0076-open-design-modals-filters.md` com fases 2a/2b (TDD+revisão+validação próprios) — sufixo de letra (`0076a-*.md`) testado e **rejeitado**: o glob do `check_docs` (`[0-9]{4}-*.md`) não casa 5º char letra, então esses arquivos seriam invisíveis à S5 (sem linha exigida, sem contar no `max`) — S5 verde de mentira.
- **2B — objetivo/escopo/critérios/tamanho (escolhida):** modelo B do mapa (escopo cheio da curadoria em 2 fatias, critérios C1–C10 + C11–C14 acima).
- **5a=C — overlay HÍBRIDO (escolhida, não B):** `:target` p/ abrir + htmx p/ conteúdo, sem JS (o `onclick` do protótipo não entra no app).
- **5b=B — `data-od-id` como contrato (escolhida):** 4 superfícies (shell+nav, home/team, battle, history ancorada) + modais, em `test/open_design_contract_test.rb`.
- **5c=C — limpeza SOB DEMANDA (escolhida, não B):** remover legado e **re-adicionar/corrigir o que quebrar** (não o pré-mover de B); C12–C14 são a rede.
- **5d=A — tags COR POR TIPO com dado real (escolhida):** pcard + membro + fighter; **esta sessão TOCA backend/presenter** (enrichment `types` + `FighterPresenter#types` + rotas fragmento + filtro `team` — listado em §3), **quebrando o invariante 0072–0075**; escopo backend mínimo, sem migração/schema/gems/services.
- **5e=B — filtros (escolhida):** ligar `team=in|out` + vestir `.filter-state`/`.filter-grid` no ODS.
- **Riscos=B (escolhida):** D71/D86/D88/D94 viram critérios com teste (C7/C10/C12–C14).

## 6. Plano TDD (passos por fatia)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Cada fatia termina em Revisor (2c, S7, teto 3 rodadas) → **PARAR** p/ validação do usuário.

### Fase 2a — 0076a (visível/funcional, legado intacto)

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (linha 0076 + "Próxima sessão" → 0077) | commit `Sessao 0076: refinamento concluido — modals-filters em 2 fatias (2a overlay hibrido+team-filter+tags+contrato, 2b limpeza sob demanda), criterios C1-C10/C11-C14 amarrados, prox sessao 0077 escritas atomicas` |
| 1 | **red→green — C2-css + C10 (bloco: overlay + keyframes/toast)** — estender `design_system_test.rb` (modal classes + `juice_safety_net_in_block`) + anexar regras **dentro** do bloco (sem tocar marcadores/legado) | `./scripts/test test/design_system_test.rb` + suíte + lint 0; commit `Passo 1: overlay :target e rede juice (projectile/toast) no bloco ODS, legado intacto` |
| 2 | **red→green — C1 (rotas center/mart)** — criar `test/modal_routes_test.rb` (2 métodos) + `GET /team/center|/team/mart` thin + botões Serviços no `index.erb` | `./scripts/test test/modal_routes_test.rb` + `test/team_routes_test.rb` + suíte + lint 0; commit `Passo 2: fragmentos center/mart em overlay via rotas novas, servicos abrem modal` |
| 3 | **red→green — C2-views (evolution + manage overlay)** — re-marcar `_evolution_modal` + envolver manage em overlay (mesma rota); meta `evolution_routes:91-135` verdes sem edição | `./scripts/test test/modal_routes_test.rb test/evolution_routes_test.rb` + suíte + lint 0; commit `Passo 3: evolucao e gerenciar em overlay hibrido, mesma rota` |
| 4 | **red→green — C3 (gates)** — re-marcar `battle.erb:1-12` + `team.erb` game-over; editar `battle_routes:848/861` + asserts team (lista no diff) | `./scripts/test test/battle_routes_test.rb test/team_routes_test.rb` + suíte + lint 0; commit `Passo 4: gates @message no ODS (notice+btn, sem gameloop-cta)` |
| 5 | **red→green — C4 (contrato)** — `data-od-id` nas 4 superfícies + criar `test/open_design_contract_test.rb` | `./scripts/test test/open_design_contract_test.rb` + suíte + lint 0; commit `Passo 5: contrato data-od-id nas 4 superficies (shell/home/battle/modais)` |
| 6 | **red→green — C5 (tags, backend mínimo)** — enrichment `types` + `FighterPresenter#types` + cores no bloco + `test_type_tags_use_real_data` (stub com `types`) | `./scripts/test test/open_design_contract_test.rb` + suíte + lint 0; commit `Passo 6: tags cor por tipo com dado real (backend minimo listado)` |
| 7 | **red→green — C6 (team filter)** — `normalized_team` + `filter_active?`/sessão + names antes do `build_page` + `list-state`/paginação/clear + estender `pokemon_list_filters_test.rb` | `./scripts/test test/pokemon_list_filters_test.rb` + suíte + lint 0; commit `Passo 7: filtro team=in/out com persistencia e OOB preservados` |
| 8 | **red→green — C7 (dress filtros)** — `.filter-grid` + `.filter-state` + clear `.btn` + linha Arquivo; `home_view` novo método | `./scripts/test test/home_view_test.rb test/design_system_test.rb` + suíte + lint 0; commit `Passo 8: filtros vestidos no ODS (filter-grid/filter-state)` |
| 9 | **red→green — C8 + C9 (curadoria)** — base fiel + conteúdo por tela; estender `design_system` + `battle/home/history_view` (edições mínimas listadas) | `./scripts/test test/design_system_test.rb test/battle_view_test.rb test/home_view_test.rb test/history_view_test.rb` + suíte + lint 0; commit `Passo 9: curadoria visual fiel (base + conteudo battle/home/history)` |
| 10 | **red→green — G1 (regressão 2a + docs)** — suíte + lint 0 (baseline **1025/4402** + novos) + `check_docs` + `checar-sessao 0076` | `./scripts/test` + `./scripts/lint` + `./scripts/check_docs` + `./scripts/checar-sessao 0076`; commit `Passo 10: regressao da fase 2a e docs — modais/filtros/tags/contrato sem quebrar legado` |
| — | **Fase 2a concluída** → **Revisor (2c)** até `Aprovado` (teto 3, senão S3) → **PARAR**, aguardar **validação 3a**. Não marcar Done, não preencher §7, não commitar conclusão. | — |

### Fase 2b — 0076b (limpeza/fechamento; só após a 3a validada; sem markup novo)

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 11 | **red→green — C11 (sem sakura)** — remover `<link sakura>` + estender autonomia + editar `layout_test` só se ancorar (listar) | `./scripts/test test/design_system_test.rb test/layout_test.rb` + suíte + lint 0; commit `Passo 11: sakura removido, bloco ODS autonomo` |
| 12 | **red→green — C12 (colisões sob demanda + D80)** — remover/escopar legadas colidentes (lista explícita) + inline history → classe; re-adicionar/corrigir o que quebrar; novo `test_legacy_collisions_removed` | `./scripts/test test/design_system_test.rb test/style_responsive_test.rb` + suíte + lint 0; commit `Passo 12: colisoes legadas removidas sob demanda (re-adicionado o que quebrou: <lista>)` |
| 13 | **red→green — C13 + C14 (juice do bloco + filtros 100% ODS)** — provar portabilidade (C10 sem edição) + contrato/dress verdes (mínima listada ou sem edição) | `./scripts/test test/design_system_test.rb test/open_design_contract_test.rb test/home_view_test.rb` + suíte + lint 0; commit `Passo 13: juice e filtros partem so do bloco apos limpeza` |
| 14 | **red→green — G4/G5 (regressão final + docs)** — suíte + lint 0 + `check_docs` + `checar-sessao 0076` | `./scripts/test` + `./scripts/lint` + `./scripts/check_docs` + `./scripts/checar-sessao 0076`; commit `Passo 14: regressao final e docs — onda open-design fechada` |
| — | **Fase 2b concluída** → **Revisor (2c)** até `Aprovado` (teto 3, senão S3) → **PARAR**, aguardar **validação 3b**. Só então: §7 preenchida, `SESSIONS.md` 0076 Done, handoff + gotchas (S6). | — |

## 7. Validação (executada pelo usuário — S2, uma tabela por fatia)

**Fase 3a (0076a) — validada pelo usuário em 2026-09-09 (resposta "validado", sem S3).**

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 (center/mart em overlay) | `test/modal_routes_test.rb` (2 métodos) + `team_routes:715-751` | abrir via Serviços | ok |
| C2 (overlay híbrido) | `modal_routes_test` + `design_system_modal_screen_classes` + `evolution:91-135`, POSTs intactos | abrir/fechar sem JS | ok |
| C3 (gates sem gameloop-cta) | `battle_routes:848/861` + asserts game-over | estados de gate | ok |
| C4 (data-od-id contrato) | `test/open_design_contract_test.rb` | — | ok |
| C5 (tags cor por tipo) | `test_type_tags_use_real_data` (stub com types) | cores no roster/battle | ok |
| C6 (team=in/out) | 4 testes (persist + OOB) | filtrar, recarregar, limpar | ok |
| C7 (filtros vestidos) | `home_view` + design_system | visual dos controles | ok |
| C8 (curadoria base) | design_system por tela | visual global | ok |
| C9 (conteúdo) | battle/home/history views estendidas | cabeçalhos, CTAs, log, footer | ok |
| C10 (rede juice) | `test_design_system_juice_safety_net_in_block` | projétil/toast animando | ok |
| G1 (sem regressão) | suíte 1054/4847 + lint 0 | — | ok |
| G2 (backend listado) | diff `db/`+`Gemfile*` vazio, presenter +4 | — | ok |
| G3 (docs + revisão) | check_docs + checar-sessao + Aprovado | — | ok |
| M1 (confete visual) | — | `./scripts/run`, modais sem JS, reflow ≤920px | ok |

**Fase 3b (0076b) — pendente (só após a 3a).** | Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) | C11–C14+G4–G5: (a preencher) | M2: (a preencher) |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.

## 8. Observações

- **`:target` + htmx-append (evolução):** o modal só existe no DOM após o `hx-get`; o trigger usa `href="#evolution-modal"` + `hx-get` (primeiro clique anexa e mira; fechar = link `href="#"` + rota close que remove o nó) — detalhar no green do Passo 3.
- **`load_team_names` depois do `build_page`:** o Passo 7 carrega os names antes de filtrar (reordenar a chamada ou carregar names quando `team` presente) — sem isso `team=in` pagina vazio.
- **`team=in` esconde starters** (`starters_visible?` falso com filtro ativo — senão o membro aparece 2×); `team=out` mantém starters (não estão no time).
- **Nomes de teste sem dígitos** (gotcha 0070): `modal_routes_test.rb`/`open_design_contract_test.rb` seguem o padrão local (`# rubocop:disable Naming/VariableNumber` onde houver `team_in_out`/seletor com número).
- **Delimitadores do bloco ODS são contrato (C4 da 0072):** não renomear os marcadores `inicio|fim`; 2a só anexa dentro; 2b só remove fora.
- **Suíte de referência:** baseline **1025/4402**, lint 0 (0075). Fila: 0076 → **0077 escritas atômicas** → 0078 CSRF → 0079 respiro.

## 9. Gotchas / Lições (memória — S6, preencher na 3b)

- **`check_docs` não enxerga sufixo de letra:** glob `[0-9]{4}-*.md` exige `-` como 5º char — `0076a-*.md` seria invisível à S5 (motivo do arquivo único com fases 2a/2b).
- **`oob_filter_controls` já existe:** o select `team` entra no partial e ganha sincronização OOB de graça — não duplicar.
- **`Pokemon#types` já vem do parse (`poke_api_parsing.rb:148`):** tags do catálogo (`pcard`) não precisam de backend; só o time (DB sem coluna) precisa do enrichment — é por isso que o toque backend é mínimo e listado.
- **Limpeza sob demanda (5c-C) funciona se a lista for explícita (0076 2b):** cada remoção legada foi decidida por uso vivo nas views (`gameloop-cta` em `team.erb:20` e `.evolution-*` no modal ficaram) vs. morto (`.filter-controls`, `.battle-layout`, `.projectile`, `.hp-bar/.pp-bar`, orfãs `.battle-pane .fighter`); nada quebrou — zero re-adicionados, só 1 port (toque 44px da nav → `.topnav nav a`).
- **Keyframes são dependência invisível da suíte:** o bloco referenciava 8 keyframes que só existiam no legado (`juice-hp/flash/damage-number/ko/shake/banner/news`, `battle-log-in`) — nenhum teste acusaria o dangling; o `test_block_carries_all_juice_keyframes` (todo `animation:` do bloco exige `@keyframes` no bloco) virou a rede do port.
- **Regex de teste precisa de âncora de linha em CSS:** `/\.bar-fill\s*\{/` casa `.hp-bar .bar-fill {` — em `test_legacy_collisions_removed` os asserts de classe base usam `/^\.bar\s*\{/` para não vazar para seletores compostos (que saíram no passo seguinte).
- **Reapontar teste responsivo = trocar o seletor, não a intenção:** 6 métodos do `style_responsive_test.rb` migraram de seletor legado para equivalente do bloco (`.filter-grid`/`.arena`/`.bar`/`.btn-sm`/`.topnav nav`/`.shot`); `test_juice_reduced_motion_disables` e `test_juice_keyframes_present` ficaram intactos (reduce legado no fim + keyframes portados mantêm presença/ordem).
- **`scripts/sweep-balance.rb` untracked polui o lint:** 19 offenses fora do repo quebram o "lint 0" do `./scripts/lint`; gate da sessão = 0 offenses nos rastreados (verificado por exclusão).
