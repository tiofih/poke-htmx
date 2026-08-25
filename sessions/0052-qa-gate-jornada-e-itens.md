# Sessão 0052 — QA Q2+Q3+GL-2: gate da jornada por tamanho do time, gate de HP e itens devolvidos no remove

> Escopo fechado pelo usuário em 2026-08-25 (QA da sessão 0051 → Q2, Q3, GL-2).

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-25 |
| Implementação | **Concluída** — passos 1–3 + docs, suíte 768/2455, lint 0 (2026-08-25) |
| Validação | **Concluída** — C1–C4 ok, validada pelo usuário em 2026-08-25 |

---

## 1. Objetivo

Fechar três bugs de fluxo/persistência do QA: **(Q3)** o gate da jornada passa a ser
**derivado do tamanho do time** (flag persistida deixa de liberar — remover abaixo de 6
re-bloqueia Batalha/Center/Mart); **(GL-2)** time de 6 com **todos os pokes zerados** não
batalha (gate de HP em `GET /battle`/`POST /battle/new` com aviso + CTA para o Poke Center,
CTA "Batalhar" escondido no painel); **(Q2)** remover Pokémon com item/segurável equipado
**devolve o item ao estoque**.

## 2. Contexto (estado atual — diagnóstico)

- **Q3** — `JourneyService#started?` (`lib/journey_service.rb:9-11`) =
  `user_state.started? || team >= 6`. A flag `user_state` é gravada no 6º add
  (`server.rb:218`) e nunca re-fecha: após remover pokes (time parcial ou vazio),
  Batalha/Center/Mart continuam liberados (decisão original da sessão 0036 C5, agora
  reportada como bug). Panel `views/team.erb:4-19` usa `@journey_started` para mostrar
  aviso/ocultar Center/Mart/CTA; rotas `GET /battle`, `POST /team/heal`, `POST /mart/buy`
  checam `started?` (`server.rb:277/284/353`).
- **GL-2** — `prepare_battle_fragment` (`server.rb:352-361`) só checa `started?`; o gate
  não verifica HP. Após derrota (`persist_finished_hp`, `battle_service.rb:225`), o time
  pode ficar todo com `hp_current = 0` e ainda entrar em batalha. `POST /battle/new`
  (`server.rb:407-414`) **nem checa o gate**. Pokémon recém-adicionado tem `hp_max`/`hp_current`
  nulos no `team_pokemon_progress` (`Pokemon` default 0, `lib/pokemon.rb:14-15`) — é cheio
  (o `BattleService#build_engine` só aplica HP persistido quando `hp_max > 0`,
  `battle_service.rb:48`).
- **Q2** — `TeamRepository#remove` (`lib/team_repository.rb:188-196`) faz `DELETE` puro.
  `assigned_item`/`held_item` do membro removido são perdidos (não voltam ao estoque).
  `TeamItemOperations#clear_item`/`clear_held_item` (`lib/team_item_operations.rb`) já sabem
  devolver ao estoque (`@inventory.add`), mas só são usados no desequipar. Item consumido em
  batalha já tem `assigned_item` limpo (`debit_used_items` — nada a devolver). Rota
  `remove_team_member` (`server.rb:264-268`) usa `settings.team.remove` direto.

## 3. Escopo

### Produção

- `lib/journey_service.rb` — `started?` = **só** `team.size >= 6` (flag deixa de liberar);
  novo `battle_ready?(user_id)` = `started? && team tem >=1 poke com HP útil`. Escritas
  `mark_started`/`mark_started_when_full` preservadas (flag vira vestigial p/ o gate).
- `lib/pokemon.rb` — predicado `usable_hp?` (`hp_max <= 0 || hp_current > 0`): nunca lutou =
  cheio; lutou com `hp_current > 0` = ok; lutou e zerou = morto.
- `lib/team_service.rb` — novo `remove_member(user_id, id)`: devolve `assigned_item`/
  `held_item` ao estoque (`InventoryRepository#add`) e então `@team.remove`.
- `server.rb` — `remove_team_member` passa a usar `settings.team_strategy.remove_member`;
  `prepare_battle_fragment`/`new_confront_battle` ganham o gate em 2 estágios
  (não iniciado → fragmento da jornada; iniciado mas time todo zerado → fragmento
  "cure no Poke Center" + CTA); `prepare_team_fragment_data` expõe `@can_battle`.
- `views/team.erb` — CTA "Batalhar" só quando `@can_battle` (Center/Mart permanecem).
- `views/battle.erb` — ramo `@message` renderiza `@gate_cta` quando presente.

### Testes

- `test/journey_service_test.rb` — redefinir `started?` (flag sozinha não libera; time 6
  libera; abaixo de 6 com flag bloqueia); novos testes `battle_ready?`/`usable_hp?`.
- `test/server_test_helpers.rb` — novo helper `fill_team(user_id)` (6 pokes, pikachu no
  slot 1) para a migração dos testes que abriam a jornada só pela flag.
- `test/team_routes_test.rb`, `test/battle_routes_test.rb`, `test/mart_routes_test.rb`,
  `test/battle_strategy_routes_test.rb` — migrar `start_journey` (flag) → `fill_team`
  (time de 6) nos testes que precisam da jornada aberta; novos testes: re-bloqueio abaixo
  de 6 (Q3), gate de HP no `/battle` e CTA escondido (GL-2), remove devolve itens (Q2).

### Fora de escopo (não abrir)

- Remover a tabela/marcador `user_state` (flag fica vestigial; refatoração futura — anotar
  no draft). Q4 (busca base-form), Q5 (remover 2x intermitente), GL-1 (game over),
  OPP-1/OPP-2 (pool de oponentes), fila J2/J4/D4/M2 — anotados, não refinados.

## 4. Critérios de aceite

### Resultado

- [x] **C1 (Q3):** a jornada é iniciada **somente** com o time de 6 membros; remover
      abaixo de 6 re-bloqueia Batalha/Poke Center/Poke Mart (fragmento de gate) e o painel
      volta ao aviso de montagem sem Center/Mart/CTA "Batalhar". — prova:
      `test/journey_service_test.rb` (`JourneyStartedTest#test_flag_alone_does_not_liberate_below_six`),
      `test/battle_routes_test.rb` (`ServerJourneyGateBattleTest#test_battle_blocked_when_team_shrinks_below_six`),
      `test/team_routes_test.rb` (painel com time < 6 sem Center/Mart/CTA).
- [x] **C2 (GL-2 — gate de HP):** `GET /battle` e `POST /battle/new` com time de 6 **todo
      zerado** devolvem aviso "cure seu time no Poke Center" + CTA para a Lista, sem montar
      batalha; Pokémon que nunca lutou (hp_max 0) conta como cheio; time parcialmente
      zerado batalha. **Ajuste S3 (2026-08-25, feedback na validação):** com o time todo
      derrotado, o botão **"Novo confronto" fica desabilitado** (tooltip "Recupere seus
      pokémons no Poke Center para batalhar.") — na **tela de fim de batalha após derrota**
      e no fragmento do gate de HP; "Novo confronto" só fica ativo quando o time tem pelo
      menos 1 poke com HP útil. — prova: `test/journey_service_test.rb`
      (`JourneyBattleReadyTest#test_not_battle_ready_when_all_hp_zero`),
      `test/battle_routes_test.rb` (`ServerBattleHpGateTest#test_battle_blocked_when_all_hp_zero`,
      `ServerBattleTest#test_finish_screen_disables_new_confront_when_team_defeated`).
- [x] **C3 (GL-2 — painel):** com todo o time zerado, o painel **esconde o CTA "Batalhar"**
      mas mantém Poke Center/Poke Mart visíveis. — prova: `test/team_routes_test.rb`
      (`ServerTeamHpGateTest#test_team_panel_hides_battle_cta_when_all_hp_zero`).
- [x] **C4 (Q2):** remover Pokémon com item/segurável equipado **devolve o item ao estoque**
      (`assigned_item` e `held_item`); item já consumido em batalha não é devolvido; remoção
      de id inexistente segue idempotente (sem erro). — prova: `test/team_routes_test.rb`
      (`test_remove_member_restores_assigned_and_held_items`).

### Garantias (RNF)

- [ ] **G1:** suíte completa verde após a migração dos testes para a nova regra (testes que
      abriam a jornada só pela flag passam a montar time de 6) + novos testes; lint 0 em
      **todo** green; commit obrigatório por passo; 0 regressão fora do escopo.
- [ ] **G2:** sem gems novas / sem mudança de schema / testes sem rede / sem
      `rubocop:disable` *(ajuste ao projeto).*
- [ ] **G3:** `REQUIREMENTS.md` + `SESSIONS.md` atualizados no mesmo escopo do passo docs;
      *status de validação* só após o usuário validar (S4).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste automatizado →
> escrever `manual` explícito + a evidência manual esperada.

## 5. Decisões de refinamento (fechadas com o usuário)

- **D1 (Q3, 2026-08-25):** gate derivado do tamanho do time — `started?` = `team >= 6`
  (a flag deixa de liberar; remover abaixo de 6 re-bloqueia). Alternativa preterida:
  re-fechar só com time vazio (menos disruptiva, mas não cobre time parcial). Flag
  `user_state` permanece gravada porém vestigial para o gate (remoção = refatoração futura).
- **D2 (GL-2, 2026-08-25):** `battle_ready?` = iniciada **e** ≥1 poke com HP útil
  (`hp_max ≤ 0` = nunca lutou → cheio; `hp_current > 0` = ok). Gate de HP aplica **só** a
  `GET /battle`/`POST /battle/new` (Center/Mart permanecem abertos — é onde se cura). UX:
  aviso "cure seu time no Poke Center" + CTA para a Lista; **e** o painel esconde o CTA
  "Batalhar" quando todo o time está zerado (Center/Mart visíveis).
- **D3 (Q2, 2026-08-25):** restauração de itens via `TeamService#remove_member` (busca o
  membro, devolve `assigned_item`/`held_item` ao estoque, então `TeamRepository#remove`);
  rota passa a usar o service (handler thin — padrão Respiro 2). Alternativa preterida:
  restaurar dentro do `TeamRepository#remove` (o repositório não conhece o estoque).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `Sessao 0052: refinamento concluido — QA Q2/Q3/GL-2, criterios e plano TDD fechados` |
| 1 | **Q3 (gate por tamanho do time):** red — redefinir `journey_service_test.rb` (flag sozinha não libera; time 6 libera; <6 com flag bloqueia); green — `started? = team >= 6`; migrar `start_journey`→`fill_team` nos testes de rota (battle/mart/heal/team) + novos testes de re-bloqueio (painel e gate) | suíte verde + lint 0, commit `Passo 1: gate da jornada derivado do tamanho do time (Q3) — flag deixa de liberar` |
| 2 | **GL-2 (gate de HP):** red — `Pokemon#usable_hp?` + `JourneyService#battle_ready?` + `GET /battle`/`POST /battle/new` com time todo zerado devolvem aviso+CTA + painel esconde CTA "Batalhar"; green — implementar (pokemon/journey_service/server/battle.erb/team.erb) | suíte verde + lint 0, commit `Passo 2: gate de HP no /battle e CTA Batalhar escondido com time zerado (GL-2)` |
| 3 | **Q2 (itens no remove):** red — rota de remove devolve `assigned_item`/`held_item` ao estoque (e item consumido não devolve); green — `TeamService#remove_member` + rota usa o service | suíte verde + lint 0, commit `Passo 3: remover membro devolve item/seguravel ao estoque (Q2)` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Validada em 2026-08-25** — S2: um resultado por critério. Ajuste S3 registrado acima
(C2 reaberto e re-aprovado): botão "Novo confronto" desabilitado com tooltip na tela de fim
de batalha após derrota e no gate de HP.

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 (Q3) | `./scripts/test -n /flag_alone_does_not_liberate|team_shrinks_below_six/` | remover 1 poke de um time de 6 → painel volta ao aviso e Center/Mart/CTA somem; `/battle` bloqueado | ok |
| C2 (GL-2) | `./scripts/test -n /battle_ready|battle_blocked_when_all_hp_zero|finish_screen_disables_new_confront/` | time de 6 todo zerado → `/battle` mostra "cure no Poke Center" + CTA; fim de batalha após derrota e gate mostram "Novo confronto" desabilitado com tooltip | ok (re-aprovado no ajuste S3) |
| C3 (GL-2 painel) | `./scripts/test -n /hides_battle_cta_when_all_hp_zero/` | painel com time zerado sem CTA "Batalhar", com Center/Mart | ok |
| C4 (Q2) | `./scripts/test -n /restores_assigned_and_held_items/` | equipar poção + Choice Band, remover → estoque volta ao saldo anterior | ok |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

- Flag `user_state` fica **vestigial** para o gate após a 0052 (escrita preservada, leitura
  removida de `started?`) — **anotar no draft**: refatoração futura para remover a tabela/
  marcador ou redefinir seu papel. Não remover nesta sessão (sem mudança de schema, G2).
- Q4 (busca só acha formas base) e Q5 (remover 2x intermitente) seguem no changelog do QA —
  não entram nesta sessão.
- Migração de testes (Passo 1): ~21 `start_journey` em rotas + setup da `ServerBattleTest`
  (classe inteira) → substituir por time de 6 (`fill_team`); testes que adicionam poke
  próprio removem o add (o `fill_team` já fornece pikachu no slot 1).
- Próximo passo do fluxo: **0052 concluída e validada (C1–C4 ok, 2026-08-25)** — organizar o
  resto do QA (Q4, Q5) e a fila (J2, J4, D4, M2, GL-1) — a critério do usuário.