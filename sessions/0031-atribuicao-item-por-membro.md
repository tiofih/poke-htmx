# Sessão 0031 — Eco-4-B: item atribuído por membro (estratégia selecionável)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Done** (commit `4cb4c3a`) — critérios de aceite e plano TDD fechados |
| Implementação | **Concluída** — 2026-08-17, passos 1–6 verdes (suíte 524/1599, lint 0) |
| Validação | **Concluída em 2026-08-18 — validada pelo usuário** |

---

## 1. Objetivo

Atender a **2ª parte da decisão 12** (`draft-arquitetura-design-patterns.md`,
seção 8) — **estratégia de itens selecionável pelo jogador** — como configuração
**pré-batalha**: em vez de o motor decidir sozinho qual item usar do estoque
comum (Eco-4-A/0030), o jogador **atribui um item a um Pokémon do time**, e
**durante a batalha esse membro usa o item atribuído automaticamente** quando a
condição de uso do item dispara.

- **Recorte da decisão 12 (definido pelo usuário nesta sessão):** o jogador
  **não** decide o item durante o round (cada rodada mostra apenas o botão
  "Jogar", sem comando de item no meio da batalha). A escolha é feita **antes**,
  atribuindo um item por membro.
- **Disparo automático (1ª versão):** o membro usa o item atribuído quando o HP
  cai **abaixo de 50%** (`<= 50%` do `hp_max`, limiar atual do `ItemUsePolicy`).
  A condição fica **aberta para outros itens futuros terem outros
  comportamentos** (ex.: item de PP, revive, berry em outro limiar) — a política
  é o ponto único de decisão, extensível por tipo de item.
- A **atribuição é persistida por membro** e o **uso continua debitando o
  inventário** a cada rodada (padrão Eco-4-A).

**Fora de escopo (RNF-04 — anotar, não refinar agora):** decidir o item/Membro
**durante** o round (comando em rodada — opção 2 descartada nesta sessão,
anotada como melhoria futura); **seguráveis/hold items** (decisão 13 — modulam
Attack/Speed via Strategy/Decorator) → sessão Eco-4-C; itens com comportamento
diferente de cura por limiar (outros triggers de uso) → anotado para iteração
futura da política.

## 2. Contexto (estado atual — pós-0030)

- Suíte base **493 runs/1525 asserts**, lint 0 (Eco-4-A, 2026-08-17).
- **`ItemUsePolicy`** (`lib/item_use_policy.rb`, puro): `decide(member:, stock:)`
  → nome do item ou `nil`; usa quando `hp_current/hp_max <= threshold`
  (`DEFAULT_THRESHOLD = 0.5`), escolhe o **menor heal que cobre** o faltante ou o
  **maior disponível** quando nenhum cobre; `heal_amount(item_name)` via catálogo.
  **Não conhece "item atribuído por membro"** — o estoque é o pool comum (`items:`).
- **`BattleEngine`** (`lib/battle_engine.rb`): `initialize(..., items: {},
  item_policy: ItemUsePolicy.new)`; `item_use_for` (time A) chama
  `@item_policy.decide(member:, stock:)`; ação `:item` registra
  `{ round, attacker, action: :item, item, healed, attacker_name }`, decrementa
  `items` e incrementa `items_used`; time B nunca usa item.
- **`BattlePokemon`** (Dry::Struct): `number/name/sprite/types/stats/hp_max/
  hp_current/moves/level` — **sem `assigned_item`**; `from(pokemon, moves:,
  level:)` + `take_damage`/`heal`/`use_move` funcionais.
- **`Pokemon`** (Dry::Struct, `lib/pokemon.rb`): `id/name/sprite/number/slot/
  moves/hp_max/hp_current/types/stats/evolutions` — **sem `assigned_item`**.
- **`team_pokemons`**: colunas de membro `slot`, `moves TEXT[]`; `TeamRepository`
  com `all(user_id)` (join progress + `ORDER BY slot`) e `set_moves`.
- **Rotas**: `GET /team/manage` (`team_manage.erb`, selects de golpes + ▲/▼ de
  slot por membro); `POST /team/:id/moves` (`save_team_moves`, valida e persiste
  via `set_moves`, re-renderiza `team_manage.erb`). Batalha: `playable_engine`
  monta `BattlePokemon.from(detail, moves:, level:)` + `apply_persisted_hp`.
- **Inventário**: `InventoryRepository` (`all`/`add`/`use`/`count`); catálogo
  estático `ItemCatalog` (`potion` 20 / `super-potion` 50 / `hyper-potion` 100,
  `heal_amount` populado). `TestDatabase` trunca `inventory` em `clear_team!`.
- Stubs de rota padrão 0030: `stub_battle_start` (all_names + type + detail +
  moves_for) e `@inventory.add` local (sem rede) para alternar estoque.

## 3. Arquitetura

### Persistência — atribuição por membro

- **Migração idempotente** `db/migrations/0031_add_assigned_item.sql`:
  `ALTER TABLE team_pokemons ADD COLUMN IF NOT EXISTS assigned_item TEXT;`
  (nullable, sem `TRUNCATE`).
- **`Pokemon`** ganha a attribute `assigned_item`
  (`Types::Coercible::String.optional.default(nil)`).
- **`TeamRepository#assign_item(user_id, id, item_name)`**: persiste o item no
  membro (só do próprio usuário; id de outro usuário/inexistente → no-op);
  `item_name` vazio/`nil` → limpa (atribuição removida). `all(user_id)` devolve
  `assigned_item` no `Pokemon`. Validação de catálogo fica na rota (padrão
  `save_team_moves`).

### `BattlePokemon#assigned_item`

- `BattlePokemon` ganha a attribute `assigned_item`
  (`Types::Coercible::String.optional.default(nil)`) e `from(..., assigned_item:)`
  a repassa nos atributos (via `attributes_for`). Caminho sem `assigned_item`
  mantém default `nil` (0 regressão na suíte 0009/0011/0015/0030).

### `ItemUsePolicy` — preferência ao item atribuído

- `decide(member:, stock:)` passa a **preferir o item atribuído do membro**:
  - se `member.assigned_item` presente, estiver no catálogo com `heal_amount > 0`
    e tiver `stock > 0` → devolve esse item (independente do "menor/maior heal"
    do pool comum — é a escolha do jogador);
  - senão (sem atribuição / item fora do estoque) → **fallback para o pool comum**
    existente (menor que cobre / maior disponível) — 0 regressão do 0030.
- `heal_amount(item_name)` inalterado (catálogo). Determinístico (sem RNG).
- **Ponto único de extensão** (nota de código/refinamento): a condição de disparo
  (hoje `hp <= threshold` para itens de cura) e a política de escolha ficam na
  `decide` — itens futuros com comportamento diferente entram aqui por tipo de
  item/categoria, sem tocar o `BattleEngine`.

### Rotas / UI

- **`POST /team/:id/item`** (novo, padrão `POST /team/:id/moves`): recebe
  `item_name`; valida (identifica/atribui ou limpa):
  - `item_name` vazio → limpa (`assign_item(..., nil)`), sem aviso;
  - item fora do catálogo ou com `heal_amount <= 0` → `@notice` e **não** persiste;
  - item no catálogo → `assign_item(..., item_name)`.
  Re-renderiza `team_manage.erb` (alvo `#team`, 200, sem `<html>`).
- **`team_manage.erb`**: por membro, um **select de item atribuído** — opção
  "Nenhum" (default) + itens de cura do **inventário do usuário** (`settings
  .inventory.all`, `heal_amount > 0`, com `×quantidade`) + botão "Salvar item"
  (`hx-post="/team/:id/item"` no alvo `#team`). O valor atual do membro fica
  selecionado.
- **`playable_engine`** (`server.rb`): `player_team` passa
  `assigned_item: member.assigned_item` ao `BattlePokemon.from`.
- **`battle.erb`**: painel "Seu Time" mostra o item atribuído por membro
  (ex.: `carrega: Poção`) ao lado do nome/carregamento — facilita a validação;
  o log de `:item` já exibe o uso na rodada.

### Testes

- **Sem rede**: `TeamRepository#assign_item` (PG local), `BattlePokemon` (puro),
  `ItemUsePolicy` (puro), `BattleEngine` (puro). Rota: inventário/catálogo locais
  + stubs de batalha existentes (`stub_battle_start`) — sem stubs novos.
- Novos/ampliados: `schema_test` (coluna `assigned_item`), `team_repository_test`
  (`assign_item`), `battle_pokemon_test` (`assigned_item`), `item_use_policy_test`
  (preferência), `battle_engine_test` (membro com atribuição usa o item
  atribuído), `server_test` (atribuir via rota + batalha usa o item atribuído).

## 4. Critérios de aceite

### Persistência

- [ ] Migração idempotente `0031_add_assigned_item.sql` — `team_pokemons
      .assigned_item TEXT` (nullable, sem `TRUNCATE`).
- [ ] `Pokemon` com attribute `assigned_item` (default `nil`); `all` devolve a
      atribuição do membro.
- [ ] `TeamRepository#assign_item(user_id, id, item_name)` persiste/limpa só do
      próprio usuário; outro usuário/id inexistente → no-op (isolamento RF-05).

### `BattlePokemon`

- [ ] Attribute `assigned_item` (default `nil`); `from(..., assigned_item:)`
      repassa; caminho sem atribuição → `nil` (0 regressão).

### `ItemUsePolicy`

- [ ] Membro com `assigned_item` no catálogo (`heal_amount > 0`) e com estoque →
      `decide` devolve o item atribuído quando HP ≤ limiar (independente do
      pool comum).
- [ ] Sem atribuição / item atribuído fora do estoque → fallback para o pool
      comum (menor que cobre / maior disponível) — 0 regressão 0030.
- [ ] HP cheio/acima do limiar → `nil` (não queima item); determinístico.
- [ ] **Ponto único de decisão**: condição/política ficam em `decide` (aberto
      para itens futuros com outros comportamentos, sem tocar o motor).

### Rotas / UI

- [ ] `POST /team/:id/item` com `item_name` válido persiste a atribuição e
      re-renderiza `team_manage.erb` (200, sem `<html>`); `item_name` vazio
      limpa; item inválido/fora do catálogo com `heal_amount <= 0` → `@notice`
      e não persiste.
- [ ] `team_manage.erb`: select de item por membro ("Nenhum" + itens de cura do
      inventário com `×qty`, valor atual selecionado) + botão "Salvar item"
      (htmx no alvo `#team`, sem JS custom — RNF-01).
- [ ] `GET /battle` monta o engine com `assigned_item` dos membros; membro com
      atribuição e HP ≤ limiar usa o item na rodada (log + débito no inventário
      por round, padrão 0030); sem atribuição → pool comum (0 regressão).
- [ ] `battle.erb` exibe o item atribuído no painel "Seu Time" (`carrega:
      <display>`).

### Garantias (RNF)

- [ ] Suíte completa verde (baseline 493/1525 preservado + novos) e lint 0;
      commit por green; 0 regressão RF-01..RF-18/D2/D3/0027..0030.
- [ ] Sem novas gems; rotas sem dependência de rede nova; sem `rubocop:disable`
      novo (padrão orçamentos).
- [ ] `REQUIREMENTS.md` (roadmap 23 — Eco-4-B na 0031), `SESSIONS.md` (tabela
      0031 fase 2 + próxima sessão), `draft-arquitetura-design-patterns.md`
      (decisão 12 — 2ª parte atendida; seguráveis continuam pendentes — 13) e
      `draft-auto-battler.md` (Fase Eco — Eco-4-B feita) atualizados no mesmo
      escopo.

## 5. Decisões de refinamento

- **Estratégia selecionável = atribuição de item por membro, uso automático**
  (decisão do usuário nesta sessão — 2ª parte da decisão 12): o jogador escolhe
  o item **antes** da batalha (persistido); durante a batalha o membro usa o
  item atribuído automaticamente quando o disparo ocorre. **Não há comando de
  item durante o round** (a rodada segue com o botão "Jogar").
- **Disparo 1ª versão: HP ≤ 50%** (`<= threshold`, limiar atual do
  `ItemUsePolicy`). **Aberto para outros itens futuros terem outros
  comportamentos** → a condição e a escolha ficam no `decide` (ponto único,
  extensível por tipo/categoria), sem ramificar o `BattleEngine`.
- **Atribuição entre migração da batalha:** atribuir um item **não** debita o
  inventário — o débito continua acontecendo **a cada rodada em que o item é
  usado** via `POST /battle/play` (padrão 0030; item atribuído sem estoque não é
  usado).
- **Fallback ao pool comum** quando o membro não tem atribuição (ou o item
  atribuído está sem estoque): preserva o comportamento automático da 0030 sem
  regressão e evita "silêncio" de cura.
- **Preferência do item atribuído independe do "menor/melhor heal"** — é a
  escolha explícita do jogador; o pool comum só entra como fallback.
- **UI de atribuição no `team_manage.erb`** (onde já se escolhem golpes/posição
  por membro), oferecendo **itens de cura do inventário** (possui `×qty`).
- **Melhoria futura anotada (descartada nesta sessão):** comandar o item
  **durante** o round (escolher na rodada em vez de pré-atribuir) fica anotado
  como iteração opcional da Eco-4; seguráveis/hold items (decisão 13) seguem
  para a Eco-4-C.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `4cb4c3a` |
| 1 | **Migração + `TeamRepository#assign_item`:** `red` — `schema_test` (coluna `assigned_item`) + `team_repository_test` (persiste/limpa, isolamento, `all` devolve). `green` — `0031_add_assigned_item.sql` + `Pokemon` (attribute) + `team_repository.rb` (`assign_item` + `row_to_pokemon`) | suíte verde + lint 0, commit `25f75ca` |
| 2 | **`BattlePokemon#assigned_item`:** `red` — `battle_pokemon_test`: attribute default `nil`, `from(assigned_item:)` repassa, sem atribuição → `nil`. `green` — `lib/battle_pokemon.rb` | suíte verde + lint 0, commit `dd66851` |
| 3 | **`ItemUsePolicy` prefere o atribuído:** `red` — `item_use_policy_test`: membro com `assigned_item` (no catálogo, com estoque) e HP ≤ limiar → devolve o atribuído; HP cheio → `nil`; sem estoque/sem atribuição → fallback pool comum (assert do fluxo atual preservado). `green` — `lib/item_use_policy.rb` (`decide`) | suíte verde + lint 0, commit `ec84f18` |
| 4 | **Motor usa o atribuído:** `red` — `battle_engine_test`: membro de time A com `assigned_item` + estoque em HP ≤ limiar → log `:item` com o item **atribuído**; sem atribuição → pool comum (0 regressão 0030). `green` — (engine já orquestra via policy; só adicionar asserts/ajustes) | suíte verde + lint 0, commit `ccb74fc` |
| 5 | **Rota + UI + batalha web:** `red` — `server_test`: `POST /team/:id/item` (atribui/limpa/inválido → notice), `team_manage.erb` com select (item do inventário selecionado), `GET /battle` monta engine com atribuição e `battle/play` usa o item atribuído (débito + `carrega:` no fragmento). `green` — rota nova + `team_manage.erb` (select) + `playable_engine` (`assigned_item:`) + `battle.erb` (`carrega:`); lint — extração `ServerTeamItemActions` (módulo) e testes de item em `ServerTeamItemTest`/`ServerBattleItemTest` (`ServerBattleTestHelpers`) p/ manter orçamentos | suíte verde + lint 0, commit `82889e1` |
| 6 | **Docs:** `REQUIREMENTS.md` (roadmap 23 — Eco-4-B na 0031 + decisão 12), `SESSIONS.md` (tabela 0031 fase 2 + próxima sessão), `draft-arquitetura-design-patterns.md` (decisão 12 2ª parte; 13 pendente), `draft-auto-battler.md` (Fase Eco — Eco-4-B feita) | suíte verde + lint 0, commit `0d7dc6e` |
| — | **Fase 2 concluída** → **PARAR** e aguardar validação do usuário (fase 3). | |

## 7. Validação (executada pelo usuário)

**Validada em 2026-08-18 pelo usuário.** Fase 3 concluída — critérios de aceite
(seção 4) verificados:

- **Persistência:** migração idempotente `0031_add_assigned_item.sql`
  (`ADD COLUMN IF NOT EXISTS assigned_item TEXT`, nullable, sem `TRUNCATE`);
  `Pokemon` com attribute `assigned_item` (default `nil`); `all(user_id)` devolve a
  atribuição do membro; `TeamRepository#assign_item` persiste/limpa (vazio/`nil` →
  NULL) só do próprio usuário, outro usuário/id inexistente → no-op (isolamento
  RF-05).
- **`BattlePokemon`:** attribute `assigned_item` (default `nil`);
  `from(..., assigned_item:)` repassa; caminho sem atribuição → `nil` (0 regressão).
- **`ItemUsePolicy`:** membro com `assigned_item` no catálogo (`heal_amount > 0`) e
  com estoque e HP ≤ limiar → `decide` devolve o item **atribuído** (independente
  do pool comum); sem atribuição / atribuído fora do estoque → fallback ao pool
  comum (menor que cobre / maior disponível); HP cheio/acima do limiar → `nil`;
  determinístico; ponto único de decisão (extensível por tipo de item sem tocar o
  motor).
- **Rotas/UI:** `POST /team/:id/item` com `item_name` válido persiste e
  re-renderiza `team_manage.erb` (200, sem `<html>`); vazio → limpa (sem aviso);
  inválido/fora do catálogo com `heal_amount <= 0` → `@notice` e não persiste;
  `team_manage.erb` com select por membro ("Nenhum" + itens de cura do inventário
  com `×qty`, valor atual selecionado) + botão "Salvar item" (htmx no alvo `#team`,
  sem JS custom — RNF-01); `GET /battle` monta o engine com `assigned_item` dos
  membros, membro com atribuição e HP ≤ limiar usa o item na rodada (log + débito
  no inventário por round), sem atribuição → pool comum (0 regressão); `battle.erb`
  exibe `carrega: <display>` no painel "Seu Time".
- **Garantias:** suíte completa **524/1599** + lint 0; commit por green; sem novas
  gems; rotas sem dependência de rede nova; sem `rubocop:disable` novo (padrão
  orçamentos — extração `ServerTeamItemActions`/`ServerTeamItemTest`/
  `ServerBattleItemTest` para manter limites).

**Roteiro de validação manual executado:**

- `rake db:seed` + comprar potions no Mart (saldo 200); atribuir "Poção" a um membro
  via `/team/manage` (select mostra `×N`); entrar na batalha → painel "Seu Time"
  mostra `carrega: Poção`.
- Jogar rodadas: membro com HP ≤ 50% usa a Poção **atribuída** — log mostra `usou
  Poção, +N HP` e o inventário debita; membro sem atribuição mantém o pool comum
  (0030 sem regressão).
- Atribuir item com estoque zerado → não usa na batalha (fallback/débito ok);
  limpar atribuição ("Nenhum") → membro volta ao pool comum.

## 8. Observações

- **Melhoria futura (anotada, fora desta sessão):** comandar o item **durante**
  o round (escolher na rodada) — opção descartada aqui por decisão do usuário.
- **Seguráveis/hold items (decisão 13)** — 1 slot/membro, modula Attack/Speed
  via Strategy/Decorator sobre `BattlePokemon` → **Eco-4-C/D** (próxima da fase
  Eco após a 0031).
- **Comportamentos por item abrem na `ItemUsePolicy`** (ponto único) — itens
  futuros (berry em outro limiar, revive, item de PP) não exigem mudança no motor.
- **A atribuição sobrevive a evolução/reordenação** (coluna no membro, sem
  TRUNCATE); remoção do membro elimina a linha de `team_pokemons` → atribuição
  some com ela (comportamento natural).
- **Lint no passo 5 (orçamentos mantidos, sem `rubocop:disable` novo):** lógica de
  item da rota extraída p/ `ServerTeamItemActions` (`server.rb`); testes de item
  de rota em `ServerTeamItemTest` e de batalha em `ServerBattleItemTest`, com as
  helpers de stub de batalha em `ServerBattleTestHelpers` (`test/server_test.rb`)
  — `ServerTeamActions` e `ServerBattleTest` voltam aos limites (ModuleLength 120
  / ClassLength 500).