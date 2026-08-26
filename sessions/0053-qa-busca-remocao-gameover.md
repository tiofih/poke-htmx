# Sessão 0053 — QA Q4+Q5+GL-1: aviso de busca base-form, remoção em 1 clique e game over (vender/recomeçar)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-25 |
| Implementação | **Concluída** — passos 1–8 + docs, suíte 804/2623, lint 0 (2026-08-25) |
| Validação | **Concluída** — C1–C12 ok, validada pelo usuário em 2026-08-25 |

---

## 1. Objetivo

Fechar os três últimos itens do QA do playtest 3 (Q1–Q3 já fechados na 0049/0052):
**(Q4)** a busca por nome mostra **aviso informativo** quando o termo só casa com
não-base/starter (apontando a forma base ou os destaques iniciais); **(Q5)** a remoção
do time fica **confiável em 1 clique** (investigar o "2 cliques" intermitente); **(GL-1)**
estado de **game over** quando todos os pokes zeram HP **e** o saldo não cobre o Poke
Center, com as opções **vender itens** (novo `POST /mart/sell`) e **recomeçar jornada**
(reset do time + saldo inicial).

## 2. Contexto (estado atual — diagnóstico)

### Q4 — busca só acha formas base
- `common_candidates` (`server.rb:132`) filtra `fetch_all_names` por `@q` e depois
  `reject STARTER_SLUGS`; a listagem segue só formas base via
  `collect_base_forms`/`base_form_names` (`server.rb:120`, `base_form?` no gateway).
  Resultado: "pika" → vazio (pikachu é não-base), "char" → nada (charmander é starter).
- Grade/paginação (0044) foram projetadas para base forms; regra J1: time se monta com
  formas base. `PokeApiParsing#evolution_chain` devolve a cadeia achatada com a base na
  primeira posição — dá para apontar a evolução base de um não-base.
- Testes de listagem em `test/pokemon_routes_test.rb` (stubs `with_all_names`,
  `with_base_forms`, `with_detail` — ver `PokeApiStub`).

### Q5 — remover do time às vezes exige 2 cliques (intermitente)
- Form: `<form hx-delete="/team" hx-target="#team-view" hx-swap="innerHTML"
  hx-include=".list-state" hx-params="*">` com hidden `id` (`views/team.erb:40-49`).
- Handler `remove_team_member` (`server.rb:264`): `remove_member` se `params[:id]`,
  invalida a batalha, devolve fragmento do time + OOB `#pokemon-list`
  (`oob_pokemon_list`, `server.rb:231` — re-renderiza a lista inteira, **incluindo os 27
  destaques via `load_starters`** quando `@q.empty? && @offset.zero?`).
- `TeamService#remove_member` (`lib/team_service.rb:66`) já é idempotente (id
  inexistente → `false`, time intacto). Testes atuais chamam `delete "/team", { id: }`
  **sem** `offset`/`q`/`HX-Request` (não reproduzem o request real do htmx).
- Hipótese principal (a confirmar na implementação): o OOB re-renderiza a lista (27
  destaques + varredura base-form) a cada remove → resposta lenta → o 1º clique remove
  no servidor mas o feedback visual demora/é absorvido por um 2º clique (no-op
  idempotente). Fix provável: proteção anti re-submit no form (`hx-disabled-elt`) +
  evitar o re-fetch desnecessário dos destaques no OOB.

### GL-1 — game over (definição do usuário)
- `BattleEngine#result` (`lib/battle_engine.rb:205`) devolve `:win`/`:lose`/`:draw`; o
  fim de batalha só recompensa (`RewardRule`). Já existem: `journey_gate_fragment` e
  `defeated_gate_fragment` (`server.rb:377/382`), botão "Novo confronto" desabilitado
  quando `!battle_ready?` (`@can_new_confront`), `Pokemon#usable_hp?`,
  `JourneyService#battle_ready?`.
- **Definição do usuário:** game over = `started?` (time ≥ 6) **&&** `!battle_ready?`
  (todos com HP 0) **&&** `balance < custo da cura total`
  (`HealService#preview_cost`). O jogador fica travado: não batalha e não cura.
- Consequência escolhida: tela de game over com **"Vender itens"** (leva ao Mart — nova
  venda geral `POST /mart/sell`) ou **"Recomeçar jornada"** (limpa o time devolvendo
  itens + saldo inicial `SaldoInicial::INITIAL_BALANCE` = 200). Não há método de venda
  hoje (`MartService` só tem `buy`; `ItemCatalog` tem preços de compra; `InventoryRepository`
  tem `use`/`add`/`count`; `WalletRepository` tem `balance`/`grant`/`spend` — sem `set`).

## 3. Escopo

### Produção
- **Q4** — `server.rb`: novo `search_hint(q)` (match no pool total → aponta base via
  `detail(match).evolutions.first` ou starter) + `@search_hint` em `load_pokemon_page`
  quando a busca não vazia e a página está vazia; `views/pokemon_list.erb`: bloco de
  aviso (nota `notice--info`) no topo.
- **Q5** — investigar e corrigir: provável `hx-disabled-elt`/indicator no form de remove
  (`views/team.erb`) e/ou evitar re-fetch dos destaques no OOB (`server.rb#oob_pokemon_list`);
  remoção continua idempotente.
- **GL-1 — venda:** `lib/sell_policy.rb` (novo, puro): `sell_price(item) = item.price / 2`;
  `lib/mart_service.rb`: `sell(user_id, item_name, quantity)` (valida item/quantidade/
  estoque, debita `InventoryRepository#use`, credita `WalletRepository#grant`); `server.rb`:
  `POST /mart/sell` (`sell_from_mart`, gated `started?`); `views/_mart.erb`: botão
  "Vender" por linha do inventário.
- **GL-1 — estado:** `lib/journey_service.rb`: `game_over?(user_id)` (deps novas
  `wallet:`/`heal_preview:`); `server.rb` (`set :journey` estende com as deps).
- **GL-1 — recomeçar:** `lib/team_service.rb`: `reset(user_id)` (remove todos os membros
  reusando `remove_member`, devolvendo itens); `lib/wallet_repository.rb`: `set(user_id,
  amount)` (upsert fixo); `server.rb`: `POST /journey/restart` (`restart_journey` — reset
  + wallet p/ `SaldoInicial::INITIAL_BALANCE` + invalidar batalha + renderizar fragmento).
- **GL-1 — UI:** `server.rb`: `game_over_fragment` no `battle_gate_fragment` (substitui
  o `defeated_gate_fragment` quando `game_over?`; `@message` + `@gate_cta` "Vender itens"
  + `@gate_action` "Recomeçar jornada"); `views/battle.erb`: ramo `@gate_action`
  (botão ativo `hx-post`); `views/team.erb` + `prepare_team_fragment_data`: banner de
  game over com botão "Recomeçar jornada" quando `@game_over`.

### Testes
- `test/sell_policy_test.rb` (novo): `SellPolicy#sell_price` (potion 10, super-potion 25,
  hyper-potion 50, choice-band 40 — metade arredondada p/ baixo).
- `test/mart_service_test.rb`: `sell` feliz (credita/debita), item inválido, quantidade
  inválida, estoque insuficiente (não debita além do disponível).
- `test/mart_routes_test.rb`: `POST /mart/sell` credita saldo + debita estoque; fragmento
  mostra botão Vender.
- `test/journey_service_test.rb`: `game_over?` (time ≥6 + HP 0 + saldo < custo → true;
  saldo suficiente → false; algum HP → false; time <6 → false). Stub de `wallet`/`heal_preview`.
- `test/team_service_test.rb`: `reset` limpa time e devolve itens equipados.
- `test/team_routes_test.rb` ou novo `test/journey_routes_test.rb`: `POST /journey/restart`
  limpa time (itens devolvidos), reseta saldo p/ 200, re-bloqueia a jornada, invalida batalha.
- `test/battle_routes_test.rb`: gate mostra `game_over_fragment` (msg + CTAs) quando travado.
- `test/team_routes_test.rb`: painel mostra banner de game over quando travado; form de
  remove tem `hx-disabled-elt`; DELETE htmx exato (id + offset/q + `HX-Request`) remove em
  1 request e devolve `#team-view` sem o membro + OOB `#pokemon-list`; 2º DELETE é no-op.
- `test/pokemon_routes_test.rb`: hint de evolução (pikachu→pichu) e de starter (charmander);
  busca base continua listando sem hint.

### Fora de escopo (não abrir)
- Vender **itens equipados** direto do equipamento (venda é só do inventário).
- Reset de **inventário** no recomeçar (estoque é preservado).
- Remoção da tabela `user_state` / flag vestigial (anotada no draft — refatoração futura).
- Outros itens do QA Q1–Q3 (fechados) e a fila J2/J4/D4/M2.
- Escritas não atômicas/idempotência das rotas (limitação anotada separadamente).

## 4. Critérios de aceite

### Resultado
- [x] **C1 (Q4 evolução)** — busca cujo termo só casa com não-base mostra aviso
      informativo apontando a forma base (ex.: "pikachu é evolução de pichu — monte com
      pichu"). — prova: `test/pokemon_routes_test.rb`
      (`test_search_non_base_shows_base_form_hint`).
- [x] **C2 (Q4 starter)** — busca cujo termo só casa com starter mostra aviso apontando
      os destaques iniciais. — prova: `test/pokemon_routes_test.rb`
      (`test_search_starter_shows_starter_hint`).
- [x] **C3 (Q4 regressão)** — busca que casa com forma base continua listando
      normalmente, sem aviso. — prova: `test/pokemon_routes_test.rb` (teste existente de
      busca preservado / novo `test_search_base_form_lists_without_hint`).
- [x] **C4 (Q5 1-clique)** — um único `DELETE /team` com `id` + `offset`/`q`
      (`.list-state`) + `HX-Request` remove o membro e devolve `#team-view` sem o membro
      + OOB `#pokemon-list` válido na mesma resposta. — prova: `test/team_routes_test.rb`
      (`test_htmx_delete_team_removes_and_swaps_both_fragments`).
- [x] **C5 (Q5 idempotência)** — repetir o mesmo `DELETE` (mesmo `id`) não altera o time
      nem devolve erro (2º clique seguro). — prova: `test/team_routes_test.rb`
      (`test_delete_team_is_idempotent_on_second_request`).
- [x] **C6 (Q5 hardening)** — o form de remover do time ganhou proteção contra re-submit
      (`hx-disabled-elt`), impedindo o disparo duplo. — prova: `test/team_routes_test.rb`
      (`test_remove_form_prevents_double_submit`) — `manual` complementar (1 clique no app).
- [x] **C7 (GL-1 condição)** — `JourneyService#game_over?` é verdadeiro só com time ≥ 6,
      todos os pokes zerados **e** saldo < custo da cura total; falso com saldo suficiente,
      com algum HP ou com time < 6. — prova: `test/journey_service_test.rb`
      (`test_game_over_when_all_hp_zero_and_unaffordable`, `test_not_game_over_when_heal_affordable`,
      `test_not_game_over_when_partial_hp`, `test_not_game_over_below_team_of_six`).
- [x] **C8 (GL-1 venda service)** — `SellPolicy#sell_price` = metade do preço (arredondado
      p/ baixo) e `MartService#sell` valida item/quantidade/estoque, debita o estoque e
      credita `sell_price × qty`; vende também seguráveis. — prova: `test/sell_policy_test.rb`
      (`test_sell_price_is_half_of_buy_price`) + `test/mart_service_test.rb`
      (`test_sell_credits_wallet_and_debits_inventory`).
- [x] **C9 (GL-1 venda rota)** — `POST /mart/sell` (gated `started?`) vende e re-renderiza
      o painel com notícia; `_mart.erb` mostra botão "Vender" por item do inventário. —
      prova: `test/mart_routes_test.rb` (`test_mart_sell_updates_balance_and_inventory`,
      `test_mart_fragment_shows_sell_buttons`).
- [x] **C10 (GL-1 recomeçar)** — `POST /journey/restart` remove todos os membros
      (devolvendo itens equipados), reseta o saldo para o inicial (200), invalida a
      batalha e re-bloqueia a jornada (time < 6); **seguro sob chamadas concorrentes**
      (double-submit) — reset em lote (`TeamRepository#clear`) sem reindex por slot.
      — prova: `test/team_routes_test.rb` / `test/journey_routes_test.rb`
      (`test_restart_journey_clears_team_and_resets_balance`,
      `test_restart_journey_returns_equipped_items`,
      `test_restart_journey_is_safe_under_concurrent_calls`).
- [x] **C11 (GL-1 UI gate + batalha)** — com game over, o gate de `GET /battle`/
      `POST /battle/new` **e a tela de fim de batalha** mostram o fragmento/mensagem de
      game over (mensagem + CTAs "Vender itens" e "Recomeçar jornada" no lugar do
      "Novo confronto"). — prova: `test/battle_routes_test.rb`
      (`test_battle_gate_shows_game_over_fragment_when_stuck`,
      `test_finished_battle_shows_game_over_and_restart_when_broke`).
- [x] **C12 (GL-1 UI painel)** — o painel do time mostra o banner de game over com o botão
      "Recomeçar jornada" quando `game_over?`. — prova: `test/team_routes_test.rb`
      (`test_team_panel_shows_game_over_banner`).

### Garantias (RNF)
- [x] Suíte completa verde com **baseline preservado** + novos testes e lint 0 em **todo**
      green; commit obrigatório por passo; 0 regressão.
- [x] Sem gems novas / sem mudança de schema / testes sem rede / sem `rubocop:disable`
      novos.
- [x] `REQUIREMENTS.md` + `SESSIONS.md` atualizados no passo docs; *status de validação*
      só após o usuário validar (S4).

> **S1:** cada critério acima aponta o teste que o prova. C6 tem `manual` complementar
> (o defeito é intermitente no navegador — evidência manual esperada: 1 clique remove).

## 5. Decisões de refinamento (fechadas com o usuário)

1. **Q4 — aviso informativo** (2026-08-25): a busca segue só formas base; quando o termo
   só casa com não-base/starter, mostra aviso apontando a evolução base
   (`detail(match).evolutions.first`, raiz da cadeia) ou os destaques iniciais para
   starter. Preterido: incluir não-base na grade (quebra o design J1 base-only e o grid).
2. **GL-1 — condição** (2026-08-25): game over = `started? && !battle_ready? &&
   balance < custo da cura total` — todos os pokes zerados **e** sem dinheiro para o
   Poke Center.
3. **GL-1 — consequência** (2026-08-25): tela de game over com **"Vender itens"** (leva
   ao Mart) ou **"Recomeçar jornada"**. A **venda é recurso geral do Mart**
   (`POST /mart/sell`, sempre disponível no painel), não só no game over — mais simples
   e útil (a tela de game over apenas aponta para ela).
4. **Preço de venda** (2026-08-25): metade do preço de compra, arredondado para baixo
   (`SellPolicy#sell_price = price / 2`) — consumível e segurável vendem.
5. **Recomeçar jornada** (2026-08-25): limpa o time via `TeamService#reset` (reusa
   `remove_member`, devolvendo itens equipados ao estoque), reseta a wallet para
   `SaldoInicial::INITIAL_BALANCE` (200, via novo `WalletRepository#set`) e invalida a
   batalha. O **estoque é preservado**; a jornada re-bloqueia automaticamente (time < 6).
6. **Q5 — investigação** (2026-08-25): hipótese principal — o OOB `#pokemon-list` re-faz
   a varredura (27 destaques + base-form) a cada remove, deixando o 1º clique sem
   feedback imediato e absorvendo um 2º clique idempotente. Fix provável: `hx-disabled-elt`
   no form de remove + evitar re-fetch desnecessário dos destaques no OOB. Confirmar com
   o teste C4 (request htmx exato) durante a implementação.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `Sessao 0053: refinamento concluido — QA Q4+Q5+GL-1 (aviso busca, remocao 1 clique, game over vender/recomecar)` |
| 1 | `SellPolicy` (novo) + `MartService#sell` (service: validação + debita estoque + credita `sell_price × qty`) | `./scripts/test test/sell_policy_test.rb test/mart_service_test.rb`; suíte verde + lint 0, commit `Passo 1:` |
| 2 | `POST /mart/sell` (rota gated `started?`) + botão "Vender" por item no `_mart.erb` | suíte verde + lint 0, commit `Passo 2:` |
| 3 | `JourneyService#game_over?` com deps `wallet:`/`heal_preview:` + `set :journey` estendido | suíte verde + lint 0, commit `Passo 3:` |
| 4 | `TeamService#reset` + `WalletRepository#set` + `POST /journey/restart` | suíte verde + lint 0, commit `Passo 4:` |
| 5 | UI do game over: `game_over_fragment` no gate + `@gate_action` no `battle.erb` + banner no painel (`team.erb`, `prepare_team_fragment_data`) | suíte verde + lint 0, commit `Passo 5:` |
| 6 | Q4: `search_hint(q)` + `@search_hint` + aviso no `pokemon_list.erb` | suíte verde + lint 0, commit `Passo 6:` |
| 7 | Q5: reproduzir o DELETE htmx exato (C4/C5) + hardening (`hx-disabled-elt`/indicador; evitar re-fetch dos destaques no OOB se confirmado) | suíte verde + lint 0, commit `Passo 7:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Validada em 2026-08-25** — S2: um resultado por critério. Ajustes S3 durante a
validação (feedback do usuário, re-aprovados): C10 — 500 no "Recomeçar jornada"
(double-submit concorrente colidia no unique `(user_id, slot)`) → reset em lote via
`TeamRepository#clear`; C11 — game over também na **tela de fim de batalha** (mensagem +
"Vender itens"/"Recomeçar jornada" no lugar do "Novo confronto"); C9 — lista de venda do
Mart sem linhas `0×` do inventário (itens equipados/consumidos não vendáveis);
C10 — `#pokemon-list` presa após o recomeçar (sem reiniciar o servidor) → refresh via OOB
com `hx-include=".list-state"`.

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 (Q4 evolução) | `./scripts/test -n /search_non_base_shows_base_form_hint/` | Buscar "pika" no app → aviso "evolução de pichu" | ok |
| C2 (Q4 starter) | `./scripts/test -n /search_starter_shows_starter_hint/` | Buscar "char" → aviso de inicial | ok |
| C3 (Q4 regressão) | `./scripts/test -n /search_base_form_lists_without_hint/` | Buscar "pichu" → lista normal | ok |
| C4 (Q5 1-clique) | `./scripts/test -n /htmx_delete_team_removes_and_swaps_both_fragments/` | 1 clique remove e atualiza lista | ok |
| C5 (Q5 idempotência) | `./scripts/test -n /delete_team_is_idempotent_on_second_request/` | 2º clique não quebra | ok |
| C6 (Q5 hardening) | `./scripts/test -n /remove_form_prevents_double_submit/` | botão desabilita durante o request | ok |
| C7 (GL-1 condição) | `./scripts/test -n /game_over_when_all_hp_zero_and_unaffordable/` | — (serviço puro) | ok |
| C8 (GL-1 venda service) | `./scripts/test -n /sell_price_is_half_of_buy_price/` + `/sell_credits_wallet_and_debits_inventory/` | — | ok |
| C9 (GL-1 venda rota) | `./scripts/test -n /mart_sell_updates_balance_and_inventory/` | Vender poção no Mart → saldo sobe, estoque cai; sem linhas `0×` | ok (re-aprovado no ajuste S3) |
| C10 (GL-1 recomeçar) | `./scripts/test -n /restart_journey_clears_team_and_resets_balance|restart_journey_is_safe_under_concurrent_calls/` | Recomeçar → time limpo, saldo 200, lista de pokes atualiza | ok (re-aprovado no ajuste S3) |
| C11 (GL-1 UI gate + batalha) | `./scripts/test -n /battle_gate_shows_game_over_fragment_when_stuck|finished_battle_shows_game_over_and_restart_when_broke/` | Time zerado + saldo baixo → game over no gate e na tela de fim de batalha | ok (re-aprovado no ajuste S3) |
| C12 (GL-1 UI painel) | `./scripts/test -n /team_panel_shows_game_over_banner/` | Banner de game over no painel do time | ok |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

- Game over só aparece quando o jogador está **travado** (não batalha **e** não cura);
  com saldo suficiente continua o aviso "cure no Poke Center" (GL-2 da 0052).
- Vender itens resolve a trava por si (acumula saldo para o Center); o recomeçar é o
  caminho terminal quando nem vendendo dá.
- Após a 0053, a fila restante é J2/J4/D4/M2 + limitações técnicas (escritas não
  atômicas, erros com status real, race no add, identidade/CSRF, CI).
- **Ideia anotada (2026-08-25, durante a validação — fora de sessão, RNF-04):** regra de
  **Pokémon com vida zerada não poder ser removido do time** (remover/readicionar traria o
  poke com HP cheio, contornando a cura e o game over) — registrada nas limitações do
  `REQUIREMENTS.md` para virar sessão após a conclusão/validação da 0053.
- **Ajustes pós-implementação (feedback do usuário, 2026-08-25):** (1) game over também
  na **tela de fim de batalha** (mensagem + "Vender itens"/"Recomeçar jornada" no lugar do
  "Novo confronto") — `battle.erb` + `expose_new_confront_state`; (2) **500 no
  "Recomeçar jornada"** — o reset antigo reusava `remove_member` (DELETE + reindex por
  membro), e o double-submit concorrente colidia no unique `(user_id, slot)` → `reset`
  virou **lote** (`restore_items` de todos + `TeamRepository#clear` em 1 DELETE, sem
  reindex); (3) **lista de venda do Mart mostrava linhas de inventário em quantidade 0**
  (itens equipados/consumidos ficam como linha `0×` no `inventory`) — `_mart.erb` passa a
  exibir **só quantidade > 0** + aviso "Nenhum item no estoque para vender"; (4) **lista
  presa após "Recomeçar jornada"** (sem reiniciar o servidor) — o restart htmx só devolvia
  o fragmento do time e a `#pokemon-list` ficava com os botões "No time ✓" do estado
  antigo; o restart agora re-renderiza a lista via OOB (`hx-include=".list-state"` no
  formulário do banner + `list_state_present?`). Suíte 804/2623.
- Próximo passo do fluxo: **0053 concluída e validada (C1–C12 ok, 2026-08-25, suíte
  804/2623, lint 0)** — organizar a fila (J2, J4, D4, M2) e as limitações técnicas — a
  critério do usuário.