# Sessão 0055 — M2: sistema de custo para montagem de time

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões ratificadas pelo usuário em 2026-08-26 (ajustes em D1/D2/D4) |
| Implementação | **Pendente** (fase 2) |
| Validação | **Pendente** (fase 3 — executada pelo usuário) |

---

## 1. Objetivo

Implementar **M2 — sistema de custo para montagem de time**, com três regras combinadas:
**(1) teto de 3 Pokémon de tier S por time** (regra dura, com aviso próprio); **(2) custo
por linha evolutiva** — cada Pokémon paga pelo **maior tier da sua cadeia de evolução**
("evoluções muito fortes = mais caro", fechando o furo de adicionar pré-evolução barata
que vira S depois) com tabela **S=120/A=70/B=55/C=40/D=30/F=20**, e **metade do custo**
para quem tem **restrição de evolução** (pedra/item/troca); **(3) orçamento de montagem
de 450 pontos** — limite derivado do time atual + candidato, **sem movimentar wallet/Eco**.
As regras valem para **todo `POST /team`** (montagem inicial e trocas; remoção libera).
O painel do time mostra custo/orçamento e o uso do teto de S.

## 2. Contexto (estado atual — antes do código)

- **Add hoje:** `add_team_member` (`server.rb:245-255`) resolve o Pokémon
  (`new_member_from_api` → `api.find` + golpes nível 1), valida (`add_team_notice`),
  insere, marca a jornada no 6º (`mark_started_when_full`) e invalida a batalha ativa
  **só quando não há erro**. Resposta = mini-status (`team_add_result.erb` com
  `@notice`/`@notice_kind`) + OOB `#team-view` + OOB `#pokemon-list`. Os bloqueios por
  teto de S e por orçamento encaixam como **notices de erro** nesse mesmo fluxo.
- **J3 (sessão 0040):** `PokemonRating#rate(pokemon, moves:) → {score:, tier:}`
  (S≥600/A≥500/B≥420/C≥350/D≥280/F<280). **`PokemonRatingCache#rating_for(name)`**
  (`lib/pokemon_rating_cache.rb`) dá o tier **por nome** com persistência (TTL 7d,
  `tmp/pokemon_rating_cache.json`, env `POKERATING_CACHE_PATH`), fetchers
  `detail`+`moves_for` no miss; é o **mesmo cache** da varredura de oponentes
  (`BattleService#default_rating_cache`, `lib/battle_service.rb:335`) — batalhas
  aquecem o cache para a montagem.
- **Cadeia de evolução já disponível no add:** `api.find(name)` monta o `Pokemon` com o
  atributo `evolutions` = **todos os membros da cadeia** (`evolution_chain`/
  `flatten_chain` em `lib/gateways/poke_api_parsing.rb`) — o **tier da linha**
  (máximo dos tiers dos membros) sai de lookups de rating sobre nomes já buscados,
  **sem fetch novo**.
- **Membros evoluem no meio da jornada** (D2-A, sessão 0023 — `evolve_member` em
  `lib/battle_service.rb:236`): por isso o teto de S e o custo usam o **tier da linha**,
  não o tier próprio do membro no momento do add.
- **Gateway:** `lib/gateways/` (`poke_api_http.rb` + `poke_api_parsing.rb` +
  `poke_api_moves.rb` + decorator `poke_api_cache.rb`). O parsing da cadeia **já extrai
  o `trigger`** (`stage_details`, `poke_api_parsing.rb:126-130`), mas
  `resolve_evolution_entries` filtra só `level-up` com `min_level` — estágios por
  item/pedra/troca são descartados. Gancho para detectar "restrição de evolução" sem
  fetch novo.
- **Eco (fora do caminho):** `WalletRepository` (balance/grant/spend/set) e
  `SaldoInicial::INITIAL_BALANCE = 200` (`db/seeds/saldo_inicial.rb`, usado no
  `POST /journey/restart`) — a montagem **não** toca nisso (ver D5).
- **Testes:** `PokeApiStub.with_find` (`test/test_helper.rb:226`) injetado via
  `Server.set :api`; `test/gateway_interface_test.rb` garante paridade de interface;
  `test/poke_api_fake.rb` é o fake HTTP do parsing. Suíte atual
  **805 runs / 2630 assertions, lint 0** (fim da 0054).

## 3. Escopo

### Produção
- `lib/team_budget.rb` (novo, domínio puro): tabela tier→custo por linha
  (**S=120, A=70, B=55, C=40, D=30, F=20**), `BUDGET = 450`, `S_LIMIT = 3`,
  `cost_for(line_tier:, restricted:)` (restrito = **metade, arredondado para baixo**),
  `fits?(current_total, new_cost)` e `s_limit_ok?(current_s_count)`.
- **Gateway — `evolution_restricted?(name)`** (novo método da interface `PokeApi`):
  `true` se o Pokémon tem **pelo menos um estágio seguinte cujo trigger ≠ "level-up"**
  (use-item/pedra, trade, …); `false` para evolução só por nível ou sem evolução. Reusa
  `find_current_species_next_stages`/`stage_details` (mesmos fetches de espécie+cadeia já
  cacheados). Paridade: HTTP/parsing + decorator de cache + fake de teste +
  `gateway_interface_test`.
- `server.rb`: no `add_team_member`, **antes do insert** — (a) calcular o **tier da
  linha** do candidato (máximo dos `rating_for` dos nomes da cadeia, fonte de rating
  **injetável via `Server.set`** — default `PokemonRatingCache` real; teste: fake
  determinístico nome→tier); (b) **teto de S**: se a linha é S e o time já tem 3
  membros de linha S → notice de erro próprio, sem insert; (c) **orçamento**: custo do
  time + custo do candidato ≤ 450, senão notice de erro, sem insert. Nenhum bloqueio
  marca jornada nem invalida batalha. `prepare_team_fragment_data` expõe
  `@team_cost`/`@team_budget`/`@team_s_count`.
- `views/team.erb`: painel mostra "Custo do time: X/450" e "S no time: n/3" (aparece em
  `GET /team` e no OOB pós add/remove).

### Testes
- `test/team_budget_test.rb` (novo): tabela tier→custo, metade para restrição
  (arredondamento), `fits?` (fronteira 450), `s_limit_ok?` (3 permite, 4º bloqueia).
- `test/poke_api_test.rb` (ou o arquivo de parsing vigente): `evolution_restricted?` com
  cadeia com item/pedra (true), só nível (false), sem evolução (false) — via
  `poke_api_fake`.
- `test/team_routes_test.rb`: tier da linha = máximo da cadeia (candidato com evolução S
  paga/conta como S); add dentro dos limites atualiza painel; add bloqueado pelo teto de
  S (aviso próprio) e pelo orçamento (aviso próprio) — time inalterado, jornada não
  marcada; remoção libera teto e orçamento; painel mostra custo/orçamento/contagem de S.
- `test/gateway_interface_test.rb`: paridade com o método novo.
- **Ajuste de suporte:** testes de rota que adicionam Pokémon passam a usar fake de
  rating determinístico (default barato, ex.: todos tier F) para a suíte existente seguir
  verde **sem rede**.

### Fora de escopo (não abrir)
- **UX-2 — custo/ranking na listagem + filtros avançados** (`draft-auto-battler.md:712`):
  sessão futura; agora o custo aparece **só no painel do time**.
- **D4 — draft temático**: sessão futura; o desenho mantém as regras em política pura e
  injetável para caberem modificadores depois (ver D6).
- **M1 — pedras de evolução no Poke Mart** (`draft:673`): a detecção usa o trigger da
  cadeia, mas **nenhum item de evolução vira mercadoria** nesta sessão. (Quando M1
  entrar, revisitar o desconto da restrição — ver Observações.)
- **Regra "Pokémon com vida zerada não pode ser removido"** (candidato próprio no
  `REQUIREMENTS.md`, ~linha 647): confirmada **fora** — o custo não depende dela.
- **Qualquer débito/crédito no wallet**, schema novo/migração, gem nova, custo persistido
  por membro (tudo **derivado** do time atual), re-contagem de teto após evolução
  acontecer (o add já considera a linha — evolução no meio da jornada não muda o time
  ter ≤ 3 linhas S).

## 4. Critérios de aceite

### Resultado
- [ ] **C1 (custo por tier da linha):** a política mapeia o tier da linha na tabela
      (S=120/A=70/B=55/C=40/D=30/F=20). — prova: `test/team_budget_test.rb`
      (`test_cost_by_line_tier`).
- [ ] **C2 (restrição paga metade):** linha com restrição de evolução paga metade do
      custo do tier, arredondado para baixo (ex.: linha B 55 → 27). — prova:
      `test/team_budget_test.rb` (`test_restricted_evolution_costs_half`).
- [ ] **C3 (checagem de orçamento):** `fits?` permite soma ≤ 450 (fronteira exata) e
      bloqueia > 450. — prova: `test/team_budget_test.rb`
      (`test_add_within_budget_allowed`, `test_add_over_budget_blocked`).
- [ ] **C4 (teto de 3 S):** `s_limit_ok?` permite até 3 membros de linha S e bloqueia o
      4º. — prova: `test/team_budget_test.rb`
      (`test_s_limit_allows_three_and_blocks_fourth`).
- [ ] **C5 (detecção de restrição no gateway):** `evolution_restricted?` devolve `true`
      para cadeia com próximo estágio por item/troca, `false` para só-nível e para sem
      evolução. — prova: `test/poke_api_test.rb`
      (`test_evolution_restricted_by_trigger`).
- [ ] **C6 (tier da linha = máximo da cadeia):** candidato cuja cadeia contém membro S
      paga e conta como S mesmo com tier próprio menor (e o mesmo para custo de linha
      não-S). — prova: `test/team_routes_test.rb`
      (`test_cost_uses_highest_chain_tier`).
- [ ] **C7 (add dentro dos limites):** `POST /team` respeitando teto e orçamento insere
      o membro e o painel (`#team-view`) mostra o novo custo e a nova contagem de S. —
      prova: `test/team_routes_test.rb` (`test_add_within_limits_updates_panel`).
- [ ] **C8 (bloqueios com aviso próprio):** 4º membro de linha S → notice do teto
      ("máximo de 3 …"), estouro de orçamento → notice do orçamento; nos dois casos time
      inalterado, jornada **não** marcada, batalha **não** invalidada. — prova:
      `test/team_routes_test.rb` (`test_add_blocked_by_s_limit`,
      `test_add_blocked_by_budget`).
- [ ] **C9 (remoção libera):** remover membro reduz o custo derivado e a contagem de S;
      um re-add antes bloqueado passa a caber. — prova: `test/team_routes_test.rb`
      (`test_remove_frees_budget_and_s_limit`).
- [ ] **C10 (painel mostra custo/orçamento/S):** o fragmento do time exibe
      "Custo do time: X/450" e "S no time: n/3" em `GET /team` e após cada add/remove
      (OOB). — prova: `test/team_routes_test.rb`
      (`test_team_panel_shows_cost_budget_and_s_count`) + **manual** (conferir
      visualmente layout/avisos com `./scripts/run`).

### Garantias (RNF)
- [ ] **G1:** suíte completa verde após cada passo + lint 0 em todo green; commit
      obrigatório por passo; 0 regressão fora do escopo (os adds existentes seguem
      funcionando via fake de rating default).
- [ ] **G2:** sem gems novas / sem mudança de schema / testes sem rede (rating e cadeia
      de evolução por stubs/fakes); manter o padrão local de RuboCop em testes.
- [ ] **G3:** `SESSIONS.md` atualizado no commit do refinamento (S4); status de
      validação só após o usuário validar (fase 3 — parar na fase 2 e aguardar).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste automatizado →
> `manual` explícito + evidência esperada (ver C10).

## 5. Decisões de refinamento (fechadas com o usuário)

- **D1 (fonte do custo + teto de S, 2026-08-26 — ajustada pelo usuário):** custo derivado
  do **tier da linha evolutiva** (máximo dos tiers da cadeia via
  `PokemonRatingCache#rating_for`, mesmo cache da varredura de oponentes) — "evoluções
  muito fortes devem ser mais caras também"; tabela **S=120, A=70, B=55, C=40, D=30,
  F=20**. Regra dura: **máximo de 3 Pokémon de linha S por time** (pedido explícito do
  usuário), com aviso próprio no add. O teto conta o **tier da linha** porque membros
  evoluem no meio da jornada (D2-A) — contar o tier próprio abriria o furo de montar 6
  pré-evoluções baratas de linhas S. **Alternativas preteridas:** orçamento puramente
  pontual sem teto explícito (o 4º S ficaria bloqueado só pelo preço — frágil e com aviso
  genérico); custo pelo tier próprio do membro (furo das pré-evoluções).
- **D2 (restrição de evolução, 2026-08-26 — ajustada pelo usuário):** Pokémon cujo
  próximo estágio exige trigger ≠ "level-up" (pedra/item, troca) paga **metade do custo
  do tier da linha** (arredondado para baixo). Detecção via **novo método
  `evolution_restricted?(name)`** no gateway, reusando o parsing de cadeia existente
  (`stage_details` já lê o trigger; nenhum fetch novo). **Alternativa preterida:** custo
  fixo 10 (proposta inicial do refinamento — o usuário preferiu a metade do tier).
- **D3 (onde o custo entra, 2026-08-26 — mantida):** em **todo `POST /team`** — montagem
  inicial (J1) e trocas. Modelo "soma do time ≤ orçamento" + contagem de S derivada:
  **remoção libera pontos e vaga no teto**, reordenação/move não altera nada. Bloqueio =
  notice de erro no fluxo existente, sem insert. **Alternativa preterida:** orçamento só
  na montagem inicial (trocas sem custo — furo de balanceamento).
- **D4 (orçamento inicial, 2026-08-26 — ajustada pelo usuário):** **450 pontos**
  (`TeamBudget::BUDGET`), calibrado pelo requisito do usuário de **permitir no máximo
  3 S por time**: 3S+3F = 420 cabe; 4S = 480 **não** cabe (o orçamento trava o 4º S além
  do teto duro); 6A = 420 cabe (time forte sem S continua viável); 3S+3C = 480 não cabe
  (quem leva 3 S usa preenchedores baratos — tensão de draft). Constante derivada, sem
  estado: time vazio = custo 0; `POST /journey/restart` (0053) zera naturalmente.
  **Alternativa preterida:** 300 (proposta inicial — com a tabela nova e o teto de S,
  esmagaria times médios sem S).
- **D5 (interação com a moeda Eco, 2026-08-26):** o custo é um **limite de montagem,
  NÃO transação monetária**: nenhum débito/crédito no `WalletRepository`, nenhum refund.
  Justificativa: (a) o objetivo do M2 é balancear montagem/draft, não a economia
  pós-batalha; (b) debitar do wallet criaria loop de farm de dinheiro para trocar o time
  e conflitaria com a economia de game over (GL-1/0053, saldo 200); (c) sem estado novo
  nem migração. **Alternativa preterida:** reusar o wallet (200) como orçamento de
  montagem com spend/refund.
- **D6 (D4 — draft temático, 2026-08-26):** **fora do escopo** (sessão futura); teto,
  tabela e orçamento moram em política **pura e injetável** (`lib/team_budget.rb` + fonte
  de rating via `Server.set`), de modo que modificadores temáticos entrem depois sem
  redesenho.
- **D7 (regra de vida zerada, 2026-08-26):** confirmada **fora** — "Pokémon com vida
  zerada não pode ser removido" é candidato separado (`REQUIREMENTS.md` ~647, rejeitado
  anteriormente com aviso) e o custo não depende dela.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (tabela + "Próxima sessão") | commit `Sessao 0055: refinamento concluido — M2 custo por linha evolutiva, teto de 3 S e orcamento 450 sem wallet, criterios e plano TDD fechados` |
| 1 | **red→green** — `lib/team_budget.rb` + `test/team_budget_test.rb`: tabela por tier da linha (C1), metade para restrição com arredondamento (C2), `fits?` com fronteira 450 (C3), `s_limit_ok?` 3/4 (C4) | `./scripts/test test/team_budget_test.rb`; suíte completa + `./scripts/lint` 0; commit `Passo 1: politica de custo por linha evolutiva com teto de 3 S e orcamento 450` |
| 2 | **red→green** — gateway `evolution_restricted?(name)`: parsing por trigger (C5) + paridade (http/cache decorator/fake/`gateway_interface_test`) | `./scripts/test test/poke_api_test.rb test/gateway_interface_test.rb`; suíte + lint 0; commit `Passo 2: evolution_restricted? no gateway via trigger da cadeia de evolucao` |
| 3 | **red→green** — regras no `POST /team` (C8 vermelho primeiro): tier da linha via `rating_for` nos nomes da cadeia (C6) + teto de S + orçamento antes do insert, notices próprios, fonte de rating injetável; fake de rating default no helper (adds existentes seguem verdes) | `./scripts/test test/team_routes_test.rb -n /budget\|s_limit/`; suíte + lint 0; commit `Passo 3: add bloqueado com aviso proprio no teto de 3 S e no estouro do orcamento` |
| 4 | **red→green** — painel e derivação (C7, C9, C10): "Custo do time: X/450" + "S no time: n/3" em `team.erb` + OOB; remoção liberando teto/orçamento provada por teste de rota | suíte completa + lint 0; commit `Passo 4: painel do time mostra custo/orcagem e contagem de S, remocao libera` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar Done, não preencher a seção 7, não commitar conclusão. |

## 7. Validação (executada pelo usuário)

*(Fase 3 — executada pelo usuário. Registro por critério, um resultado por linha — S2.
Ajuste de validação = alteração formal de critério com data e reaprovação — S3.)*

| Critério | Evidência automatizada | Evidência manual | Resultado |
| --- | --- | --- | --- |
| C1 (custo por tier da linha) | | | |
| C2 (restrição paga metade) | | | |
| C3 (checagem de orçamento) | | | |
| C4 (teto de 3 S) | | | |
| C5 (detecção no gateway) | | | |
| C6 (tier da linha = máx. cadeia) | | | |
| C7 (add dentro dos limites) | | | |
| C8 (bloqueios com aviso) | | | |
| C9 (remoção libera) | | | |
| C10 (painel custo/orçamento/S) | | | |

## 8. Observações

- **Latência no add frio:** `rating_for` por nome da cadeia no miss faz `detail` +
  `moves_for` (alguns RTTs) — o primeiro add de uma linha nunca avaliada pode demorar um
  pouco. Mitigado pelo `PokeApiCache` (HTTP, já existente) e pelo cache persistente de
  rating, **aquecido pela varredura de oponentes** nas batalhas. Aceito em D1; pré-warm
  assíncrono é candidato futuro (fora desta sessão).
- **Famílias ramificadas (ex.: Eevee):** o tier da linha considera **todos** os membros
  da cadeia, incluindo ramos por pedra — a linha conta pelo melhor ramo. Combinado com o
  desconto da restrição (D2), Eevee paga metade do melhor ramo. Quando **M1** (pedras no
  Mart) entrar, revisitar: a restrição deixa de ser "inalcançável" e o desconto pode ser
  recalibrado (anotado — fora do fluxo, RNF-04).
- **Testes de rota existentes** que adicionam Pokémon (pikachu/meowth/bulbasaur…) passam a
  precisar do fake de rating default (barato) para não tocar rede nem estourar regras —
  previsto no passo 3 (G1 cobre a regressão).
- **Gotchas duráveis** levantados neste refinamento (paridade de interface do gateway,
  choke point do `PokemonRatingCache`, trigger já parseado na cadeia) registrados na
  memória do projeto (`gotchas/m2-custo-gateway-e-rating.md`).
- Depois da 0055: a fila J2/J4/D4, **UX-2** (custo/ranking na listagem + filtros — depende
  desta sessão) e as demais limitações técnicas — a critério do usuário.
