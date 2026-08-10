# Draft — Levantamento de arquitetura & design patterns (2026-08-10)

> **Fora do fluxo.** Levantamento/discovery para embasar as próximas implementações.
> Não gera critérios de aceite nem plano TDD agora (RNF-04). Revisar ao fechar as fases.
> Sessão de origem: refinamento alongado — apenas levantamento e anotações, **zero
> edição de código**.

---

## 1. Estado atual do código (levantamento real)

Camadas hoje (Sinatra + Dry::Struct + PostgreSQL + htmx):

| Camada | Arquivo | Papel | Padrão atual |
| --- | --- | --- | --- |
| Rota/Controladora | `server.rb` | Todas as rotas + lógica de orquestração inline nos handlers | Controladora fina→gorda (God routes) |
| Aplicação/Helpers | `server.rb` `helpers do` | `current_user`, `battle_moves_for` (domínio preso no HTTP) | Mixin de helpers |
| Domínio puro | `lib/battle_engine.rb`, `lib/battle_pokemon.rb`, `lib/type_effectiveness.rb`, `lib/move.rb`, `lib/opponent_generator.rb`, `lib/battle_registry.rb` | Núcleo do game loop, sem rede | Value Objects + Engine |
| Infra/Integração | `lib/poke_api.rb` | Toda a conversa com PokéAPI (HTTP + parse + caches em classe) | Facade/procedural estático |
| Persistência | `lib/team_repository.rb` | SQL por usuário; slots; moves | Repository |
| Apresentação | `views/*.erb` | Fragmentos htmx + `layout.erb` | ERB direto sobre os objetos |
| Testes | `test/*` (0019) | `TestSupport` (builders/factories), `TestDatabase` (introspection), `PokeApiStub` (stub de métodos singleton) | TestSupport + stubs |

Metrificação: **222 runs / 778 asserts, lint 0** (baseline da sessão 0019).

### `rubocop:disable` restantes — produção (alvo do refactor futuro)

Anotado no `draft-auto-battler.md` (sessão 0019 validada), **não executado**:

| Arquivo | Disables | O quê |
| --- | --- | --- |
| `server.rb` | 1 | `Metrics/ClassLength` (classe inteira) |
| `lib/battle_engine.rb` | 1 região | `ClassLength` + `AbcSize` + `MethodLength` + `ParameterLists` |
| `lib/battle_pokemon.rb` | 1 | `MethodLength` (`from`) |
| `lib/poke_api.rb` | 2 regiões | `ClassLength` + (`AbcSize`, `MethodLength` em `detail`) |
| `lib/team_repository.rb` | 2 | `ClassLength` + `MethodLength` (`all`) |

Total: **5 arquivos / 7 disables**. Plano de sessão futura única já esboçado no
`draft-auto-battler.md` (linha 237), com critério de "uma fase, salvo mudança de
contrato público".

---

## 2. Roadmap consolidado (ordem fechada em 2026-08-10)

> **Ordem encaminhada (decisão 2/8 da seção 8):** refactor produção → E1 → D2 → D3 →
> Fase Eco → (D4/D1 como candidatos futuros).

### Sessões em sequência

| # | Sessão (provável) | Escopo | Depende de |
| --- | --- | --- | --- |
| **1** | **Refactor produção** (respiro, molde da 0019) | Remover os 7 `rubocop:disable` de `lib/**` + `server.rb` (seção 1.1). Critério: suíte 222/778 + lint 0 preservados, sem mudança de comportamento. | — (agora) |
| **2** | **E1 — Cache de detalhes** (gateway/cache) | `PokeApi` → interface + adapter real (Faraday) + decorator de cache (TTL/LRU **fixos** — decisão 9). Refactor de `PokeApiStub` para adapter fake. | 1 (adapter reaproveita extração do `PokeApi`) |

> **E1 dividida em 2 sessões (decisão do usuário, 2026-08-10):** **E1-A — sessão 0021**
> (interface `PokeApi` + adapter real `PokeApiHttp` + adapter fake nos testes + injeção via
> `settings.api`/`PokeApi.instance`; memoização atual permanece por instância) — **implementada**
> em 2026-08-10 (sessão 0021, passos 1–6 commitados, `lib/poke_api.rb` static removido;
> `PokeApiStub` virou construtor de `PokeApiFake` + swap de `Server.api`) → **E1-B —
> sessão 0022** (decorator `PokeApiCache` TTL/LRU **fixos**, remove a memoização do adapter
> real). Sequência: E1-A → E1-B → D2 → D3 → Eco.

> **E1-B concluída (sessão 0022, 2026-08-10):** `PokeApiCache` (decorator TTL **600s** / LRU
> **máx 1000** — valores fixos, decisão 9) sobre a interface `PokeApi`, implementando o
> contrato e cacheando `[método, *args]` (`find`/`detail`/`move` não cacheiam nil;
> `fetch_all_names` só lista não-vazia — RF-18 preservado). A **memoização interna do
> `PokeApiHttp` foi removida** (`@fetch_all_names`/`@move_cache`/`@pokemon_moves_cache`/
> `@available_moves_cache`/`@type_relations`) — o adapter voltou a ser estateless; o cache
> vive no decorator. Composition root: `PokeApi.instance = PokeApiCache.new(PokeApiHttp.new)`.
> Testes do decorator com relógio injetável. E1 encerrada → próxima: **D2 (sessão 0023)**.

> **D2 dividida em A/B (decisão do usuário, 2026-08-10):** esta divisão **não muda a ordem do
> roadmap** (D2 → D3 → Eco), apenas detalha a entrega. **D2-A — sessão 0023**
> (opcionalmente 0023/0024): tabela nova `team_pokemon_progress` (decisão 3), 1ª evolução/
> nível 1 na montagem (4), `ExperienceCurve` **linear** por ora (5), stats escalam com o nível,
> `RewardRule` estrutura o gancho `:finished` (XP), `BattleEngine#result` (half-FSM terminal),
> oponente escala com o nível do jogador. **D2-B — sessão 0024** (evolução por nível +
> aprendizado de golpes por nível — cruz com D1) usando **dados oficiais da species**
> (`evolution_chain` + `level_learned_at`, decisão do usuário em 2026-08-10 — ver seção 8,
> decisão 15). **Implementada em 2026-08-10 (passos 1–7 TDD, suíte 327/1018, lint 0 —**
> **aguardando validação do usuário).**

> **D2-A concluída e validada (sessão 0023, 2026-08-10, passos 1–9 TDD + fase 3 do
> usuário):**
> migração `0023_add_team_pokemon_progress` (tabela por `team_pokemon_id`, FK `ON DELETE
> CASCADE`; `clear_team!`/truncates 0003/0007 em `CASCADE`); `ExperienceCurve` linear
> (`xp_needed = level*100`, `level_for_xp` por acumulado); `TeamRepository#add` cria
> progresso (nível 1/xp 0) na mesma transação; `ProgressionRepository` (`get`/`grant`
> por usuário via join de dono, no-op para estranho/id inexistente); `BattlePokemon` com
> `level` (stats escalam `base + (level−1)*0.5`, redondo — sem nível = idêntico);
> `RewardRule` (`DEFAULT_WIN_XP 50 / DRAW 25 / LOSE 20`, injetáveis — hook `:finished`
> pronto p/ Eco-1); `BattleEngine#result` (half-FSM terminal `nil`/`:win`/`:lose`/`:draw`,
> perspectiva do time A); `OpponentGenerator(level:)`; `server.rb` (`settings.progression`,
> `GET /battle` com nível por membro + oponente no **nível médio** do jogador, `POST
> /battle/play` concede XP **uma única vez** na transição para `:finished`, `battle.erb`
> com "Nível N" + aviso de XP). Suíte **292/941**, lint 0. **Validada pelo usuário em
> 2026-08-10 (fase 3) — sessão 0023 concluída.** **Próxima: D2-B — sessão 0024.**
| **3** | **D2 — XP/evolução** | **D2-A (sessão 0023):** tabela `team_pokemon_progress` (3); nível 1 na montagem (4); `ExperienceCurve` linear (5); stats escalam; `RewardRule` no `:finished` + `BattleEngine#result` (half-FSM); oponente escala. **D2-B (sessão 0024):** evolução + aprendizado por nível, dados oficiais da species (15). | 1, 2 (volume de requests) |
| **4** | **D3 — Histórico/rank** | Tabela `battles`; vitórias/derrotas por usuário + oponente serializado + data (6); rank **local e global** (7). Resolve o `BattleRegistry` no ponto mais atômico (8). | 3 (`:finished` já concede recompensa) |
| **5** | **Eco-1 — Moeda pós-batalha** | Tabela `wallet`; `RewardRule` passa a conceder **XP + dinheiro** no `:finished` (decisão 10 — moeda ao final da batalha como um todo). | 3 (mesmo hook), 4 (resultado persistido) |
| **6** | **Eco-2 — Poke Center** | `HealService` + `HealCostPolicy` **proporcional ao HP faltante** (11); rota htmx + fragmento; cobra do saldo. | 5 (saldo) |
| **7** | **Eco-3 — Poke Mart (catálogo + inventário)** | `Item` (Value Object), catálogo estático, compra com dinheiro, `InventoryRepository`, fragmentos htmx. | 5 (saldo) |
| **8** | **Eco-4 — Itens em batalha** | Consumíveis (poções) como **ação automática** no motor, depois aberta ao jogador (12); seguráveis escopo simples (13); estratégia do time **selecionável** (12). | 6/7 (itens), 3 (estratégia/engine) |
| — | **D4 — Draft temático** (candidato futuro) | Regras de validação na montagem (estende RF-07) | pós-Eco ou em paralelo |
| — | **D1 parcial / nível de aprendizado** (candidato futuro) | Golpes aprendíveis por nível (cruz com D2) | entra junto/antes do D2 |

**Nota:** D2 obriga estado persistente de progressão → impacto em `TeamRepository`
(novas colunas ou nova tabela) e multiplação de requests (reforça E1). É o item que
mais tensiona a arquitetura atual.

### Fase E — Economia & serviços entre batalhas (nova candidata, anotada 2026-08-10)

> Visão do usuário: **após cada batalha ganhamos dinheiro além de XP**; entre batalhas
> o jogador pode **passar no Poke Center** (recuperar os Pokémon, gastando dinheiro) ou
> no **Poke Mart** (comprar itens para os Pokémon — **consumíveis**, **seguráveis**
> (hold items) e **poções**). Proposta de divisão em fases:

| Fase | Escopo | Impacto arquitetural |
| --- | --- | --- |
| **Eco-1 — Moeda pós-batalha** | Criar saldo por usuário (tabela `wallet`/coluna) e conceder dinheiro ao atingir `:finished(win/lose/draw)` — **mesmo hook do XP (half-FSM, seção 6.1)**. Testável sem rede. | Novo `WalletRepository`; hook de terminal ganha a concessão de moeda ao lado do XP. |
| **Eco-2 — Poke Center** | Serviço de recuperação: custo baseado em HP faltante (e/ou reavivar?); rota htmx `POST /team/heal` + fragmento; cobra do saldo. | `HealService` (uso de caso); cálculos puros (`HealCostPolicy`); reforça persistir HP/status do time (D2 já persiste). |
| **Eco-3 — Poke Mart (catálogo + inventário)** | Catálogo de itens (Dry::Struct `Item`), compra com dinheiro, inventário persistido por usuário (tabela `inventory`), fragmentos htmx. | `Item` como Value Object; `InventoryRepository`; catálogo estático (molde de `TYPE_NAMES`); serviços de compra. |
| **Eco-4 — Itens em batalha** | Consumíveis (poções restauram HP **durante** a batalha — ação não-ofensiva no motor), seguráveis (hold items modulam stats/passivos via Strategy). | `BattleEngine` ganha tipos de ação além do ataque → **confirma o half-FSM** (ação = evento com transição); hold items via **Strategy/Decorator** sobre `BattlePokemon` (stats). |

**Circuito fechado:** batalha → `:finished` → XP + dinheiro → gastar (Center/Mart) →
batalhar de novo. D2 (XP) e Eco-1 compartilham exatamente o mesmo ponto de gancho
(terminal da batalha) — fazem sentido juntos ou na sequência.

### Novas ideias emergentes J1/J2/J3 (anotadas 2026-08-10, fora do fluxo)

> Registradas em `draft-auto-battler.md` (Cadastro de ideias 2026-08-10). Cruzamento com
> o estudo de arquitetura:

| Ideia | Essência | Impacto no roadmap/arquitetura |
| --- | --- | --- |
| **J1 — Seleção inicial de time** | Fim do dropdown + busca paginada (RF-01/RF-06); no início de cada partida, lista de Pokémon **base** para montar o time inicial de 6. | Redefine a entrada do jogo — `#pokemon-list`/`#pokemon` deixam de ser o hub. Pode entrar como "núcleo da jornada" (virar porta de entrada antes de D2). Cruz com D4 (draft). |
| **J2 — Personalização entre batalhas** | 3ª opção entre batalhas: dar **itens seguráveis**, **adicionar/trocar skills**, **usar itens**, **mudar estratégia de ataque do time** e reordenar Pokémon. | Estende A3 (`/team/manage`) + Eco-3/4. **Estratégia selecionável do time já é decisão 12.** Vira provável sessão própria pós-Eco. |
| **J3 — Ranking S–F de balanceamento** | Classificar cada Pokémon de **S a F** por stats + moves para balancear os times adversários que aparecem na jornada. | Fonte de verdade do `OpponentGenerator` (hoje sorteio puro) e do balanceamento por progressão. Sugere **`PokemonRating`** (domínio puro, molde de `TypeEffectiveness`). |

**J3 é o que mais interessa ao estudo de padrões:** gera um componente de domínio puro
(`PokemonRating#rate(pokemon) → :S..:F`) consumido pelo gerador de oponentes — sem rede,
TDD-ável, no mesmo molde das policies (seção 5). J1/J2 misturam fluxo de jogo + UI (refinam
com os wireframes de `docs/screens/`).

---

## 3. Padrões de projeto HOJE (presentes na base)

| Padrão | Onde | Observação |
| --- | --- | --- |
| **Value Object** (Dry::Struct imutável) | `Pokemon`, `BattlePokemon`, `Move`, `BattleResult` | Sólido; base dos testes. `attack/defense/hp` etc. imutáveis ajudam o determinismo. |
| **Strategy** (injeção via construtor) | `BattleEngine(target_strategy:)`, `OpponentGenerator(rng:, fetcher:)`, `TypeEffectiveness` em `BattleEngine` | Bom grau de injeção de dependência no domínio. |
| **Factory Method / Builder** | `BattlePokemon.from`, `OpponentGenerator#team`, `PokeApi.extract_move`, `PokeApi.detail` | Presente, mas espalhado e acoplado ao estático `PokeApi`. |
| **Repository** | `TeamRepository` | Único persistente; por-agregado (time). |
| **Registry** | `BattleRegistry` | Estado de batalha em memória por usuário (efêmero). |
| **Facade/Proxy** | `PokeApi` | Todo HTTP + parse + cache concentrado. |
| **Memoization** | `PokeApi` (`@fetch_all_names`, `@move_cache`, `@pokemon_moves_cache`, `@available_moves_cache`, `@type_relations`) | Cache em classe estática — funcional mas global e opaco. |
| **Helper/Mixin** | `server.rb helpers` | Orquestração útil mas mistura domínio (moves) com HTTP. |

## 4. Anti-padrões / dívidas que torram capacidade de evoluir

| Anti-padrão | Onde | Custo para D2/D3/D4 |
| --- | --- | --- |
| **God class estática** | `server.rb`, `BattleEngine`, `PokeApi` | Métricas estourando → origem dos `rubocop:disable`. Cada feature nova aumenta. |
| **Rota-gorda (orquestração no handler)** | `GET /battle` (45 linhas inline: busca time → detalhes → oponente → engine → registry) | Lógica de regra de negócio não testável sem HTTP. D2/D3 vão dobrar esse handler. |
| **Gateway acoplado e global** | `PokeApi` estático com caches em classe | E1 (cache) e D2 (escala) exigem trocar a implementação (TTL, LRU, decorator) e stub nos testes — hoje via monkey-patch de métodos singleton. |
| **Domínio preso ao HTTP** | `battle_moves_for` em `server.rb` (saved × fallback × Struggle) | Decisão de golpes pertence ao domínio; D1/D2 precisam reusar. |
| **Presentação replicada** | `battle.erb` duplica o loop "Seu Time"/"Oponente"; `team.erb`/`team_manage.erb` duplicam slots | D3 (histórico) reusaria a mesma apresentação. |
| **Lógica SQL espalhada** | `TeamRepository` só; mas D2/D3 vão somar projeções | Repositórios novos surgem sem contrato comum. |
| **State efêmero** | `BattleRegistry` em memória | D3 exige persistência; D2 exige progressão persistida. |

---

## 5. Padrões a IMPLEMENTAR (por driver do roadmap)

| Padrão | Driver | Proposta |
| --- | --- | --- |
| **Application Service / Use Case** | D2/D3 + refactor produção | Extrair orquestração dos handlers (ex.: `BattleService#prepare(user)`, `TeamService`) em classes PORO testáveis. Encolhe `server.rb` (mata o `ClassLength`) e os handlers virando thin controllers. |
| **Gateway interface + Adapter** (PokeApi como interface com impl real e stub) | E1 + D2 + testes | Trocar `PokeApi` estático por um gateway injetável (construtor recebe `http`). `PokeApiStub` deixa de depender de monkey-patch de singleton e vira adapter fake — simplifica os testes já estabelecidos na 0019. |
| **Cache Decorator** | E1 | Decorator com TTL/LRU sobre o gateway (não no domínio). Remove a memoização global atual e dá controle de invalidação. |
| **Repository por agregado** | D2/D3/Eco | `BattleRepository` (persistir `battles` p/ D3), `ProgressionRepository` ou colunas de nível em `team_pokemons` (D2), **`WalletRepository`** e **`InventoryRepository`** (saldo/itens Eco-1/3). Contrato comum (`all/add` por `user_id`), espelhando `TeamRepository`. |
| **Strategy estendido** | D2/D1/Eco-4 | Mover seleção de golpe (hoje `choose_move`) e aprendizado por nível para estratégias injetáveis — testável e reusável. **Hold items (seguráveis) entram como strategy/decorator sobre `BattlePokemon`** (modulam stats/passivos sem tocar o núcleo do motor). |
| **Presenter / decorator de view** | D3 + battle.erb + Eco-2/3 | Apresentar payloads prontos (ex.: `BattleLogPresenter`, fighter row, `InventoryPresenter`), eliminando a duplicação de loops nos ERB. |
| **Composition Root / injeção simples** | Todos | Construir serviços/repositórios no boot (Sinatra `set :services`, `set :api`), sem framework DI — manter o estilo leve. |
| **Rule/Policy objects** | D2/D4/Eco | Políticas puras: `ExperienceCurve` (XP→nível), `EvolutionRule` (nível→evolução), `DraftRule` (validação de montagem temática), **`RewardRule` (moeda/XP por resultado)** e **`HealCostPolicy`** (custo do Poke Center). Genéricas e TDD-áveis sem rede, no molde de `TypeEffectiveness`/`BattleEngine`. |
| **Rating (classificador de balanceamento)** | **J3** | **`PokemonRating`** — domínio puro que classifica um Pokémon em **S–F** por stats + moves (fórmula a definir). Consumido pelo `OpponentGenerator` e pelo balanceamento por progressão. Sem rede; mesma família das policies. |
| **Command (ação de batalha)** | Eco-4 | Consumíveis em combate (poção) são **ações não-ofensivas** no motor — modelar como comando/evento no half-FSM (seção 6.1) em vez de ramificar `BattleEngine#act` com if/else. |

---

## 6. Arquitetura-alvo proposta (visão)

```
views/            ← Presenters + ERB (fragmentos htmx), sem lógica de negócio
                     (ex.: BattleLogPresenter, FighterPresenter)

                                │
server.rb         ← só routing (thin controller): parse params → chama Use Case
  ▼
app/services/     ← Application Services (PORO): BattleService, TeamService
                     (orquestram domínio + infra, testáveis sem HTTP)
  ▼
lib/ (domínio)    ← BattleEngine, BattlePokemon, Move, Item, TypeEffectiveness,
                     OpponentGenerator, ExperienceCurve, EvolutionRule,
                     RewardRule, HealCostPolicy…
                     (puro, sem rede, com dependências injetadas)
  ▼
lib/repositories/ ← TeamRepository, BattleRepository, ProgressionRepository,
                     WalletRepository, InventoryRepository
  ▼
lib/gateways/     ← PokeApi (interface) + PokeApiHttp (real, via Faraday)
                     + PokeApiCache (decorator TTL/LRU)   [E1]
```

**Benefícios diretos para o roadmap:**
- D2 (XP/evolução): policies puras + ProgressionRepository entram sem engordar `BattleEngine`.
- D3 (histórico): `BattleRepository` + Presenter; sem tocar no domínio.
- E1 (cache): ✅ **implementado (E1-A sessão 0021 + E1-B sessão 0022)** — `PokeApi.instance`
  = `PokeApiCache.new(PokeApiHttp.new)` (TTL 600s / LRU 1000 fixos); adapter real estateless;
  transparente para serviços.
- Eco (moeda/Center/Mart): `WalletRepository`/`InventoryRepository` + `Item` (Value Object)
  + serviços `HealService`/`ShopService` seguem o mesmo molde; **o hook de `:finished`
  agrega XP + moeda numa só política de recompensa** (seção 6.1).
- Refactor produção (7 disables): os `ClassLength`/`AbcSize` de `server.rb`/`BattleEngine`/
  `PokeApi`/`TeamRepository` caem naturalmente por extração (não à força).

---

## 6.1. Gameloop como máquina de estado — anotação (2026-08-10)

**Pergunta:** fazer o gameloop virar uma máquina de estado — ajuda ou atrapalha?

**Veredito:** ajuda numa camada **fina** (nível da batalha); atrapalha se virar
re-modelagem do motor inteiro.

- **NÃO fazer (YAGNI):** FSM estrita dentro do `BattleEngine` (estados por ação:
  `player_turn`, `opponent_turn`, `apply_damage`, `check_fainted`...). O motor é puro,
  determinístico e teste por alimentar estado→conferir saída; FSM fina perdê essa
  testabilidade de estados parciais. Complexidade real está nas regras (efetividade,
  dano, moves, PP), não no fluxo. Também não resolve os `rubocop:disable` de produção.
- **FAZER (half-FSM):** estado **terminal explícito** da batalha — hoje `finished?`/
  `winner` são computados por inspeção. Introduzir enum de status
  `:preparing → :in_progress → :finished(win|draw|lose)` com transições/guards
  explícitas. Drivers:
  - **D2 (XP):** concede XP ao atingir `:finished(win|lose)` — policy consome o terminal.
  - **Eco (moeda):** mesmo hook de recompensa agrega **XP + dinheiro por resultado**
    (`RewardRule`) — um só ponto concede tudo, evitando duplicar a lógica de grant.
  - **Eco-4 (items em batalha):** poção/consumível é **ação entre turnos** —
    um `:item` command (seção 5) transpõe sob guards, sem ramificar `BattleEngine#act`.
  - **D3 (histórico/rank):** persistir os 3 terminais sem re-computar.
  - **UI:** `battle.erb` deixa de checar `finished?`/`winner` por inspeção.
  - **Base futura:** pausa/serialização/recomeço, se interatividade entrar.
- **Forma:** enum + transição leve (não o padrão GoF State com classes). Mais
  Ruby/Sinatra-idiomático, cola com o `BattleResult` atual e mantém determinismo
  (com `rng` já injetado via `OpponentGenerator`).
- **Impacto em teste:** diminui (estados são valores, asserts diretos); exige só
  cobertura das transições. Não muda `PokeApiStub` nem o baseline 222/778.

---

## 7. Riscos / impactos a considerar antes de decidir

- **PokeApiStub (testes 0019):** hoje stuba métodos **singleton** via redefinição.
  Mudar `PokeApi` para instância/injeção muda os helpers `with_find`, `with_detail`,
  `with_moves_for`, etc. É a maior refatoração de testes do movimento — exige passo
  cuidadoso para não regredir a baseline 222/778.
- **RNF-04:** não abrir escopo novo no meio da sessão corrente. Este draft é anotação;
  o refactor de produção viraria sessão própria com critérios + plano TDD.
- **Ordem sugerida:** (1) refactor produção (7 disables) como "respiro" assim como a 0019;
  (2) gateway + cache (E1) antes de D2 para aliviar o volume de requests; (3) D2 com
  services/policies/repository já na nova arquitetura; (4) D3/D4 aproveitam a base.
- **Escopo do gateway é o item mais invasivo** (toca todos os pontos de uso + tests).
  Pode ser dividido em 2 sessões: interface+adapter, depois decorator de cache.

---

## 8. Decisões fechadas (2026-08-10, usuário)

| # | Decisão | Resolução |
| --- | --- | --- |
| 1 | Arquitetura de camadas (seção 6) como norte | **Aceita** — norte das próximas sessões |
| 2 | Ordem das próximas sessões | **Refactor produção (7 disables) primeiro** → depois E1 (gateway/cache) → D2 |
| 3 | D2: onde persiste `level/xp` | **Tabela nova** `team_pokemon_progress` (isolada de `team_pokemons`) |
| 4 | D2: estado de montagem | Confirmado: **1ª evolução, sempre nível 1 na montagem** |
| 5 | D2: curva de experiência | **Linear por ora**; balanceamento fino fica para etapa posterior |
| 6 | D3: dimensões do histórico | Confirmado: vitórias/derrotas por usuário, oponente serializado, data |
| 7 | D3: rank | **Local e global** (por usuário + líder no geral) |
| 8 | `BattleRegistry` (efêmero) | Resolver no que for **mais atômico** (persistir no D3 ou ajuste no refactor — o que implicar menor toque) |
| 9 | E1: cache | **TTL/LRU fixos** (sem configuração por tipo por ora) — **aplicado na sessão 0022**: TTL **600s**, LRU **máx 1000 entradas** |
| 10 | Eco: quando conceder moeda | **Ao final da batalha como um todo** — XP + moeda conjugados no hook `:finished` (`RewardRule`) |
| 11 | Poke Center: custo | **Proporcional ao HP faltante** (`HealCostPolicy`) |
| 12 | Consumível em batalha (Eco-4) | **Automático no início** (estratégia decide); depois abrir para o jogador escolher — **o mesmo vale para a estratégia do time** (estratégias selecionáveis) |
| 13 | Itens seguráveis | **Escopo simples**: 1 slot por Pokémon, modula só Attack/Speed por ora |
| 14 | Commit deste draft | `Draft: levantamento de arquitetura e design patterns (2026-08-10) — base para D2/E1/refactor de produção e fase Eco (moeda, Poke Center, Poke Mart)` |
| 15 | D2: fonte de evolução e aprendizado | **Dados oficiais da species** (`evolution_chain` + `level_learned_at`) — não níveis fixos padrão. Aplicado na D2-B (sessão 0024) |

**Sequência de sessões encaminhada — ver seção 2 (roadmap consolidado):** refactor
produção → E1 → D2 → D3 → Eco-1..4. A estratégia selecionável do time (decisão 12)
impacta o `BattleEngine`/`OpponentGenerator` — política a detalhar na fase própria.

### Perguntas em aberto — ideias J1/J2/J3 (anotadas 2026-08-10)

- [ ] **J1 (seleção inicial):** a lista base é fixa (iniciais/famílias clássicas),
      sorteada do pool ou por gen? Quantas opções por tela? Entra **antes** de D2
      (virar porta de entrada da jornada) ou depois do refactor?
- [ ] **J2 (personalização):** tela própria ou extensão de `/team/manage`?
      Estratégia de ataque é **por time ou por Pokémon**? Trocar skills tem custo
      (Eco) ou é livre?
- [ ] **J3 (rating S–F):** fórmula dos pontos (peso por stats + moves aprendíveis)?
      Classificação computada **offline/via cache** ou na montagem do oponente?
      Rank é exibido na UI?
- [ ] **J1 + D4 (draft temático):** seleção inicial e draft temático se sobrepõem —
      unificar ou manter separados?