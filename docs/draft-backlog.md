# Draft — Backlog consolidado (drafts + playtests)

> **Fonte única de drafts e playtests (consolidado em 2026-09-08).** Substitui os arquivos
> `draft-arquitetura-design-patterns.md`, `draft-auto-battler.md`, `draft-design-system.md`,
> `draft-playtest-changelog.md`, `draft-ui-ux.md` e `draft-wireframes.md` (removidos do root;
> os detalhes de escopo/critérios/planos TDD de itens **já executados** vivem em `REQUIREMENTS.md`
> e `sessions/`). Os registros de playtest continuam nos arquivos `docs/playtest-*.md`.
>
> Regra RNF-04: escopos grandes abaixo são **anotados fora do fluxo** — só viram sessão
> (refinamento → TDD → validação) **após** a sessão corrente estar concluída e validada.

---

## 1. Catálogo — Itens FEITOS (Done)

> Referência rápida: cada item já virou sessão. O detalhe está em `REQUIREMENTS.md` (roadmap)
> e na respectiva `sessions/NNNN-*.md`.

### Arquitetura / Performance / Infra
| Item | Sessão | Resumo |
|---|---|---|
| Refactor produção (7 `rubocop:disable`) | 0020 | Extração de módulos em `lib/**` + `server.rb`; disables zerados |
| Refactor testes (disables) | 0019 | `TestSupport`/`TestDatabase`/`PokeApiStub` genérico; split por área |
| E1-A — gateway `PokeApi` | 0021 | Interface + `PokeApiHttp` real + `PokeApiFake`; injeção via `settings.api` |
| E1-B — cache decorator | 0022 | `PokeApiCache` TTL 600s / LRU 1000 |
| E2 / RF-18 — tratamento de erros | 0018 | Robustez da fonte + fragmentos amigáveis |
| P1 — paralelismo + cache persistente | 0035 | `Parallelizer` + cache thread-safe + `PersistentJsonStore` |
| P2 — varredura da banda do oponente | 0050 | Lotes paralelos + cap 256 + `PokemonRatingCache` + escrita coalescida |
| BUG-4 — vazamento de conexões PG | 0051 | `ConnectionRegistry` + `MAX_CONNECTIONS` + evicção; `after` por request |
| Respiro 2 (server.rb gordo) | 0033 | Extração de `BattleService`/`TeamService` + split de `server_test.rb` |

### Auto-battler / Motor / Gameloop
| Item | Sessão | Resumo |
|---|---|---|
| A1 — reordenação manual de slots | 0008 | RF-08 (`#move`, slots contíguos 1..N, ▲/▼) |
| A2 — UI layout/estilos externos | 0014 | RF-14 (layout único, nav, CSS externo) |
| A3 — página de gerenciamento de time | 0017 | RF-17 (página própria, golpes+slots) |
| B1 — modelo de batalha | 0009 | RF-09 (`BattlePokemon`, `take_damage`, `alive?/fainted?`) |
| B2 — efetividade de tipos | 0010 | RF-10 (`TypeEffectiveness`, STAB, 18 tipos) |
| B3 — motor de auto-batalha | 0011 | RF-11 (`BattleEngine` + `BattleResult`) |
| B4 — oponente automático | 0012 | RF-12 (`OpponentGenerator`, seed/fetcher injetáveis) |
| C1 — batalha por htmx | 0013 | RF-13 (rotas + fragmento) |
| C1-b — log de batalha melhorado | 0016 | RF-16 (atacante→alvo, golpe, dano) |
| D1 — golpes / moves / PP | 0015 | RF-15 (`Move`, `use_move`, Struggle, escolha determinística) |
| D2-A — XP / nível | 0023 | `team_pokemon_progress`, `ExperienceCurve`, `RewardRule` |
| D2-B — evolução + aprendizado | 0024 | Species oficial, `evolution_chain`, `level_learned_at` |
| D3 — histórico / rank | 0026 | `battles` + `BattleRepository`, rank local/global |
| JN-5 — gameloop (montagem→batalha→loja/cura) | 0048 | CTAs do circuito |
| BUG-1 — oponente sempre o mesmo | 0049 | `opponent_rng` injetável + máquina de estado da batalha ativa |
| B5 — "Batalhar" resolve a batalha inteira | 0069 | `BattleService#resolve` (teto 100, débito 1×, log completo) |
| C2 — animações nos ataques (juice) | 0063 | HP/projétil/flash/KO/dano/screenshake CSS-only |
| JN-3 — 1 uso de item por Pokémon/batalha | 0045 | `@items_used_by_member` + badge "já usou item" |
| JN-3-B — equipamento limitado pelo estoque | 0046 | `assign_with_swap`, débito/repõe, limpa `assigned_item` |

### Economia
| Item | Sessão | Resumo |
|---|---|---|
| Eco-1 — moeda pós-batalha | 0027 | `wallet` + `WalletRepository` + `RewardRule#money_for` |
| Eco-2 — Poke Center | 0028 | HP persistente + `HealCostPolicy` 0.5/HP + `HealService` |
| Eco-3 — Poke Mart | 0029 | `Item`/`ItemCatalog` + `InventoryRepository` + `MartService` |
| Eco-4-A — itens em batalha (automático) | 0030 | `ItemUsePolicy` + ação `:item` no half-FSM |
| Eco-4-B — item atribuído por membro | 0031 | `assigned_item`, política prefere o atribuído |
| Eco-4-C — seguráveis / hold items | 0032 | `Item#stat/multiplier`, `held_item` via Strategy/Decorator |
| M2 — custo de montagem de time | 0055 | `TeamBudget` (BUDGET 450, `cost_for`, `fits?`) |
| M2b — balanceamento (remover trava S via custo) | 0058 | `S_r = 110`; `S_LIMIT`/`s_limit_ok?` removidos |
| M1 — itens de evolução no Mart (pedras) | 0068 | 6 pedras clássicas price 80, oferta 3/rodada, modal evolução |

### UI/UX
| Item | Sessão | Resumo |
|---|---|---|
| Onda 0 — quick wins | 0038 | `alt`/`aria-label`, `loading="lazy"`, `hx-indicator`, hierarquia notices, copy pt-BR |
| Onda 1 — jornada visível (Caminho B) | 0042 | Lista+Time unificados na página única `/` de 2 colunas |
| Onda 2 — leitura da batalha | 0041 | Partial única dos painéis + presenter + barras HP/PP |
| Onda 3 — estrutura | 0044 | Estado ativo no nav + limpeza de painéis + grid responsivo |
| JN-1 — telas próprias (fim do empilhamento) | 0039 | Cada área vira tela própria |
| JN-2 — golpes em lista | 0037 | Lista/select no lugar de checkboxes |
| JN-4 — componentes Mart/Center | 0047 | Partials `_mart.erb`/`_center.erb` + custo antecipado |
| J3 — ranking S–F (balanceamento) | 0040 | `PokemonRating#rate` + `band_for_level` |
| J1 — seleção inicial de time | 0036 | Formas base + 27 iniciais gen 1–9; gates da jornada |
| UX-2 — custo/ranking na lista + filtros + alinhamento | 0057 | Filtros combináveis, ordenação por custo/tier, "limpar filtros" |
| RESP-1 — responsividade (viewport + grid + colapso) | 0060 | `<meta viewport>`, grid `auto-fill`, `list-team-grid` collapse |

### Design system (parcial — ver nota)
O `draft-design-system.md` propunha tokens/copy/acessibilidade. Boa parte foi aplicada nas
ondas UX (0038/0041/0044/0057) e na 0060. O **redesenho visual completo** (sistema oklch,
classes novas, remover sakura) é o escopo do `open-design/` (ver `open-design/migration-guide.md`)
e entra como a **Onda open-design** (sessões 0072–0076). Os tokens hex antigos do
`draft-design-system.md` são **superseded** pelo sistema oklch do `open-design/`.

---

## 2. Backlog — Itens PENDENTES (anotados fora do fluxo — RNF-04)

> Candidatos a sessão futura. A numeração abaixo é apenas de referência/rastreio.

### Arquitetura / Infra / Performance
- **Escritas multi-tabela fora de transação única** — compra/batalha orquestram wallet+inventory+XP em passos separados. (limitação aberta; candidata a "escritas atômicas"; detalhe consolidado na **§4.B**, candidata a **0084**)
- **Remover `pry` do runtime de produção** — `server.rb`/Gemfile; barato, respiro técnico. (consolidado na **§4.B**)
- **TTLs divergentes entre as 2 camadas de cache** — memória 600s vs disco 7d; documentar/decidir.
- **Memoização request-scoped de journey/team nos renders gated** — hoje 2× team + 2× user_state por request.
- **Instrumentação mínima (tempo por rota/log)** — orientar otimizações com dados.
- **Prune de expirados no `PersistentJsonStore`** — escrita coalescida feita (0050); poda de TTL expirados não confirmada.
- **INFRA-1 — cache da PokéAPI em Redis** — substituir `PersistentJsonStore` por `RedisJsonStore`; "não fazer agora", sessão própria.
- **Polling/SSE/streaming da resolução da batalha** — se o log ficar longo no futuro.
- **Persistência do log de batalha em DB** — hoje derivado do engine em memória.
- **Atualizar para HTMX 4.0** + **adicionar skills da atualização** (routing AGENTS/CLAUDE).
  - T128: pinado `htmx.org@2.0.3` (`views/layout.erb:7`); breaking hits: rename de eventos (`layout.erb:38-53`), `hx-disabled-elt`→`hx-disable` (`team.erb:57`), `hx-params` removido (`team.erb:53`) + `hx-delete` form-data, flip ordem OOB, swap default 4xx/5xx (`server.rb:1296`), `HX-Trigger`→`HX-Source`.
  - Checklist: renomear eventos/atributos, pinar 4.0.0 + upgrade-check, fallback `htmx-2-compat`, verificar OOB/indicators/modais; esforço ~M (maioria verificação); skill `htmx-upgrade-from-htmx2`; implementação futura, fora do fluxo (RNF-04).
- **Flag `user_state` vestigial** — `JourneyService#started?` agora só usa `team>=6`; remover/redefinir papel.

### Auto-battler / Motor
- **D4 — modos de draft temático** — regras de validação na montagem (1 por tipo, ban de lendários…); cruza com J1.
- **J2 — personalização entre batalhas** — tela própria ou extensão de `/team/manage`; estratégia por time vs por Pokémon; troca de skills com custo?
- **IA-1 — API/WebSocket para IA jogar** — REST vs WS, autenticação de agente, escopo (batalha vs loop completo).
- **IA-2 — IA esgota todos os golpes/PP antes de Struggle** — hoje Struggle pode entrar cedo.
- **IA-3 — golpes de debuff (status moves que reduzem stats)** — modelar efeito de stat, alvo, N rodadas.
- **IA-4 — sistema de crítico e RNG** — chance ~6.25%, multiplicador, rng injetável.
- **RNG injetável no motor** — determinismo total em aberto (default seed fixa).
- **CURA-1 — outros modos de cura / poções fora de batalha** — usar poções no painel do time (fora de batalha), debitar estoque.
- **Mecânica de batalha (`BattleEngine`)** — sessão futura dedicada (não tocada na 0069).

### Economia / Balanceamento
- **ECO rebalance — heal trap / death spiral** — `lose_money 40 < heal 131`; softlock na 1ª derrota (propostas: `lose 60`, `heal 0.3`, 1ª cura grátis).
- **Ajuste da tabela de XP e dinheiro** — revisar `ExperienceCurve` (linear `level*100`) e `RewardRule#money_for` (100/50/40).
- **Dificuldade dinâmica por desempenho da batalha anterior** — ajustar banda/nível do oponente por resultado/placar/HP restante.
- **Oponente 6v6 garantido** — `complete_with_fallback` com mínimo 6 (relaxar banda→orçamento→pool base, sem repetir); estender TP-4 com `OPPONENT_MIN_SIZE`; ref 0066 + sessions/0081:103 out-of-scope note.
- ~~**Times iniciam no nível 5**~~ — **[FEITO — 0067]** time inicial `level: 5` xp 1000 (`SESSIONS.md:379`, validada 2026-08-31). Mantido por histórico.
- ~~**Vitórias +2 níveis, derrotas +1**~~ — **[FEITO — 0067]** `RewardRule#levels_for` win +2/draw +1/lose +1 via `grant_levels` (`SESSIONS.md:379`); o `lose→0` veio depois na 0081 (Done). Mantido por histórico.
- **Exploits/desequilíbrios (playtest 0063)** — **E5 (linha S restrita 110) feito na 0058** (`docs/draft-backlog.md:65`); seguem abertos E1 (lendários desde nível 5 vs banda D/C), E2 (farm de derrota), E3 (custo por linha vs base = noob trap), E4 (sem cap de tier S), E6 (gate `base_form?` só 1ª evolução).

### UI/UX
- **UX-1 — janelas flutuantes Center/Mart (modais)** + gerência de golpes no Center + itens no Mart + 4 selects para golpes (reestruturar `team_manage`). *Parte do escopo `open-design` (sessão 0076 modals).*
- **J4 — identidade legível (apelido/nome)** — ranking hoje exibe UUID cru; recomendado `nickname` em `user_state`.
- **P2 (playtest) — comunicar o modelo auto-battler (onboarding)** — o jogador não sabe que a estratégia é pré-combate.
- **P5 (playtest) — painel do time em modo único** — Center/Mart + edição inline; sem esconder saldo.
- **P6 (playtest) — visibilidade do estado de item/segurável no gerenciar** — select mostra "Nenhum" mesmo equipado.
- **P7 (playtest) — estado vazio / aviso de cura antes da batalha** — batalha não deve iniciar com time HP 0.
- **P8 (playtest) — ranking global sem seeds no topo** — seeds ("seed-shop") não devem competir.
- **P4 (playtest) — recompensa variável por performance** — base + bônus por rodadas/KO/time.
- **Botões desabilitados sem motivo visível** — "No time ✓" sem tooltip; remover/evoluir com motivo só em `title`.
- **Toast do add fora da viewport** e **detalhe abre fora da tela (sem auto-scroll)**.
- **"×N" do Mart = afordabilidade, não estoque** — rótulo enganoso.
- **Consumo de itens em batalha opaco** — sem "usou 1 Pocao (restam N)".
- **Recompensa-positiva na derrota** — mensagem lê como vitória ("Seu Time ganhou 20 XP…").
- **Batalha em 2 etapas** — "Novo confronto"→"Batalhar" redundante vs 1 clique no painel do time.
- **Painel do time com scroll interno** — `window.scrollTo` não rola a página.
- **Nav minimalista** — oculta Mart/Center/Jornada até time 6/6; novato não sabe que existem.
- **Manage sem paginação/busca** — O(n) forms por poke (180 forms no mobile).
- **-1hp persist** — `battle_engine` 119-126, mecânica TP-17/TP-10.
- **LOG-juice** — aparência do log + animações CSS + reduced-motion.
- **T20 casual — feedback de add/remove** — label do botão Add + toast; remover confirm; posição do Add no card.
- **T20 casual — custo/cura legíveis** — legenda X/450 + "Faltam N"; heal desabilitado com motivo + re-render do saldo.
- **T20 casual — batalha/filtros/time vazio** — fundir CTAs + loading; labels de filtro + "N resultados" + empty state; pill de progresso com time vazio.
- **T20 casual — prontidão/log** — copy do readiness pill + link; logs newest-first + respeitar reduced-motion por último.
- **Heal-success toast pós-modal (follow-up 0082 close-on-success)** — toast/alert em battle + home após fechar modal de cura (hoje zero feedback); referenciar close-on-success da 0082.
- **Efeitos de golpe: projétil + shake (extensível)** — a jogada deve mostrar o efeito saindo do Pokémon atacante em direção ao atacado e um shake no que recebe o golpe. Precisa ser extensível para: (a) futuras mudanças de estratégia de ataque; (b) cor do efeito derivada do tipo do golpe. **Absorvido pela sessão 0087 (`sessions/0087-strike-fx-chegada-real.md`).**
  - Contexto: a sessão 0086 (battle-log + juice CSS-only) excluiu explicitamente "projétil <900px" do escopo; o caminho do strike já carrega `data-from-side` / `data-to-side` na entrada do log e emite gates `[data-jx-*]` OOB — usar isso como gancho de extensibilidade em vez de JS por golpe.
  - Nota: cabe avaliação de tipo-de-golpe (o move já é conhecido no servidor; verificar se o tipo vem no payload atual ou se precisa ser exposto).
  - Chegada real atacante→atacado (medido 2026-09-14, anotado pós-review da 0086): hoje é teto direcional, não chegada — `.shot` é filho de `li.fighter` (`views/_fighter_panel.erb:14`), absoluto sobre o card, `translateX(calc(100% + 40vw))` (`public/style.css:1587,1598`) → para no podium (~472px vs ~815px medidos centro-a-centro).
  - Esforço: **M** CSS-only com `container-type: inline-size` + `--fx-travel: 67cqi` derivado do grid `1fr/1.06fr/1fr` + 2 gaps de 32px (aproximado, erro de dezenas de px); **L** se pouso fiel ponto-a-ponto — exige medição em runtime = JS, hard-out do escopo (`sessions/0086-battle-log-juice.md §3:39`).
  - Requer: mover o markup do `.shot` do card para o track da arena (CSS não move elemento entre colunas; o servidor já sabe `data-from-side`/`data-to-side`), elemento de impacto por-linha no card alvo no instante da chegada (C13 postergou de propósito), keyframes `juice-shot-ltr/rtl` (`public/style.css:1581-1601`), rede reduced-motion (C14), 6 caudas do lab para o look de "saída", testes `test/style_responsive_test.rb:275-289,322-428` + e2e.
  - Risco: abaixo de 900px a arena colapsa para 1 coluna (`public/style.css:607-611`) mas o travel é horizontal em `min-width:900px` → projétil voa pelo vazio (hoje mascarado pelo fade em 40vw).
  - **D6a (aprovada na 0087 em 2026-09-15):** `data-strategy` fica **default-only** (`"strike"`) nesta sessão — a extensibilidade é a **forma** do gancho (já coberta pelos testes de contrato, C12 da 0086) e uma segunda estratégia de ataque é **YAGNI** (sem caso de uso/tipo definido). Item **absorvido pela sessão 0087** (`sessions/0087-strike-fx-chegada-real.md`).
- **Convergência de paleta de tipos com o lab (`docs/type-effects-lab.html`)** — o lab define head claro + 6 tails saturadas em HEX CRU por tipo; 7/18 já casam (grass, water, electric, fighting, steel, ghost, dragon — alguns limítrofes) e 11 divergem: fire→#f97316, normal→#a8a29e, ice→#22d3ee, poison→#9333ea, ground→#92400e, flying→#38bdf8, psychic→#db2777, bug→#65a30d, rock→#78716c, dark→#1f2937, fairy→#f472b6.
  - Esforço S: ~20 LOC em `public/style.css:19-36` (18 tokens `--t-*`), 1 linha em `DESIGN.md:14`, revisão visual dos badges `.ftag--*` (`public/style.css:1399-1501`).
  - Bloqueios: `DESIGN.md:3-4` proíbe hex hardcoded (tokens só via DESIGN.md) e C11 (`sessions/0086-battle-log-juice.md §4:57`) exige "paleta `--t-*` existente + fallback" → exige S3 no C11; `--t-*` é global (pinta badges em roster/team/battle), não só o projétil.
- **Remover o toggle JOGAR-AUTO e disparar os tempos no clique de "Batalhar"** — eliminar o checkbox `#auto-play`/`name="auto"` e o chain por `HX-Trigger`, de modo que um unico clique em `#play-btn` rode a batalha inteira com o pacing ajustado.
  - Pedido do usuario na validacao da 0086 (2026-09-14); altera comportamento ja validado (C4 tiered pacing + "Pular", C7 advance-one-round + JOGAR-AUTO) → **exige S3 nos C4/C7 e sessao nova**.
  - Hooks afetados: `views/battle.erb:70` (toggle) e `views/battle.erb:71-73` (`hx-include="#auto-play"`, `hx-trigger="click, next-strike from:body, next-round from:body"`); `server.rb:1070` (`next-round` em `advance_battle`), `server.rb:1074-1075` (`auto_play_requested?`), `server.rb:1086` (`next-strike` em `strike_battle`); pacing CSS-only em `public/style.css:1880+` (`.log-skip-input`/`.log-skip-btn`).
  - Testes a remover/reescrever: `test/battle_routes_test.rb` `test_battle_auto_toggle_chains_advance_until_finished` (l.186), `test_battle_auto_off_stops_chain` (l.206), `test_battle_auto_stays_checked_across_swaps` (l.217), `test_battle_strike_button_wires_auto_chain` (l.227) + e2e `e2e/specs/battle-log.spec.ts` caso `auto toggle chains to finish without further clicks` (~l.99).
- **Projétil deve sair do slot do pokémon atacante e chegar ao slot do pokémon alvo (anotado 2026-09-15 — NÃO faz parte da sessão 0087 e não está coberto pelos critérios daquela sessão)** — hoje o projétil sai de uma caixa de time e chega à outra: o voo é um rail horizontal na altura da linha de cards, não um trajeto de slot a slot.
  - **Absorvido pela sessão 0088 ("projétil slot→slot"), aprovado pelo usuário em 2026-09-15; reaprovação pendente na validação da 0088.**
  - Evidência: a sessão 0087 (`49ffd74` e anteriores) entregou, por decisão D1b/D3b, uma track única filha do `.arena` com `--fx-travel: calc(35cqi + 42px)` — isso resolve a **chegada no eixo horizontal** (borda do card alvo), mas a origem/destino efetivos ficam na altura da linha de cards das caixas de time.
  - Limite estrutural registrado no refinamento: uma track única dá rail horizontal; o Y do slot específico **não é derivável em CSS puro**.
  - O markup hoje carrega só `data-from-side` / `data-to-side` / `data-move-type` (`views/_jx_shot.erb`, emitido por `server.rb` `strike_shot_oob`); **não existe** índice/identidade do pokémon atacante ou alvo chegando ao nó do projétil.
  - Rotas técnicas a avaliar no refinamento:
    1. **JS ponto-a-ponto** medindo os centros dos cards via `getBoundingClientRect` — **rota escolhida para a 0088**. A afirmação de que seria "o primeiro script além do htmx no projeto" é **falsa**: `views/layout.erb:37-54` **já** embarca ~17 linhas de JS do projeto ligado a `htmx:beforeRequest`/`afterSwap`. O que a 0088 introduz é uma **exceção política explícita** ao RNF-01 (registrada no próprio requisito), não JS pela primeira vez.
    2. **CSS com aritmética por índice de slot** (âncoras/`nth-child` + custom props por linha) — **descartada**: exige altura de card uniforme; hoje o conteúdo manda na altura do card e forçá-la arrisca clipar conteúdo.
    3. **CSS anchor positioning** (`anchor()` / `position-anchor`) — **descartada**: inviável para animar o travel porque `anchor()` não alimenta `transform`.
  - Esforço: **L** — exige a identidade do slot chegando ao markup (mudança de presenter/engine) + âncoras e possivelmente JS.

### Playtest / QA / Ferramentas
- **TP-1** — playbook de playtest reutilizável (helpers no harness).
- **TP-2** — estado determinístico por sessão (`POST /dev/seed`).
- **TP-3** — log estruturado da batalha (JSON/CSV por rodada).
- **TP-4** — balanceamento parametrizável por env (`XP_WIN`, `OPPONENT_DELTA`…).
- **TP-5** — checagem de robustez pré-playtest (`scripts/stress_smoke`).
- **TP-6** — add em rajada robusto (`hx-disabled-elt` + fila/debounce).
- **TP-7** — gerenciar com auto-save ou "Salvar tudo".
- **TP-8** — nomenclatura consistente de item (Pocao vs potion).
- **TP-9** — item equipado visível em todas as telas (home/batalha).
- **TP-10** — estado único do time (uma fonte de verdade p/ HP/PP/itens).
- **TP-11** — reset de progressão para jogadores novos (não herdar vitórias).
- **TP-12** — detalhe de batalha no histórico (rounds, HP final, golpes, itens).
- **TP-13** — "Jogar tudo" + velocidade (1×/2×/4×).
- **TP-14** — card com tipo/stats na Lista (critério de escolha no onboarding).
- **TP-15** — targeting configurável ou documentado.
- **TP-16** — botão "Desistir"/"Render" na batalha (com penalidade explícita).
- **TP-17** — revisar fórmula de dano (nível 1 gera 1–210; HP não decrementa conforme log).
- **TP-18** — AI do oponente com golpes não-ofensivos (não usar Struggle com PP).
- **TP-19** — `GET /battle` inicia nova batalha se a anterior está finalizada.
- **TP-20** — warning de time ferido ao iniciar nova batalha.
- **L1** — facilitar playtest via IA (endpoints JSON + seed determinístico) — consolidar em TP-2/TP-3.
- **L2** — suite Grafana de observabilidade (Prometheus/Grafana/Loki/Tempo; Mimir recomendado cortar).
- **L3** — botão "reportar bug" (Nível A: link pré-preenchido recomendado; Nível C: `POST /feedback` só com auth).
- **Cassettes VCR gigantes** — `record: :once`/`PokeApiStub` (recomendado A), Git LFS (B) ou limpar (C).
- **Stub de `load_starters`/`STARTER_SLUGS` no `ServerTeamRemoveQ5Test`** — o DELETE re-renderiza `pokemon_list` e busca 27 starters × (`/pokemon` + `/pokemon-species` + `/evolution-chain`) + `?limit=100000`, gerando um cassette de 20 MB (27536 linhas); o stub elimina a necessidade dele (hoje gitignored, replay offline local).
- **e2e `e2e/specs/battle-log.spec.ts` vermelho pré-existente (anotado 2026-09-15, NÃO faz parte da 0087)** — `buildTeamOfSix` (região `:17`) trava no 6º add com "Orçamento insuficiente", derrubando 4 testes do arquivo (incluindo a expectativa de badge). Os dois testes adicionados pela 0087 passam. Pré-existente, não é regressão da 0087; ajustar o helper (orçamento/ordem dos adds do time fixo) antes de reusar o arquivo como gate.
- **`ConnectionRegistryTest` flaky por ordem de execução (anotado 2026-09-15, NÃO faz parte da 0087)** — falha em algumas ordens da suíte completa, passa isolado e no re-run (observado no run da suíte do Passo 3 em 2026-09-15). Investigar estado compartilhado entre testes (registry global/`MAX_CONNECTIONS`/evicção) ou fixar a ordem/isolamento.

### Achados não bloqueantes das revisões da 0087 (anotado 2026-09-15 para triagem)

> Ambos os reviews deram veredito `Aprovado`. Os itens abaixo são **NÃO bloqueadores** e **NÃO fazem parte dos critérios validados** da 0087 — ficam anotados para triagem futura.

**CSS / contrato**
- **Reduce-motion só mata `animation`; `display:block` persiste** → ponto estático para quem usa reduced motion. `public/style.css:2494` (+ gate `:1025`/`:2469`); C9 prova apenas presença.
- **Família `--jx-*` inteira inerte** — 0 consumidores de `var(--jx-*)`. `public/style.css:965`, `:2517-2525`.
- **Razão do grid hardcoded 3×** — `public/style.css:605`, `/3.06`, `35cqi` sem teste de acoplamento; um `gap` ou proporção novo quebra o travel em silêncio.
- **`@media (max-width: 700px) .podium{position:static}` é morto** — o `sticky` posterior vence (`public/style.css:620-622` vs `:789`).

**Testes / guardas**
- **Gate `@container (min-width: 981px)` duplicado** (`public/style.css:1028` e `:2472`); o teste lê o último bloco (`gates.last`), então mutar o primeiro passa despercebido. `test/style_responsive_test.rb:359-360`.
- **e2e com esperas que engolem timeout e medição possível de nó stale**; tolerância de chegada `-20..40px` ≈ 3–4× o erro real (~5–15px). `e2e/specs/battle-log.spec.ts:191-206`.
- **`is-attacking` sem consumidor** em CSS/teste após a track virar o nó do projétil. `lib/battle_juice_presenter.rb:37`.
- **Guarda de layout não assegura o invariante em que o fix se apoia** (`offsetParent === .arena`) — 1 assert resolveria. `e2e/specs/battle-log.spec.ts:330-350`.
- **Comentário obsoleto**: o Passo 7 tornou `.battle-column` o pai da track novamente. `test/style_responsive_test.rb:332-333`.
- **Perna de 900px da guarda reafirma os mesmos três fatos** e nunca afirma o regime de coluna única que invoca. `e2e/specs/battle-log.spec.ts:322-350`.

**CI / duplicação**
- **e2e fora do CI** — `.github/workflows/ci.yml` roda só `./scripts/test`, lint e `check_docs`, então nenhuma guarda de layout protege o merge.
- **Duplicação do markup do shot** — `views/battle.erb:46-47` repete `server.rb:1137-1145` (risco de drift).

### Achados não bloqueantes da revisão da 0088 (anotado 2026-09-15 para triagem)

> O review da 0088 deu veredito `Aprovado`. Os itens abaixo são **NÃO bloqueadores** e **NÃO fazem parte dos critérios validados** da 0088 — ficam anotados para triagem futura. O achado **média** (exceção ao RNF-01 desatualizada em `REQUIREMENTS.md:499`) foi corrigido no commit de revisão; os demais seguem aqui.

- **Base de layout sem guarda** — `views/layout.erb:81-82` assume `shot.offsetParent === shot.parentElement` e `.shot` renderizado (`offsetWidth > 0`); nenhum dos dois é guardado (uma regra futura que posicione a coluna, ou o último settle com o gate off, gera offset silencioso).
- **Centros dos cards sensíveis a `transform`** — `views/layout.erb:87-90` usa `getBoundingClientRect()` nos centros (sensível) enquanto a base é imune por layout; hoje mascarado pelo `animation-delay` de 0,55s (`public/style.css:941`, `:2471`).
- **e2e pode medir nó stale** — `e2e/specs/battle-log.spec.ts:186-195`: `.catch(() => undefined)` engole timeout e a medição pode comparar um `.shot` antigo (pré-existente, `docs/draft-backlog.md:223`).
- **Comentário obsoleto** — `test/style_responsive_test.rb:332-333` (pré-existente, `docs/draft-backlog.md:226`): o texto diz que a coluna deixou de ser ancestral da track; o assert está correto, só o comentário engana.
- **C7 com prova sintética** — `e2e/specs/battle-log.spec.ts:362-422`: com `javaScriptEnabled:false` o `vars == ''` é garantido; a prova real do fallback é a geometria do rail.
- **Info: payload não consumido** — `lib/battle_log_presenter.rb:65-67` (`from_slot`/`to_slot`) é exigido por C3/testado, mas nenhuma view consome hoje.
- **Info: gate `@container` duplicado** — `public/style.css:1030` vs `:2480` (pré-existente, `docs/draft-backlog.md:222`; a 0088 não agravou).

### Achados não bloqueantes da revisão da 0079 (anotado 2026-09-15 para triagem)

> O review da 0079 deu veredito `Aprovado`. Os itens abaixo são **NÃO bloqueadores** e **NÃO fazem parte dos critérios validados** da 0079 — a sessão 0079 ainda **aguarda a validação do usuário (fase 3)**. Ficam anotados para triagem futura.

- **Média (histórico, não HEAD):** os commits da própria 0079 não são auto-consistentes — `git show cad1f49:public/style.css | grep -c card--tight` → 0 (idem em `6e41875`), então o teste C2 commitado em `cad1f49` está vermelho naquela revisão e `history.erb` em `6e41875` referencia classe indefinida; o bloco chegou em `9b421c4`, rotulado como Passo 1 da 0078. Quebra bisect/CI. Já divulgado em `sessions/0079:106`, mas `:8` afirma "Passos 1-2 verdes" (verdadeiro na árvore, não no commit).
- **Baixa:** `sessions/0079:48` promete verificação "classe a classe" contra `history.html` (incl. `history_page.erb`); nenhum teste lê o protótipo, a superfície nomeada é provada pelos testes da 0075 (`history_view_test.rb:42-129`) e a extensão em `history_view_test.rb:98` duplica `history_curation_test.rb:27,29` verbatim.
- **Baixa:** `.card--tight` (`public/style.css:1751`) não consta da lista de componentes do `DESIGN.md:24-29`.
- **Baixa:** o `git stash` prescrito pela G1 (`sessions/0079:22,55,102`) não foi usado; a árvore ficou suja e foi varrida por commit alheio (substância preservada).
- **Info:** o Status foi escrito pelo commit do Passo 3 mas omite o Passo 3.
- **Info:** `refute_match(/class="card" style=/)` (`history_curation_test.rb:29`) não pega `class="card card--tight" style="…"` e fica mascarado no próprio teste.

---

## 3. Referências aos arquivos de playtest

Os registros de playtest (experiência, achados, evidências) ficam nos arquivos:
- `docs/playtest-01-economia.md` — economia de montagem (teto 3× S via custo) → base da 0058 (M2b).
- `docs/playtest-02-responsividade.md` — responsividade (viewport/grid/breakpoints) → base da 0060 (RESP-1).
- `docs/playtest-03-gameplay.md` — rodada completa de gameplay (design/bugs) → base de RESP-1/M2b/ECO rebalance.
- `docs/playtest-0063-juice.md` — playtest advisory da sessão 0063 (juice), perfis novato/casual/hardcore.

## Curadoria 0076 (decidida pelo usuário em 2026-09-09, pós-validação da 0075)

Auditoria read-only (markup + CSS) do implementado 0072–0075 vs protótipos
`open-design/*.html` levantou ~60 divergências **novas** (não mapeadas).
O usuário mandou **todas** para o escopo da 0076 (última da onda),
somando ao escopo original (modais center/mart/membro, filtros `team=in|out`,
remoção sakura/CSS antigo, gates `@message`). Atenção no refinamento:
escopo grande — considerar fatiar (ex.: 0076a filiais visuais + 0076b limpeza).

- **data-od-id (adotar como contrato):** shell+nav, home/team, battle, history.
- **Base visual fiel:** topnav (sticky/blur), botões (base/secondary/hover/sm/lg/disabled),
  card (radius/padding), tipografia (mono eyebrow/meta, lead), espaçamentos
  (section/row/grid-2-1/arena/container por tela), componentes (meter ok, pill,
  roster grid), tokens de escala `--fs-*/--gap-*`.
- **Ausentes:** tags de tipo, sprite-tile base, pcard-meta/add, nav-badge,
  end-states (state-pill/cards), battle responsivo (podium 700px, transition/engaged).
- **Conteúdo battle:** cabeçalho + contadores, CTAs fiéis, log fiel, moves com
  cor de tipo, stock-items com regra.
- **Home/history:** título+lead, meter acessível, catalog count/clear, pcard fiel, footer.
- **Técnicos (junto à limpeza):** keyframes projectile p/ o bloco ODS (D86 —
  quebra se remover o legado), toast no ODS (D88), colisões .bar/nav/log (D71–D76),
  filtros vs CSS (D94), inline do history (D80).
- Relatório completo nos resultados das auditorias da sessão (ver handoff 2026-09-09).

## Paridade 1:1 open-design (análise exaustiva 2026-09-09, decisão: fatiar por tela)

Inventário programático (classes/ids/odid/roles/copy/CSS por seletor/vars/JS/media)
+ grafo (presenters, record, moves) + leituras diretas. 1:1 confirmado: shell/topnav,
tokens :root completos, history CSS, modal shell, odid, tags, filtros, juice no bloco.
Gaps numerados HOME-1–4, BATTLE-5–9, HISTORY-10 (só dados), MODAIS-11 no relatório da
sessão (ver handoff). Decisão do usuário: **fatiar por tela** — 0077 parity-home,
0078 parity-battle, 0079 parity-history (migração só se confirmada); fila de
estabilidade (atomicidade/CSRF/respiro) desliza 3 posições. Decisões pendentes no
refinamento: tabs vs empilhado, podium vs res-top, formato do log, dot-por-tipo
(custo backend), h-sub rico (migração).

---

## 4. Consolidação 2026-09-15 — catálogo único (fila, estabilidade, GDD, memória)

> Levantamento completo das fontes (draft, `SESSIONS.md`, `sessions/`, `TODO.md`,
> `REQUIREMENTS.md`, `GDD.md`, memória ai-memory). Onde o item já existia em §2, o
> registro abaixo **enriquece** aquele item (não duplica). Itens stale/absorbidos mantêm
> o histórico e o motivo.

### 4.A Sessões na fila que nunca fecharam (furaram quando 0072–0086 passaram na frente)

- **0079 open-design-history-1a1** — TDD concluído, **aguardando Revisor (S7)** e validação. `sessions/0079-open-design-history-1a1.md:8-9`, `SESSIONS.md:515`. **S/M**.
- **0078 open-design-battle-1a1** — implementação verde (Passos 1-3: `9b421c4`, `924e5b6`, `4604ee9`), validação pendente. O Status antigo citava 8 falhas alheias da 0077 em `_center`/`_mart`; **não reproduzido** — a suíte está verde hoje (1180 runs / 0 failures em `d5a06dd`), então o que fica é um *check* antes de retomar, não a falha. `sessions/0078-open-design-battle-1a1.md:8-9`, `SESSIONS.md:514`. **M/L**.
- **0077 open-design-home-1a1** — fase 2+3 pendentes. `sessions/0077-open-design-home-1a1.md:8-9`, `SESSIONS.md:513`. **M**.
- **0083 ui-polish** — pendente, visual-only (sem backend/regras/rotas). `sessions/0083-ui-polish.md:8-9`, `SESSIONS.md:519`. **S/M**.

### 4.B Fila Estabilidade/Segurança — sem número de sessão

> Números **0084/0085** ficaram reservados em `SESSIONS.md:403` (escritas→0083, CSRF→0084,
> respiro→0085), mas a numeração saltou 0083→0086 quando a 0083 virou `ui-polish`.
> Proposta de reuso em §4.F.

- **Escritas atômicas + idempotência** — transação única + idempotência por round em `BattleService#finish_effects`/`MartService#purchase_result`; double-submit de `POST /battle/play`/`POST /mart/buy`. `REQUIREMENTS.md:554-560`, `docs/draft-backlog.md:97` (§2). **M/L**. Candidata a **0084**.
- **CSRF / identidade** — `?as=` takeover, `SESSION_SECRET` hardcoded, POSTs sem CSRF; severidade **High**. `REQUIREMENTS.md:561-565`, `GDD.md:60`, `reviews/audit-baseline-2026-09-13.md:9,11`. **M**. Candidata a **0085**.
- **Estado transiente + migrações destrutivas** — `BattleRegistry`/cache P1 não sobrevivem a `docker compose down`; migrações 0003/0007 com `TRUNCATE`. `REQUIREMENTS.md:574-576`. **S/M**.
- **`pry` no boot de produção** — `require "pry"`; mover para dev. `REQUIREMENTS.md:577-578`, `docs/draft-backlog.md:98` (§2). **S**.
- **CD/deploy** — CI só roda checks; sem alvo de deploy (registry, serviço, secrets). `REQUIREMENTS.md:586-587`. **M**.

### 4.C Fonte órfã `GDD.md` (itens que NÃO estão no draft)

> `GDD.md` (2026-09-13) propõe a jornada Bazaar-like; a maioria dos itens não está no
> draft. Registrar como **fila a refinar**, sem data de execução.

- **Onboarding** (nome+avatar persistidos em `user_state`) + **montagem em 2 vias** (1-a-1 vs time fechado pré-montado). `GDD.md:31-33`.
- **Escolha de oponente por 3 cartas** (fraco/médio/forte, preview honesto, re-role por confronto). `GDD.md:34`.
- **Ginásio temático** (líder por tipo dominante, intro de chefe). `GDD.md:35`.
- **Lojas segmentadas** (portas Pedras/Poções/Equips). `GDD.md:36,50-53`.
- **PvP fantasma** (snapshot de time real + IA do PvE; rank por temporada/ginásio). `GDD.md:37,44`.
- **Pós-batalha unificada** (recompensa + cura rápida inline; mata o "pedágio do Center"). `GDD.md:38`.
- **Empty-states A–E** (history zero, filtro zero, time 0/6, erro por status, mart/center vazios). `GDD.md:59`.
- **Sinergia L2** (bônus/proteção por par adjacente do mesmo tipo; 1 regra por temporada). `GDD.md:45-46`.
- **IV/EV light** (chips no detalhe; fora do MVP). `GDD.md:46`.
- **Revive-½** (Poções; traz fainted a 50%). `GDD.md:53`.
- **Roadmap em 12 fatias** (1 tela = 1 sessão SDD). `GDD.md:65-66`.
- Já com dono/linha no draft: "Resolver batalha"→0069 (Done), "derrota XP-only/streak"→§2 ECO rebalance (`:123`), "anti-perda devolve holds"→0052 (Done). `GDD.md:30,48`.

### 4.D Itens que só existiam na memória (ai-memory) — não estavam no draft

- **BUG-2 — remover Pokémon com itens equipados perde os itens** — falta `InventoryRepository#add` antes do DELETE. **M**. `gotchas/poke-htmx-team-remove-loses-equipped-items.md`.
- **T75 — toast de sucesso do heal** — sem feedback depois que o modal da 0082 fecha. **S**. `gotchas/0082-modal-close-fade-filtered.md`. (Confirma a origem do item §2 `docs/draft-backlog.md:155`.)
- **`@team_s_count` morto** — atribuído em `server.rb:1032` (método `:696`) e **sem consumidor** em `views/`/`test/`; a gotcha cita `:786` (drift). **XS**. `gotchas/m2b-balanceamento-s-rest-110.md`.
- **reduced-motion não mata `transition`** e `from_side`/`to_side` sem DRY. **S**. `gotchas/juice-reduced-motion-guard.md`. (Cruza com §2 `:150` e com os achados da 0087 `:216`.)
- **Heal parcial (`affordable_hp` + FIFO) deliberadamente adiado**. **M**. `gotchas/0065-heal-trap.md`. (Cruza com §2 ECO rebalance `:123`.)

### 4.E Stale / possivelmente resolvidos (histórico mantido)

- `notes/pending-spacing-replication-across-screens.md` — provavelmente **superseded** pela onda open-design 0072–0079; verificar antes de usar.
- **BUG-1** (`gotchas/poke-htmx-battle-opponent-deterministic-by-user-id.md`) — **contradito** pela tabela de concluídos: corrigido na 0049 (`docs/draft-backlog.md:49`).
- `gotchas/open-design-views-mockup-rotas-futuras.md` — verificar se a 0076 entregou `GET /team/center` e `/team/mart` **antes** de abrir o item (0076 Done, `SESSIONS.md:517`).
- `docs/draft-backlog.md:127-128` (nível 5; +2/+1) — **feitos na 0067** (`SESSIONS.md:379`); `lose→0` na 0081 (Done); **E5 na 0058** (`:65`). Já anotados no próprio item.
- `sessions/0086-battle-log-juice.md` cita itens `TODO.md T2/T3/T6b` que **não existem mais** — `TODO.md` está com **0 bytes** hoje (referência pendurada).
- `GDD.md:69` cita `vaults/Projetos/poke-htmx/draft-futuro.md`, **ausente do repo**.

### 4.F Anomalia de numeração

`SESSIONS.md:403` reservava **0084** (CSRF) e **0085** (respiro) — e antes `:402` reservava 0080/0081/0082 para escritas atômicas/CSRF/respiro. Com a 0083 virando `ui-polish` e a numeração saltando para **0086**, os slots **0084/0085** seguem livres. Proposta: quando os itens de §4.B virarem sessão, usar **0084 = escritas atômicas + idempotência** e **0085 = CSRF/identidade** (o "respiro" pode absorver `pry` ou ser descartado).
