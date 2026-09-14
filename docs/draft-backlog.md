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
- **Escritas multi-tabela fora de transação única** — compra/batalha orquestram wallet+inventory+XP em passos separados. (limitação aberta; candidata a "escritas atômicas")
- **Remover `pry` do runtime de produção** — `server.rb`/Gemfile; barato, respiro técnico.
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
- **Times iniciam no nível 5** — `TeamRepository#add`/`ProgressionRepository` criar progresso `level: 5`.
- **Vitórias +2 níveis, derrotas +1** — conceder XP equivalente a 2/1 níveis.
- **Exploits/desequilíbrios (playtest 0063)** — E1 (lendários desde nível 5 vs banda D/C), E2 (farm de derrota), E3 (custo por linha vs base = noob trap), E4 (sem cap de tier S), E5 (linha S restrita 110), E6 (gate `base_form?` só 1ª evolução).

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
- **Efeitos de golpe: projétil + shake (extensível)** — a jogada deve mostrar o efeito saindo do Pokémon atacante em direção ao atacado e um shake no que recebe o golpe. Precisa ser extensível para: (a) futuras mudanças de estratégia de ataque; (b) cor do efeito derivada do tipo do golpe.
  - Contexto: a sessão 0086 (battle-log + juice CSS-only) excluiu explicitamente "projétil <900px" do escopo; o caminho do strike já carrega `data-from-side` / `data-to-side` na entrada do log e emite gates `[data-jx-*]` OOB — usar isso como gancho de extensibilidade em vez de JS por golpe.
  - Nota: cabe avaliação de tipo-de-golpe (o move já é conhecido no servidor; verificar se o tipo vem no payload atual ou se precisa ser exposto).
  - Chegada real atacante→atacado (medido 2026-09-14, anotado pós-review da 0086): hoje é teto direcional, não chegada — `.shot` é filho de `li.fighter` (`views/_fighter_panel.erb:14`), absoluto sobre o card, `translateX(calc(100% + 40vw))` (`public/style.css:1587,1598`) → para no podium (~472px vs ~815px medidos centro-a-centro).
  - Esforço: **M** CSS-only com `container-type: inline-size` + `--fx-travel: 67cqi` derivado do grid `1fr/1.06fr/1fr` + 2 gaps de 32px (aproximado, erro de dezenas de px); **L** se pouso fiel ponto-a-ponto — exige medição em runtime = JS, hard-out do escopo (`sessions/0086-battle-log-juice.md §3:39`).
  - Requer: mover o markup do `.shot` do card para o track da arena (CSS não move elemento entre colunas; o servidor já sabe `data-from-side`/`data-to-side`), elemento de impacto por-linha no card alvo no instante da chegada (C13 postergou de propósito), keyframes `juice-shot-ltr/rtl` (`public/style.css:1581-1601`), rede reduced-motion (C14), 6 caudas do lab para o look de "saída", testes `test/style_responsive_test.rb:275-289,322-428` + e2e.
  - Risco: abaixo de 900px a arena colapsa para 1 coluna (`public/style.css:607-611`) mas o travel é horizontal em `min-width:900px` → projétil voa pelo vazio (hoje mascarado pelo fade em 40vw).
- **Convergência de paleta de tipos com o lab (`public/type-effects-lab.html`)** — o lab define head claro + 6 tails saturadas em HEX CRU por tipo; 7/18 já casam (grass, water, electric, fighting, steel, ghost, dragon — alguns limítrofes) e 11 divergem: fire→#f97316, normal→#a8a29e, ice→#22d3ee, poison→#9333ea, ground→#92400e, flying→#38bdf8, psychic→#db2777, bug→#65a30d, rock→#78716c, dark→#1f2937, fairy→#f472b6.
  - Esforço S: ~20 LOC em `public/style.css:19-36` (18 tokens `--t-*`), 1 linha em `DESIGN.md:14`, revisão visual dos badges `.ftag--*` (`public/style.css:1399-1501`).
  - Bloqueios: `DESIGN.md:3-4` proíbe hex hardcoded (tokens só via DESIGN.md) e C11 (`sessions/0086-battle-log-juice.md §4:57`) exige "paleta `--t-*` existente + fallback" → exige S3 no C11; `--t-*` é global (pinta badges em roster/team/battle), não só o projétil.
- **Remover o toggle JOGAR-AUTO e disparar os tempos no clique de "Batalhar"** — eliminar o checkbox `#auto-play`/`name="auto"` e o chain por `HX-Trigger`, de modo que um unico clique em `#play-btn` rode a batalha inteira com o pacing ajustado.
  - Pedido do usuario na validacao da 0086 (2026-09-14); altera comportamento ja validado (C4 tiered pacing + "Pular", C7 advance-one-round + JOGAR-AUTO) → **exige S3 nos C4/C7 e sessao nova**.
  - Hooks afetados: `views/battle.erb:70` (toggle) e `views/battle.erb:71-73` (`hx-include="#auto-play"`, `hx-trigger="click, next-strike from:body, next-round from:body"`); `server.rb:1070` (`next-round` em `advance_battle`), `server.rb:1074-1075` (`auto_play_requested?`), `server.rb:1086` (`next-strike` em `strike_battle`); pacing CSS-only em `public/style.css:1880+` (`.log-skip-input`/`.log-skip-btn`).
  - Testes a remover/reescrever: `test/battle_routes_test.rb` `test_battle_auto_toggle_chains_advance_until_finished` (l.186), `test_battle_auto_off_stops_chain` (l.206), `test_battle_auto_stays_checked_across_swaps` (l.217), `test_battle_strike_button_wires_auto_chain` (l.227) + e2e `e2e/specs/battle-log.spec.ts` caso `auto toggle chains to finish without further clicks` (~l.99).

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
