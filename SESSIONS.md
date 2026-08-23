# SESSIONS — Poke-HTMX

> **Fluxo:** cada passo de implementação é uma **sessão** (arquivo próprio em `sessions/`).
> Fonte da verdade: `REQUIREMENTS.md`.

> **Sequência rígida (RNF-04):** um passo só é iniciado quando **todas as fases do passo anterior** estiverem devidamente concluídas e validadas (red → green → refactor → validação + critérios verificados).

## Ciclo de cada sessão (SDD em fases)

Cada sessão percorre **três fases** nesta ordem. A próxima fase só começa quando a fase atual estiver concluída (cada fase marcada como `Done` no arquivo da sessão):

### 1. Refinamento (preparação)

- Abertura: rodar `./scripts/iniciar-sessao` (digest do estado) + `./scripts/levantar-roadmap`
  (backlog/limitações abertas) e ler **na íntegra apenas** o arquivo da sessão corrente
  em `sessions/`; consultar `REQUIREMENTS.md`/`SESSIONS.md` por **busca** (grep/ctx_search),
  não ler inteiros.
- Esclarecer objetivo, escopo e **critérios de aceite** do passo.
- **Cada critério de aceite referencia o teste (arquivo/nome Minitest) que o prova**
  (S1); critério sem teste automatizado registra `manual` explícito.
- Registrar decisões de design (schema, gems, nomes de rotas) no arquivo da sessão.
- **Entrega:** arquivo da sessão com critérios de aceite fechados e plano TDD.
- **No commit do refinamento:** atualizar **também** `SESSIONS.md` — tabela de
  progresso + "Próxima sessão" (S4), inclusive para sessões fora de fila.
- Dúvidas em aberto → resolver antes de codar.

### 2. Implementação (TDD)

- Seguir **TDD**: `red` (teste falha) → `green` (implementação mínima, suíte verde) → `refactor`.
- **Commit obrigatório após cada green.**
- Atualizar `REQUIREMENTS.md`/`SESSIONS.md` no mesmo trabalho quando o comportamento mudar.

### 3. Validação (verificação) — executada pelo USUÁRIO

- A **validação é feita pelo usuário**. Ao terminar a fase 2 (implementação TDD, suíte
  e lint verdes), o agente **para** e aguarda o feedback do usuário — não marca fases
  como concluídas, não atualiza `REQUIREMENTS.md`/`SESSIONS.md` com status de validação
  e não commita a conclusão da sessão antes disso.
- Com o feedback em mãos, o usuário roda a **suíte completa** (Minitest) e confirma
  tudo verde.
- Verificar os **critérios de aceite** da sessão contra a implementação.
- **Registrar a validação como tabela por critério** (S2):
  `critério | evidência automatizada | evidência manual | resultado (ok/nok)` — um
  resultado por critério, nunca um bloco único.
- **Ajuste identificado na validação = reabrir o critério** (S3): registrar a alteração
  com data e recomeçar a aprovação do usuário; nunca aplicar "ajuste" sem esse registro.
- Registrar resultados e problemas no arquivo da sessão (feito junto ao usuário).
- Atualizar `REQUIREMENTS.md` (status dos requisitos) e `SESSIONS.md` (progresso +
  próxima sessão) apenas após a validação do usuário.

---

## Próxima sessão

**Sessão 0027 (Eco-1), 0028 (Eco-2 — Poke Center) e 0029 (Eco-3 — Poke Mart)
concluídas e validadas em 2026-08-14** (0029: suíte 459/1432, lint 0).

**Sessão 0030 (Eco-4-A — itens em batalha) concluída e validada em 2026-08-17**
(0030: suíte 493/1525, lint 0 — uso automático de poções em batalha).

**Sessão 0031 (Eco-4-B — item atribuído por membro) concluída e validada em
2026-08-18** (0031: suíte 524/1599, lint 0 — estratégia selecionável via
atribuição de item por membro, decisão 12 — 2ª parte).

**Sessão 0032 (Eco-4-C — seguráveis/hold items) concluída e validada em
2026-08-18** (0032: suíte 559/1696, lint 0 — 1 slot/membro, modula Attack/Speed,
decisão 13; equipa se tiver, não consome).

**Sessão 0033 (Respiro 2 — BattleService/TeamService + split de testes) concluída e
validada em 2026-08-19** (0033: suíte 559/1696, lint 0, grep `rubocop:` em `server.rb`
→ 0 — services de produção extraídos, handlers thin, `server_test.rb` fatiado).

**Sessão 0034 (D1 parcial — nível de aprendizado de golpes) concluída e validada em
2026-08-19:** gating do manage por nível (`TeamService` com `progression`, `manage_data`
via `learnable_moves` filtrado por `level <= membro`), validação gated (golpe acima do
nível não salva), nível exibido na UI (`"<nome> — Nível N"`), união com moves salvos
(legados visíveis/removíveis), troca manual preservada, `:finished` inalterado — suíte
566/1734, lint 0, critérios conferidos pelo usuário.

**Sessão 0036 (J1 — seleção inicial de time) concluída e validada em 2026-08-22:**
fim do dropdown (lista clicável sprite+nome+Add, pool total 20/página **só formas
base** via `base_form?`, destaques "Iniciais" com os **27 iniciais gen 1–9**
fora da listagem) e tela de entrada da jornada (gate battle/mart/center até o time
inicial de 6; marcador `user_state` + derivado do time). Ajustes S3 de validação
registrados na seção 5-A da sessão. Suíte 611/1936, lint 0.

**Sessão 0037 (JN-2 — golpes em lista) concluída e validada em 2026-08-22:**
checkboxes do `team_manage.erb` fora — **lista clicável com marcação via htmx**
(linha por golpe com `data-move`, `marked` nos selecionados), toggle como rascunho
na própria rota `POST /team/:id/moves` (`draft=1` + `toggle`, re-renderiza sem
persistir), cap de 4 aplicado no preview com aviso (`TeamService#preview_move`),
rascunho inicial = golpes salvos (legados e rótulo "— Nível N" preservados);
save/validação intactos. Testes de manage/golpes em `test/team_manage_test.rb`.
Suíte 614/1952, lint 0.

**Sessão 0038 (Onda 0 UX — quick wins) concluída e validada em 2026-08-22:**
`alt` nos sprites e `aria-label` nos ▲▼, `loading="lazy"` nas listagens,
evoluções do detalhe viram links (mesmo alvo `#pokemon`), copy pt-BR
("Adicionar ao time", "Remover do time", "Filtrar por nome"), hierarquia de
notices (`notice--info/success/error`; `kind:` em HealService/MartService,
`@notice_kind` nos handlers) e indicador global de carregamento (barra fixa +
eventos htmx). Suíte 624/2006, lint 0.

**Sessão 0039 (JN-1 — telas próprias) implementada (fase 2 concluída,
aguardando validação):** cada área virou **página própria com layout** (Lista
`GET /`, Time `GET /team`, Batalha `GET /battle`, Histórico `GET /history`) com
modo fragmento via `HX-Request`; nav com **links reais + estado ativo** por rota;
htmx intra-tela (`#team-view`, `#battle-view`, `#pokemon-detail`,
`#add-status`); add na lista → mini-status local; rotas `_close` de
batalha/histórico removidas (404), `teamRefresh` eliminado. Suíte 626/2017,
lint 0.

**Próxima sessão:** **0039 — JN-1**, aguardando validação do usuário (fase 3);
depois fila retoma em **J3** → ondas 1–3 de UX a critério → organizar o resto.

> **Fase Eco concluída (Eco-1..4 — sessões 0027..0032).** Respiro 2 concluído e validado
> (0033). D1 parcial concluído e validado (0034). **P1 concluído e validado (0035,
> 2026-08-19 — GET /battle ~38s, 2º play ~4s)**. **J1 concluído e validado (0036,
> 2026-08-22 — dropdown fora, jornada com gate e formas base/iniciais 27)**.
> **JN-2 concluído e validado (0037,
> 2026-08-22 — golpes em lista clicável, rascunho sem persistir)**. **Onda 0 UX
> concluída e validada (0038, 2026-08-22 — acessibilidade, copy pt-BR, notices,
> indicador; UX priorizada antes da fila por decisão do usuário)**. **JN-1 implementado
> (0039 — aguardando validação do usuário; urgência do usuário em 2026-08-22)**. Próximas:
> **J3** → ondas 1–3 de UX → organizar o resto
> (JN-3, JN-4, JN-5, J2, J4, D4).

## Progresso das sessões

| # | Sessão | Fase | Status |
| --- | --- | --- | --- |
| 0001 | Persistir equipe em PostgreSQL (RNF-02) | Concluída | Done (passos 0–5 validados) |
| 0002 | Remoção semântica (`DELETE /team`, RF-04) | Concluída | Done (passos 0–5 validados) |
| 0003 | Equipe por usuário (sessão/cookie, RF-05) | Concluída | Done (passos 0–6 + S1, validado em 2026-08-08) |
| 0004 | Página de detalhes (tipos, stats, evoluções) | Concluída | Done (passos 0–4, validado em 2026-08-08) |
| 0005 | Navegação pela sprite + Fechar/Voltar (RF-06) | Concluída | Done (passos 0–3, validado em 2026-08-08) |
| 0006 | Paginação/filtro na listagem | Concluída | Done (passos 0–6, validado em 2026-08-08) |
| 0007 | Montagem de times — cap 6 + slots + sem duplicados (RF-07) | Concluída | Done (passos 0–9, validado em 2026-08-08) |
| 0008 | Reordenação manual de slots (RF-08) | Concluída | Done (passos 0–8, validado em 2026-08-08) |
| 0009 | Modelo de batalha (RF-09, B1) — BattlePokemon puro | Concluída | Done (passos 0–5, validado em 2026-08-08) |
| 0010 | Efetividade de tipos (RF-10, B2) — lookup puro + tabela via PokéAPI | Concluída | Done (passos 0–8, validado em 2026-08-08) |
| 0011 | Motor de auto-batalha (RF-11, B3) — BattleEngine puro 6v6 | Concluída | Done (passos 0–9, validado em 2026-08-08) |
| 0012 | Oponente automático (RF-12, B4) — OpponentGenerator puro | Concluída | Done (passos 0–5, validado em 2026-08-08) |
| 0013 | Batalha na web (RF-13, C1) — BattleEngine incremental + rotas htmx | Concluída | Done (passos 0–7, validado em 2026-08-09) |
| 0014 | UI: layout e estilos externos (RF-14, A2) — layout.erb + nav + style.css | Concluída | Done (passos 0–4, validado em 2026-08-09) |
| 0015 | Golpes/moves e PP (RF-15, D1) — Move + moves_for + BattleEngine determinístico + battle.erb | Concluída | Done (passos 0–7, validado em 2026-08-09) |
| 0016 | Logs de batalha detalhados (RF-16, C1) — entry com attacker_name/target_name + battle.erb | Concluída | Done (passos 0–3, validado em 2026-08-09) |
| 0017 | Página de gerenciamento de time (RF-17, A3) — slot + golpes persistidos + team_manage.erb | Concluída | Done (passos 0–6 + ajustes de validação, 199 runs/708 asserts, validado em 2026-08-09) |
| 0018 | Tratamento de erros (RF-18, E2) — robustez da fonte + fragmentos amigáveis 200 + handler global | Concluída | Done (passos 0–5, 222 runs/778 asserts, lint 0, validado em 2026-08-09) |
| 0019 | Respiro: refatoração de testes — remoção dos `rubocop:disable` (6 arquivos, orçamentos em `test/.rubocop.yml`, `TestSupport`/`TestDatabase`/`PokeApiStub` genérico) | Concluída | Done (passos 1–6, 222 runs/778 asserts preservados, lint 0, validado em 2026-08-10) |
| 0020 | Respiro: refatoração de produção — remoção dos 7 `rubocop:disable` de `lib/**` + `server.rb` (5 arquivos, módulos por área, suíte 222/778 + lint 0 preservados) | Concluída | Done (passos 1–6, suíte 222/778, lint 0, grep `rubocop:` em lib+server → 0, validado em 2026-08-10) |
| 0021 | E1-A: gateway da PokéAPI — interface `PokeApi` + adapter real `PokeApiHttp` + adapter fake `PokeApiFake` + injeção (`settings.api`/`PokeApi.instance`); static `lib/poke_api.rb` e `PokeApiStub.stub_singleton` removidos | Concluída | Done (passos 1–6, suíte 239/821, lint 0, grep `PokeApi\.[a-z]` em lib+server → só `PokeApi.instance`, validado em 2026-08-10) |
| 0022 | E1-B: decorator de cache TTL/LRU fixos — `PokeApiCache` (TTL 600s / máx 1000) sobre a interface `PokeApi`, remove a memoização interna do `PokeApiHttp`, `PokeApi.instance` decorado no boot | Concluída | Done (passos 1–6, suíte 256/849, lint 0, validado em 2026-08-10) |
| 0023 | D2-A: progressão persistida — `team_pokemon_progress` + `ExperienceCurve` linear + `RewardRule` no `:finished` + `BattleEngine#result` + stats escalam + oponente escala | Concluída | Done (passos 1–10, suíte 292/941, lint 0, validado em 2026-08-10) |
| 0024 | D2-B: evolução por nível + aprendizado de golpes por nível (dados oficiais da species) | Concluída | Done (passos 1–7 + hotfix, suíte 328/1025, lint 0, validado em 2026-08-10) |
| 0025 | Seeds de validação — SeedTeam parametrizável + 3 cenários prontos + rake db:seed (dados hardcoded) | Concluída | Done (passos 1–3 + ajustes de validação, suíte 337/1086, lint 0, validado em 2026-08-10) |
| 0026 | D3: histórico/rank de batalhas — `battles` + `BattleRepository` + persistência no `:finished` + `GET /history` (rank local/global) + seed `batalhas_historico` | Concluída | Done (passos 1–7, suíte 367/1172, lint 0, validado em 2026-08-13) |
| 0027 | Eco-1: moeda pós-batalha — `wallet` + `RewardRule#money_for` + `WalletRepository` + grant no hook `:finished` + aviso no `battle.erb` | Concluída | Done (passos 1–5, suíte 386/1216, lint 0, validado em 2026-08-14) |
| 0028 | Eco-2: Poke Center — HP persistente por membro + `HealCostPolicy` proporcional ao HP faltante + `WalletRepository#spend` + `HealService` + `POST /team/heal` + carryover de HP p/ a próxima batalha | Concluída | Done (passos 1–8, suíte 428/1333, lint 0, validado em 2026-08-14) |
| 0029 | Eco-3: Poke Mart — `Item` + catálogo estático + `InventoryRepository` + `MartService` + `POST /mart/buy` + bloco Poke Mart no `team.erb` + seed `saldo_inicial` | Concluída | Done (passos 1–5, suíte 459/1432, lint 0, validado em 2026-08-14) |
| 0030 | Eco-4-A: itens em batalha — `Item#heal_amount` + `BattlePokemon#heal` + `ItemUsePolicy` automática (decisão 12) + `BattleEngine` ação `:item` (half-FSM) + `InventoryRepository#use` + `POST /battle/play` debitando + `battle.erb` (branch `:item` + estoque) | Concluída | Done (passos 0–7, suíte 493/1525, lint 0, validado em 2026-08-17) |
| 0031 | Eco-4-B: item atribuído por membro — `assigned_item` persistido (0031_add_assigned_item) + `TeamRepository#assign_item` + `BattlePokemon#assigned_item` + `ItemUsePolicy` prefere o atribuído (decisão 12 — 2ª parte) + `BattleEngine` usa o atribuído + `POST /team/:id/item` + select no `team_manage.erb` + `battle.erb` (`carrega:`) | Concluída | Done (passos 0–6, suíte 524/1599, lint 0, validado em 2026-08-18) |
| 0032 | Eco-4-C: seguráveis/hold items — `Item` `stat`/`multiplier` + `ItemCatalog.can_hold` (choice-band/scarf, decisão 13) + coluna `held_item` (0032_add_held_item) + `TeamRepository#assign_held_item` + `BattlePokemon#held_item` + modulação de `stat` (motor sem mudança) + `POST /team/:id/held-item` + select "Segurável:" no `team_manage.erb` + `battle.erb` (`segura:`) + seed `team_duelo` | Concluída | Done (passos 0–6 + seed, suíte 559/1696, lint 0, validado em 2026-08-18) |
| 0033 | Respiro 2 — services de produção: `BattleService` (prepare/advance) e `TeamService` (manage_data/save_moves/assign), providers lambda p/ gateway, 3 `rubocop:disable` de `server.rb` removidos, `server_test.rb` (1925 linhas) fatiado em 7 arquivos por área + `battle_test_helpers.rb` | Concluída | Done (passos 1–4, suíte 559/1696, lint 0, grep `rubocop:` em `server.rb` → 0, validado em 2026-08-19) |
| 0034 | D1 parcial — nível de aprendizado de golpes: gating do manage por nível (`TeamService` + `progression`, `manage_data` via `learnable_moves` filter `level <= membro`), validação gated, nível na UI (`"<nome> — Nível N"`) + união com moves salvos, troca manual preservada, `:finished` inalterado | Concluída | Done (passos 1–5, suíte 566/1734, lint 0, validado em 2026-08-19) |
| 0035 | P1 — performance do gateway: `Parallelizer` (pool threads) + `PokeApiCache` thread-safe + `PersistentJsonStore` (`tmp/`) + choke point `http_get` + fonte paralela (`type_relations`/`OpponentGenerator`/`BattleService`) | Todas | Concluída — **validada pelo usuário em 2026-08-19** (GET /battle ~38s, 2º play ~4s; suíte 586/1787, lint 0) |
| 0036 | J1 — seleção inicial de time: fim do dropdown (lista clicável sprite+nome+Add, pool total 20/página + destaques "Iniciais") + tela de entrada da jornada (gate battle/mart/center até time de 6, marcador `user_state` + derivado do time) | Concluída | Done (passos 0–6 + ajustes S3 — só formas base, 27 iniciais gen 1–9; suíte 611/1936, lint 0, validado em 2026-08-22) |
| 0037 | JN-2 — gerenciamento de golpes em lista: fim dos checkboxes do manage (lista clicável com marcação via htmx, toggle como rascunho na própria rota sem persistir, cap 4 no preview) + save/validação de `POST /team/:id/moves` intactos | Concluída | Done (passos 1–4, suíte 614/1952, lint 0, validado em 2026-08-22) |
| 0038 | Onda 0 UX — quick wins: alt/aria-label nos sprites e ▲▼ + `loading="lazy"`, evoluções do detalhe viram links, copy pt-BR ("Adicionar ao time", "Remover do time", "Filtrar por nome") + hierarquia de notices (`notice--info/success/error`), indicador global de carregamento htmx | Concluída | Done (passos 1–5, suíte 624/2006, lint 0, validado em 2026-08-22) |
| 0039 | JN-1 — telas próprias (fim do empilhamento): páginas próprias por rota com layout (Lista/Time/Batalha/Histórico), nav real com estado ativo, htmx intra-tela (`#team-view`/`#battle-view`/`#pokemon-detail`/`#add-status`), add → mini-status, remoção do span hack/_close/teamRefresh | Implementação | Concluída — passos 1–6 (suíte 626/2017, lint 0), aguardando validação do usuário |

## Estrutura do arquivo de sessão

Todo arquivo em `sessions/` contém as seções:

1. **Objetivo**
2. **Critérios de aceite** — cada critério aponta o **teste que o prova**
   (arquivo/nome Minitest); verificação só manual = `manual` explícito (S1).
3. **Plano TDD** (passos + testes)
4. **Decisões de refinamento**
5. **Validação** — **tabela por critério** (S2): `critério | evidência automatizada |
   evidência manual | resultado (ok/nok)`; suíte executada; ajuste de validação
   registrado como **alteração formal de critério** (S3).
6. **Observações** (impedimentos, dúvidas, próximo passo sugerido)

> **Consistência (S4/S5):** `SESSIONS.md` (tabela + "Próxima sessão") é atualizado no
> **commit do refinamento** de toda sessão; `./scripts/check_docs` confere
> `sessions/` ↔ tabela de progresso ↔ "Próxima sessão".