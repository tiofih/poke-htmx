# Sessão 0045 — JN-3: itens de uso único por Pokémon (quantidade usada × comprada)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Em andamento** — decisões do usuário em 2026-08-24 |
| Implementação | Pendente |
| Validação | Pendente — **executada pelo usuário** |

---

## 1. Objetivo

Aplicar a regra de **1 uso de item curativo por Pokémon por batalha** (JN-3 do
`draft-auto-battler.md`): hoje as poções são consumíveis automáticos
(`ItemUsePolicy`) e o `InventoryRepository#use` debita do estoque, mas **não há
trava** — o mesmo lutador pode ser curado em várias rodadas da mesma batalha,
drenando o estoque comprado repetidamente no mesmo confronto. A regra fecha esse
furo: **cada membro do time A usa no máximo 1 item por batalha** (seja do pool
comum, seja o item atribuído), alinhada à quantidade comprada (usar consome a qtd
até zerar; sem refill infinito no mesmo lutador). Sem mudança de esquema, sem
gems novas, domínio puro + motor + view.

## 2. Contexto (estado atual — diagnóstico)

- `lib/battle_engine.rb:110-115` — `item_use_for(attacker_team_index, attacker)`:
  só o time A (índice 0) usa item; chama `@item_policy.decide(member:, stock: @items)`
  e retorna o item se houver estoque. **Não há memória de "quem já usou"** — toda
  rodada em que o membro vivo está urgente (HP ≤ 50%) e há estoque, ele usa de novo.
- `lib/battle_engine.rb:117-126` — `item_action` decrementa `@items[item_name]`,
  registra `@items_used[item_name]` e loga `{ action: :item, item:, healed: }`.
- `lib/item_use_policy.rb` — `decide(member:, stock:)` é puro e determinístico
  (threshold 0.5, prefere item atribuído, senão o menor que cubra o missing);
  não conhece estado da batalha (sem noção de "já usado nesta batalha").
- `lib/battle_service.rb:89-91,107-114,288-295` — `inventory_stock(user_id)`
  vira `items:` no `BattleEngine`; `debit_used_items` debita do inventário apenas
  os itens usados no **round corrente** do log.
- `views/battle.erb:9,11-18` — renderiza `_fighter_panel` para o time A e exibe o
  estoque restante (`@engine.items`) no rodapé do painel; **sem badge** por membro.
- `lib/fighter_presenter.rb` — `FighterPresenter.new(pokemon)` expõe identidade,
  HP/PP bars, moves, `assigned_item_label`/`held_item_label`; **sem flag de uso**.
- Testes atuais: `test/battle_engine_test.rb` (`BattleEngineItemTest`, helpers
  `potion_fighter`/`weak_opponent`/`engine_with`) cobrem uso automático, preferência
  do atribuído, fallback, clamp de cura, oponente nunca usa; `test/item_use_policy_test.rb`
  cobre a política pura; `test/battle_routes_test.rb`
  (`test_battle_renders_remaining_stock_in_player_panel`,
  `test_battle_play_debits_used_item_and_shows_heal_log`,
  `test_battle_play_without_item_use_does_not_debit_inventory`) cobre rotas;
  `test/fighter_presenter_test.rb` cobre o presenter. Baseline: suíte
  **694 runs/2200 asserts**, lint 0.

## 3. Escopo

### Produção

- `lib/battle_engine.rb` —
  - novo estado `@items_used_by_member` (hash `[team_index, member_index] => item_name`,
    ou equivalente) inicializado no construtor;
  - `item_use_for(attacker_team_index, attacker_index, attacker)`: além do time A,
    **bloqueia** se `@items_used_by_member[[0, attacker_index]]` já estiver marcado —
    retorna `nil` antes de consultar a policy (regra: 1 uso por membro por batalha,
    valendo também para o item atribuído);
  - `item_action` marca o uso por membro após consumir;
  - acesso de leitura p/ a view: `member_used_item?(team_index, member_index)` e/ou
    `used_item_for(team_index, member_index)`.
- `lib/fighter_presenter.rb` — `initialize(pokemon, item_used: false)` + predicate
  `item_used?` + `item_used_badge` (texto do badge, ex.: "já usou item") — default
  falso mantém os testes atuais intactos.
- `views/battle.erb` — montar presenters do time A com o flag por membro
  (`@engine.member_used_item?(0, index)`).
- `views/_fighter_panel.erb` — renderizar o badge quando `fighter.item_used?`
  (apenas quando o presenter o expuser; o oponente nunca usa item → sem badge).

### Testes

- `test/battle_engine_test.rb` (`BattleEngineItemTest`) — novos:
  `test_member_uses_item_at_most_once_per_battle` (2 rodadas, estoque sobrando, 2º
  uso bloqueado), `test_other_members_can_still_use_their_one_item` (regra é por
  membro, não global), `test_assigned_item_counts_as_single_use` (atribuído usado na
  1ª rodada → bloqueia na 2ª).
- `test/fighter_presenter_test.rb` — `test_item_used_defaults_false` e
  `test_item_used_badge_when_flagged`.
- `test/battle_routes_test.rb` — novo
  `test_battle_panel_shows_item_used_badge_after_member_uses_item` (após `play` com
  uso, fragmento contém o badge; membro sem uso não exibe).

### Fora de escopo (não abrir)

- JN-4 (componentes Mart/Center), JN-5 (gameloop), J2, J4, D4; P2 (perf da 1ª
  batalha ~2min).
- Mudar o limite de estoque/consumo (o débito continua igual — `debit_used_items`).
- Itens em batalha do **oponente** (continua nunca usando — time B não tem estoque).
- Badge/juice em telas fora da batalha; mudança de markup das rotas (rotas intactas).

## 4. Critérios de aceite

### Resultado

- [ ] **C1 — Regra de 1 uso por membro por batalha (motor):** um membro do time A
      que já usou item nesta batalha **não usa outro na rodada seguinte**, mesmo com
      HP ≤ threshold e estoque restante — vale para item do **pool comum e o
      atribuído**; outros membros seguem podendo usar (regra por membro, não
      global); estoque continua debitando por uso. Prova:
      `test/battle_engine_test.rb` (`test_member_uses_item_at_most_once_per_battle`,
      `test_other_members_can_still_use_their_one_item`,
      `test_assigned_item_counts_as_single_use`).
- [ ] **C2 — Badge "já usou item" por membro (UI):** o painel do lutador exibe o
      badge no membro do time A que já usou o item único desta batalha; membros sem
      uso (e o oponente) não exibem; estoque restante continua no rodapé do painel.
      Prova: `test/fighter_presenter_test.rb`
      (`test_item_used_defaults_false`, `test_item_used_badge_when_flagged`) +
      `test/battle_routes_test.rb`
      (`test_battle_panel_shows_item_used_badge_after_member_uses_item`) +
      `manual` (visual no `/battle` após 2 rodadas com uso).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (694 runs/2200 asserts)** +
      novos testes e lint 0 em **todo** green; commit obrigatório por passo; 0
      regressão.
- [ ] Sem gems novas / sem mudança de schema / testes sem rede / sem
      `rubocop:disable` novo.
- [ ] `REQUIREMENTS.md` (roadmap — JN-3 executado), `SESSIONS.md` (tabela +
      "Próxima sessão") e `draft-auto-battler.md` (JN-3 marcado) atualizados no
      passo docs; status de validação só após o usuário validar (S4).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste automatizado →
> escrever `manual` explícito + a evidência manual esperada.

## 5. Decisões de refinamento (fechadas com o usuário)

- **2026-08-24 — Próxima sessão = JN-3 (itens de uso único por Pokémon)**, escolhida
  pelo usuário dentre o backlog aberto (JN-3, JN-4, JN-5, J2, J4, D4, P2).
- **2026-08-24 — Regra estrita: 1 uso por Pokémon por batalha** (independente de
  estoque/threshold) — preterido: limite configurável/constante, ou só limite por
  estoque (comportamento atual, não resolve o dreno repetido no mesmo lutador).
- **2026-08-24 — A trava vale para qualquer item**, inclusive o **atribuído**
  (`assigned_item`); usar o atribuído na 1ª rodada bloqueia o uso na 2ª — preterido:
  atribuído sempre pode usar.
- **2026-08-24 — UI: badge "já usou item" por membro** no painel do lutador
  (espelho da trava); estoque restante continua no rodapé — preterido: manter só o
  estoque restante atual.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (S4) | commit `Sessao 0045: refinamento concluido — JN-3 itens de uso unico (1 uso por Pokemon por batalha), criterios e plano TDD fechados`; `./scripts/checar-sessao 0045` + `./scripts/check_docs` |
| 1 | C1 — testes novos do motor (red: `test_member_uses_item_at_most_once_per_battle`, `test_other_members_can_still_use_their_one_item`, `test_assigned_item_counts_as_single_use`) → `@items_used_by_member` no `BattleEngine`, bloqueio em `item_use_for`, marcação em `item_action`, leitores `member_used_item?`/`used_item_for` (green) | suíte verde + lint 0, commit `Passo 1:` |
| 2 | C2 — testes novos do presenter + rota (red: `test_item_used_defaults_false`, `test_item_used_badge_when_flagged`, `test_battle_panel_shows_item_used_badge_after_member_uses_item`) → `FighterPresenter#item_used?`/`item_used_badge`, `battle.erb` passando o flag por membro, badge em `_fighter_panel.erb` (green) | suíte verde + lint 0, commit `Passo 2:` |
| 3 | **Docs:** `REQUIREMENTS.md` (roadmap — JN-3 executado), `SESSIONS.md`, `draft-auto-battler.md` (JN-3 marcado) | suíte verde + lint 0, commit `Passo 3:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Pendente** *(S2: uma linha por critério; S3: ajuste aqui reabre o critério).*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 — 1 uso por membro por batalha (pool + atribuído, por membro) | `test/battle_engine_test.rb` (3 novos testes) | — | pendente |
| C2 — badge "já usou item" por membro | `test/fighter_presenter_test.rb` (2 novos) + `test/battle_routes_test.rb` (1 novo) | `/battle` após 2 rodadas com uso: badge visível no membro usado, ausente nos demais/oponente | pendente |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

- O motor é o dono do estado da batalha (`BattleRegistry` por `user_id`), então a
  trava "por batalha" reseta naturalmente a cada novo confronto (`prepare` cria novo
  engine) — sem estado global.
- `item_use_for` ganha `attacker_index` na assinatura; `act` já o possui
  (`battle_engine.rb:220`), então a mudança é local.
- O oponente (time B) nunca usa item (`item_use_for` retorna `nil` para
  `attacker_team_index != 0`) — badge só se aplica ao time A.
- P2 (perf da 1ª batalha ~2min) permanece anotado como limitação/fora da fila.
- **Anotado durante a validação (fora de escopo, RNF-04 — draft-auto-battler.md
  "JN-3-B"):** o usuário equipou o **mesmo `choice-band` em 2 pokes diferentes** e foi
  permitido — hoje `assign_item`/`assign_held_item` não têm trava de unicidade por
  time, e o select do `team_manage.erb` não indica item/segurável já em uso (nem
  quantidade livre). Candidata a sessão própria (equipamento único por time, valendo
  para Itens e Seguráveis); **não** implementada nesta sessão.