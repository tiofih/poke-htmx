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
over) refinada e implementada em 2026-08-25** (passos 1–7, suíte 797/2579, lint 0 —
AGUARDANDO validação do usuário; arquivo `sessions/0053-qa-busca-remocao-gameover.md`):
**Q4** — a busca segue só formas base e ganha **aviso informativo** quando o termo só
casa com não-base/starter (aponta a evolução base via `evolutions.first` ou os destaques
iniciais); **Q5** — remoção robusta (botão "Remover" com `hx-disabled-elt="this"` +
regressão do `DELETE` htmx exato remove em 1 request e é idempotente); **GL-1** — **game
over** quando todos os pokes zeram HP **e** o saldo < custo da cura total (`game_over?`
no `JourneyService`, deps `wallet:`/`heal_preview:`), com **venda de itens** (novo
`POST /mart/sell` + `SellPolicy` = metade do preço, geral do Mart) e **recomeçar jornada**
(`POST /journey/restart` — `TeamService#reset` devolvendo itens + `WalletRepository#set`
p/ saldo inicial 200; redirect full-page para `/`). Depois da 0053: a fila (J2, J4, D4,
M2) e as limitações técnicas (escritas não atômicas, erros com status real, race no add,
identidade/CSRF, CI) — a critério do usuário.

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
| 0053 | QA Q4+Q5+GL-1 — aviso de busca base-form, remoção em 1 clique e game over (vender/recomeçar): **Q4** hint informativo quando o termo só casa com não-base/starter (aponta a evolução base ou os destaques iniciais); **Q5** remoção robusta (investigação do "2 cliques" intermitente — hardening `hx-disabled-elt` no form + idempotência); **GL-1** game over = time todo zerado **e** saldo < custo da cura (`game_over?` no `JourneyService`), com venda de itens (`POST /mart/sell` + `SellPolicy` 50% do preço) e recomeço da jornada (`POST /journey/restart` — `TeamService#reset` devolvendo itens + `WalletRepository#set` p/ saldo inicial 200) | Implementação | Concluída — passos 1–7, suíte 797/2579, lint 0, **aguardando validação do usuário** (2026-08-25) |

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