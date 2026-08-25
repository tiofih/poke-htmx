# Sessão 0046 — JN-3-B: equipamento limitado pela quantidade do estoque

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-24 |
| Implementação | **Concluída** — passos 1–3 + correções de validação em 2026-08-24 (suíte 718/2294, lint 0) |
| Validação | **Done** — executada pelo usuário em 2026-08-24 (tabela da seção 7; correções de UI revalidadas) |

---

## 1. Objetivo

Aplicar a regra de **equipamento por quantidade do estoque** (JN-3-B do
`draft-auto-battler.md`): hoje `TeamService#assign_item`/`assign_held_item` só fazem
`SET` no membro — o mesmo item (poção, choice-band...) pode ser equipado em mais pokes
do que a quantidade comprada. A regra fecha o furo: **itens e seguráveis são por poke**
(cada poke equipa 1 item + 1 segurável) e os pokes **só equipam conforme a quantidade
disponível no time** — **equipar debita do estoque**, **desequipar repõe**, **trocar
repõe o antigo e debita o novo**, **re-equipar o mesmo item no mesmo poke não debita
de novo**; na UI, o option mostra a **quantidade livre** e fica **desabilitado (×0)**
quando esgota. Em batalha, **item atribuído consumido não debita de novo** (já saiu do
estoque na equipação) e **limpa o `assigned_item`** do membro; itens do pool comum
continuam debitando; seguráveis permanecem até desequipar. Sem mudança de schema, sem
gems novas.

## 2. Contexto (estado atual — diagnóstico)

- `lib/team_service.rb:49-61` — `assign_item`/`assign_held_item` delegam a
  `assign_catalog_item`/`assign_held_catalog_item`; item consumível só valida catálogo
  (`heal_amount > 0`), **sem validação de estoque e sem débito**; segurável valida
  `@inventory.count(...).positive?` mas **também sem débito**; `clear_item`/
  `clear_held_item` fazem `SET nil` **sem repor** ao estoque.
- `lib/team_repository.rb:128-143` — `assign_item`/`assign_held_item` (módulo
  `ItemAssignmentOperations`): `UPDATE team_pokemons SET assigned_item/held_item`
  isolado por `user_id`.
- `lib/inventory_repository.rb` — `all(user_id)` (todas as linhas, inclusive `quantity
  = 0`), `add` (upsert), `count`, `use` (decremento min 0) — reutilizáveis para
  débito/reposição.
- `lib/battle_service.rb:89-91,288-295` — `inventory_stock(user_id)` vira `items:` no
  `BattleEngine`; `debit_used_items` (107-114) debita do inventário **todos** os itens
  usados no round — com a nova regra precisa **não debitar** itens que eram atribuídos
  (já saíram do estoque na equipação) e **limpar** o `assigned_item` do membro.
- `lib/battle_engine.rb:118-128` — `item_action` registra log `{ action: :item, item:,
  healed:, attacker_name: }` **sem `attacker_index`** — o service precisa identificar o
  membro para limpar o `assigned_item`.
- `views/team_manage.erb:34-71` — selects de Item (`@inventory` filtrando `heal_amount
  > 0`) e Segurável (`category == "held"`); options com `×quantity` do estoque, sem
  distinção de **em uso**/desabilitado.
- Testes atuais: `test/team_strategy_routes_test.rb` (`ServerTeamItemTest`/
  `ServerTeamHeldItemTest`) cobrem atribuição/limpeza/rejeição; `test/battle_strategy_routes_test.rb`
  (`test_battle_uses_assigned_item_and_debits_inventory` espera débito do atribuído no
  round — **será ajustado**); `test/battle_routes_test.rb` (pool comum debita). Baseline:
  suíte **701 runs/2222 asserts**, lint 0.

## 3. Escopo

### Produção

- `lib/team_service.rb` —
  - `assign_catalog_item`: valida catálogo (`heal_amount > 0`) e **estoque disponível**
    (`@inventory.count(user_id, item_name).positive?`); **no-op se o membro já tem o
    mesmo item** (re-equipar não debita de novo); senão **repõe o item anterior**
    (`@inventory.add(user_id, antigo, 1)` se havia) e **debita o novo**
    (`@inventory.use(user_id, item_name, 1)`) e grava;
  - `clear_item`: **repõe** o item atual ao estoque antes de limpar;
  - espelhos em `assign_held_catalog_item`/`clear_held_item` (categoria `held`);
  - mensagem de erro sem estoque: "Item sem estoque para equipar." (espelha o padrão
    existente "Item não disponível para equipar.").
- `lib/battle_service.rb` —
  - `inventory_stock` → novo `battle_items(user_id)`: estoque livre **+ 1 por item
    atribuído** de cada membro (item atribuído "no poke" fica disponível para a batalha
    mesmo fora do estoque);
  - `debit_used_items`: por item usado no round, se o membro correspondente tinha
    `assigned_item == item` → **limpa o `assigned_item`** do membro (consumido, não
    debita de novo); senão **debita do estoque** (pool comum);
  - `build_engine` usa `items: battle_items(user_id)`.
- `lib/battle_engine.rb` — `item_action` inclui `attacker_index` no log de item
  (identifica o membro no `debit_used_items`).
- `views/team_manage.erb` — selects de Item/Segurável: option mostra a **quantidade
  livre** (`×quantity` do estoque); option com `quantity <= 0` **e** não equipada no
  poke atual → `disabled` com `×0`; item equipado no poke atual → `selected` mesmo com
  `×0`.

### Testes

- `test/team_strategy_routes_test.rb` — novos em `ServerTeamItemTest`/
  `ServerTeamHeldItemTest`: equipar **sem estoque** → aviso e não grava; equipar
  **debita** do estoque; **re-equipar o mesmo item** no mesmo poke não debita de novo;
  **trocar** item repõe o antigo e debita o novo; **desequipar** (vazio) repõe ao
  estoque; option **`disabled` ×0** quando esgota (e o equipado do poke atual segue
  `selected`).
- `test/battle_strategy_routes_test.rb` — ajustar `test_battle_uses_assigned_item_and_debits_inventory`
  para a nova regra (item atribuído consumido **não debita** o estoque e **limpa** o
  `assigned_item`); novo espelho de pool comum ainda debitando (se necessário).
- `test/battle_engine_test.rb` — se aplicável, teste do log de item com
  `attacker_index`.

### Fora de escopo (não abrir)

- JN-4 (componentes Mart/Center), JN-5 (gameloop), J2, J4, D4; P2 (perf da 1ª batalha
  ~2min).
- Compras/estoque inicial (Mart/Center intactos); seeds.
- Mudança de schema/colunas; mudança de contrato das rotas (rotas intactas).
- Itens em batalha do **oponente** (não tem estoque/atribuído).

## 4. Critérios de aceite

### Resultado

- [ ] **C1 — Equipar/desequipar com débito/reposição (service + rotas):** equipar um
      item/segurável **debita 1 do estoque** e grava no membro; **sem estoque** → aviso
      e não grava; **re-equipar o mesmo item** no mesmo poke → no-op (sem débito duplo);
      **desequipar** (Nenhum) **repõe 1 ao estoque**; **trocar** de item **repõe o
      antigo e debita o novo**. Prova: `test/team_strategy_routes_test.rb` (novos
      testes em `ServerTeamItemTest`/`ServerTeamHeldItemTest`).
- [ ] **C2 — UI manage: quantidade livre + desabilitado:** no select de Item e
      Segurável, cada option mostra a **quantidade livre** (estoque pós-débito); option
      com estoque 0 **não equipada no poke atual** fica **`disabled`** com `×0`; o item
      equipado no poke atual fica **`selected`** mesmo com `×0`. Prova:
      `test/team_strategy_routes_test.rb` (markup) + `manual` (visual no
      `/team/manage`).
- [ ] **C3 — Batalha: item atribuído consumido não debita de novo e limpa o poke:**
      usar o item **atribuído** na batalha **não debita** o estoque (já saiu na
      equipação) e **limpa o `assigned_item`** do membro; itens do **pool comum** (não
      atribuídos) continuam **debitando** do estoque; seguráveis não são consumidos
      (inalterado). Prova: `test/battle_strategy_routes_test.rb` (ajustado) +
      `test/battle_routes_test.rb` (pool) + `manual` (opcional).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (701 runs/2222 asserts)** + novos
      testes e lint 0 em **todo** green; commit obrigatório por passo; 0 regressão.
- [ ] Sem gems novas / sem mudança de schema / testes sem rede / sem `rubocop:disable`
      novo.
- [ ] `REQUIREMENTS.md` (roadmap — JN-3-B executado), `SESSIONS.md` (tabela +
      "Próxima sessão") e `draft-auto-battler.md` (JN-3-B marcado) atualizados no passo
      docs; status de validação só após o usuário validar (S4).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste automatizado →
> escrever `manual` explícito + a evidência manual esperada.

## 5. Decisões de refinamento (fechadas com o usuário)

- **2026-08-24 — Próxima sessão = JN-3-B (equipamento por quantidade do estoque)**,
  escolhida pelo usuário para encerrar a parte dos equipamentos (anotada durante a
  validação da 0045).
- **2026-08-24 — Regra:** itens/seguráveis são **por poke** (1 item + 1 segurável por
  poke); pokes **só equipam conforme a quantidade disponível no time**; **equipar
  debita do estoque**; **itens usados em batalha são consumidos** (poke fica **sem item
  atribuído**); **seguráveis continuam equipados/ativos até desequipar** (desequipar
  repõe a unidade).
- **2026-08-24 — Trocar de item repõe o antigo e debita o novo**; **re-equipar o mesmo
  item no mesmo poke NÃO debita de novo**.
- **2026-08-24 — Item atribuído usado em batalha NÃO debita de novo** (já saiu do
  estoque na equipação) — apenas limpa o `assigned_item` do membro; pool comum segue
  debitando.
- **2026-08-24 — UI:** option de item/segurável já equipado em outro poke (ou estoque
  0) fica **desabilitado** com `×0`; item equipado no poke atual fica **selected**
  mesmo com `×0`; quantidade exibida é a **livre** (ex.: Choice Band ×2 no 1º poke,
  ×1 no 2º).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (S4) | commit `Sessao 0046: refinamento concluido — JN-3-B equipamento por quantidade do estoque, criterios e plano TDD fechados`; `./scripts/checar-sessao 0046` + `./scripts/check_docs` |
| 1 | C1 — testes red de service/rotas (sem estoque → aviso; debita; re-equipar no-op; trocar repõe+debita; desequipar repõe) → `TeamService` (débito/reposição/validação) (green) | suíte verde + lint 0, commit `Passo 1:` |
| 2 | C2 — testes red de markup (option `disabled` ×0 + `selected` do equipado; qtd livre) → `team_manage.erb` (green) | suíte verde + lint 0, commit `Passo 2:` |
| 3 | C3 — testes red de batalha (atribuído consumido não debita + limpa `assigned_item`; pool continua debitando) → `battle_engine.rb` (`attacker_index` no log) + `battle_service.rb` (`battle_items` + `debit_used_items`) (green) | suíte verde + lint 0, commit `Passo 3:` |
| 4 | **Docs:** `REQUIREMENTS.md` (roadmap — JN-3-B executado), `SESSIONS.md`, `draft-auto-battler.md` (JN-3-B marcado) | suíte verde + lint 0, commit `Passo 4:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Concluída em 2026-08-24 — validada pelo usuário** *(S2: uma linha por critério).*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 — equipar/desequipar com débito/reposição | `test/team_strategy_routes_test.rb` (`test_post_team_item_debits_stock_on_assign`, `test_post_team_item_reequip_same_item_does_not_debit_again`, `test_post_team_item_switch_restores_old_and_debits_new`, `test_post_team_item_empty_clears_and_restores_stock`, `test_equip_and_clear_five_potions_restores_full_stock` + espelhos held) | `/team/manage`: equipar desconta na hora, desequipar repõe, trocar repõe antigo + debita novo, re-equipar não debita de novo | **ok** |
| C2 — UI: quantidade livre + desabilitado | `test/team_strategy_routes_test.rb` (`test_team_manage_disables_item_option_when_stock_empty`, `test_team_manage_keeps_current_item_selected_even_with_zero_stock`, `test_team_manage_disables_held_option_when_stock_empty`, `test_team_manage_keeps_current_held_selected_even_with_zero_stock`, `test_team_manage_shows_debited_stock_after_equip`, `test_team_manage_shows_restored_stock_after_clear`) | `/team/manage`: qtd livre visível (×4/×1), option disabled ×0, equipado do poke atual selected | **ok** |
| C3 — batalha: atribuído consumido não debita + limpa | `test/battle_strategy_routes_test.rb` (`test_battle_consumes_assigned_item_and_clears_member_without_debit`) + `test/battle_routes_test.rb` (pool debita) + `test/battle_engine_test.rb` (`attacker_index` no log) | — | **ok** |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

- **Anotado na validação (resíduo de UI, fora de critério — RNF-04):** o usuário
  reportou que ao salvar item/segurável o scroll **ainda pula para baixo** (após a
  correção do pulo para cima com `overflow-anchor: none` + preservação do `scrollY`).
  Anotado como candidato a investigação futura (comportamento de swap/scroll do htmx
  no manage; pode exigir `hx-preserve` ou alvo mais granular no swap).
- **Correções de UI feitas durante a validação (fora do critério, produção):**
  (a) **estoque exibido no manage** passou a refletir débito/reposição após
  equipar/desequipar — `save_team_item`/`save_team_held_item` carregavam `@inventory`
  via `team_manage_context` antes do assign e não recarregavam depois (o HTML mostrava
  o estoque anterior ao débito; "equipar 5 e desequipar todas → 4"); fix
  `reload_manage_state` (recarrega `@team` + `@inventory` no POST) + testes de markup
  (`×4` após equipar, `×1` após desequipar); (b) **salvar item/segurável no 4º/5º poke
  fazia a tela pular para o topo** — swap do `#team-view` (innerHTML) derrubava a
  âncora de scroll; fix `overflow-anchor: none` no `.team-column` + preservação do
  `scrollY` entre `htmx:beforeRequest`/`htmx:afterSwap` no `layout.erb`.
- O estoque (`inventory`) passa a representar itens **livres** (não equipados); itens
  equipados ficam "no poke" (`assigned_item`/`held_item`). O `battle_items` soma os
  atribuídos para a batalha enxergar o que o poke carrega.
- `InventoryRepository#all` retorna linhas com `quantity = 0` — base para o `disabled`
  ×0 na UI.
- O `attacker_index` no log de item identifica o membro no `debit_used_items` (a ordem
  de `engine.teams[0]` espelha `@team.all(user_id)`).
- JN-4, JN-5, J2, J4, D4 e P2 (perf da 1ª batalha ~2min) permanecem no backlog, a
  critério do usuário.