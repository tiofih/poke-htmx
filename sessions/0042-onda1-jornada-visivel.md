# Sessão 0042 — Onda 1 UX: jornada visível (Caminho B — Lista+Time unificados)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-24 |
| Implementação | **Concluída** — passos 1–6 em 2026-08-24 (suíte 686/2163, lint 0) |
| Validação | **Done** — executada pelo usuário em 2026-08-24 (tabela da seção 7, ajustes S3 reaprovados) |

---

## 1. Objetivo

Entregar a **Onda 1 de UX** (`draft-ui-ux.md` §5) no **Caminho B — unificar a
Lista com o Time na mesma tela** (decisão do usuário 2026-08-24): `GET /` vira uma
**página única de 2 colunas** — busca + lista de Pokémon à esquerda, **painel do
time** (contador n/6 + membros com reordenar/remover + Center/Mart gated) à
direita. A página `/team` deixa de existir como página própria (nav perde o link
"Time"); `GET /team` permanece apenas como **fragmento htmx interno** (404 em
navegação direta). Estados do botão Add (default / "No time ✓" / cheio) incluídos.
Reusa `JourneyService` e o `@team` já carregado; contrato do gateway intacto.

## 2. Contexto (estado atual — diagnóstico)

- `GET /` (`server.rb:67` `render_index`) renderiza `index.erb` — busca +
  `#pokemon-list` + `#add-status` + `#pokemon-detail`; **não tem nenhum painel de
  time** (o time fica na página `/team`, separada).
- `GET /team` (`server.rb:124` `render_team`) é **página própria** quando a
  requisição não é htmx (`erb :team_page`), ou fragmento quando htmx (`erb :team`,
  layout: false). `team_page.erb` é só um wrapper `<div id="team-view">`.
- Ações do time (add `POST /team`, remove `DELETE /team`, move
  `POST /team/:id/move`, heal `POST /team/heal`, mart `POST /mart/buy`) re-renderizam
  o fragmento `team.erb` com alvo `#team-view` — esse painel hoje só existe na
  página `/team`.
- **Add na lista** (`views/pokemon_list_item.erb:10-13`): `POST /team` com alvo
  `#add-status` (mini-status, desde JN-1/0039); **não atualiza o painel do time**
  — invisível na mesma tela até a unificação.
- `index.erb` (15 linhas) sem grid/largura cheia; a sakura limita `body` a
  `max-width: 38em` (anotação 0041/§8: aplicar largura cheia nas demais telas).
- Botão Add não tem estados: sempre "Adicionar ao time", mesmo para Pokémon já no
  time ou com o time cheio (`pokemon_list_item.erb:12`).
- Nav (`views/layout.erb:14-19`) tem link "Time" (`href="/team"`).
- `pokemon_list.erb`/`pokemon_list_item.erb` não recebem `@team_names`; o
  `load_pokemon_page` (`server.rb:81`) carrega só `@page`/`@items`/`@starters`.
- Testes afetados: `test/team_routes_test.rb` (`test_team_page_renders_full_page...`,
  `test_get_team_returns_own_session_team` via `get "/team"`), `test/pokemon_routes_test.rb`
  (`test_nav_time_link_points_to_team_page`, `test_layout_marks_active_nav_link_on_list_page`),
  `test/mart_routes_test.rb:55` (`get "/team"`). Baseline: suíte 680 runs/2132 asserts,
  lint 0.

## 3. Escopo

### Produção

- `views/index.erb` — página única **2 colunas** (largura cheia): esquerda = busca
  + `#pokemon-list` (+ `#add-status`/`#pokemon-detail`); direita = `#team-view`
  (contador "Time n/6" + `erb :team`). Contador via `@journey_started`/`@team`.
- `server.rb` `render_index` — carrega dados do time (`prepare_team_fragment_data`
  ou equivalente leve) para o `#team-view` da página unificada.
- `server.rb` `render_team` — **página própria removida**: `GET /team` não-htmx →
  404 (`pass 404` ou `halt 404`); htmx → fragmento `team.erb` (inalterado).
- `views/layout.erb` — nav perde o link "Time"; link "Lista" (`/`) continua.
- `views/team_page.erb` — **removido** (não há mais página própria do time).
- `views/pokemon_list_item.erb` — estados do botão Add: default ("Adicionar ao
  time"), `in-team` ("No time ✓", `disabled` quando `@team_names` inclui o nome),
  `full` (desabilitado + aviso quando `@team.size >= 6`). Exige `@team_names` no
  render da listagem.
- `server.rb` `load_pokemon_page`/`render_pokemons_list`/`render_index` — expõe
  `@team_names` (nomes do time corrente) e `@team_size`/`@team_full`.
- `public/style.css` — layout 2 colunas + largura cheia (`body.page-list` ou
  equivalente) + contador n/6 + estados do botão Add (estilo `disabled`/`in-team`).
- Textos de contrato preservados: "Adicionar ao time", "No time ✓" (novo),
  "Filtrar por nome", "Gerenciar time", "Monte seu time inicial...", "Poke Center",
  "Poke Mart", "Remover do time", "Curar", "Saldo:", mini-status de add.

### Testes

- `test/team_routes_test.rb` — `GET /team` não-htmx → **404**; `GET /team` htmx →
  fragmento (alvos `hx-target="#team-view"` preservados); `test_team_page_renders_full_page...`
  substituído por assert de 404.
- `test/pokemon_routes_test.rb` — página `/` renderiza `#team-view` (painel do
  time na unificada) + contador "Time n/6"; nav **sem** link `href="/team"`;
  `test_layout_marks_active_nav_link_on_list_page` atualizado (Lista ativa, sem
  link Time).
- `test/mart_routes_test.rb:55` — troca `get "/team"` por `get "/"` (com jornada)
  ou htmx `get "/team"` se o fluxo exigir o fragmento.
- `test/pokemon_routes_test.rb` (ou novo `test/list_add_states_test.rb`) — botão
  Add: default; `in-team` (`disabled` + "No time ✓") quando Pokémon no time;
  `full` (desabilitado) quando time cheio; `@team_names` exposto.

### Fora de escopo (não abrir)

- Onda 3 (grid responsivo da listagem) do `draft-ui-ux.md`; JN-3/JN-4/JN-5/J2/J4/D4;
  P2 (perf da 1ª batalha ~2min); largura cheia de Histórico/Detalhe/Manage
  (anotação 0041 — fica para onda futura).
- Contrato do gateway (`paginate`, `find`, `base_form?`, `learnable_moves`) intacto.
- Mudança de rotas/contratos de `TeamRepository`/`BattleService`/`JourneyService`
  (além de reusar `started?`/`mark_started_when_full` como hoje).
- Gerenciar time (`/team/manage`) — continua fragmento dentro do `#team-view`
  (link "Gerenciar time" preservado); sem mudanças de layout/manage.

## 4. Critérios de aceite

### Resultado

- [x] **C1 — Página `/` unificada com painel do time**: `GET /` renderiza busca +
      lista + `#team-view` com o time do usuário (membros, reordenar/remover,
      contador "Time n/6" quando pré-jornada) — prova: `test/pokemon_routes_test.rb`
      (`test_index_renders_team_panel_with_counter_when_not_started`,
      `test_index_team_panel_shows_members`).
- [x] **C2 — Página `/team` removida (404 em navegação direta)**: `GET /team`
      sem `HX-Request` → 404; com `HX-Request` → fragmento `team.erb` — prova:
      `test/team_routes_test.rb` (`test_team_page_is_removed_and_returns_404_without_htmx`;
      fragmentos via `htmx_session`).
- [x] **C3 — Nav sem link "Time"**: layout não renderiza `href="/team"`; link
      "Lista" (`/`) ativo na página `/` — prova: `test/pokemon_routes_test.rb`
      (`test_nav_has_no_time_link_after_unification`,
      `test_layout_marks_active_nav_link_on_list_page`,
      `test_index_has_header_navigation_links` atualizados).
- [x] **C4 — Estados do botão Add**: default "Adicionar ao time"; `in-team`
      ("No time ✓", `disabled`) quando o Pokémon já está no time; `full`
      (desabilitado) quando `@team.size >= 6` — prova:
      `test/pokemon_routes_test.rb` (`test_pokemons_add_button_shows_in_team_when_pokemon_in_team`,
      `test_pokemons_add_buttons_disabled_when_team_full`) +
      `test/team_routes_test.rb` (OOB: `test_remove_from_full_team_returns_active_add_buttons_oob`,
      `test_add_sixth_member_disables_add_buttons_oob`). *Ajuste S3 (2026-08-24):
      add/remove devolvem o `#pokemon-list` re-renderizado via `hx-swap-oob` para o
      estado dos botões refletir a mudança na mesma tela.*
- [x] **C5 — Ações do time atualizam `#team-view` na página unificada**: após add
      (`POST /team`), o painel do time na `/` reflete o novo membro (mini-status
      preservado + `#team-view` atualizado) — prova: `test/team_routes_test.rb`
      (`test_post_team_includes_team_view_out_of_band_swap`).

### Garantias (RNF)

- [x] Suíte completa verde com **baseline preservado (680 runs/2132 asserts)** +
      novos testes e lint 0 em **todo** green; commit obrigatório por passo; 0 regressão.
- [x] Sem gems novas / sem mudança de schema / testes sem rede / sem `rubocop:disable`.
- [x] `REQUIREMENTS.md` + `SESSIONS.md` + `draft-ui-ux.md` (Onda 1 marcada) +
      `docs/screens/pokemon-list.md` + `docs/screens/team.md` atualizados no passo
      docs; status de validação só após o usuário validar (S4).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste automatizado →
> escrever `manual` explícito + a evidência manual esperada.

## 5. Decisões de refinamento (fechadas com o usuário)

- **2026-08-24 — Próxima sessão = Onda 1 UX (jornada visível)** — preteridos:
  Onda 3 (grid), JN-3, JN-4, JN-5, J2, J4, D4, P2 (perf), largura cheia geral.
- **2026-08-24 — Caminho B: unificar Lista+Time na mesma tela** (decisão do usuário
  2026-08-22 revisitada) — preterido: Caminho A (contador/strip na lista mantendo
  `/team` página própria).
- **2026-08-24 — Layout 2 colunas (lista | time) em largura cheia** — busca + lista
  à esquerda, painel do time à direita — preterido: empilhado (lista acima, time
  abaixo).
- **2026-08-24 — Página `/team` removida**: `GET /team` não-htmx → 404; continua
  como fragmento htmx interno (alvo `#team-view`) — preterido: manter `/team`
  página própria ou redirecionar para `/`.
- **2026-08-24 — Nav perde o link "Time"** (o painel do time fica na própria
  Lista) — preterido: transformar em âncora `#team-view`.
- **2026-08-24 — Estados do botão Add incluídos**: default / "No time ✓" (disabled)
  / cheio (disabled), via `@team_names` exposto na rota da listagem — preterido:
  só a unificação das telas.
- **2026-08-24 — Ajuste S3 (bug de validação, reabre C4/C5):** ao **remover** um
  Pokémon de um time cheio, os botões Add da lista **não reativavam** — o estado
  `@team_full` só era recalculado ao re-renderizar a listagem, não após `DELETE
  /team` (que re-renderizava apenas `#team-view`). **Correção:** `add_team_member`
  e `remove_team_member` passam a devolver também o `#pokemon-list` re-renderizado
  via `hx-swap-oob` (`oob_pokemon_list`), usando `offset`/`q` carregados do
  formulário via `hx-include=".list-state"` (hidden inputs no fragmento da lista).
  Isso cobre o caso **simétrico** do add (adicionar o 6º desabilita os botões).
- **2026-08-24 — Ajuste S3 (bug de validação):** no painel do time, o link
  "Gerenciar time" (inline) ficava **na mesma linha** do primeiro Pokémon
  (número do slot + sprite) — `.slot` é `inline-block`. **Correção:** envolver o
  link num `<p class="team-tools">` (elemento em bloco).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (S4) | commit `Sessao 0042: refinamento concluido — ...`; `./scripts/checar-sessao 0042` + `./scripts/check_docs` |
| 1 | C2 — `GET /team` não-htmx → 404; fragmento htmx preservado (`render_team`) | suíte verde + lint 0, commit `Passo 1:` |
| 2 | C1 + C3 — `index.erb` 2 colunas com `#team-view` (+ contador n/6) + `render_index` carregando time; nav sem link "Time"; `team_page.erb` removido | suíte verde + lint 0, commit `Passo 2:` |
| 3 | C4 — `@team_names`/`@team_size` expostos na listagem + estados do botão Add (`in-team`/`full`) | suíte verde + lint 0, commit `Passo 3:` |
| 4 | C5 — add `POST /team` também atualiza `#team-view` (painel na `/` reflete novo membro; mini-status preservado) | suíte verde + lint 0, commit `Passo 4:` |
| 5 | CSS 2 colunas + largura cheia (`body` da página `/`) + contador + estados do botão | suíte verde + lint 0, commit `Passo 5:` |
| 6 | **Docs:** `REQUIREMENTS.md` (roadmap — Onda 1 executada), `SESSIONS.md`, `draft-ui-ux.md` (Onda 1 marcada), `docs/screens/pokemon-list.md` + `docs/screens/team.md` (Caminho B) | suíte verde + lint 0, commit `Passo 6:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Concluída em 2026-08-24 — validada pelo usuário** *(S2: uma linha por critério).*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 página `/` unificada com `#team-view` | `test/pokemon_routes_test.rb` | `/` em tela cheia: busca + lista à esquerda, time (n/6 + membros) à direita | ok |
| C2 `/team` 404 direto / fragmento htmx | `test/team_routes_test.rb` | abrir `/team` no browser → 404; ações do time continuam atualizando o painel | ok |
| C3 nav sem link "Time" | `test/pokemon_routes_test.rb` | nav mostra Lista/Batalha/Histórico; Lista ativa | ok |
| C4 estados do botão Add | `test/pokemon_routes_test.rb` + `test/team_routes_test.rb` (OOB add/remove) | na lista, Pokémon no time mostra "No time ✓" desabilitado; time cheio desabilita todos; **remover de um time cheio reativa** os botões; **adicionar o 6º desabilita** todos | ok |
| C5 add atualiza `#team-view` | `test/pokemon_routes_test.rb` + `test/team_routes_test.rb` (`test_post_team_includes_team_view_out_of_band_swap`) | ao adicionar, mini-status + painel do time atualizam na mesma tela | ok |

> **S3 — ajustes de validação (registrados na seção 5):** durante a validação o
> usuário reportou 2 bugs: (1) remover de um time cheio não reativava os botões Add
> da lista — corrigido com `#pokemon-list` em `hx-swap-oob` no add/remove (reabre
> C4/C5); (2) o link "Gerenciar time" ficava na mesma linha do primeiro Pokémon —
> corrigido com `<p class="team-tools">`. **Reaprovado** pelo usuário na validação
> final (comportamento validado em 2026-08-24).

## 8. Observações

- Fila: após a 0042 (Onda 1), restam Onda 3 (grid), JN-3, JN-4, JN-5, J2, J4, D4 e a
  perf da 1ª batalha (P2) como candidatas — a critério do usuário.
- O caminho B unifica em vez de adicionar contador/strip na lista (Caminho A);
  o painel do time à direita já entrega a visibilidade da jornada na própria Lista.
- Estados do botão Add exigem expor `@team_names` na rota da listagem — mesmo dado
  de `settings.team.all(current_user)` já usado em `prepare_team_fragment_data`
  (sem novo contrato de gateway).
- Largura cheia aplicada **só** na página `/` (anotação 0041 §8: Histórico/Detalhe/
  Manage ficam para onda futura).
- `test/team_page_renders_full_page_with_team_view` (team_routes_test.rb) foi
  substituído por `test_team_page_is_removed_and_returns_404_without_htmx` —
  evidência automatizada de C2.
- **Anotação (2026-08-24, fora de sessão — RNF-04):** flakiness na suíte —
  `PG::ConnectionBad: too many clients already` intermitente ao rodar `./scripts/test`
  com o container `web` ativo. O app em execução segura conexões persistidas
  (repositórios singleton); rodadas repetidas acumulam até estourar `max_connections`
  (100). Workaround observado: `docker compose stop web` antes da suíte (ou
  `restart db` + aguardar) — com `web` parado a suíte roda limpa (689 runs/2184
  asserts). Candidata a sessão futura (ex.: pool com limite/`max_connections` maior,
  ou desligar o app durante a suíte em CI).