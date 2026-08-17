# Sessão 0030 — Itens em batalha (Eco-4)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Em andamento** — este arquivo fecha objetivo, escopo, critérios de aceite e plano TDD |
| Implementação | Pendente |
| Validação | Pendente (executada pelo usuário) |

---

## 1. Objetivo

Começar a **Eco-4 (itens em batalha)** do `draft-arquitetura-design-patterns.md`
(item 8 da seção 2 / seção 6.1 — half-FSM) como **Eco-4-A — poções como ação
não-ofensiva no motor de batalha**, fechando o circuito Eco: comprar (Eco-3/0029)
→ **usar durante a batalha** → bater de novo.

- Durante uma batalha, um membro do **time do jogador** pode **usar uma poção do
  inventário** (Eco-3) em vez de atacar — ação **não-ofensiva** que restaura HP
  até `hp_max`.
- **Decisão 12:** uso **automático** nesta sessão — a **estratégia decide**
  (`ItemUsePolicy` injetável, determinística); abrir ao jogador escolher fica para
  a sessão seguinte na fase Eco.
- O **consumo debita o inventário** (`InventoryRepository#use`, novo) — persistido
  no `POST /battle/play` a cada rodada em que o item é usado.
- `Item` ganha `heal_amount` (a Eco-3 deixou explicitamente para a Eco-4).

**Fora de escopo (RNF-04 — anotar, não refinar agora):** **seguráveis/hold
items** (decisão 13 — 1 slot/membro, modula só Attack/Speed) → anotado para uma
sessão futura; **estratégia selecionável pelo jogador** (segunda parte da decisão
12 — "depois abrir para o jogador escolher") → anotado para a próxima sessão da
fase Eco; oponente usar itens (fora — normalmente jogador-centered).

## 2. Contexto (estado atual — pós-0029)

- Suíte base **459 runs/1432 asserts**, lint 0 (Eco-3, 2026-08-14).
- **`Item`** (`lib/item.rb`, Dry::Struct): `name`/`display_name`/`category`/`price`
  — **sem `heal_amount`** (deliberado na 0029: efeito é Eco-4).
- **`ItemCatalog`** (`lib/item_catalog.rb`): catálogo estático — `potion` 20 /
  `super-potion` 50 / `hyper-potion` 100, categoria `consumable`; `all`/`find`.
- **`InventoryRepository`** (`lib/inventory_repository.rb`, espelho `WalletRepository`):
  `all(user_id)` → `[{ name:, quantity: }]` ordenado; `add` upsert; `count`;
  isolamento RF-05. **`use` (decremento) não existe ainda.**
- **`BattlePokemon`** (`lib/battle_pokemon.rb`): Dry::Struct com `hp_max`/`hp_current`,
  `take_damage` funcional (clamp 0), `alive?`/`fainted?`; **sem `heal`**.
- **`BattleEngine`** (`lib/battle_engine.rb`, puro/sem rede e sem PG):
  `initialize(team_a:, team_b:, effectiveness:, target_strategy:)`;
  `act` sempre gera **ataque** (golpe ou legado); `play_round` incremental;
  `log` com entries `{ round, attacker, move/move_type, damage, ko, attacker_name,
  target_name }`. Sem noção de "item" no motor.
- **Rotas de batalha** (`server.rb` `ServerBattleActions`/`BattleRoutes`):
  `GET /battle` (`render_battle_fragment` → `playable_engine` monta time do jogador,
  oponente, `BattleEngine`, guarda em `settings.battles`); `POST /battle/play`
  (`advance_battle`: `play_round` → hooks de `:finished` → renderiza `battle.erb`).
- `settings.inventory` já configurado (`set :inventory, InventoryRepository.new`).
- `battle.erb` (alvo `#battle`): painéis Seu Time/Oponente, log do último round,
  vencedor + botões; estado em memória via `BattleRegistry` por `user_id`.
- `TestDatabase` (`test/test_helper.rb`): `clear_team!` trunca também `inventory`;
  helper `inventory_quantity(user_id, item_name)`.
- `InventoryRepository` e catálogo são **locais** (PG + constante) — testes de rota
  novos **sem stub de rede** (padrão Poke Mart).

## 3. Arquitetura

### `Item#heal_amount` + catálogo (puro)

- `Item` ganha `heal_amount` (`Types::Coercible::Integer`, `default(0)`).
- Catálogo (decisão de balanceamento aberto — validar na fase 3):
  - `potion` 20 → cura **20**
  - `super-potion` 50 → cura **50**
  - `hyper-potion` 100 → cura **100**

### `BattlePokemon#heal` (puro, espelho de `take_damage`)

- `heal(amount)` funcional: retorna nova instância com
  `hp_current = [hp_current + amount, hp_max].min` (nunca passa de `hp_max`);
  `amount <= 0` → sem efeito (mesma instância). Original intacto.

### `ItemUsePolicy` — estratégia automática (decisão 12)

- `lib/item_use_policy.rb`, classe pura `ItemUsePolicy` (molde `HealCostPolicy`/
  `RewardRule`): `ItemUsePolicy.new(threshold: DEFAULT_THRESHOLD = 0.5,
  catalog: ItemCatalog)`.
- `decide(member:, stock:)` → **nome do item** ou `nil`:
  - `stock` = hash `{ name => quantity }` (quantidades positivas) do estoque do time A.
  - Sem HP faltante (`hp_current >= hp_max`) → `nil`.
  - Acima do limiar de urgência (`hp_current.to_f / hp_max > threshold`) → `nil`
    (não queima poção em dano leve).
  - Filtra itens do catálogo disponíveis com `heal_amount` positivo.
  - Se nenhum → `nil`.
  - Escolha **determinística**: dentre os que **cobrem o HP faltante**
    (`heal_amount >= missing`, onde `missing = hp_max - hp_current`) usa o **menor**
    `heal_amount` (sem desperdício); se nenhum cobre, usa o **maior** `heal_amount`
    disponível (melhor recuperação possível).

### `BattleEngine` — ação não-ofensiva `:item` (half-FSM leve)

- `initialize(..., items: {}, item_policy: ItemUsePolicy.new)`:
  - `items` = estoque **do time A** por nome (`{ "potion" => 2 }`), default `{}`.
  - `item_policy` = estratégia de uso (decisão 12 — automática/injetável).
- `attr_reader :items, :items_used`:
  - `items` → estoque **restante** (hash); `items_used` → hash `{ name => count }`
    do que foi consumido até agora.
- `act` (membro do **time A** == indice 0): se `item_policy.decide(member:, stock:
  items)` devolver um item **e** houver estoque → gera **ação de item** em vez de
  ataque:
  - `healed = min(policy_healed, missing)` (clamp em `hp_max`); `apply_heal`
    substitui o `BattlePokemon` no time (HP novo);
  - decrementa `items[name]` e incrementa `items_used[name]`;
  - **não** consome PP nem gasta turno de ataque (a ação da rodada foi consumir).
  - Log entry `{ round, attacker: side, action: :item, item: name, healed: n,
    attacker_name: attacker.name }` — **sem** `target`/`damage`/`ko`.
- Time B (oponente) **nunca usa item** (estoque é do time A; viés de validação).
- `target_strategy` (alvo de ataque) permanece como está — toca só o caminho de ataque.
- Motor continua **puro**: sem PG, sem rede; determinístico (policy sem RNG).

### `InventoryRepository#use` — decremento idempotente (espelho `add`)

- `use(user_id, item_name, quantity = 1)` → decrementa `quantity` (mínimo 0),
  retorna a quantidade nova; `quantity` nulo/`<= 0` ou item fora do catálogo →
  no-op (quantidade atual); sem linha → 0. Isolamento RF-05 (por `user_id`).

### Rotas: estoque no `GET /battle` + débito no `POST /battle/play`

- `playable_engine` monta `items:` de `settings.inventory.all(current_user)` →
  `{ name => quantity }` e injeta no `BattleEngine`. `GET /battle` (re)abre a
  batalha com o estoque atual do inventário.
- `advance_battle`: após `play_round`, **debita os itens usados no round**: para
  cada entry do log com `entry[:round] == @engine.rounds` e `entry[:action] ==
  :item` → `settings.inventory.use(current_user, entry[:item], 1)`. Deltas por
  round ⇒ idempotente (cada `play` avança uma rodada única). Independente do
  `:finished` (o consume acontece a cada round, mesmo se o usuário abandonar).

### `battle.erb`

- Log do último round: branch para `entry[:action] == :item` →
  `Seu Time: <nome> usou <display do item>, +N HP` (display via `ItemCatalog.find`).
- Painel "Seu Time": linha de **estoque restante** (`Itens: Poção ×N`, por item
  com `quantity > 0`, exibindo o display do catálogo) — facilita a validação.

### Testes

- **Sem rede**: motor (`ItemUsePolicy`, `heal`, `BattleEngine`) 100% puro; rota
  usa inventário/catálogo locais (PG + constante) — sem `PokeApiStub` nos novos.
- Novos/ampliados: `test/item_catalog_test.rb` (heal_amount), `test/battle_pokemon_test.rb`
  (`heal`), `test/item_use_policy_test.rb` (puro), `test/battle_engine_test.rb`
  (ação `:item`), `test/inventory_repository_test.rb` (`use`), `test/server_test.rb`
  (estoque no `GET /battle`, débito no `POST /battle/play`, log/item no fragmento).

## 4. Critérios de aceite

### `Item#heal_amount` + catálogo

- [ ] `Item` ganha `heal_amount` (`Types::Coercible::Integer`, default 0).
- [ ] Catálogo com cura por item: `potion` 20 / `super-potion` 50 /
      `hyper-potion` 100; `find` devolve o item com o heal correto.

### `BattlePokemon#heal`

- [ ] `heal(amount)` **funcional**: nova instância com `hp_current` = atual +
      amount, **clamp em `hp_max`** (nunca excede); original intacto.
- [ ] `amount <= 0` → sem efeito (mesma instância); funcionamento coerente com
      `alive?`/`fainted?` (curar pode reavivar pessoa com `hp_current > 0`).

### `ItemUsePolicy`

- [ ] `decide(member:, stock: [])` → `nil` com HP cheio, com HP > limiar (ex.:
      `threshold 0.5`, HP em 70%) ou em stock vazio.
- [ ] HP ≤ limiar: escolhe dentre os que **cobrem o HP faltante** o **menor
      `heal_amount`** (sem desperdício); caso nenhum cubra, o **maior** disponível.
- [ ] Só considera itens do catálogo com `heal_amount` positivo e `stock` > 0.
- [ ] `threshold` injetável (default `0.5`); determinístico (sem RNG).

### `BattleEngine` — ação `:item`

- [ ] `items:` no construtor (default `{}`; estoque do time A por nome);
      `attr_reader :items` (restante) e `:items_used` (consumido).
- [ ] Membro do **time A** com HP ≤ limiar e poção no estoque → usa item **em
      vez de atacar**: HP novo = `hp_current + heal` clampado em `hp_max`;
      `items` decrementa; `items_used` incrementa; **não** consome PP.
- [ ] Log entry `{ round, attacker: side, action: :item, item: name, healed: n,
      attacker_name }` (without `target`/`damage`/`ko`).
- [ ] Sem estoque / policy `nil` / time B (oponente) → ataque normal (0 regressão
      da suíte 0011/0015); time B nunca usa item mesmo com `items` presente.
- [ ] HP restaurado respeita `hp_max` (overheal clampado); determinístico.
- [ ] Motor continua puro (sem PG/rede) — testes diretos na API do engine.

### `InventoryRepository#use`

- [ ] `use(user_id, item_name, quantity = 1)` decrementa (mín 0) e retorna a
      quantidade nova; sem linha → 0; `quantity` nulo/`<= 0` ou item fora do
      catálogo → no-op.
- [ ] Isolamento RF-05: decrementa só do próprio `user_id`.

### Rotas / UI

- [ ] `GET /battle` monta o engine com `items:` do inventário do usuário
      (`settings.inventory.all` → hash); reabertura lê o estoque atual.
- [ ] `POST /battle/play`: a cada round que usa item, **debita 1 de cada item
      usado** via `settings.inventory.use` (idempotente por round); round sem
      item → nada debitado; fragmento 200 sem `<html>`.
- [ ] `battle.erb`: log do round com `action: :item` mostra
      `Seu Time: <nome> usou <display do item>, +N HP`; painel Seu Time mostra o
      **estoque restante** (`Itens: <display> ×N`, para `quantity > 0`).
- [ ] Escolha feita pelo `ItemUsePolicy` default (decisão 12 — automático;
      oponente nunca usa item).
- [ ] Sem JS custom (RNF-01); testes de rota sem rede; dano/vencedor/HP do
      caminho sem item intactos (0 regressão).

### Garantias (RNF)

- [ ] Suíte completa verde (baseline 459/1432 preservado + novos) e lint 0;
      commit por green; 0 regressão RF-01..RF-18/D2/D3/0025..0029.
- [ ] Sem novas gems; rotas tocadas sem dependência de rede (inventário/catálogo
      locais); sem `rubocop:disable` (padrão orçamentos).
- [ ] `REQUIREMENTS.md` (roadmap item 23 — Eco-4-A executado na 0030), `SESSIONS.md`
      (tabela 0030 em fase 2 + próxima sessão), `draft-arquitetura-design-patterns.md`
      (item 8 seção 2 / seção 6.1 — ação `:item`) e `draft-auto-battler.md`
      (Fase Eco — Eco-4-A feita) atualizados no mesmo escopo.

## 5. Decisões de refinamento

- **Escopo único (a) — poções em batalha (Eco-4-A):** decisão do usuário nesta
  sessão. **Seguráveis/hold items** (decisão 13) e **estratégia selecionável**
  (2ª parte da decisão 12) ficam para as próximas sessões da fase Eco (anotadas
  em 6. Observações). O roadmap `Eco-4 (itens em batalha)` é atendido por partes.
- **Motor continua puro** — o estoque de itens é **injetado** (`items:`) a partir do
  inventário na criação da batalha (`GET /battle`), e o **débito** no PG é feito
  pela camada web (`POST /battle/play`), a partir das entries `:item` do round
  recém-executado (idempotência por round). Sem PG/rede dentro do
  `BattleEngine`/`ItemUsePolicy` (padrão do projeto: domínio puro, rota orquestra).
- **Última parte da decisão 12 — "abrir ao jogador escolher" — fica para a próxima
  sessão**: aqui o uso é automático (policy injetável deixa a UI de escolha ser
  adicionada depois sem refatorar o motor).
- **`heal_amount` agora no `Item`** — a 0029 deixou explicitamente o efeito para a
  Eco-4; trás o valor de cura para perto do item (catálogo), sem mudar a tabela
  `inventory` (que só guarda quantidade).
- **Balanceamento aberto — cura igual ao preço** (potion 20→20, super 50→50,
  hyper 100→100): fácil de validar e calibra o circuito (win 100 / draw 50 /
  lose 40). Reavaliar na fase 3 se quiser heal/distribuição diferentes.
- **Gatilho por limiar de HP (`DEFAULT_THRESHOLD 0.5`)**: usar poção quando
  `hp_current <= 50% do hp_max` evita queimar potions em dano leve; o policy
  escolhe o menor heal que cobre o faltante (0 desperdício) — determinístico.
- **Oponente não usa itens** nesta sessão (foco no jogador; estoque é do time A).
- **Débito por round no `POST /battle/play`** — não só no `:finished`: se o
  jogador abandonar a batalha, o item já consumido foi debitado (consistência com
  a compra da Eco-3, que persiste imediatamente).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `Sessao 0030: refinamento concluido — Eco-4-A (pocoes como acao nao-ofensiva no motor em batalha, ItemUsePolicy automatico, decisoes 12/13 escopadas), criterios e plano TDD fechados` |
| 1 | **`Item#heal_amount` + catálogo:** `red` — `item_catalog_test.rb` ampliado: `Item.new(...)` aceita `heal_amount`; `find("potion")` tem `heal_amount 20`, `super-potion` 50, `hyper-potion` 100. `green` — `lib/item.rb` (+attribute) + `lib/item_catalog.rb` (valores) | suíte verde + lint 0, commit `Passo 1:` |
| 2 | **`BattlePokemon#heal`:** `red` — `battle_pokemon_test.rb`: heal funcional com clamp em `hp_max`, `<= 0` sem efeito, original intacto. `green` — `lib/battle_pokemon.rb` | suíte verde + lint 0, commit `Passo 2:` |
| 3 | **`ItemUsePolicy`:** `red` — `item_use_policy_test.rb` novo (puro): HP cheio/acima do limiar/stock vazio → `nil`; cobre com menor heal; sem cobertura usa maior heal; só itens do catálogo com heal>0 em stock>0; threshold injetável. `green` — `lib/item_use_policy.rb` | suíte verde + lint 0, commit `Passo 3:` |
| 4 | **`BattleEngine` ação `:item`:** `red` — `battle_engine_test.rb`: `items:`/`items_used`/`items` (restante); membro de time A em HP ≤ limiar com poção → log `:item` + HP novo + estoque decrementa + sem PP; sem estoque/`nil`/time B → ataque normal (0 regressão); clamp no `hp_max`. `green` — `lib/battle_engine.rb` (init + `act` item + `apply_heal`) | suíte verde + lint 0, commit `Passo 4:` |
| 5 | **`InventoryRepository#use`:** `red` — `inventory_repository_test.rb`: decrementa (min 0) e retorna nova quantidade; sem linha → 0; nulo/`<= 0`/fora do catálogo → no-op; isolamento RF-05. `green` — `lib/inventory_repository.rb` | suíte verde + lint 0, commit `Passo 5:` |
| 6 | **Rotas + UI:** `red` — `server_test.rb`: `GET /battle` injeta estoque do inventário no engine; `POST /battle/play` com item usado debita `inventory_quantity` e mostra `usou <Poção>, +N HP` no fragmento + estoque restante (`Itens:`); round sem item → nada debitado; fragmento 200 sem `<html>`. `green` — `playable_engine` (`items:`) + `advance_battle` (débito por round) + `lib/battle_engine.rb` exposição `items`/`items_used` + `views/battle.erb` | suíte verde + lint 0, commit `Passo 6:` |
| 7 | **Docs:** `REQUIREMENTS.md` (roadmap 23 — Eco-4-A na 0030), `SESSIONS.md` (tabela 0030 fase 2 + próxima sessão), `draft-arquitetura-design-patterns.md` (item 8 seção 2 — Eco-4-A; seção 6.1 ação `:item`), `draft-auto-battler.md` (Fase Eco — Eco-4-A) | suíte verde + lint 0, commit `Passo 7:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar validação do usuário (fase 3). | |

## 7. Validação (executada pelo usuário)

_Pendente — a ser preenchida pelo usuário na fase 3 desta sessão._

**Roteiro de validação manual sugerido:**
- `rake db:seed` (saldo + inventário) ou comprar potions no Poke Mart; adicionar
  Pokémon com HP baixo ao time.
- Entrar na batalha → painel Seu Time mostra o **estoque** (`Itens: Poção ×N`).
- Jogar rodadas: quando um membro cai ≤ 50% HP, a estratégia automática usa a
  poção — log mostra `usou <Poção>, +N HP`, inventário decrementa no PG e o
  fragmento mostra o estoque restante.
- Batalha sem itens → comportamento atual intacto (nada de itens no log).

## 8. Observações

- **Próximas sessões da fase Eco (anotado — decisão do usuário nesta sessão):**
  - **Eco-4-B — estratégia selecionável pelo jogador** (2ª parte da decisão 12:
    abrir a escolha de "usar poção agora / atacar" na UI em vez do automático);
  - **Eco-4-C / Eco-4-D — seguráveis (hold items)** (decisão 13: 1 slot por
    Pokémon, modula só Attack/Speed via Strategy/Decorator sobre `BattlePokemon`).
- **Balanceamento do catálogo/heal** (20/50/100) e **threshold 0.5** a validar na
  fase 3; o `ItemUsePolicy` deixa o critério injetável sem refatorar o motor.
- **Gatilho "<= 50% do HP max"** evita desperdício; numa iteração futura pode
  virar "usar sempre que faltar HP" ou prioridade por membro (anotado no draft).
- **Meio da sessão sem novo escopo (RNF-04):** seguráveis/estratégia selecionável
  só entram após a validação da 0030.