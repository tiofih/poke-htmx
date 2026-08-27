# Sessão 0058 — M2b: balanceamento remover trava S via custo (orçamento único limitador)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões ratificadas pelo usuário em 2026-08-27 (D1 B, D2 B, D3 B, D4 B, D5 A, D6 C) |
| Implementação | **Pendente** — aguardando fase 2 (TDD, 5 passos) |
| Validação | **Pendente** — fase 3 pelo usuário (S2/S3) |

---

## 1. Objetivo

Remover a **trava hard de 3 Pokémon S por time** e fazer o **orçamento de montagem (450)** ser o **único limitador**, via `TeamBudget.cost_for` com **S restrito 60→110** — o 4º S (puro ou restrito) passa a ser bloqueado **só por `fits?`**.

## 2. Contexto (estado atual — antes do código)

- **M2 entregue (0055):** `lib/team_budget.rb` com `BUDGET = 450`, `S_LIMIT = 3`, `TIER_COST = {S:120, A:70, B:55, C:40, D:30, F:20}`, `cost_for(line_tier:, restricted:)` (restrito = metade floor, ex.: S 120→60, B 55→27), `fits?(current_total:, new_cost:)` e `s_limit_ok?(current_s_count:)`. O add (`POST /team` em `server.rb:594-618`) chama `budget_block_notice(pokemon)` que checa **teto de S** (`s_limit_notice` → `TeamBudget.s_limit_ok?`) **antes** do orçamento (`budget_notice` → `TeamBudget.fits?`), com notices distintos ("Máximo de 3 …" / "Orçamento insuficiente …"). O painel em `views/team.erb:8-10` mostra `S no time: n/3` e `Custo do time: X/450`; o badge da listagem (`views/pokemon_list_item.erb` + `server.rb:build_pokemon_costs`) reflete o mesmo `TeamBudget.cost_for` + `evolution_restricted?` (max da cadeia via `PokemonRatingCache`).
- **Problema:** a trava hard de 3 S é redundante com o orçamento — um time 3S + 1S_restrito hoje cabe (3×120 + 60 = 420 ≤ 450) e só a trava impede o 4º S. O `TIER_COST` com `S_rest=60` deixa o restrito barato demais, permitindo contornar o orçamento com 1 restrito entre 4 S. Quando M1 (pedras no Mart) entrar, a restrição deixa de ser "inalcançável" e o desconto atual distorce o draft.
- **O que muda:** manter `TIER_COST` dos puros, mas **S restrito = 110** (exceção ao "metade floor" só para S), **remover `S_LIMIT`/`s_limit_ok?`/`s_limit_notice`/`budget_block_notice`** e deixar **só `fits?` bloquear** (puro 120 e restrito 110: 3×120 + 120 = 480 > 450 e 3×120 + 110 = 470 > 450 — ambos bloqueados). Painel e badge passam a refletir o novo custo, sem "/3" nem notice de teto.
- **Eco/wallet fora:** `WalletRepository`/`SaldoInicial` continuam intocados nesta sessão (limite derivado, sem transação), mas D5 deixa explícito que BUDGET/wallet poderiam ser tocados futuramente se necessário (permissivo).

## 3. Escopo

### Produção

- `lib/team_budget.rb`: **S restrito 60→110** — `cost_for(line_tier:, restricted:)` passa a devolver **110 quando `line_tier == "S"` e `restricted == true`** (exceção ao `base/2`); demais tiers seguem `base/2 floor`. **Remover** `S_LIMIT` e `s_limit_ok?` (e qualquer helper `s_limit_*`); `BUDGET` (450) e `TIER_COST` dos puros **permanecem**, sem const extra.
- `server.rb` (`ServerTeamActions`): **remover** `s_limit_notice` e `budget_block_notice` (que combinava teto+orçamento) e simplificar o gate do `POST /team` (`add_team_member`/`budget_block_notice`) para **só orçamento** — `team_total_cost(team)` + `pokemon_cost(pokemon, lt)` → `TeamBudget.fits?`; se não couber → notice único `"Orçamento insuficiente para adicionar este Pokémon."` (mesma string já usada em `budget_notice`), sem ramo de "Máximo de 3 …". `team_s_count` pode permanecer só onde o painel precisa (contagem informativa), mas **não** como gate; se mantido, apenas para exibição. Preservar `line_tier_for`/`evolution_chain_names`/`tier_max`/`team_total_cost`/`pokemon_cost`/`budget_notice`; fonte de rating injetável (`Server.set :rating_source`) e `evolution_restricted?` intactos.
- `views/team.erb`: painel troca `"S no time: n/3"` → `"S no time: n"` (ou `"S: n"` mantendo o `span.team-s-count` sem teto implícito) — contagem informativa, sem "/3" nem referência a limite. O badge da listagem (`views/pokemon_list_item.erb` + `public/style.css` `[data-tier]`) **reflete** automaticamente o novo `cost_for` (S restrito 110) sem mudar estrutura; verificar que `build_pokemon_costs` usa `TeamBudget.cost_for` já cobre.

### Testes

- `test/team_budget_test.rb`: cobre **C1** e **C2** — `cost_for` S restrito = 110, demais restritos = metade floor (A 35, B 27, C 20, D 15, F 10), puros inalterados, e `fits?` na fronteira 450 (ver §4). Remover/ajustar testes de `s_limit_ok?` (a API deixa de existir — testes antigos devem ser removidos/atualizados).
- `test/team_routes_test.rb`: cobre **C3** e **C4** — `POST /team` com 3 S no time bloqueia o **4º S puro (120)** e o **4º S restrito (110)** por orçamento insuficiente (time inalterado, notice de orçamento, sem notice de teto; `journey_started`/batalha não invalidados), com `FakeListRating` determinístico nome→tier + `PokeApiStub`/`evolution_restricted?` stubado, **sem rede**. Usa `team_total_cost` derivado (S puro 120, S rest 110).
- `test/team_routes_test.rb` (ou `test/team_view_test.rb` se existir): cobre **C5** — painel após add/remove mostra `S no time: n` sem "/3" e `Custo do time: X/450` consistente, com add de S restrito refletindo 110.
- `test/pokemon_list_cost_test.rb` (existe da 0056): garantir que o badge da listagem reflete o novo custo (S restrito mostra 110 + classe `poke-cost--restricted`); **manual** para cores/alinhamento/OOB visual (ver C6).

### Fora de escopo (não abrir)

- **M1 — pedras de evolução no Poke Mart** (`draft:673`), **D4 — draft temático**, **UX-2b filtros já entregues** — anotados no `REQUIREMENTS.md`/drafts (RNF-04), ficam fora.
- **Q5 / race no add / escritas não atômicas / CSRF / identidade `?as=` / CI / `pry` / regra "vida zerada não pode ser removido" / J2 / J4** e demais limitações técnicas — fora desta sessão; BUDGET 450 e wallet (200) **não são alterados nesta sessão**, mas **D5 registra que poderiam ser tocados futuramente** se o balanceamento exigir (permissivo, ver §6 D5) — a implementação foca no escopo B (só `team_budget.rb`/`server.rb`/`team.erb`).
- **Persistir custo por membro**, schema novo/migração, gem nova, **const extra** para S_rest (D4 B — sem const nova, só exceção em `cost_for`) — fora.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 (cost_for S restrito = 110):** `TeamBudget.cost_for(line_tier: "S", restricted: true) == 110`; demais restritos seguem metade floor (A 35, B 27, C 20, D 15, F 10) e puros inalterados (S 120, A 70, B 55, C 40, D 30, F 20). — prova: `test/team_budget_test.rb` (`test_cost_restricted_s_is_110` + `test_restricted_costs_half_except_s` + `test_cost_by_line_tier_pure`).
- [ ] **C2 (fits? fronteira 450 como único limitador):** `fits?` permite soma ≤ 450 e bloqueia > 450 (ex.: 3×120=360 + 110=470 bloqueia; 330+120=450 permite; 340+110=450 permite; 341+110=451 bloqueia). — prova: `test/team_budget_test.rb` (`test_fits_blocks_over_budget` / `test_fits_allows_exact_budget`).
- [ ] **C3 (4º S puro bloqueado só por orçamento):** com 3 S puros no time (custo 360), `POST /team` de 4º S **puro** (custo 120, `evolution_restricted? == false`) retorna notice de orçamento insuficiente, **sem** notice de teto, time inalterado, jornada não marcada, batalha não invalidada. — prova: `test/team_routes_test.rb` (`test_fourth_pure_s_blocked_by_budget_only`).
- [ ] **C4 (4º S restrito bloqueado só por orçamento):** com 3 S puros no time (360), `POST /team` de 4º S **restrito** (custo 110, `evolution_restricted? == true`) também bloqueia por orçamento (470 > 450), sem notice de teto, time inalterado; e um cenário com 2S+1S_rest (350) + S_rest (110) = 460 também bloqueia, enquanto 2S+S_rest=230 + A_rest 35 cabe (prova que não é trava hard). — prova: `test/team_routes_test.rb` (`test_fourth_restricted_s_blocked_by_budget_only` + `test_restricted_s_not_hard_capped`).
- [ ] **C5 (painel S n sem teto implícito):** o fragmento do time exibe `S no time: n` (sem "/3") e `Custo do time: X/450` em `GET /team` (ou `GET /` `#team-view`) e após cada add/remove (OOB), consistente com o novo custo (ex.: S restrito conta 110 no total). — prova: `test/team_routes_test.rb` (`test_team_panel_shows_s_count_without_limit` + `test_team_panel_cost_reflects_restricted_s_110`) + **manual** para layout.
- [ ] **C6 (badge da listagem reflete custo + visual):** a listagem (`GET /` e `GET /pokemons`) mostra badge `S · 110` quando restrito (com `poke-cost--restricted`/`◆`) e `S · 120` quando puro, demais tiers com metade floor, com cor por `data-tier`, sem quebrar grid 6×6, e OOB `#pokemon-list` pós add/remove preserva badges. — prova: `test/pokemon_list_cost_test.rb` (`test_pokemon_list_shows_restricted_s_110` + `test_oob_after_add_preserves_badges`) + **manual** (conferido visualmente via `./scripts/run`: badge alinhado, cores por tier, OOB da lista após `POST /team`/`DELETE /team`).

### Garantias (RNF)

- [ ] **G1:** suíte completa verde após cada passo + lint 0 em todo green; commit obrigatório por passo; 0 regressão fora do escopo (adds existentes seguem verdes via fake de rating default barato).
- [ ] **G2:** sem gems novas / sem mudança de schema / testes sem rede (rating e cadeia por stubs/fakes determinísticos, reuso do `rating_source` injetável via `Server.set`; manter padrão local de RuboCop em testes).
- [ ] **G3:** `SESSIONS.md` atualizado no commit do refinamento (S4); status de validação só após o usuário validar (fase 3 — parar na fase 2 e aguardar).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste automatizado → `manual` explícito + evidência esperada (ver C6).

## 5. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Parar ao fim da fase 2 e aguardar validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (tabela + "Próxima sessão") | commit `Sessao 0058: refinamento concluido — M2b balanceamento remover trava S via custo (S_rest 110, orcamento unico limitador), criterios e plano TDD fechados` |
| 1 | **red→green — cost_for S restrito 110** (C1 vermelho primeiro): `lib/team_budget.rb` exceção `S && restricted → 110` (demais `base/2 floor`), remover/atualizar testes de `s_limit_ok?` onde necessário | `./scripts/test test/team_budget_test.rb -n /cost_restricted_s|restricted_costs_half|cost_by_line_tier/`; suíte completa + `./scripts/lint` 0; commit `Passo 1: custo S restrito 60 para 110 em TeamBudget (excecao ao metade)` |
| 2 | **red→green — remover trava hard de S** (C3/C4 preparação): `lib/team_budget.rb` remover `S_LIMIT`/`s_limit_ok?`, `server.rb` remover `s_limit_notice`/`budget_block_notice` e trocar gate do `POST /team` para **só `budget_notice`/`fits?`** (notice único de orçamento), sem ramo "Máximo de 3 …" | `./scripts/test test/team_budget_test.rb test/team_routes_test.rb -n /s_limit|budget_block|fourth.*blocked/` (espera `s_limit_*` inexistir e bloqueios ainda via orçamento); suíte + lint 0; commit `Passo 2: remover trava hard de 3 S — orcamento 450 como unico limitador` |
| 3 | **red→green — server bloqueia 4º S puro só por orçamento** (C3): `server.rb` `pokemon_cost`/`team_total_cost` + `budget_notice` com `S puro 120` → `fits?` bloqueia 4º S (480>450), time inalterado, journey/battle preservados, sem notice de teto | `./scripts/test test/team_routes_test.rb -n /fourth_pure_s_blocked_by_budget_only/`; suíte + lint 0; commit `Passo 3: 4o S puro bloqueado por orcamento (sem trava hard)` |
| 4 | **red→green — 4º S restrito bloqueado + remove libera** (C4): `POST /team` de S restrito 110 com 3S (470>450) também bloqueia por orçamento; `DELETE /team` libera custo e vaga (ex.: 3S→2S libera add de S_rest 110) | `./scripts/test test/team_routes_test.rb -n /fourth_restricted_s_blocked|remove_frees_budget/`; suíte + lint 0; commit `Passo 4: 4o S restrito (110) bloqueado por orcamento e remocao libera` |
| 5 | **red→green — painel/badge + manual** (C5/C6): `views/team.erb` `S no time: n` sem "/3", `Custo do time: X/450` refletindo 110, badge da listagem (`pokemon_list_item.erb`) com `S · 110 ◆` quando restrito (via `TeamBudget.cost_for` já usado em `build_pokemon_costs`), OOB preservado, cores por `data-tier`; `manual` visual | suíte completa + lint 0; commit `Passo 5: painel S n sem teto e badge da listagem reflete S_rest 110` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar Done, não preencher a seção 7, não commitar conclusão. | — |

## 5-A. Ajuste S3 (validação — alteração formal de critério)

*(Vazio — preenchido na fase 3 se a validação reprovar algum critério. Registrar data, critério reaberto, alteração e reaprovação — S3.)*

## 6. Decisões de refinamento (fechadas com o usuário em 2026-08-27)

- **D1 — Objetivo/fonte do limite (B — orçamento como único limitador):** remover a trava hard de 3 S e deixar o **orçamento 450** bloquear o 4º S sozinho. Alternativa preterida: A — manter trava hard (redundância e UX confusa com dois notices). Motivo: a trava hard virou contorno — com `S_rest 60` um 4º S restrito ainda cabia (420) e só a trava impedia; ao elevar `S_rest` para 110 o orçamento já barra ambos (puro 480 e restrito 470), simplifica regras e prepara M1 (pedras no Mart deixam restrição alcançável).
- **D2 — Escopo técnico (B — cost_for S_rest 60→110 + remover S_LIMIT/s_limit_ok? + s_limit_notice/budget_block_notice + UI S n/3→S n/teto implícito + badge):** `cost_for` com exceção S_rest 110, remoção completa da API de teto e dos notices/helpers de teto, gate do `POST /team` só por `fits?`, painel sem "/3" e badge refletindo 110. Alternativa preterida: patch mínimo só no custo sem remover a trava (deixaria código morto e notice duplicado).
- **D3 — Critérios S1 (B — 5 granulares + 1 manual):** C1 cost_for 110, C2 fits fronteira, C3 4º S puro bloqueado, C4 4º S restrito bloqueado, C5 painel S n — todos com teste automatizado apontado; C6 badge/visual como `manual` (alinhamento/cores/OOB). Alternativa preterida: 3 critérios enxutos (aglutinaria puro+restrito e painel+badge, perdendo rastreabilidade quando um quebra).
- **D4 — Onde mexer (B — lib/team_budget.rb + server.rb + views/team.erb, sem const extra):** só os 3 arquivos do M2; sem const nova para `S_REST` (exceção inline em `cost_for`). Alternativa preterida: criar `S_RESTRICTED_COST` ou tocar `BUDGET`/wallet nesta sessão (ver D5).
- **D5 — Fora de escopo (A — nada fora, permissivo, mas implementação foca no escopo B):** vale mexer em `BUDGET`/`Wallet` **futuramente** se o balanceamento exigir, mas **esta sessão implementa apenas o escopo B** (os 3 arquivos acima). O refinamento registra a permissividade para não travar M1/Eco, sem abrir escopo agora. Motivo: manter a sessão atômica e reversível; alterar `BUDGET`/wallet exigiria re-calibrar game over (0053) e sementes (0025) — anotado para sessão futura (RNF-04).
- **D6 — Tamanho/Plano TDD (C — 5 passos atomizados):** 1 por tier/área (cost → remover trava → puro bloqueado → restrito+remove → UI/badge). Alternativa preterida: 3 passos comprimidos (esconderia regressão entre puro e restrito) ou 4 passos sem UI isolado.

## 7. Validação (executada pelo usuário — fase 3)

*(Fase 3 — executada pelo usuário. Registro por critério, um resultado por linha — S2.
Ajuste de validação = alteração formal de critério com data e reaprovação — S3.)*

| Critério | Evidência automatizada | Evidência manual | Resultado |
| --- | --- | --- | --- |
| C1 (cost_for S restrito 110) | — | — | — |
| C2 (fits? fronteira 450) | — | — | — |
| C3 (4º S puro bloqueado por orçamento) | — | — | — |
| C4 (4º S restrito bloqueado por orçamento) | — | — | — |
| C5 (painel S n sem teto) | — | — | — |
| C6 (badge + visual) | — | `manual` (badge S·110/S·120, cores data-tier, OOB #pokemon-list, alinhamento) | — |
| G1 (suíte + lint) | — | — | — |
| G2 (sem gems/schema, sem rede) | — | — | — |
| G3 (S4/S5) | — | — | — |

## 8. Observações

- **Por que 110 e não 60:** com 60, `3×120 + 60 = 420` ainda cabe e só a trava hard impedia o 4º S restrito; com 110, `3×120 + 110 = 470 > 450` e `4×120 = 480 > 450` — ambos bloqueados só por `fits?`, sem código de teto. Demais restritos seguem `base/2` (A 35, B 27, C 20, D 15, F 10) — só S foge da regra.
- **Latência no add frio:** `line_tier_for` paga `rating_for` por membro da cadeia no miss (`detail` + `moves_for`), mitigado por `PokeApiCache` e `PokemonRatingCache` aquecido pela varredura de oponentes (0050); aceito, mesmo trade-off do M2 (0055) e da 0056.
- **Famílias ramificadas (Eevee):** `line_tier` = máximo dos tiers dos ramos (inclui ramos por pedra); S restrito paga 110 pelo melhor ramo, combinando com `evolution_restricted?` (trigger ≠ level-up). Quando M1 entrar, revisitar: a restrição deixa de ser inalcançável e o desconto de 110 pode ser recalibrado (anotado — fora do fluxo, RNF-04).
- **BUDGET/wallet permissivo (D5 A):** esta sessão **não** altera `BUDGET` (450) nem `WalletRepository`/`SaldoInicial` (200); registra apenas que poderiam ser tocados futuramente (ex.: recalibrar 450↔200↔110) se o meta exigir — decisão do usuário para não travar M1/Eco, mas sem implementar agora.
- **Gotchas duráveis** do M2 (`gotchas/m2-custo-gateway-e-rating.md` — paridade de interface do gateway, choke point do `PokemonRatingCache`, trigger já parseado, `TIER_ORDER`/`TeamBudget::TIER_COST`) seguem valendo aqui; `S_rest 110` é exceção documentada em `TeamBudget.cost_for`.
- **OOB da lista:** `POST /team`/`DELETE /team` já re-renderizam `#pokemon-list` via `oob_pokemon_list` (Onda 1) para reativar/desabilitar botões Add — o badge continua consistente após mutações do time, com o novo custo 110 quando restrito.

