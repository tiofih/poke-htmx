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

**Sessão 0039 (JN-1 — telas próprias) concluída e validada em 2026-08-22:**
cada área virou **página própria com layout** (Lista `GET /`, Time `GET /team`,
Batalha `GET /battle`, Histórico `GET /history`) com modo fragmento via
`HX-Request`; nav com **links reais + estado ativo** por rota; htmx intra-tela
(`#team-view`, `#battle-view`, `#pokemon-detail`, `#add-status`); add na lista →
mini-status local; rotas `_close` de batalha/histórico removidas (404),
`teamRefresh` eliminado. Suíte 626/2017, lint 0.

**Sessão 0040 (J3 — ranking S–F) concluída e validada em 2026-08-23:**
`PokemonRating` (domínio puro) classifica Pokémon em S–F por stats ponderados +
bônus dos moves (top-4, STAB-aware), com `band_for_level` (nível → banda de
tiers); `OpponentGenerator` ganhou `rater`/`moves_fetcher`/`band` (`options:`)
filtrando oponentes pela banda com fallback puro; `build_opponent` deriva a banda
do nível médio do jogador (fim do sorteio puro). Retorno `score` + `tier`, sem UI.
Suíte 649/2063, lint 0. Validação ok; observado `GET /battle` ~2min na 1ª chamada
(varredura serial da banda) — anotado como limitação/perf (fora de sessão, RNF-04).

**Sessão 0041 (Onda 2 UX — leitura da batalha) concluída e validada em 2026-08-23:**
`Move#pp_max` (default = pp, preservado no `use_move`) + `FighterPresenter`
(linha do lutador: HP/PP percent+tier, itens) + `BattleLogPresenter` (últimas 3
rodadas, mais recente no topo) + partial único `_fighter_panel.erb` (fim da
duplicação dos painéis) com barras `hp-bar`/`pp-bar` + log com rótulo por rodada +
`hx-indicator` local no botão Jogar. Ajuste S3 de validação: layout em **3 colunas
em tela cheia** (Seu Time à esquerda, controles centralizados + log ao centro,
Oponente à direita). Suíte 680/2132, lint 0. Anotado p/ próximas tasks: aplicar o
mesmo espaçamento/largura cheia nas demais telas (Lista/Time/Histórico/Detalhe/
Manage — ver `draft-ui-ux.md` §4).

**Sessão 0042 (Onda 1 UX — jornada visível, Caminho B) concluída e validada em
2026-08-24** (suíte 689/2184, lint 0): `GET /` virou página única de **2 colunas
em largura cheia** (busca + lista à esquerda, painel do time com contador
"Time n/6" + membros à direita); **página `/team` removida** (`GET /team` sem
`HX-Request` → 404, fragmento htmx interno preservado como alvo `#team-view`);
**nav perdeu o link "Time"**; `team_page.erb` removido; **estados do botão Add**
(default / "No time ✓" desabilitado / cheio desabilitado) via `@team_names`/
`@team_full` expostos na rota da listagem; add `POST /team` devolve mini-status +
`#team-view` com `hx-swap-oob`; **ajustes S3 de validação** — add/remove também
re-renderizam `#pokemon-list` via OOB (remover de time cheio reativa os botões,
adicionar o 6º desabilita) e link "Gerenciar time" em `<p class="team-tools">`
(linha própria). Preteridos: Onda 3 (grid), JN-3/JN-4/JN-5/J2/J4/D4, P2 (perf),
largura cheia de Histórico/Detalhe/Manage. Anotado (fora de sessão): flakiness
`too many clients` na suíte com o container `web` ativo — workaround
`docker compose stop web`. Ver `sessions/0042-onda1-jornada-visivel.md`.

**Sessão 0043 (Estabilidade do banco — correção direta, fora da fila) concluída
e validada em 2026-08-24** (suíte 692/2193, lint 0): fim do "too many clients"
— `ConnectionRegistry` (`lib/connection_registry.rb`) registra as conexões dos
repositórios e `Minitest::Test#after_teardown` (`test/test_helper.rb`) fecha
todas após cada teste; 7 repositórios/seed passam a registrar conexão (pico na
suíte caiu de 74 → 9, roda limpa com o `web` ativo). Avisos de constante nos
seeds eliminados (guard `unless defined?` em `saldo_inicial.rb`). Sem mudança no
app (repositórios singleton seguem com conexão persistida). Ver
`sessions/0043-estabilidade-banco-conexoes.md`.

**Sessão 0044 (Onda 3 UX — estrutura) refinada em 2026-08-24** (fase 1
concluída), **implementada em 2026-08-24** (passos 1–3 + ajustes S3) e **validada
pelo usuário em 2026-08-24** (suíte 694/2200, lint 0): grade **uniforme de 6
colunas com páginas cheias e paginação on-demand** — `PAGE_SIZE` 36 = grid 6×6,
página 1 = 27 iniciais + 9 comuns (sem título "Iniciais"), páginas 2+ = 36
comuns; **cada página carrega só o próprio lote** (scan `base_form?` em batchs;
"Página X" sem total, próximo lote sob demanda); iniciais só na 1ª página;
corrigido o bug visual do item e os slots vazios — + largura cheia do Histórico
(`body.page-history`). **Estabilidade corrigida durante a validação:** conexão
PG **por thread** (fim do "message type while idle"/NoMethodError sob Puma
concorrente), timeout de 15s na gateway e **banco de teste separado**
(`pokedex_test`) — suíte roda verde com o `web` ativo (fim do hang/flakiness).
Ver `sessions/0044-onda3-grid-responsivo.md`.

**Sessão 0045 (JN-3 — itens de uso único por Pokémon) concluída e validada em
2026-08-24** (fase 1 em 2026-08-24; implementação passos 1–3, suíte 701/2222, lint 0;
validação ok): regra estrita de **1 uso de item curativo por Pokémon por batalha** —
o `BattleEngine` rastreia quem já usou (`@items_used_by_member`) e bloqueia novos usos
do mesmo membro na mesma batalha, valendo para o pool comum **e** o item atribuído
(cada membro 1 item por batalha, independente de estoque/threshold); badge "já usou
item" por membro no painel do lutador (`FighterPresenter#item_used?`).
**Anotado (fora da fila, JN-3-B):** equipamento não respeita a quantidade do estoque
(choice-band em 2 pokes) — regra fechada: equipar debita, itens consumidos na batalha
(poke fica sem), seguráveis permanecem até desequipar, option desabilitado + qtd
livre.

**Sessão 0046 (JN-3-B — equipamento por quantidade do estoque) concluída e validada
em 2026-08-24** (passos 1–3, suíte 718/2294, lint 0; validação ok): itens/seguráveis
são por poke (1 de cada) e os pokes só equipam conforme a quantidade do time —
**equipar debita do estoque, desequipar repõe, trocar repõe o antigo e debita o novo,
re-equipar o mesmo item não debita de novo** (`TeamItemOperations` em `lib/`); item
atribuído consumido em batalha **não debita de novo** e **limpa o `assigned_item`**
(`battle_items` soma atribuídos + `debit_used_items` por `attacker_index`); UI mostra
a quantidade livre e desabilita (×0) itens esgotados. **Correções de UI na validação:**
`reload_manage_state` no POST (estoque exibido reflete débito/reposição) + `overflow-anchor:
none`/preservação do `scrollY` (pulo de scroll no swap). **Anotado (resíduo):** scroll
ainda pula para baixo ao salvar — fora de critério, investigar depois. Próximo: JN-4,
JN-5, J2, J4, D4 e P2 (perf da 1ª batalha ~2min) — a critério do usuário.

**Sessão 0047 (JN-4 — componentes de Poke Mart e Poke Center) concluída e validada
em 2026-08-24** (passos 1–3, suíte 724/2329, lint 0; C1–C5 ok): blocos de
Poke Center/Mart extraídos de `views/team.erb` em partials reutilizáveis
(`_mart.erb`/`_center.erb`) no painel do time (`#team-view`), com cura completada
(**HP atual/máx + custo total antecipado** via `HealService#preview_cost`, botão
Curar desabilitado quando já curado ou saldo insuficiente) e compra completada
(**preço × quantidade comprável = saldo/preço**, botão desabilitado quando saldo <
preço). Sem rotas/páginas novas — `team_hp.erb` absorvido pelo `_center.erb`
(removido). Próximo: organizar o resto (JN-5, J2, J4, D4 e P2) — a critério do usuário.

**Sessão 0048 (JN-5 — gameloop: circuito explícito por CTAs) refinada em 2026-08-25,
implementada em 2026-08-25 e VALIDADA pelo usuário em 2026-08-25** (passos 1–2, suíte
727/2344, lint 0; C1–C5 ok; decisão do usuário: **fluxo guiado por CTAs**, sem
páginas/rotas novas): o circuito montagem → batalha → Poke Center/Poke Mart → repete
vira explícito na navegação — ao terminar a batalha, o painel de fim mostra CTAs para
Poke Center e Poke Mart (levam à Lista `/`, onde `#team-view` mostra os partials
`_center.erb`/`_mart.erb`) além do botão "Novo confronto" (mantido); no painel do time
pós-jornada, um CTA **Batalhar** (`/battle`) fecha o circuito. `nav` permanece
`Lista/Batalha/Histórico` (sem reordenação). Ver
`sessions/0048-jn5-gameloop.md`. **Anotações 2026-08-25 (RNF-04):** Center/Mart como
janelas flutuantes + gerência de golpes/itens (4 selects); itens de evolução no Mart
aleatórios por rodada; custo de montagem de time; "batalhar" resolve a batalha inteira;
animações nos ataques; bug "novo confronto" repete oponente (seed determinístico por
user). Próximo: organizar o resto (J2, J4, D4 e P2) + as novas anotações — a critério
do usuário.

**Sessão 0049 (BUG-1/Q1 — oponente novo a cada confronto + máquina de estado do
gameloop) refinada, implementada e VALIDADA pelo usuário em 2026-08-25** (passos 1–5,
suíte 735/2358, lint 0; C1–C7 ok):
fim da seed fixa `Random.new(user_id.sum)` em `BattleService#build_opponent`
(`lib/battle_service.rb`) — dependência injetável `opponent_rng` (default
`-> { Random.new }`) — e **máquina de estado da batalha ativa**: `prepare` reusa a
batalha por estado (preparada não iniciada → **re-deriva o time do jogador preservando
o oponente**; em andamento/finalizada → **preserva o engine**), "Novo confronto" virou
ação explícita `POST /battle/new` (limpa e prepara novo) e **add/remove/move invalidam**
a batalha ativa. Ajuste **S3** registrado em 2026-08-25: o C1 original ("novo a cada
confronto") foi **reprovado na validação** porque trocava o oponente a cada acesso a
`/battle`; critérios reabertos (C1 redefinido + C4–C7) e implementados. Critérios
C1–C7 e plano TDD fechados (`sessions/0049-oponente-novo-por-confronto.md`); suíte
verde, lint 0, validado em 2026-08-25. Depois da 0049: organizar os demais
itens do QA (Q2–Q5) e a fila (J2, J4, D4, P2, M2) — a critério do usuário.

**Sessão 0050 (P2 — performance da varredura da banda do oponente) refinada em
2026-08-25** (fase 1 concluída — critérios C1–C4 e plano TDD fechados em
`sessions/0050-p2-perf-varredura-banda.md`): ataque ao `GET /battle` ~2min da 1ª
chamada (anotado na validação da 0040) sem mudar a banda — **varredura paralela em
lotes** no `OpponentGenerator` (novo caminho `ratings:` nome→tier, ordem
determinística por seed, lote via `Parallelizer`) + **cap de varredura**
(`max_candidates:` default 256) com fallback puro + **cache de rating persistente**
(`PokemonRatingCache` novo, keyed por nome, TTL 7d, write-through, sem Faraday)
evitando re-ratear espécies já avaliadas; caminho `rater`/`moves_fetcher` intacto
(backward-compat). Decisões: estratégia A+B+cache; `ratings:` como novo caminho
opcional; cache persistente keyed por nome; cap 256 heurístico (S3). **Implementada em
2026-08-25 (passos 1–5, suíte 748/2387, lint 0 — AGUARDANDO validação):** varredura da
banda em **lotes paralelos** (`ratings:` no `OpponentGenerator`, determinístico por
seed) + cap `max_candidates:` 256 com fallback puro + `PokemonRatingCache` persistente
no `BattleService`; caminho `rater`/`moves_fetcher` intacto; banda preservada.
**Ajuste S3 em 2026-08-25:** benchmark mostrou que a 1ª batalha seguia ~55-63s — o
gargalo é o **write-through do `PersistentJsonStore`** (260MB reescritos a cada miss,
~1.45s/miss, sob `@store_mutex`). C4 reaberto e estendido (C4-b): **escrita coalescida**
— `store` só em memória, writer em background (intervalo 30s) + `flush!` síncrono
(testes/exit), `PokeApiHttp#flush!`; **passos 6–7 em 2026-08-25 (suíte 751/2391, lint 0,
web parado para a suíte — app vazou conexões PG, ver anotação)**. **VALIDADA pelo
usuário em 2026-08-25 (C1–C3 ok, C4 nok→ok via C4-b, C4-b ok; benchmark pós-fix:
1ª batalha 2.81s / frio real 1.64s / 2ª 0.01s — de ~60s).** Depois da 0050: organizar o
resto do QA (Q2–Q5) e a fila (J2, J4, D4, M2) — a critério do usuário.

**Sessão 0051 (BUG-4 — vazamento de conexões PG em produção) refinada em 2026-08-25**
(fase 1 concluída — critérios C1–C3 e plano TDD fechados em
`sessions/0051-bug4-vazamento-conexoes.md`): o `ConnectionRegistry` só limpa conexões no
`after_teardown` dos testes — em produção (Puma `run!`, 7 repos × threads) **acumulam
sem nunca fechar** (80 conexões no `pokedex` no benchmark da 0050, derrubou a suíte com
"too many clients"). Fix fechado: **liberação por request** — `after` no `server.rb`
chama `release_current_thread!` (fecha as conexões da thread ao fim de cada request) —
+ **teto global `MAX_CONNECTIONS` 30** (env `PG_MAX_CONNECTIONS`) com evicção
(prefere thread morta, senão LRU); isolamento por thread (0044) preservado. Decisões:
preterido pool por operação nos 7 repositórios (refactor grande, baixa concorrência) e
trocar/configurar o servidor. **Implementada em 2026-08-25 (passos 1–3, suíte 755/2404,
lint 0 — AGUARDANDO validação):** `release_current_thread!` no registry + teto
`MAX_CONNECTIONS` 30 com evicção (thread morta primeiro, senão LRU) + `after {
release_current_thread! }` no `server.rb` — cada request fecha as conexões da sua thread.
**VALIDADA pelo usuário em 2026-08-25 (C1–C3 ok; `pg_stat_activity` estável em 14
conexões após ~18 requests — antes 80 e subindo; suíte verde com o `web` ativo).**
Depois da 0051: organizar o resto do QA (Q2, Q3, Q5) e a fila (J2, J4, D4, M2, GL-2) —
a critério do usuário.

**Sessão 0052 (QA Q2+Q3+GL-2 — gate da jornada, gate de HP e itens no remove) refinada em
2026-08-25** (fase 1 concluída — critérios C1–C4 e plano TDD fechados em
`sessions/0052-qa-gate-jornada-e-itens.md`): **Q3** — `JourneyService#started?` passa a ser
**derivado do tamanho do time** (`team >= 6`; a flag `user_state` deixa de liberar — remover
abaixo de 6 re-bloqueia Batalha/Center/Mart, decisão do usuário em detrimento de re-fechar
só com time vazio); **GL-2** — novo `battle_ready?` (≥1 poke com HP útil: `hp_max ≤ 0` =
nunca lutou → cheio; `hp_current > 0`) aplicado a `GET /battle`/`POST /battle/new` com aviso
"cure no Poke Center" + CTA, e o painel esconde o CTA "Batalhar" quando o time está todo
zerado (Center/Mart permanecem); **Q2** — `TeamService#remove_member` devolve
`assigned_item`/`held_item` ao estoque antes de `TeamRepository#remove` (rota passa a usar o
service). Flag `user_state` vira vestigial para o gate (escrita preservada; remoção =
refatoração futura anotada no draft). Migração de testes: `start_journey` (flag) → `fill_team`
(time de 6) nas rotas. **VALIDADA pelo usuário em 2026-08-25 (C1–C4 ok; ajuste S3 — C2
reaberto e re-aprovado: botão "Novo confronto" desabilitado com tooltip na tela de fim de
batalha após derrota e no gate de HP; suíte 770/2473, lint 0).**

**Sessão 0053 (QA Q4+Q5+GL-1 — aviso de busca base-form, remoção em 1 clique e game
over) refinada, implementada e **VALIDADA pelo usuário em 2026-08-25** (C1–C12 ok,
passos 1–8 + ajustes S3, suíte 804/2623, lint 0; arquivo
`sessions/0053-qa-busca-remocao-gameover.md`):**
**Q4** — a busca segue só formas base e ganha **aviso informativo** quando o termo só
casa com não-base/starter (aponta a evolução base via `evolutions.first` ou os destaques
iniciais); **Q5** — remoção robusta (botão "Remover" com `hx-disabled-elt="this"` +
regressão do `DELETE` htmx exato remove em 1 request e é idempotente); **GL-1** — **game
over** quando todos os pokes zeram HP **e** o saldo < custo da cura total (`game_over?`
no `JourneyService`, deps `wallet:`/`heal_preview:`), com **venda de itens** (novo
`POST /mart/sell` + `SellPolicy` = metade do preço, geral do Mart) e **recomeçar jornada**
(`POST /journey/restart` — `TeamService#reset` em **lote** devolvendo itens +
`WalletRepository#set` p/ saldo inicial 200; redirect full-page para `/`). Ajustes S3 da
validação (feedback do usuário, re-aprovados): game over também na **tela de fim de
batalha** (mensagem + "Vender itens"/"Recomeçar jornada" no lugar do "Novo confronto"),
**fix do 500** no recomeçar (reset em lote via `TeamRepository#clear` — double-submit
concorrente não colide mais no unique `(user_id, slot)`), **lista de venda sem linhas
`0×`** do inventário (itens equipados/consumidos não aparecem mais como vendáveis) e
**`#pokemon-list` refrescada via OOB após o recomeçar** (botões Add deixam de ficar
travados no estado antigo). Depois da
0053: a fila (J2, J4, D4, M2) e as
limitações técnicas (escritas não atômicas, erros com status real, race no add,
identidade/CSRF, CI) — a critério do usuário.

**Sessão 0054 (limitação técnica — erros com status real) refinada em 2026-08-26**
(fase 1 concluída — critérios C1–C3 e plano TDD fechados em
`sessions/0054-erros-status-real.md`): o handler global `error 500 do` (`server.rb`)
passa a devolver **status 500** nas requisições **não-htmx** (monitoria/healthcheck/
navegação direta) — fim do "esconde falhas de monitoria" — e **mantém 200 + fragmento**
(`views/error.erb`) nos swaps **htmx** via `htmx_request?` (padrão 0018 preservado);
o log do erro original (`env["sinatra.error"]`) segue em ambos. **Fora de escopo:**
`halt 404` (já devolve 404), os fragmentos amigáveis 200 **por rota** (PokeAPI nil etc.,
decisão 0018), página de erro full-page estilizada, configurar htmx para swap em 5xx
(preterido — ver D1) e as demais limitações anotadas (escritas não atômicas, race no add,
identidade/CSRF, estado transiente, `pry`, CI). Depois da 0054: as demais limitações
técnicas e a fila J2/J4/D4/M2 — a critério do usuário.

**Sessão 0055 (M2 — sistema de custo para montagem de time) concluída e validada em
2026-08-26** (suíte 819/2701, lint 0): custo pelo tier da linha evolutiva (S=120/A=70/
B=55/C=40/D=30/F=20), metade para restrição de evolução, teto de 3 S + orçamento 450
em todo `POST /team`, sem wallet. Painel do time mostra custo/orçamento/contagem de S.
**Fora de escopo:** UX-2 (custo/ranking na listagem), D4 (draft temático), M1 (pedras no
Mart), regra de vida zerada.

**Sessão 0056 (UX-2 — custo e tier na listagem) concluída e validada em
2026-08-26** (refinamento + implementação passos 1–3 em 2026-08-26 — commit c420352,
suíte 826/2748, lint 0; revisor **Aprovado** em 2026-08-26): exibir **custo e tier da linha
evolutiva** na listagem da `GET /` via badge inline em `pokemon_list_item.erb`
(`<span class="poke-cost" data-tier="B">B · 55</span>`, restrito mostra metade + ícone `◆`
+ classe `poke-cost--restricted`, cor por tier via `[data-tier]` em `public/style.css`),
reusando `PokemonRatingCache` (`rating_source` via `Server.set`, TTL 7d) +
`TeamBudget.cost_for` + `api.evolution_restricted?` — `line_tier` = máximo da cadeia via
`find(name).evolutions` já disponíveis no `Parallelizer` batch 24, sem fetch extra;
paginação/busca preservadas e sem rede, OOB da lista pós add/remove preserva badges,
visual (alinhamento/cores) conferido via `manual`. Correções: `moves || []` em
`PokemonRatingCache`/`PokemonRating` + fallback `evolution_chain_names` evitando `[]→:F`.
**Fora de escopo:** filtros avançados, alinhamento lista↔time, ordenação por custo/tier,
persistir custo, Q5/race/escritas atômicas/CSRF/CI/pry, M1 pedras, regra vida zerada.
**Próximas candidatas:** 0057 (UX-2b filtros/tipos/geração/custo/ranking combináveis +
alinhamento lista↔time), bug Q5 (2 cliques — persiste), fila J2/J4/D4 e limitações
técnicas (escritas não atômicas, race no add, identidade/CSRF) — a critério do usuário.

**Sessão 0057 (UX-2b — filtros avançados + ordenação + alinhamento lista↔time) concluída e validada em 2026-08-26** (refinamento + implementação passos 1–4 + 4a–4e em 2026-08-26 — commits ffc0fc2/80fe761/3e68b71/3088200/2de0e0b/0595757/ed1651d/19af345/f813b19, suíte 854/3016, lint 0; revisor **Aprovado** 2/3): filtros combináveis **tipo (18 tipos) + geração (1..9) + custo/tier** (line_tier = máx. da cadeia via `PokemonRatingCache` + `TeamBudget.cost_for` + `evolution_restricted?` metade floor, cadeia ramificada prova máx. ramo) **server-side no `load_pokemon_page`** (derivação no batch 24, filtrar/ordenar **antes** de paginar, `PAGE_SIZE` 36, `generation_for` + `pokemon_names_by_type` via `/type` endpoint, `session[:list_filters]` com OOBs, grid 6×6 preservado); **ordenação por custo/tier** (`sort` cost_asc/cost_desc/tier_desc/tier_asc) + botão **"limpar filtros"** (com OOB `filter-controls` condicional, debounce 300ms sem perder foco) + alinhamento `list-column`↔`team-column`. Hotfixes S3 na validação: **4b** tipo rock via `/type` + `detail` (2.5min→<1s), **4c** limpar dropdowns OOB, **4d** rating via `detail` (tier F→real), **4e** busca sem perder foco. **Fora de escopo:** Q5/race/escritas atômicas/CSRF/CI/M1/J2/J4/D4. **Próximas candidatas:** bug Q5 (2 cliques — persiste), fila J2/J4/D4 e limitações técnicas (escritas não atômicas, race no add, identidade/CSRF, CI, `pry`, M1 pedras, regra vida zerada, Poke Center flutuante, itens evolução aleatórios no Mart, "batalhar resolve tudo", animações) — a critério do usuário.

**Sessão 0058 (M2b — balanceamento: remover trava S via custo) concluída e validada em 2026-08-27** (refinamento + implementação passos 1–5 + ajuste S3 em 2026-08-27 — commits 938bbbf/dbe8a4f/b46a8a4/d490923/8a051de/06b5d10, suíte 863/3070, lint 0; revisor **Aprovado**): remover **trava dura de 3 S** (`S_LIMIT`/`s_limit_ok?`/`s_limit_notice`/`budget_block_notice` removidos), `TeamBudget.cost_for` **S restrito 60→110** (exceção ao metade floor só para S; demais restritos seguem metade — A 35/B 27/C 20/D 15/F 10, puros S 120/A 70/B 55/C 40/D 30/F 20), **orçamento 450 como único limitador** (4º S puro 480>450 e restrito 470>450 bloqueados só por `fits?`; painel sem `S no time:` — só `Custo do time: X/450` — e badge `S·110 ◆` quando restrito); sem const extra, sem tocar `BUDGET`/wallet nesta sessão (D5 permissivo — poderiam ser tocados futuramente). **Ajuste S3 na validação:** painel `S no time: n/3 → S n` removido completamente (06b5d10), C5 reaberto e revalidado ok. **Próximas candidatas:** bug Q5 (2 cliques — persiste), fila J2/J4/D4 e limitações técnicas (escritas não atômicas, race no add, identidade/CSRF, CI, `pry`, M1 pedras, Poke Center flutuante, itens evolução aleatórios no Mart, "batalhar resolve tudo", animações) — a critério do usuário.

**Sessão 0059 (Q5 — remover em 1 clique, hardening htmx + OOB condicional) concluída e validada em 2026-08-27** (refinamento + implementação passos 1–4 + cleanups 1–4 + validação S2 em 2026-08-27 — commits a715877/8398006/91619c2/86982e9, suíte 869/3150, lint 0; revisor **Aprovado**, sem S3): `DELETE /team` via htmx remove em 1 request idempotente sem re-submit (hardening `hx-disabled-elt`/`hx-sync="closest form:replace"`/`hx-indicator="#team-view"` + `oob_pokemon_list` condicional só quando `starters_visible?` (`q.empty? && offset.zero? && !filter_active? && !sort_active?`, preserva badges `poke-cost` e evita varredura de 27 destaques quando filtrado/paginado/ordenado)). **Próximas candidatas:** bug vida zerada (regra pedida no playtest), fila J2/J4/D4 e limitações técnicas (escritas não atômicas, race no add, identidade `?as=`/CSRF, CI, `pry`, M1 pedras, Poke Center flutuante, itens evolução aleatórios no Mart, "batalhar resolve tudo", animações) — a critério do usuário.

**Sessão 0060 (RESP-1 P0 — viewport + grid + colapso Lista+Time) concluída e validada em 2026-08-27** (refinada em 2026-08-27, passos 1–3 + validação S2 em 2026-08-27, suíte 875/3167 lint 0, revisor **Aprovado** — sem S3): `<meta viewport width=device-width,initial-scale=1>` em `views/layout.erb` + `pokemon-grid` `auto-fill minmax(140px,1fr)` + `list-team-grid` collapse `960` + `img max-width:100%` (viewport libera medias, grid 768 42px→~180px, lista+time 768 empilha). Roadmap ajustado 0063 após 0068 — Onda 1 UX (0060 P0 → 0061 filtros/batalha → 0062 quick-wins), Onda 2 Economia (0064 vida zerada → 0065 death spiral → 0066 pool oponente → 0067 pedras+modais → 0068 resolver batalha → **0063 juice**), Onda 3 Estabilidade (0069 race add → 0070 escritas atômicas → 0071 CSRF → 0072 respiro).

**Sessão 0061 (RESP-1 P1 — filtros 44px + battle 900 + barras fluidas) concluída e validada em 2026-08-27** (refinada em 2026-08-27, passos 1–3 + validação S2 em 2026-08-27, suíte 878/3187 lint 0, revisor **Aprovado** — sem S3): filtros `grid 2col <600 + q full-width + min-height 44px` (grid `1fr 1fr` em 600px, `q` full-width, 44px em todos os controles) + `battle-layout` `1fr` em `900px` + barras `100% max-width 120/80 + min-width:0`/`team-column min-height:auto` em 960 (barras fluidas em 100px).

**Sessão 0062 (RESP-1 P2 — quick-wins maximal) concluída e validada em 2026-08-28** (refinada em 2026-08-28, passos 1–3 + S3 + ajustes pós-validação `Time`/`gap` em 2026-08-28 — commits eda6ea6/caa637b/5eec85b/f85c5f6/b145620, suíte 889/3279 lint 0, revisor Aprovado): Q1 aspas `pokemon.erb` + Q2 limpar filtros flex + Q3 nav wrap/gap/44px + Q4 body 8px@600 + Q5 `78vh→calc(100vh - 110px)` + Q7 badge `Time n/6` via `server.rb` before + OOB `nav-badge` + gap `0.3em`; S3 reindex transacional + OOB nav + 1 clique + pós-validação `Lista`→`Time` + espaço.

**Sessão 0064 (vida-zerada-nao-remove — Onda 2 Economia #1) concluída e validada em 2026-08-28** (refinada + implementada em 2026-08-28 — commits 51a1d6c/f4b5c97/ce060ed/502993a, suíte 906/3367 lint 0, revisor **Aprovado** sem S3): `Pokemon#fainted?` (`hp_max>0 && hp_current==0`) + `alive? = !fainted?` (alinhado a `BattlePokemon#fainted?`) em `lib/pokemon.rb`; `TeamService#remove_member` bloqueia `fainted?` devolvendo `false` + notice error, `views/team.erb` botão "Remover do time" `disabled` + `title="Pokémon derrotado — cure antes de remover"` quando `fainted?`, `DELETE /team` htmx lê `false` e seta `@notice/@notice_kind=:error`; `TeamService#reset` (`POST /journey/restart`) ignora bloqueio e limpa mesmo com todos `fainted?` (`@team.clear` direto) + devolve itens + saldo 200. Decisões: só service guarda (repo burro), `fainted?+alive?` (D5 C), `disabled+title` (D6 A), `false+notice error` (D8 A), `reset` ignora (D7 A), conter P sem death spiral (D9 A, fica p/ 0065). Validação S2 por critério ok (C1-C7 + G1-G3).

**Sessão 0065 (death-spiral-game-over — Onda 2 Economia #2) concluída e validada em 2026-08-28** (refinada + implementada em 2026-08-28 — commits f93671e/ce9ada6/d547d73/26fa4ba, suíte 925/3510 lint 0, revisor **Aprovado** sem S3): death spiral visibilizado sem cura parcial — `HealService#heal` mantém **bloqueio total** quando `balance < cost` (não cura nada, `kind: :error`, `notice "Dinheiro insuficiente para curar (custo X, saldo Y)."`), `JourneyService#game_over?` (`started? && !battle_ready? && !affordable_heal?` via `preview_cost` total) permanece `true` no spiral (todo `fainted?` + sem saldo para cura total) com banner Game Over + CTAs `Vender | Recomeçar` existentes; venda (`POST /mart/sell` + `SellPolicy` 50% + `InventoryRepository#use` + `WalletRepository#grant`) e reset (`POST /journey/restart` + `TeamService#reset` `@team.clear` + `WalletRepository#set` 200) garantidos como breakers no spiral; `preview_cost` (`policy.cost(missing_hp)`, 0.5/Hp) sem mutação e `views/_center.erb` `Custo total` + botão Curar `disabled` quando insuficiente. Decisões: D1 A `death-spiral-game-over`, D2 B médio sem parcial (TeamService + venda entram como breaker, não para curar parcial), D3 A bloqueio total, D4 A nada novo no game over (só regressão), D5 C 7+ com venda/reset, D6 A HealService decide (`cost_per_hp` + `cost(missing)` + `affordable_hp` futuro, mas N/A nesta sessão), D7 A 3 passos (expansível 4–5), D8 A FIFO N/A. Validação S2 por critério ok (C1-C7 + G1-G3).

**Sessão 0066 (pool-oponente-base-form — Onda 2 Economia #3) concluída e validada em 2026-08-29** (refinada em 2026-08-28, implementada em 4 passos + S3 C13 em 2026-08-29 — commits `91e39fa/a0aef8f/5d3ef00/6e8ff83/188026f`, suíte **934/3636**, lint 0, revisor **Aprovado** round 2/3; ajuste S3 C13 paridade de golpes por nível `learnable_moves <= level` últimos 4 + Struggle fallback — Poliwag 4 em nível 1 mantido fiel live API min 1 em gens modernas): pool do oponente filtrado **dentro de `OpponentGenerator`** via `base_checker` injetável + `generation_for ≤ player_generation` + **varredura intercalada single pass** (lotes 24 + `ratings:`) + **orçamento fictício ≤450** + **level = average + delta por banda** + **fallback pool base sem repetição** + paridade de golpes. Validada S2 por critério (C1–C13 + G1–G3 + S3).

**Sessão 0067 (progressao-inicial-nivel5-recompensa — Onda 2 Economia #4) concluída e validada em 2026-08-31** (refinada em 2026-08-29, implementada em 3 passos + ajuste revisor em 2026-08-31 — commits `7c3135e/1943232/0bc0b42/80c83fb`, suíte **959/3697**, lint 0, revisor **Aprovado** round 2/3): time inicial **nível 5 xp 1000** (`cumulative_xp_for(4)=1000`, `level_for_xp(1000)=5`, sem migração retroativa) + **recompensa bypass** `RewardRule#levels_for` win **+2** / draw **+1** / lose **+1** (`money_for` preservado) via `ProgressionRepository#grant_levels` direto no `level` (sem recalcular `level_for_xp`, `ExperienceCurve` vira display) chamado **1× por `:finished`** em `BattleService#grant_finished_xp` (`Set` guard + `finished?`), refletindo em `average_player_level`/banda/`generation_for_level`/`opponent level` (`Set` idempotente, `grant_levels` xp = `cumulative_xp_for(new_level-1)` display-only, banda `D-C` offset 0 para avg5). Validada S2 por critério (C1-C6 + G1-G3 ok, sem S3). **Próxima sessão:** **0068 pedras+modais** (oferta 3 pedras/rodada preço 80 + modais evolução) → **0069 resolver batalha** → **0063 juice** — a critério do usuário.

**Sessão 0068 (pedras-modais — Onda 2 Economia #5) concluída e validada em 2026-08-31** (refinada em 2026-08-31, implementada em 7 passos + registro de gotchas — commits `77c22bc/94780fd/9e33fa8/04d004d/ff840db/91a1274/3884f1a/a00a67c`, suíte **983/3819**, lint 0, revisor **Aprovado** sem S3): **pedras de evolução** — catálogo **6 clássicas** (fire/water/thunder/leaf/moon/sun-stone) `category: "stone"` display pt-BR **price 80** (D3), **oferta 3/rodada por confronto concluído** derivada **sem banco** seed `hash(user_id)+battle_count` via `catalog.shuffle(random:)` (D1/D2), **gate de compra só ofertadas** em `MartService#buy` sem debitar não-ofertada (D7), **`PokeApi#stone_evolutions`** trigger `use-item` com `item` capturado no `stage_details` e rede → `[]` (D4), **modal `#evolution-modal`** overlay real 3 estados (lista por pedra + qtd inventário + botão Evoluir, re-renderiza o mesmo modal, multi-ramo em linhas, role/aria) com botão "Evoluir" por membro em `team_manage.erb`/`team.erb` (D5/D6), uso manual evolui+consome 1 e **`fainted?` bloqueado sem consumir** (D10/C10), pedras **vendáveis 50%** (D9), **evolução automática ortogonal preservada** (D8). Validada S2 por critério (C1–C12 ok + C13 `manual` ok via navegador, sem S3). **Próxima sessão:** **0069 resolver batalha** → **0063 juice** — a critério do usuário.

**Sessão 0069 (resolver-batalha — B5 do `draft-auto-battler.md`, reforço G4 do playtest) concluída e validada em 2026-09-02** (refinada em 2026-09-02, implementada em 5 passos + registro de gotchas — commits `55dac87/25aa981/98411d6/d7a3a93/9f59d2b/92d6547`, suíte **985/3831**, lint 0, revisor **Aprovado** sem S3): **"Batalhar" resolve a batalha inteira num único request** — novo `BattleService#resolve` (loop de `play_round` **atualizando `@rounds`**, débito de itens de **todas** as rodadas — gotcha `items_used_in_round` `lib/battle_service.rb:212-215`, `finish_effects` **1×**, **teto de 100 rodadas** contra loop infinito), `POST /battle/play` passa a resolver tudo (fim das rodadas manuais; `BattleEngine#battle` intocado — 35 callers), **log completo** (limite 3 sai do caminho via modo completo do `BattleLogPresenter`), **botão "Jogar" removido** (só "Batalhar"), UI revela o log **rodada a rodada com animação CSS local** (fade/slide-in escalonado, `prefers-reduced-motion`) **sem polling/SSE e sem novo request**; **economia preservada** (XP/dinheiro 1×, fainted/game over/invalidação intactos). Validada S2 por critério (C1–C8 ok + G1–G3 ok, C8 e parte de C7 `manual` ok via navegador, sem S3). **Próxima sessão após 0069:** **0063 juice** → Onda 3 Estabilidade (race add, escritas atômicas, CSRF, respiro — numeração desliza) — a critério do usuário.

**Sessão 0063 (juice — Onda 2 Economia #6) concluída e validada em 2026-09-08** (refinada em 2026-09-02, implementada em 5 passos + registro de gotchas — commits `0a9e105/be8b08e/6aa4f6e/62d9c7c/938d145/2ccc277`, suíte **995/3938**, lint 0, revisor **Aprovado** sem S3): HP animado (dano/cura) + projéteis C2 (**só ≥900px**; <900px flash no alvo) + flash de dano + KO fade/grayscale + número de dano flutuante + screenshake leve — **CSS-only**, origem calculada no servidor (replay do log), reusa `--log-delay`/stagger da 0069 e `prefers-reduced-motion` desliga tudo, zero JS/polling/SSE — + juice fora da batalha (toast do add + hover/active em botões, §juice `draft-ui-ux.md`) + banner vitória/derrota animado + news de evolução/XP animadas; presenter backwards-compat (`BattleLogPresenter` `from_side`/`to_side` 0/1 mantendo `round/side/text` + `BattleJuicePresenter` HP inicial por replay) sem tocar engine/backend/economia; C1 (texto do log) já atendido. Validada S2 por critério (C1–C4 + G1–G3 ok, C5 `manual` ok via navegador, sem S3). **Próxima após a 0063:** Onda 3 Estabilidade (race add, escritas atômicas, CSRF, respiro — numeração desliza) — a critério do usuário.

**Sessão 0070 (race-no-add-do-time — Onda 3 Estabilidade) concluída e validada em 2026-09-08** (refinada em 2026-09-08, implementada em 4 passos + registro de gotchas — commits `c8bc861/ce4254b/f28860f/828452b/7d3c7e7`, suíte **998/3950**, lint 0, revisor **Aprovado** sem S3): corrige a **race completa do `add`** do time — a colisão de **slot** (`(user_id, slot)`) **e** a de **número duplicado** (`(user_id, number)`), ambas **check-then-insert** que lançam `PG::UniqueViolation` (HTTP 500) sob concorrência — com **um único mecanismo** no `TeamRepository#add` (`lib/team_repository.rb:171-179`): `rescue PG::UniqueViolation` + **retry com re-deriva de `next_free_slot`** (até `MAX_TEAM_SIZE` tentativas), mantendo `TeamFullError` ("Time cheio")/`DuplicateError` ("já está no time") após esgotar. `settings.team` é o `TeamRepository` (`server.rb:1171`), `add` chamado direto do `server.rb:555`; `TeamService` não tem `add`. **Sem migração** (índices únicos já existem em `0007_add_slot.sql`: `(user_id, number)`/`(user_id, slot)`); `ConnectionRegistry` já é thread-safe (conexão por thread) → testes com **threads reais**. Critérios: C1 adds concorrentes sem exceção (N membros, slots `1..N`), C2 re-add mesmo number não duplica, C3 time cheio → `TeamFullError` + aviso sem 500, C4 rota `POST /team` sem 500 sob corrida, C5 sem regressão. Validada S2 por critério (C1–C5 + G1–G3 ok, sem S3). **Próxima após 0070:** **0071 CI/CD** (GitHub Actions + healthcheck) → **0072 escritas atômicas** (batalha/compra) → **0073 CSRF** → **0074 respiro** (numeração desliza) — a critério do usuário.

**Sessão 0071 (ci-cd-healthcheck — CI no GitHub Actions + healthcheck do app/banco) concluída e validada em 2026-09-08** (refinada em 2026-09-08 — decisões D1 A, D2 A, D3 A, D4 A, D5 A, D6 A, D7 A; implementada em 5 passos + fixes de validação — commits `8c7ff87/c912e2e/13fcd68/e30dbba/f4e6152` + `400d5c2/fd81dc6`; suíte **1003/3980**, lint 0, revisor **Aprovado** sem S3): adiciona **CI no GitHub Actions** (workflow `.github/workflows/ci.yml` que roda `test` + `lint` + `check_docs` via `docker compose` fiel ao dev, com cache de camadas do build `docker/build-push-action` `cache-from/to: type=gha` + cache do bundle `actions/cache` em `vendor/bundle` + `Gemfile.lock`; gatilhos `push` main + `pull_request`; qualquer check vermelho bloqueia o merge) e **healthcheck** do app (**nova rota `GET /health`** — 200, sem tocar a rede nem o banco, `before` com `next if /health`) e do banco (`pg_isready` no `docker-compose.yml`), atendendo a limitação **"Sem CI"** (`REQUIREMENTS.md:575-576`). **CD fora de escopo (D7)** — anotado no roadmap para depois. Prova dos critérios via **teste Minitest de estrutura** (`test/ci_structure_test.rb` — YAML load dos workflows e do `docker-compose.yml`, assert jobs/gatilhos/cache/healthcheck; tolera a chave `on` do YAML parseada como boolean pelo Psych) + `test/health_test.rb` (`GET /health` 200). **Fixes de validação (run real no Actions):** `400d5c2` (`docker/setup-buildx-action` — driver `docker-container` para o cache `gha`; o default `docker` não suporta exportar cache) e `fd81dc6` (job `test` aguarda o db saudável com `docker compose up -d --wait db` — race de startup do Postgres, achado A5 do revisor). Validada S2 por critério (C1–C6 + G1–G4 ok, sem S3; run `34276074017` verde). **Próxima após 0071 (fila reordenada em 2026-09-08, decisão do usuário — implementar o `open-design` antes das correções pontuais):** **Onda open-design (portar o redesenho do `open-design/` conforme `migration-guide.md`)** — **0072 open-design-base** (design system: `style.css` tokens + classes, remover sakura + novo `layout.erb` topnav/footer) → **0073 open-design-home** (portar `index`/`team` — roster herói + catálogo de apoio) → **0074 open-design-battle** (portar `battle`/`_fighter_panel` — arena/podium/log/result) → **0075 open-design-history** (portar `history`) → **0076 open-design-modals-filters** (encapsular modais center/mart/membro + ligar filtros `team=in|out`). Depois volta a **Onda 3 Estabilidade (numeração desliza):** **0077 escritas atômicas** (batalha/compra) → **0078 CSRF** → **0079 respiro** — a critério do usuário.

**Sessão 0072 (open-design-base — Onda open-design, 1ª de 5) concluída e validada em 2026-09-09** (refinada em 2026-09-09 — decisões A1 aditivo, B2 sakura fallback até 0076, D1 shell agora; implementada em 5 passos + registro de gotchas — commits `0ff4ee7/a674096/a5ead92/c7cfc41/6777a2c/dd2cf4b/1f776fd`; suíte **1009/4058**, lint 0, revisor **Aprovado** sem S3): adiciona o **design system base** ao `public/style.css` (bloco `:root` com tokens oklch + classes-núcleo `.topnav`/`.btn`/`.container`/`.section`/`.stack`/`.row`/`.card`/`.eyebrow`/`.lead`/`.meta`/`.num`/`.muted`) de forma **aditiva** (preserva juice/responsivo/views; remoção do CSS antigo fica para as sessões de view 0073+) e porta o **shell do `layout.erb`** (topnav + footer + `<link rel="stylesheet" href="/style.css">` + `body page-battle/page-history`), **preservando** o JS de `#global-loading`/scroll-restore e o `<meta name="viewport">` e **mantendo o sakura CDN como fallback até a 0076** (mix visual topnav dark + conteúdo sakura-light é intencional/temporário). Critérios C1–C6 amarrados ao novo `test/design_system_test.rb` (tokens/classes/shell/autonomia/rota `/style.css`/body) + `style_responsive_test.rb`/`layout_test.rb` verdes (regressão G1). Validada S2 por critério (C1–C6 + G1–G3 ok, sem S3; confirmação manual via navegação `/`, `/battle`, `/history`). **Próxima sessão:** **0073 open-design-home** (portar `index`/`team`) → 0074 open-design-battle → 0075 open-design-history → 0076 open-design-modals-filters → 0077 escritas atômicas → 0078 CSRF → 0079 respiro.

**Sessão 0073 (open-design-home — Onda open-design, 2ª de 5) concluída e validada em 2026-09-09** (refinada em 2026-09-09 — decisões A1 index+team adaptativo, B2 `.pcard` agora, C1 sem rota nova, ITEM 3 Gerenciar→`budget-summary`; implementada em 6 passos + ajuste do revisor — commits `1f7f2f5/375e413/5af98e0/c83dbae/e44474c/6580c9e` + `3061b73`; suíte **1011/4124**, lint 0, revisor **Aprovado** em 2 rodadas S7 — achado "botões de serviço mortos" resolvido em `3061b73`, sem S3): porta a **home** (`index` — 2 colunas time+catálogo) e o **`team`** (roster) para o design system, **vestindo a view existente** com as classes novas (§5.2/§5.3 — não clone literal), **preservando** features testadas (▲▼ `name="new_slot"`, badge `#N`, Evoluir por membro, `gameloop-cta Batalhar`, restart game-over, hardening do form Remover, `disabled` fainted); **inclui** `.pcard`/`.pcard-add` (re-marca `pokemon_list_item.erb`: `starter-item`/`list-item`→`.pcard`, botão→`.pcard-add`, B2) e **move** "Gerenciar time" para o `budget-summary` do `index.erb` (ITEM 3); `index.erb` = `section > container > app-head.row-between` (título + `budget-summary` custo/meter + Gerenciar) + `grid-2-1` [ `stack` (team-pane `#team-view` + card services `Saldo`) | `aside.catalog-pane` (`#filter-controls` + `#pokemon-list` como `<div class="catalog">` — NÃO `<ul>`, preserva `hx-swap="innerHTML"`) ], preservando `#pokemon-detail`/`#add-status`/`#filter-controls`/`#team-view`, **sem rota nova** (`team=`/modais center/mart/membro = 0076), sakura mantido até 0076 (B2). Critérios C1–C10 → `test/home_view_test.rb` (novo, estrutural) + `test/design_system_test.rb` (estendido `test_design_system_home_screen_classes`) + editar `test_index_page_uses_full_width_list_body_class` (`.grid-2-1`/`.catalog-pane`, mantém `page-list`), `test_index_renders_clickable_list` (36×`<li class="pcard">`) e `test_team_fragment_manage_link_is_on_its_own_line` (Gerenciar em `budget-summary` no index). Validada S2 por critério (C1–C10 + G1–G3 ok, sem S3; confirmação manual via navegação `/` — roster, catálogo `.pcard`, busca/filtros, remover, Gerenciar no budget-summary; mix topnav dark + sakura-light temporário até a 0076). **Próxima sessão:** **0074 open-design-battle** (portar `battle`/`_fighter_panel` — arena/podium/log/result) → 0075 open-design-history → 0076 open-design-modals-filters → 0077 escritas atômicas → 0078 CSRF → 0079 respiro.

**Sessão 0074 (open-design-battle — Onda open-design, 3ª de 5) concluída e validada em 2026-09-09** (refinada em 2026-09-09 — decisões A1+A1a(i) portar battle inteira, B1+B1b CSS aditivo + juice portado pro ODS, C1 sem rota nova, `.ftags` badges reais ou omitir, manter `data-side`; implementada em 4 passos — commits `05d0a40/693ebad/16d287d` + Passo 5 regressão, suíte **1018/4279**, lint 0, revisor **Aprovado** sem S3):** portar `battle.erb` + `_fighter_panel.erb` (wrapper `battle_page.erb` **intacto**) para o design system — estrutura do protótipo `battle.html` (`.arena` com 2× `ul.fighters` + `.podium` central com round-banner/controles/`.log`/`#result-box`, cobrindo preparado/andamento/fim/game-over), classes de batalha do §1.2 **aditivas no bloco ODS** (traduzidas do `<style>` do `battle.html`, breakpoints ~@980/@700), **juice 0063 portado para os seletores novos DENTRO do bloco** (B1b — `fighter--ko/flash/shooting`, `hp-bar`/`pp-bar`, winner/xp → novos; `prefers-reduced-motion` novo; CSS antigo íntegro → `style_responsive_test.rb` sem edição), **colisão `.fighter` antigo neutralizada por escopo-legado morto** (`.battle-pane .fighter` — única edição fora do bloco), **gates `@message` mantêm `.notice`/`.gameloop-cta` até 0076**, contratos de fragmento `#battle-view` (swap de `POST /battle/play`/`/battle/new`), contexto injetado (`@engine`/presenters) e juice/resolver 0069 preservados. Critérios C1–C7 + G1 + 1 manual → `test/battle_view_test.rb` (novo, estrutural) + `test/design_system_test.rb` (estendido `test_design_system_battle_screen_classes`) + editar `test/battle_routes_test.rb` (`:125-163` hp/pp bars, `:178,256` log, `:269-270` winner/xp, `:337,346-347` ctas fim, `:848,861` verificar gates). Validada S2 por critério (C1–C7 + G1–G3 ok + M1 `manual` ok via navegador, sem S3). **Próxima sessão:** **0075 open-design-history** → 0076 open-design-modals-filters → 0077 escritas atômicas → 0078 CSRF → 0079 respiro.

**Sessão 0075 (open-design-history — Onda open-design, 4ª de 5) concluída e validada em 2026-09-09** (refinada em 2026-09-09 — decisões B portar history+history_page, A escopo history inteira/0076 fica modais-filtros-sakura, C critérios com history_view_test novo + design_system estendido + history_routes editado + style_responsive estendido + 1 manual, A vestir in-place sem rota nova, A CSS aditivo no bloco ODS, A ranking rank-list/rank-row com barra ∝ e .you, A posição pos-card com 3 chips, A batalhas history-list/history-row com badges, A vazio intacto, A 3-4 commits; implementada em 3 passos — commits `aca31eb/25363f9/9e0c1ea`, suíte **1025/4402**, lint 0, revisor **Aprovado** sem S3):** portar `history.erb` + `history_page.erb` (re-marcado com `pagehead`/`container`, wrapper `#history-view` + htmx preservados) para o design system — `.pos-card` (badge + título + 3× `.stat-chip.win/.loss/.draw`, fallback nil no card) + `ul.rank-list>li.rank-row` (`.rank-pos.num` + `.rank-name` + `.rank-bar>span` ∝ `wins/total` + `.rank-wins`, `.you` na linha atual) + `ul.history-list>li.history-row` (`.result-badge.win/.loss/.draw` via `result_label` + `.history-main>.h-title/.h-sub` + `.history-date.num` dd/mm HH:MM), classes de history do §1.2 **aditivas no bloco ODS** (traduzidas do `<style>` do `history.html`; CSS antigo íntegro), `render_history`/`load_history_data` intocados, vazio `p.notice.notice--info` intacto. Critérios C1–C8 + G1–G3 + 1 manual → `test/history_view_test.rb` (novo, estrutural) + `test/design_system_test.rb` (estendido `test_design_system_history_screen_classes`) + editar `test/history_routes_test.rb` (`:19-20` chips, `:23-31` `.you`) + estender `test/style_responsive_test.rb` (`test_history_rows_stack_at_920`, regra nova ≤920px). Validada S2 por critério (C1–C8 + G1–G3 ok + M1 ok via navegador, sem S3). **Próxima sessão:** **0076 open-design-modals-filters** → 0077 escritas atômicas → 0078 CSRF → 0079 respiro.

**Sessão 0076 (open-design-modals-filters — Onda open-design, 5ª de 5, última da onda) concluída e validada em 2026-09-09** (refinada em 2026-09-09 — decisões B fatiar 2a+2b, C overlay híbrido, B data-od-id contrato, C limpeza sob demanda, A tags cor por tipo com backend mínimo listado, B filtros ligar+vestir, B riscos como critérios; fase 2a em 9 passos — commits `9867114`…`540d110`, suíte 1054/4847, revisor Aprovado sem S3, validada 3a S2 C1–C10+G1–G3 ok + M1 ok; fase 2b em 4 passos — commits `43404b3`/`83ee284`/`4049381`/`b9453aa`, suíte **1057/4900**, lint 0 nos rastreados, revisor Aprovado sem S3 com zero re-adicionados):** modais center/mart/membro/evolução em overlay híbrido (`:target` + htmx) + filtros `team=in|out` vestidos + contrato `data-od-id` + tags cor por tipo + curadoria visual fiel, depois remoção sakura + 12 seletores legados + 8 keyframes no bloco (D80 em `.gap-after`); legado remanescente só com uso vivo (`.gameloop-cta` team, `.evolution-*`, reduce). Validada S2 por fatia (3a + 3b: C1–C14+G1–G5 ok + M1/M2 ok, sem S3). **Onda open-design FECHADA (0072→0076). Próxima sessão:** **0077 escritas atômicas** → 0078 CSRF → 0079 respiro.

**Resíduo open-design fatiado por tela e refinado em 2026-09-09 (decisão do usuário — fidelidade híbrida, backend thin listado sem migração, S1 com 1 teste novo por tela + extensões):** **0077 open-design-home-1a1** (`home-team.html` → miolo `_center`/`_mart` + `team_manage`/evolução + list-item/detalhe) → **0078 open-design-battle-1a1** (`battle.html` + end-states + results-desktop → fim de `battle.erb`/`_fighter_panel`, motor só leitura) → **0079 open-design-history-1a1** (curadoria fina 1:1 do `history.html`). **Deslizamento:** antigas 0077 escritas atômicas→**0080**, 0078 CSRF→**0081**, 0079 respiro→**0082**. **Atenção:** `public/style.css` está DIRTY (~1129+/1003-) — o implementador deve conferir/stash antes de editar o CSS. **Próxima sessão:** **0077** → 0078 → 0079 → 0080 escritas atômicas → 0081 CSRF → 0082 respiro.

**Tuning de economia/progressão refinado em 2026-09-10 (decisão do usuário — objetivo B reconciliar + conter inflação, escopo B médio, critérios A granulares, P1-A lose 0, P2-A cura escala com nível médio, P3-A reconciliação real, oponente fora, 1 sessão):** **0081 tuning-economia-progressao** (C1 lose→`reward_rule_test`, C2 cura→heal tests, C3 XP/sweep→progression+battle tests) → **deslizamento:** center-mart-modal-only→**0082**, escritas atômicas→**0083**, CSRF→**0084**, respiro→**0085**. **Próxima sessão:** **0081** → 0082 → 0083 → 0084 → 0085 (0080 validada em 2026-09-10 — RNF-04 liberada para a 0081 implementação; **0078 implementada** (Passos 1–3 `9b421c4`/`924e5b6`/`4604ee9`, **aguarda validação do usuário**) e **0079 com TDD concluído** (**aguarda revisão S7** e depois validação); 0077 segue com fase 2 pendente).

**Próxima sessão (2026-09-14):** **0083-ui-polish** (fase 2 pendente) — **0086-battle-log-juice concluída e validada em 2026-09-14** (S2 C1–C15+G1 ok, aprovação em bloco; suíte 1171/6107, lint 0) → 0083 na sequência (0082 Done em 2026-09-11; merge B->D->C).

> **Fase Eco concluída (Eco-1..4 — sessões 0027..0032).** Respiro 2 concluído e validado
> (0033). D1 parcial concluído e validado (0034). **P1 concluído e validado (0035,
> 2026-08-19 — GET /battle ~38s, 2º play ~4s)**. **J1 concluído e validado (0036,
> 2026-08-22 — dropdown fora, jornada com gate e formas base/iniciais 27)**.
> **JN-2 concluído e validado (0037,
> 2026-08-22 — golpes em lista clicável, rascunho sem persistir)**. **Onda 0 UX
> concluída e validada (0038, 2026-08-22 — acessibilidade, copy pt-BR, notices,
> indicador; UX priorizada antes da fila por decisão do usuário)**. **JN-1 concluído e validado
> (0039, 2026-08-22 — telas próprias, nav real com estado ativo, htmx intra-tela)**.
> **J3 concluído e validado (0040, 2026-08-23 — ranking S–F, banda por nível no
> `OpponentGenerator`; suíte 649/2063, lint 0; perf da 1ª batalha ~2min anotada)**.
> **0041 (Onda 2 UX — leitura da batalha) concluída e validada (2026-08-23 — suíte
> 680/2132, lint 0)**: `Move#pp_max` + `FighterPresenter`/`BattleLogPresenter` puros,
> partial único dos painéis com barras HP/PP, log das últimas 3 rodadas e
> `hx-indicator` no botão Jogar; ajuste S3 de layout em 3 colunas (Seu Time esq,
> controles centralizados + log centro, Oponente dir, tela cheia). Próximas: ondas
> 1–3 de UX restantes → organizar o resto (JN-3, JN-4, JN-5, J2, J4, D4).

**Próxima sessão (2026-09-15):** **0087-strike-fx-chegada-real** — Efeitos de golpe: projétil com chegada real (borda→borda do alvo) e gate por container query (CSS-only, sem JS além do htmx). Status: **concluída e validada em 2026-09-15** (Passos 1–7 `0637cb6`…`49ffd74`, suíte 1173/6159 lint 0, revisor Aprovado rounds 1–2, S2 C1–C9+G1–G3 ok sem `nok`; S3 C9/C15 da 0086 reaprovadas; o Passo 7 fechou a fragilidade de layout com guarda e2e ao vivo).

**Próxima sessão (2026-09-15):** **slot a slot (candidato a refinamento — ainda sem arquivo de sessão)** — item registrado em `docs/draft-backlog.md` (2026-09-15): o projétil deve sair do slot do pokémon atacante e chegar ao slot do alvo (hoje é um rail horizontal de caixa de time a caixa de time). Exige identidade do slot no markup/engine e decisão entre JS ponto-a-ponto, CSS por índice ou CSS anchor positioning. Sujeito à próxima sessão, mas **apenas candidato** — sem arquivo em `sessions/` e **sem linha na tabela de progresso** até o refinamento (S5b).

**Próxima sessão (2026-09-15):** **0088-projetil-slot-a-slot** — o projétil sai do slot do pokémon atacante e chega ao slot do pokémon alvo em x e y (progressive enhancement sobre o rail CSS da 0087, que passa a fallback). Status: **concluída e validada em 2026-09-15** pelo usuário (Passos 1–6 `6e1caa3`…`d5a06dd` + fix S3 `a9949dc` + draft `3484260`; suíte 1180/6219 lint 0; revisão `Aprovado` `reviews/review-2026-09-15T14-00-01-passos1-6-0088.md`; S2 C1–C9+G1–G3 ok sem `nok`; exceção ao RNF-01 reaprovada na validação).

**Próxima sessão (2026-09-15):** **nenhuma sessão agendada.** A 0088 (última) foi validada em 2026-09-15 e não há novo arquivo em `sessions/` a abrir; sem linha na tabela de progresso para sessão sem arquivo (S5b). Os candidatos abertos vivem em `docs/draft-backlog.md` — a triagem dos achados não bloqueantes das revisões da **0087** e da **0088** (`docs/draft-backlog.md:210-245`) e a dívida pré-existente (os 4 e2e vermelhos de `buildTeamOfSix`, o flake de ordem do `ConnectionRegistryTest`, o e2e fora do CI).

**Próxima sessão (2026-09-16):** **0083-ui-polish** (refinada, fase 2 pendente) — a **0078** e a **0079** foram validadas pelo usuário em 2026-09-16 (S2 por critério, sem `nok`), encerrando o resíduo open-design por tela; a fila volta para a 0083.

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
| 0039 | JN-1 — telas próprias (fim do empilhamento): páginas próprias por rota com layout (Lista/Time/Batalha/Histórico), nav real com estado ativo, htmx intra-tela (`#team-view`/`#battle-view`/`#pokemon-detail`/`#add-status`), add → mini-status, remoção do span hack/_close/teamRefresh | Concluída | Done (passos 1–6, suíte 626/2017, lint 0, validado em 2026-08-22) |
| 0040 | J3 — ranking S–F (balanceamento de oponentes): `PokemonRating` (domínio puro) classifica Pokémon em S–F por stats ponderados + bônus dos moves (top-4, STAB-aware), consumido pelo `OpponentGenerator` via banda de tier derivada do nível médio do jogador (fim do sorteio puro), retorno score + tier sem UI | Concluída | Done (passos 1–5, suíte 649/2063, lint 0, validado em 2026-08-23; `GET /battle` ~2min na 1ª chamada — perf anotada) |
| 0041 | Onda 2 UX — leitura da batalha: fim da duplicação dos painéis (partial único `_fighter_panel.erb` + `FighterPresenter`/`BattleLogPresenter` puros em `lib/`), barras visuais de HP/PP (tokens do draft-design-system §3), log das últimas 3 rodadas (mais recente no topo) e `hx-indicator` local no botão Jogar; `Move#pp_max` (default = pp) | Concluída | Done (passos 1–5 + ajuste S3 de layout em 3 colunas — Seu Time esq, controles centralizados + log centro, Oponente dir, tela cheia; suíte 680/2132, lint 0, validado em 2026-08-23) |
| 0042 | Onda 1 UX — jornada visível (Caminho B): página única `/` de 2 colunas (busca + lista à esquerda, painel do time com contador n/6 + membros à direita), página `/team` removida (404 direto, fragmento htmx interno preservado), nav sem link "Time", estados do botão Add (default / "No time ✓" / cheio via `@team_names`) | Concluída | Done (passos 1–6 + ajustes S3 — add/remove re-renderizam `#pokemon-list` via `hx-swap-oob`, link "Gerenciar time" em `<p>` próprio; suíte 689/2184, lint 0, validado em 2026-08-24) |
| 0043 | Estabilidade do banco (correção direta, fora da fila): fim do "too many clients" na suíte — `ConnectionRegistry` registra as conexões dos repositórios e o `after_teardown` fecha todas após cada teste (pico 74 → 9), 7 repositórios/seed registrando conexão; warnings de constante nos seeds eliminados (`unless defined?` em `saldo_inicial.rb`) | Concluída | Done (passos 1–2, suíte 692/2193, lint 0, validado em 2026-08-24) |
| 0044 | Onda 3 UX — estrutura: grade uniforme de 6 colunas com páginas cheias e paginação on-demand (`PAGE_SIZE` 36 = grid 6×6; página 1 = 27 iniciais + 9 comuns; cada página carrega só o próprio lote) corrigindo o bug visual do item e os slots vazios + largura cheia do Histórico (`body.page-history`); corrigidos também conexão PG por thread e banco de teste separado (fim do flakiness) | Concluída | Done (passos 1–3 + ajustes S3, suíte 694/2200, lint 0, validado em 2026-08-24) |
| 0045 | JN-3 — itens de uso único por Pokémon: regra de **1 uso de item curativo por Pokémon por batalha** (`@items_used_by_member` no `BattleEngine`, bloqueio de novo uso do mesmo membro — pool comum e item atribuído) + badge "já usou item" por membro no painel do lutador | Concluída | Done (passos 1–3, suíte 701/2222, lint 0, validado em 2026-08-24; JN-3-B anotado — equipamento por quantidade do estoque) |
| 0046 | JN-3-B — equipamento por quantidade do estoque: equipar **debita**, desequipar **repõe**, trocar **repõe o antigo e debita o novo**, re-equipar o mesmo item **não debita de novo**; item atribuído consumido em batalha **não debita de novo** e limpa o `assigned_item`; UI com quantidade livre + option `disabled` ×0 | Concluída | Done (passos 1–3 + correções de UI na validação, suíte 718/2294, lint 0, validado em 2026-08-24; resíduo anotado — scroll ainda pula p/ baixo) |
| 0047 | JN-4 — componentes de Poke Mart e Poke Center: blocos de `views/team.erb` viram partials reutilizáveis (`_mart.erb`/`_center.erb`) no painel do time, com cura completada (HP atual/máx + custo total antecipado, Curar desabilitado quando curado/insuficiente) e compra completada (preço × quantidade comprável, botão desabilitado quando saldo < preço); sem rotas/páginas novas | Concluída | Done (passos 1–3, suíte 724/2329, lint 0, validado em 2026-08-24; `team_hp.erb` removido) |
| 0048 | JN-5 — gameloop: circuito explícito por CTAs (fluxo guiado) — fim de batalha mostra CTAs Poke Center/Poke Mart (levam à Lista `/`) + "Novo confronto" mantido; painel do time pós-jornada ganha CTA "Batalhar" (`/battle`); nav permanece Lista/Batalha/Histórico; sem páginas/rotas novas | Concluída | Done (passos 1–2, suíte 727/2344, lint 0, validado em 2026-08-25; anotações RNF-04 registradas) |
| 0049 | BUG-1/Q1 — oponente novo a cada confronto + máquina de estado do gameloop: fim da seed fixa por usuário (`opponent_rng` injetável, default `Random.new`) + reuso da batalha ativa por estado (preparada → re-deriva o time preservando o oponente; em andamento/finalizada → preserva), "Novo confronto" via `POST /battle/new`, add/remove/move invalidam a batalha | Concluída | Done (passos 1–5, suíte 735/2358, lint 0, validado em 2026-08-25; ajuste S3 — C1 reprovado e reaberto: oponente trocava a cada acesso) |
| 0050 | P2 — performance da varredura da banda do oponente: varredura **paralela em lotes** no `OpponentGenerator` (caminho `ratings:` nome→tier, determinística por seed) + **cap de varredura** `max_candidates:` com fallback puro + **cache de rating persistente** (`PokemonRatingCache`, keyed por nome, TTL 7d, write-through) + **C4-b (S3): escrita do cache HTTP coalescida** (`PersistentJsonStore` — store em memória + writer background + `flush!`) | Concluída | Done (passos 1–7, suíte 751/2391, lint 0, validado em 2026-08-25; ajuste S3 — C4 reaberto e resolvido no C4-b: 1ª batalha ~60s → 2.81s / frio real 1.64s; anotado GL-2 — trava para time com HP zerado) |
| 0051 | BUG-4 — vazamento de conexões PG em produção (`ConnectionRegistry` só limpa no `after_teardown`; app acumulou 80 conexões no benchmark e derrubou a suíte): **liberação por request** (`after` no `server.rb` → `release_current_thread!`) + **teto global** `MAX_CONNECTIONS` 30 com evicção (thread morta primeiro, senão LRU), isolamento por thread (0044) preservado | Concluída | Done (passos 1–3, suíte 755/2404, lint 0, validado em 2026-08-25; `pokedex` estável em 14 conexões — antes 80 — e suíte verde com o `web` ativo) |
| 0052 | QA Q2+Q3+GL-2 — gate da jornada por tamanho do time (Q3: `started?` = `team >= 6`, flag deixa de liberar — remover abaixo de 6 re-bloqueia), gate de HP no `/battle` (GL-2: `battle_ready?` com poke cheio se nunca lutou, aviso+CTA "cure no Poke Center", CTA "Batalhar" escondido no painel, botão "Novo confronto" desabilitado na tela de fim após derrota) e itens devolvidos no remove (Q2: `TeamService#remove_member` repõe `assigned_item`/`held_item` ao estoque) | Concluída | Done (passos 1–3 + ajuste S3, suíte 770/2473, lint 0, validado em 2026-08-25; flag `user_state` vira vestigial — anotado no draft) |
| 0053 | QA Q4+Q5+GL-1 — aviso de busca base-form, remoção em 1 clique e game over (vender/recomeçar): **Q4** hint informativo quando o termo só casa com não-base/starter (aponta a evolução base ou os destaques iniciais); **Q5** remoção robusta (investigação do "2 cliques" intermitente — hardening `hx-disabled-elt` no form + idempotência); **GL-1** game over = time todo zerado **e** saldo < custo da cura (`game_over?` no `JourneyService`), com venda de itens (`POST /mart/sell` + `SellPolicy` 50% do preço) e recomeço da jornada (`POST /journey/restart` — `TeamService#reset` em lote devolvendo itens + `WalletRepository#set` p/ saldo inicial 200) | Concluída | Done (passos 1–8 + ajustes S3, suíte 804/2623, lint 0, validado em 2026-08-25; game over também na tela de fim de batalha; fix do 500 no recomeçar — reset em lote; lista de venda sem `0×`; `#pokemon-list` refrescada via OOB após recomeçar) |
| 0054 | Limitação técnica — erros com status real: handler global `error 500 do` passa a devolver **status 500** nas requisições **não-htmx** (monitoria/healthcheck/navegação direta) e mantém **200 + fragmento** (`views/error.erb`) nos swaps **htmx** (`htmx_request?`), preservando o log do erro original — fragmentos amigáveis 200 por rota (decisão 0018) e `halt 404` ficam fora | Concluída | Done (fase 2 + validação do usuário em 2026-08-26; C1/C2 por teste, C3-log `manual`; suíte 805/2630, lint 0) |
| 0055 | M2 — sistema de custo para montagem de time: custo pelo **tier da linha evolutiva** (maior tier da cadeia, via `PokemonRatingCache` — S=120/A=70/B=55/C=40/D=30/F=20), **metade do custo** para restrição de evolução (novo `evolution_restricted?` no gateway), **teto duro de 3 Pokémon S por time** + **orçamento de montagem 450** validados em todo `POST /team` como **limites derivados — sem tocar o wallet/Eco**; painel do time mostra custo/orçamento/contagem de S | Concluída | Done (passos 1–4, suíte 819/2701, lint 0, validado em 2026-08-26; UX-2 e bug Q5 2 cliques anotados como candidatos) |
| 0056 | UX-2 — custo e tier na listagem (M2): exibir custo e tier da linha evolutiva na `GET /` via badge inline em `pokemon_list_item.erb` (`poke-cost` + `data-tier`, S=120/A=70/B=55/C=40/D=30/F=20, restrito = metade floor) com cor por tier, reusando `PokemonRatingCache`/`TeamBudget`/`evolution_restricted?` (line_tier = máx. da cadeia via `evolutions` do batch 24, sem fetch extra); paginação/busca preservadas e sem rede, OOB da lista, visual com `manual` | Concluída | Done (passos 1–3, suíte 826/2748, lint 0, validado em 2026-08-26) |
| 0057 | UX-2b — filtros avançados + ordenação + alinhamento lista↔time: filtros combináveis tipo+geração+custo/tier (line_tier = máx. da cadeia + metade restrito via `TeamBudget`/`evolution_restricted?`), ordenação por custo/tier, botão "limpar filtros", persistência em `session[:list_filters]` e alinhamento das colunas da `/` (server-side no `load_pokemon_page`, batch 24, `PAGE_SIZE` 36, novo `generation_for`/`pokemon_names_by_type` via `/type`, debounce 300ms, sem rede, OOB preservado) | Concluída | Done (passos 1–4 + 4a–4e + S3 4b–4e, suíte 854/3016, lint 0, validado em 2026-08-26; revisor Aprovado 2/3) |
| 0058 | M2b — balanceamento: remover trava S via custo (S_rest 110, orçamento único limitador) — S restrito 60→110 (exceção ao metade floor só para S), remover `S_LIMIT`/`s_limit_ok?`/`s_limit_notice`/`budget_block_notice`, painel sem `S no time:` (só `Custo do time: X/450`) e badge `S·110 ◆` quando restrito | Concluída | Done (passos 1–5 + ajuste S3 06b5d10, suíte 863/3070, lint 0, validado em 2026-08-27; revisor Aprovado; S_rest 110, orçamento 450 único limitador, painel sem S) |
| 0059 | Q5 — remover em 1 clique (hardening htmx + OOB condicional) — DELETE htmx em 1 request, idempotente, sem re-submit + OOB condicional só quando starters visíveis | Concluída | Done (passos 1–5 + cleanups 1–4, suíte 869/3150 lint 0, validado em 2026-08-27; revisor Aprovado) |
| 0060 | RESP-1 P0 — viewport + grid + colapso Lista+Time (Onda UX): `<meta viewport>` + `pokemon-grid` auto-fill `minmax(140px,1fr)` + `list-team-grid` collapse `960` + `img max-width:100%` | Concluída | Done (passos 1–3, suíte 875/3167 lint 0, validado em 2026-08-27; revisor Aprovado) |
| 0061 | RESP-1 P1 — filtros 44px + battle 900 + barras fluidas (Onda UX): grid 2col <600 + q full-width 44px, battle 1fr em 900, barras 100% max-width + team-column auto 960 | Concluída | Done (passos 1–3, suíte 878/3187 lint 0, validado em 2026-08-27; revisor **Aprovado**, sem S3) |
| 0062 | RESP-1 P2 — quick-wins maximal (aspas+nav+padding+calc+badge) — Q1 aspas `pokemon.erb` + Q2 limpar filtros flex + Q3 nav wrap/gap/44px + Q4 body 8px@600 + Q5 `78vh→calc(100vh - 110px)` + Q7 badge `Time n/6` via `server.rb` before+OOB; S3 reindex transacional + OOB nav + 1 clique + pós `Lista`→`Time` gap | Concluída | Done (passos 1–3 + S3 + ajustes Time/gap, suíte 889/3279 lint 0, validado em 2026-08-28; revisor Aprovado) |
| 0064 | vida-zerada-nao-remove — Onda 2 Economia #1: `Pokemon#fainted?`+`alive?` + `TeamService#remove_member` bloqueia fainted (`false+notice error`) + `views/team.erb` `disabled+title` + `DELETE /team` htmx bloqueado + `POST /journey/restart` ignora e limpa | Concluída | Done (passos 1–4, suíte 906/3367 lint 0, validado em 2026-08-28; revisor **Aprovado** sem S3) |
| 0065 | death-spiral-game-over — Onda 2 Economia #2: heal trap visibilizado (bloqueio total, sem cura parcial) + `game_over?` no spiral + banner Vender/Recomeçar + venda/reset como breakers + `preview_cost` | Concluída | Done (passos 1–3, suíte 925/3510 lint 0, validado em 2026-08-28; revisor **Aprovado** sem S3) |
| 0066 | pool-oponente-base-form — Onda 2 Economia #3: pool só base-form + geração ≤ player_generation + orçamento fictício ≤450 + level average+delta por banda + paridade de golpes por nível (learnable ≤ level, últimos 4, Struggle fallback — Poliwag 4 em nível 1 fiel), via `base_checker` injetável em `OpponentGenerator` com varredura intercalada (single pass) lotes 24 + cache 7d + cap 256 + fallback base sem repetição | Concluída | Done (4 passos + S3 C13, suíte 934/3636 lint 0, validada em 2026-08-29; revisor Aprovado round 2/3; S3 formal 6e8ff83 antes de 188026f) |
| 0067 | progressao-inicial-nivel5-recompensa — Onda 2 Economia #4: progressão inicial nível 5 xp 1000 + recompensa +2/+1 via bypass grants (TeamRepository 5/1000 sem migração, RewardRule levels_for win2/draw1/lose1, ProgressionRepository grant_levels direto, BattleService guard 1× `Set`, ExperienceCurve display, oponente escala de 5) | Concluída | Done (refinada 2026-08-29, 3 passos + ajuste revisor `80c83fb`, suíte 959/3697 lint 0, revisor Aprovado 2/3, validada em 2026-08-31 — S2 C1-C6+G1-G3 ok) |
| 0068 | pedras-modais — Onda 2 Economia #5: pedras de evolução (catálogo 6 clássicas `category: stone` price 80, oferta 3/rodada derivada seed `hash(user_id)+battle_count` sem banco, gate de compra só ofertadas, `PokeApi#stone_evolutions` use-item com `item` no stage_details, modal `#evolution-modal` 3 estados + botão Evoluir por membro, fainted bloqueado sem consumir, venda 50%, automática ortogonal) | Concluída | Done (refinada 2026-08-31, 7 passos + gotchas `a00a67c`, suíte 983/3819 lint 0, revisor Aprovado sem S3, validada em 2026-08-31 — S2 C1-C12 ok + C13 manual ok) |
| 0069 | resolver-batalha — B5 "Batalhar" resolve a batalha inteira num único request (novo `BattleService#resolve` loopa rodadas atualizando `@rounds` com teto 100, debita itens de todas as rodadas — gotcha `items_used_in_round`, `finish_effects` 1×, `BattleEngine#battle` intocado; `POST /battle/play` resolve tudo, log completo via `BattleLogPresenter` modo completo, botão "Jogar" removido, UI revela o log com animação CSS local + `prefers-reduced-motion` sem polling/SSE; economia preservada) | Concluída | Done (refinada 2026-09-02, 5 passos + gotchas `92d6547`, suíte 985/3831 lint 0, revisor Aprovado sem S3, validada em 2026-09-02 — S2 C1-C8 ok + G1-G3 ok, C8 e parte de C7 manual ok via navegador) |
| 0063 | juice — Onda 2 Economia #6: HP animado (dano/cura) + projéteis C2 (só ≥900px; <900px flash no alvo) + flash de dano + KO fade/grayscale + número de dano flutuante + screenshake leve — CSS-only, origem calculada no servidor (replay do log), reusa `--log-delay`/stagger da 0069, `prefers-reduced-motion` desliga tudo, zero JS/polling/SSE — + juice fora da batalha (toast do add + hover/active em botões) + banner vitória/derrota + news evolução/XP animadas; presenter backwards-compat (`from_side`/`to_side` 0/1 + `BattleJuicePresenter` HP inicial por replay) sem tocar engine/backend/economia | Concluída | Done (refinada 2026-09-02, 5 passos `0a9e105`…`2ccc277`, suíte 995/3938 lint 0, revisor Aprovado sem S3, validada em 2026-09-08 — S2 C1-C4+G1-G3 ok + C5 manual ok) |
| 0070 | race-no-add-do-time — Onda 3 Estabilidade: race completa do `add` (colisão de slot `(user_id, slot)` + número duplicado `(user_id, number)`, ambas check-then-insert → `PG::UniqueViolation` 500) corrigida via `rescue PG::UniqueViolation` + retry com re-deriva de `next_free_slot` no `TeamRepository#add` (até `MAX_TEAM_SIZE` tentativas), mantendo `TeamFullError`/`DuplicateError`; sem migração (índices únicos já existem em `0007_add_slot.sql`); testes com threads reais (C1-C5) | Concluída | Done (refinada 2026-09-08, 4 passos `c8bc861`…`7d3c7e7`, suíte 998/3950 lint 0, revisor Aprovado sem S3, validada em 2026-09-08 — S2 C1-C5+G1-G3 ok) |
| 0071 | ci-cd-healthcheck — CI no GitHub Actions (workflow `test`+`lint`+`check_docs` via `docker compose`, cache de camadas do build `type=gha` + cache do bundle `vendor/bundle`+`Gemfile.lock`, gatilhos push main + pull_request, check vermelho bloqueia merge) + healthcheck do app (nova rota `GET /health` 200 sem rede) e do banco (`pg_isready` no `docker-compose.yml`); atende a limitação "Sem CI"; **CD fora de escopo (D7)**; prova via teste de estrutura (`ci_structure_test.rb` YAML load) + `test_health_returns_ok`; run verde no Actions é confirmação manual | Concluída | Done (refinada 2026-09-08, 5 passos `8c7ff87`…`f4e6152` + fixes `400d5c2`/`fd81dc6`, suíte 1003/3980 lint 0, revisor Aprovado sem S3, validada em 2026-09-08 — S2 C1-C6+G1-G4 ok, run 34276074017 verde) |
| 0072 | open-design-base — Onda open-design (1ª de 5): design system `public/style.css` (bloco `:root` com tokens oklch + classes-núcleo topnav/btn/container/section/stack/row/card/eyebrow/lead/meta/num/muted) **aditivo** (preserva juice/responsivo/views) + shell `views/layout.erb` (topnav + footer + `<link rel="stylesheet" href="/style.css">` + `body page-battle/page-history`, preserva JS `#global-loading`/scroll-restore, **sakura mantido até a 0076**); critérios C1–C6 → `test/design_system_test.rb` + rota `/style.css`; sem regressão de `style_responsive_test.rb`/`layout_test.rb` | Concluída | Done (refinada 2026-09-09, 5 passos `0ff4ee7`…`1f776fd`, suíte 1009/4058 lint 0, revisor Aprovado sem S3, validada em 2026-09-09 — S2 C1-C6+G1-G3 ok, sem S3) |
| 0073 | open-design-home — Onda open-design (2ª de 5): portar `index` (2 colunas time+catálogo) + `team` (roster) para o design system (§5.2/§5.3) **vestindo a view existente** (A1 — não clone literal), **incluindo** `.pcard`/`.pcard-add` (re-marcar `pokemon_list_item.erb`: `starter-item`/`list-item`→`.pcard`, botão→`.pcard-add`; B2) e **movendo** "Gerenciar time" para o `budget-summary` do `index` (ITEM 3); `index.erb` = `section > container > app-head.row-between (título + budget-summary custo/meter + Gerenciar) + grid-2-1 [ stack (team-pane `#team-view` + card services Saldo) | aside.catalog-pane (`#filter-controls` + `#pokemon-list` como `<div class="catalog">` — NÃO `<ul>`, preserva `hx-swap="innerHTML"`) ]`, preservando `#pokemon-detail`/`#add-status`/`#filter-controls`/`#team-view`, **sem rota nova** (`team=`/modais center/mart/membro = 0076), sakura mantido até 0076; critérios C1–C10 → `test/home_view_test.rb` (novo) + `test/design_system_test.rb` (estendido `test_design_system_home_screen_classes`) + editar `test_index_page_uses_full_width_list_body_class` (`.grid-2-1`/`.catalog-pane`), `test_index_renders_clickable_list` (36×`.pcard`) e `test_team_fragment_manage_link_is_on_its_own_line` (budget-summary em index) | Concluída | Done (refinada 2026-09-09, 6 passos `1f7f2f5`…`6580c9e` + ajuste revisor `3061b73`, suíte 1011/4124 lint 0, revisor Aprovado 2 rodadas S7 sem S3, validada em 2026-09-09 — S2 C1-C10 + G1-G3 ok, sem S3) |
| 0074 | open-design-battle — Onda open-design (3ª de 5): portar `battle` (`.arena` com 2× `ul.fighters` + `.podium` central round-banner/controles/`.log`/`#result-box`, cobrindo preparado/andamento/fim/game-over) + `_fighter_panel` (card `.fighter`/`.fighter-id`/`.fmeta`/`.ftags`/`.hp`/`.bar`/`.hp-val`/`.moves`/`.move`) para o design system (§1.2, traduzido do `<style>` do `battle.html` com breakpoints ~@980/@700), **vestindo a view existente** (A1+A1a(i), `battle_page.erb` wrapper intacto); CSS **aditivo** no bloco ODS (B1) com **colisão `.fighter` neutralizada por escopo-legado morto** (`.battle-pane .fighter` — única edição fora do bloco); **juice 0063 portado para os seletores novos DENTRO do bloco** (B1b: `fighter--ko/flash/shooting`, `hp-bar`/`pp-bar`, winner/xp → novos; `prefers-reduced-motion` novo; CSS antigo íntegro → `style_responsive_test.rb` sem edição); **gates `@message` ficam `.notice`/`.gameloop-cta` até 0076**; preserva `#battle-view` (swap de `POST /battle/play`/`/battle/new`), contexto injetado (`@engine`/presenters), juice (data attrs/`--log-delay`/`data-side` mantido) e resolver 0069; `.ftags` = badges reais do presenter (usado/carrega/segura) ou omitir — presenter intocado; critérios C1–C7 + G1 + 1 manual → `test/battle_view_test.rb` (novo) + `test/design_system_test.rb` (estendido `test_design_system_battle_screen_classes`) + editar `test/battle_routes_test.rb` (`:125-163` hp/pp bars, `:178,256` log, `:269-270` winner/xp, `:337,346-347` ctas fim, `:848,861` verificar gates) | Concluída | Done (refinada 2026-09-09, 4 commits, suíte 1018/4279 lint 0, revisor Aprovado sem S3, validada em 2026-09-09 — S2 C1-C7+G1-G3 ok + M1 manual ok) |
| 0075 | open-design-history — Onda open-design (4ª de 5): portar `history.erb` + `history_page.erb` para o design system (`.pos-card` com badge + 3× `.stat-chip.win/.loss/.draw` + fallback nil no card, `ul.rank-list>li.rank-row` com `.rank-bar>span` ∝ `wins/total` + `.you`, `ul.history-list>li.history-row` com `.result-badge` + `.history-main` + `.history-date` dd/mm HH:MM, CSS aditivo no bloco ODS, vestir in-place sem rota nova, vazio `notice--info` intacto); critérios C1–C8 → `test/history_view_test.rb` (novo) + `test/design_system_test.rb` (estendido) + editar `test/history_routes_test.rb` + estender `test/style_responsive_test.rb` + 1 manual | Concluída | Done (refinada 2026-09-09, 3 passos `aca31eb`…`9e0c1ea`, suíte 1025/4402 lint 0, revisor Aprovado sem S3, validada em 2026-09-09 — S2 C1-C8+G1-G3 ok + M1 ok) |
| 0076 | open-design-modals-filters — Onda open-design (5ª de 5, última): modais em overlay HÍBRIDO (`:target` + htmx, rotas `GET /team/center\|/team/mart` + evolution/manage no mesmo padrão) + filtros `team=in|out` vestidos no ODS + contrato `data-od-id` nas 4 superfícies + tags cor por tipo com dado real (toca backend/presenter — mínimo listado, sem migração) + curadoria visual; fase 2a (C1–C10, legado intacto) → validação 3a, fase 2b limpeza sob demanda (C11–C14: sem sakura, colisões D71, juice do bloco) → validação 3b; riscos D71/D86/D88/D94 como critérios; testes novos `modal_routes` + `open_design_contract`, estendidos `design_system`/`home/battle/history_view`/`pokemon_list_filters` | Concluída | Done (refinada 2026-09-09, 2a em 9 passos `9867114`…`540d110` suíte 1054/4847 + 2b em 4 passos `43404b3`…`b9453aa` suíte 1057/4900 lint 0, revisor Aprovado 2 rodadas S7 sem S3, validada 3a+3b em 2026-09-09 — S2 C1-C14+G1-G5 ok + M1/M2 ok — **onda open-design fechada**) |
| 0077 | open-design-home-1a1 — Resíduo open-design (1ª de 3, por tela): `home-team.html` → miolo `_center` (`heal-list`/`heal-item`) + `_mart` (`mart`/`mart-name`/`item-icon`/`price`/`tabs`) + `team_manage` (`stat-grid`/`mv-row`/`evo-row`/`equip-row`) + `_evolution_modal` (padrão `.modal`) + `pokemon_list_item` (`pcard-meta`/`name`) + `pokemon_detail` (`tag-row`/`stat-grid`/`evo-row`); fidelidade híbrida, backend thin listado (5 renders, sem migração), CSS ANTES da linha `fim` com delimitador `0077`; critérios C1–C4 → `test/home_residue_test.rb` (novo: `test_center_mart_inner`/`test_manage_evolution`/`test_catalog_detail`) + extensões cirúrgicas + 1 manual | Concluída | Done (Passos 1–5 `ea7192a`/`a00db99`/`2671204`/`d0832bf`/`d922add`; bloco CSS `Home 1:1 (0077)` entrou em `4f1538c`; suíte 1180/6217 lint 0, revisor Aprovado `reviews/review-2026-09-16T21-42-00-0077-rodada2.md`, validada em 2026-09-16 — S2 C1–C4+G1–G3+M1 ok, sem `nok`) |
| 0078 | open-design-battle-1a1 — Resíduo open-design (2ª de 3, por tela): `battle.html` + `battle-end-states.html` + `battle-results-desktop.html` (nunca portados) → fim de `battle.erb` (`res-screen`/`state-card`/mini-arena, 4 estados) + fim de `_fighter_panel`; fidelidade híbrida, `resolve`/`finish_effects`/`expose_battle_result` só leitura, CSS ANTES da linha `fim` com delimitador `0078`; critérios C1–C3 → `test/battle_end_states_test.rb` (novo: `test_battle_end_states`/`test_results_card_rewards`) + extensões cirúrgicas + 1 manual | Concluída | Done (Passos 1–3 `9b421c4`/`924e5b6`/`4604ee9` + ajustes S7 `814b722`/`be93e68`/`3770ba2`, suíte 1180/6217 lint 0, revisor Aprovado `reviews/review-2026-09-16T18-14-26-0078-final.md`, validada em 2026-09-16 — S2 C1–C3+G1–G3+M1 ok, sem `nok`) |
| 0079 | open-design-history-1a1 — Resíduo open-design (3ª de 3, por tela): curadoria fina 1:1 do `history.html` sobre `history.erb` + `history_page.erb` (base 0075 pronta); fidelidade híbrida (literal onde sem legado), backend thin listado, CSS ANTES da linha `fim` com delimitador `0079`; critérios C1–C2 → `test/history_curation_test.rb` (novo: `test_history_matches_prototype`) + extensões cirúrgicas + 1 manual | Concluída | Done (Passos 1–2 `cad1f49`/`6e41875` + CSS no bloco `9b421c4`, suíte 1180/6219 lint 0, revisor Aprovado `reviews/review-2026-09-15T15-00-22-0079.md`, validada em 2026-09-16 — S2 C1–C2+G1–G3+M1 ok, sem `nok`; ressalva: commits `cad1f49`/`6e41875` não auto-consistentes e `.card--tight` fora do `DESIGN.md`) |
| 0080 | convergencia-visual — Fechar o gap protótipo × app (itens 1-4+6): regra base global do `body` + topnav (CTA sempre `.btn` + "Voltar ao time" em `/battle`) + roster `team.erb` em grid 2-col com nível + Gerenciar (PRESERVA ▲▼) + re-marcação completa do `.pcard` espelhando `home-team.html` + meio do `.podium` em `.card`; CSS no bloco ODS com delimitador `0080`; item 5 center/mart → 0081 própria (modal-only); critérios C1–C5 → `test/convergence_0080_test.rb` (novo) + extensões cirúrgicas (`design_system`/`home_view`/`battle_view`/`layout_test`, sem tocar `open_design_contract`) + 1 manual (screenshots 1440px `tmp/comp-*` vs `tmp/proto-*`); sem migração/schema/gems, motor/economia intocados | Concluída | Done (refinada + implementada em 2026-09-10, suíte 1085/5291 lint 0, revisor Aprovado, validada em 2026-09-10 — S2 C1–C5+C1b+G1–G3 ok + M1 ok, S3 C1b doctype revalidado) |
| 0081 | tuning-economia-progressao — Reconciliar progressão (XP real via `xp_for`/`level_for_xp`, fim do bypass `grant_levels` e da ilusão 25x do sweep) + conter inflação (`lose_levels` 0, cura escala com nível médio); escopo `reward_rule`, `heal_cost_policy`/`heal_service`, `progression_repository`/`battle_service`, sweep + testes; fora visual/oponente/TeamBudget/migrações destrutivas; critérios C1→`reward_rule_test`, C2→heal tests, C3→progression+battle tests | Concluída | Done (validada em 2026-09-11, tuning chain) |
| 0082 | center-modal-heal — cura via modal (`_center_modal`→`_center`, motivo inline + OOB de saldo; sem economia/migrações) | Concluída | Done (validada em 2026-09-11) |
| 0083 | ui-polish — polimento visual home/team/battle (header gate, filtros, pills, pcard; visual-only, sem backend/regras/rotas) | Refinada | Refinada em 2026-09-10 (fase 2 pendente) |
| 0086 | battle-log-juice — log por rodada legível (chronological R1 no topo, flip S3 2026-09-11) + juice CSS-only + consumo/recompensa visível (sem engine/economia/rotas) + S3 C4–C8 (pacing, effect-sync, módulos, stepper/strike-flow) + S3 2026-09-12 C9–C15 (efeito atacante→alvo, shake no alvo, cor por tipo; presenter touch aprovado) | Concluída | Done (Passos 1–32 `9254ba4`…`147ad98` + doc `39b42eb`, suíte 1171/6107 lint 0, revisor Aprovado round 12 `reviews/review-2026-09-14T10-24-59.md`, validada em 2026-09-14 — S2 C1–C15+G1 ok, aprovação em bloco, sem `nok`) |
| 0087 | strike-fx-chegada-real — efeitos de golpe CSS-only: projétil com chegada real borda→borda do alvo (D1b), gate do travel por `@container` no `.arena` com `container-type: inline-size` em vez de `@media` (D2c), nó `.shot` fora do card em track dedicada filha direta de `.arena` (D3b), `--fx-travel` em `cqi`; sem JS além do htmx, sem engine/rotas; S3 reabre C9/C15 da 0086 | Concluída | Done (Passos 1–7 `0637cb6`…`49ffd74`, suíte 1173/6159 lint 0, revisor Aprovado round 2 `reviews/review-2026-09-15T10-57-40-passos1-6.md` + `reviews/review-2026-09-15T11-45-10-passo7.md`, validada em 2026-09-15 — S2 C1–C9+G1–G3 ok, aprovação em bloco, sem `nok`) |
| 0088 | projetil-slot-a-slot — projétil sai do slot do atacante e chega ao slot do alvo em x e y (D1a rota JS medido escrevendo `--fx-dy`; D2a exceção estreita e formal ao RNF-01 para um handler inline em `views/layout.erb`; D3a índices `attacker_index`/`target_index` no strike entry + `from_slot`/`to_slot` com guarda + `data-from-slot`/`data-to-slot` nos dois caminhos de render; D4a/D5 rail CSS da 0087 vira fallback, coluna única no-op; D6a e2e mede par ordenado; D7a teste de `target_strategy`; D8 reaberturas formais) — sem lib/polling/SSE, motor/economia/rotas intocados; S3 reabre C1/C6 da 0087 | Concluída | Done (Passos 1–6 `6e1caa3`…`d5a06dd` + fix S3 `a9949dc` + draft `3484260`, suíte 1180/6219 lint 0, revisor Aprovado `reviews/review-2026-09-15T14-00-01-passos1-6-0088.md`, validada em 2026-09-15 — S2 C1–C9+G1–G3 ok, aprovação em bloco, sem `nok`) |

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