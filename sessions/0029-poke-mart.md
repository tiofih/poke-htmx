# Sessão 0029 — Poke Mart (Eco-3)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluído — 2026-08-14 (`Item` + catálogo estático + `InventoryRepository` + `MartService` + rota `POST /mart/buy` + bloco Poke Mart no `team.erb` + seed de saldo inicial) |
| Implementação | Concluída — 2026-08-14, passos 1–5 verdes (suíte 459/1432, lint 0) |
| Validação | Pendente (executada pelo usuário) |

---

## 1. Objetivo

Criar o **Poke Mart** (Eco-3 do `draft-arquitetura-design-patterns.md`, item 7 da
seção 2 e item 23 do roadmap; fase E seção 8) — o **terceiro elo do circuito
fechado batalha → `:finished` → XP + dinheiro → gastar (Center/Mart) → batalhar
de novo**:

- **`Item`** (Dry::Struct / Value Object, molde `Move`/`Pokemon`) + **catálogo
  estático** (constante, molde `TYPE_NAMES` de `poke_api_types.rb`) — **sem rede**.
- **Compra com dinheiro**: reutiliza `WalletRepository#spend` (Eco-2/0028) + caso
  de uso `MartService` (molde `HealService`/`RewardRule`).
- **`InventoryRepository`** — inventário **persistido por usuário** (tabela
  `inventory`, RF-05) espelhando `WalletRepository`.
- **Rota htmx `POST /mart/buy`** + **bloco Poke Mart no `team.erb`** (catálogo
  com botão "Comprar" por item + inventário + saldo) — padrão do Poke Center
  (0028).
- **Seed de saldo inicial** (`db/seeds/saldo_inicial.rb` + `rake db:seed`) —
  reavaliar o gasto sem depender de batalhas (anotado em 0027/0028 para Eco-3).

**Fora de escopo (RNF-04 — anotar, não refinar agora):** usar itens/consumíveis
**em batalha** (Eco-4 — poção como ação não-ofensiva no motor), **itens
seguráveis** (hold items — Strategy/Decorator sobre `BattlePokemon`), **estratégia
selecionável do time** (decisão 12), **UI de saldo permanente (navbar)** (anotado
desde 0027; aqui o saldo aparece no bloco do Mart apenas), **valores de cura dos
itens** (pertencem à Eco-4 — o catálogo define preço/categoria, não efeito).

## 2. Contexto (estado atual — pós-0028)

- Suíte base **428 runs/1333 asserts**, lint 0 (Eco-2, 2026-08-14).
- **`WalletRepository`** (`lib/wallet_repository.rb`, Eco-1/0027): `balance`,
  `grant` e **`spend`** (Eco-2/0028) — débito atômico, retorna novo saldo,
  no-op p/ insuficiente/nulo/<=0. Reutilizado diretamente na compra.
- **`HealService`** (0028): molde de caso de uso — injeta repos + policy, retorna
  hash de resultado (`healed`, `cost`, `balance`, `notice`), sem rede.
- **`HealCostPolicy`** (0028): puro, `DEFAULT_COST_PER_HP = 0.5`. Balanceamento de
  moeda (win 100 / draw 50 / lose 40 da Eco-1) segue aberto, calibra o Mart.
- `settings` no `configure` (`server.rb:519-539`): `team`, `progression`,
  `battles`, `battle_history`, `wallet`, `api`, `heal`.
- Migrações idempotentes em `db/migrations/*.sql` (última: `0028_add_team_hp.sql`);
  `rake db:setup` e `TestDatabase.setup!` aplicam todas em ordem.
- `TestDatabase` (`test/test_helper.rb`): `clear_team!` trunca
  `team_pokemons, team_pokemon_progress, battles, wallet` (precisa incluir
  `inventory`); `wallet_balance(user_id)`; `table_exists?`/`table_column_info`/
  `primary_key`/`index_exists` para schema.
- `Rakefile` `db:seed`: roda todas as `db/seeds/*.rb` (TeamBasico, TeamEvolucao,
  TeamNiveisMistos, BatalhasHistorico) — ganha o `saldo_inicial`.
- `team.erb` é o fragmento de time (alvo `#team`, `hx-trigger="load"`); já tem o
  bloco **Poke Center** (HP + botão Curar) quando o time é não-vazio.
- `server.rb` `ServerTeamActions`: `render_team`/`add_team_member`/
  `remove_team_member`/`move_team_member`/`heal_team` re-renderizam `team.erb`
  com `@team` (+ `@notice` quando há aviso).
- Testes sem rede: `PokeApiStub.with_gateway` genérico; Poke Mart é todo local
  (catálogo estático + repos PG) — **sem stub de rede** nas rotas novas.

## 3. Arquitetura

### `lib/item.rb` + catálogo estático — puro (molde `TYPE_NAMES`)

- `Item < Dry::Struct`: `name` (slug, `Types::Strict::String`), `display_name`
  (`Types::Strict::String`), `category` (`Types::Strict::String`, ex. `"consumable"`),
  `price` (`Types::Coercible::Integer`). **Sem `heal_amount`** — efeito é Eco-4.
- `lib/item_catalog.rb`: `ITEM_CATALOG = [ Item.new(...), ... ].freeze` (constante,
  molde `TYPE_NAMES`) com `ItemCatalog.all` → a lista e `ItemCatalog.find(name)` →
  `Item` ou `nil`. Catálogo inicial (balanceamento aberto, calibra com a moeda):
  - `potion` / "Poção" / `consumable` / 20
  - `super-potion` / "Super Poção" / `consumable` / 50
  - `hyper-potion` / "Hiper Poção" / `consumable` / 100

### Migração `db/migrations/0029_add_inventory.sql` (idempotente, sem truncate)

```sql
-- 0029: inventario do Poke Mart (Eco-3). Idempotente; sem truncate.
-- 1 linha por (user_id, item_name); quantidade soma via upsert (RF-05).

CREATE TABLE IF NOT EXISTS inventory (
  user_id TEXT NOT NULL,
  item_name TEXT NOT NULL,
  quantity INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, item_name)
);
```

### `lib/inventory_repository.rb` — espelho `WalletRepository`

- `all(user_id)` → `[{ name:, quantity: }]` ordenado por nome (0 linhas → `[]`).
- `add(user_id, item_name, quantity)` → upsert incrementa `quantity`, retorna a
  quantidade nova; `quantity` nulo/`<= 0` → no-op (quantidade atual); item fora
  do catálogo → no-op.
- `count(user_id, item_name)` → quantidade (0 sem linha).
- Isolamento RF-05: tudo por `user_id`.

### `lib/mart_service.rb` — caso de uso (molde `HealService`)

- `MartService.new(inventory:, wallet:, catalog: ItemCatalog)`.
- `buy(user_id, item_name, quantity = 1)` → hash de resultado:
  - item fora do catálogo → `{ bought: false, notice: "Item não disponível." }`;
  - `quantity` nulo/`<= 0` → `{ bought: false, notice: "Quantidade inválida." }`;
  - `cost = item.price * quantity`; `balance < cost` → `{ bought: false, cost:,
    balance:, notice: "Dinheiro insuficiente para comprar (custo N, saldo M)." }`;
  - saldo suficiente → `add` no inventário + `spend` do custo → `{ bought: true,
    item:, quantity:, cost:, balance:, notice: "Comprado N × Poção por C de
    dinheiro. Saldo: M." }`.
- **Sem rede** (catálogo puro + repos PG) — testável com `TestDatabase`, sem
  `PokeApiStub`.

### Rota `POST /mart/buy` + bloco no `team.erb`

- **`MartRoutes.register_buy`** → `POST /mart/buy` → `MartService#buy(current_user,
  params[:item_name], params[:quantity].to_i)` → `@notice` + `@team` (e dados do
  Mart) → re-renderiza `team.erb` (`layout: false`, alvo `#team`).
- `configure`: `set :mart, MartService.new(inventory: InventoryRepository.new,
  wallet: settings.wallet)` e `set :inventory, InventoryRepository.new`.
- `team.erb`: bloco **"Poke Mart"** (quando time não-vazio, ao lado do Poke
  Center) — para cada item do catálogo: `display_name` + preço + `form
  hx-post="/mart/buy"` (hidden `item_name`, hidden `quantity` default 1, botão
  "Comprar", alvo `#team`); abaixo, **inventário** (nome + `N×`, quando `> 0`)
  e **saldo** ("Saldo: N"). `@notice` exibe o aviso do resultado da compra.
- As ações que re-renderizam `team.erb` (`render_team`, `add_team_member`,
  `remove_team_member`, `move_team_member`, `heal_team`, `buy_from_mart`) passam a
  popular `@catalog`, `@inventory` e `@balance` via um helper compartilhado
  (`mart_data` em `ServerTeamActions`) — **leitura local (PG), sem rede**.

### Seed `db/seeds/saldo_inicial.rb` + `Rakefile`

- `SaldoInicial.call(user_id:, db_url:)` → insere saldo inicial no `wallet`
  (`INITIAL_BALANCE = 200`, constante) via upsert (`grant`-like); idempotente
  (re-executar não dobra). Default `rake db:seed` inclui `SaldoInicial` para um
  usuário `seed-shop`; `SEED=saldo_inicial` executa só ela.

### Testes

- Novos: `test/item_catalog_test.rb` (puro), `test/inventory_repository_test.rb`,
  `test/mart_service_test.rb` (caso de uso), ampliação de `test/schema_test.rb`
  (tabela `inventory` + PK `(user_id, item_name)`), `test/seed_scripts_test.rb`
  (`saldo_inicial`), `test/server_test.rb` (`POST /mart/buy` + bloco no `team.erb`).
- `TestDatabase`: `clear_team!` trunca também `inventory`; helper
  `inventory_quantity(user_id, item_name)` (leitura p/ asserts).

## 4. Critérios de aceite

### `Item` + catálogo (puro, sem rede)

- [ ] `Item < Dry::Struct` com `name`/`display_name`/`category`/`price`.
- [ ] `ITEM_CATALOG` constante com pelo menos 3 itens (`consumable`); `all`
      devolve a lista; `find(name)` → `Item` ou `nil` (nome desconhecido).

### Migração / `InventoryRepository`

- [ ] `0029_add_inventory.sql` idempotente cria `inventory` com PK
      `(user_id, item_name)` e `quantity INTEGER NOT NULL DEFAULT 0`;
      re-executar não quebra (sem `TRUNCATE`).
- [ ] `all(user_id)` → lista ordenada `{ name:, quantity: }`; sem linhas → `[]`.
- [ ] `add(user_id, item_name, quantity)` incrementa e retorna a quantidade nova;
      `quantity` nulo/`<= 0` ou item fora do catálogo → no-op.
- [ ] `count(user_id, item_name)` → 0 sem linha.
- [ ] Isolamento RF-05: itens de um `user_id` não aparecem para outro.

### `MartService`

- [ ] Item fora do catálogo → `{ bought: false, notice: "Item não disponível." }`
      (sem `spend`, sem `add`).
- [ ] `quantity` nulo/`<= 0` → `{ bought: false, notice: "Quantidade inválida." }`.
- [ ] Saldo suficiente → `add` + `spend(cost)`; `{ bought: true, item:, quantity:,
      cost:, balance: }` com os valores corretos (ex.: `potion` a 20, qtd 2 →
      custo 40, saldo debitado 40, inventário +2).
- [ ] Saldo insuficiente → `{ bought: false, cost:, balance:,
      notice: "Dinheiro insuficiente..." }`; nada é debitado nem adicionado.
- [ ] Sem rede (catálogo puro + repos PG via `TestDatabase`).

### Rota / UI

- [ ] `POST /mart/buy` com item válido compra, cobra do saldo (`spend`),
      incrementa o inventário (`add`) e re-renderiza `team.erb` (fragmento, alvo
      `#team`, 200, sem `<html>`) com `@notice` do resultado.
- [ ] `POST /mart/buy` com item inválido / quantidade inválida / saldo
      insuficiente → fragmento 200 com `@notice` de aviso, sem compra (0 dano).
- [ ] `team.erb` exibe bloco "Poke Mart" (quando time não-vazio): catálogo com
      preço + botão "Comprar" por item, inventário (`nome N×`, quando `> 0`) e
      saldo ("Saldo: N"); sem JS custom (RNF-01); time vazio → fragmento normal
      sem o bloco (0 regressão do Poke Center).
- [ ] Todas as ações que re-renderizam `team.erb` continuam 200 e sem `<html>`
      (0 regressão add/remove/move/heal).

### Seed

- [ ] `SaldoInicial.call(user_id:)` insere saldo inicial (`INITIAL_BALANCE = 200`)
      no `wallet` via upsert; re-executar não dobra o saldo.
- [ ] `rake db:seed` default aplica `saldo_inicial` (e `SEED=saldo_inicial` só ela).

### Garantias (RNF)

- [ ] Suíte completa verde (baseline 428/1333 preservado + novos) e lint 0;
      commit por green; 0 regressão RF-01..RF-18/D2/D3/0025/0026/0027/0028.
- [ ] Sem novas gems; sem dependência da PokéAPI nas rotas tocadas (Poke Mart é
      local — catálogo estático + repos PG); sem `rubocop:disable` (padrão
      orçamentos).
- [ ] `REQUIREMENTS.md` (roadmap item 23 — Eco-3 executado na 0029), `SESSIONS.md`
      (tabela 0029 em fase 2 + próxima sessão), `draft-arquitetura-design-patterns.md`
      (item 7 da seção 2 / fase E seção 8 atendida) e `draft-auto-battler.md`
      (Fase Eco — Eco-3 feita) atualizados no mesmo escopo.

## 5. Decisões de refinamento

- **`Item` puro + catálogo estático em constante** (molde `TYPE_NAMES`) em vez de
  tabela/tabela dinâmica — itens são imutáveis e poucos; preço/categoria no código,
  **quantidade** no PG (nunca misturar catálogo com estado). Sem rede.
- **Sem `heal_amount` no `Item`** — o efeito (poção restaura HP) é dado da **Eco-4**
  (itens em batalha); aqui o catálogo define apenas o que aparece/vende.
- **`InventoryRepository` espelha `WalletRepository`** (upsert atômico, no-op p/
  inválidos, tudo por `user_id`) — mesmo contrato e mesmo padrão de teste.
- **`MartService` injeta `inventory` + `wallet` + `catalog`** (molde
  `HealService`/caso de uso, seção Rule/Policy objects do draft); sem rede →
  testável com `TestDatabase`.
- **Compra reutiliza `WalletRepository#spend`** (Eco-2/0028) — débito anotado em
  0027 como dependência; o Mart fecha o "gastar" do circuito junto com o Center.
- **Bloco "Poke Mart" dentro do `team.erb`** (ao lado do Poke Center, quando time
  não-vazio) — padrão fragmento htmx, alvo `#team`; sem rota/página dedicada de
  saldo (navbar fica p/ depois, anotado desde 0027; saldo aparece no bloco).
- **Catálogo inicial com balanceamento aberto** — Poção 20 / Super Poção 50 /
  Hiper Poção 100 (3 potências); calibra com win 100 / draw 50 / lose 40 (Eco-1)
  e o `HealCostPolicy` 0.5/HP (0028); a validar com o usuário na fase 3.
- **Seed `saldo_inicial` (200)** — reavaliar o gasto sem depender de batalhas
  (anotado em 0027/0028 para Eco-3); idempotente (upsert, não dobra).
- **Quantidade na rota** via input numérico (`quantity` hidden default 1) —
  permite comprar mais de 1 de uma vez; `MartService` valida nulo/<=0.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `ee55d1e` |
| 1 | **`Item` + catálogo:** `red` — `item_catalog_test.rb` novo (attributes; `ITEM_CATALOG` ≥ 3 itens consumable; `all`; `find` nil p/ desconhecido). `green` — `lib/item.rb` + `lib/item_catalog.rb` | suíte verde + lint 0, commit `e3c9668` |
| 2 | **Migração + `InventoryRepository`:** `red` — `schema_test.rb` (tabela `inventory` + PK `(user_id, item_name)`), `inventory_repository_test.rb` novo (`all` ordenado, `add` upsert/no-op, `count`, isolamento). `green` — `0029_add_inventory.sql` + `lib/inventory_repository.rb` + `TestDatabase` (`clear_team!` trunca `inventory`, helper `inventory_quantity`) | suíte verde + lint 0, commit `a9ee177` |
| 3 | **`MartService`:** `red` — `mart_service_test.rb` novo (injeção `inventory`/`wallet`/`catalog`): item inválido, quantidade inválida (nulo e 0), compra com custo correto (add + spend), saldo insuficiente (nada). `green` — `lib/mart_service.rb` | suíte verde + lint 0, commit `1eff33a` |
| 4 | **Rota + UI:** `red` — `server_test.rb` `ServerMartTest`: `POST /mart/buy` compra + cobra + incrementa + `@notice` + fragmento sem `<html>`; inválido/insuficiente → aviso sem compra; `team.erb` com bloco Poke Mart (catálogo/inventário/saldo) e `mart_data` nas re-renderizações. `green` — `MartRoutes.register_buy` + `set :mart`/`set :inventory` + helper `mart_data` + `buy_from_mart` + `team.erb` | suíte verde + lint 0, commit `cb78a39` |
| 5 | **Seed `saldo_inicial`:** `red` — `seed_scripts_test.rb`: `SaldoInicial.call` insere 200 (upsert que sobrescreve, re-executar não dobra). `green` — `db/seeds/saldo_inicial.rb` + `Rakefile` (`db:seed` default com `seed-shop` + `SEED=saldo_inicial`) | suíte verde + lint 0, commit `ea9d3e9` |
| 6 | **Docs:** `REQUIREMENTS.md` (roadmap 23 — Eco-3 implementado na 0029), `SESSIONS.md` (tabela 0029 fase 2 + próxima sessão), `draft-arquitetura-design-patterns.md` (item 7 / fase E seção 8 atendida), `draft-auto-battler.md` (Fase Eco — Eco-3 feita) | suíte verde + lint 0, commit `Passo 6:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar validação do usuário (fase 3). | |

## 7. Validação (executada pelo usuário)

Pendente — será preenchida na fase 3 após o feedback do usuário.

## 8. Observações

- **Próxima sessão após 0029:** Fase Eco — **Eco-4 (itens em batalha)** — poções
  como ação não-ofensiva no motor (Command/half-FSM), seguráveis escopo simples,
  estratégia selecionável (decisão 12); depois candidatos futuros (D4, D1, J1,
  J2, J3).
- **Balanceamento do catálogo** (20/50/100) a validar com o usuário na fase 3 —
  calibra a moeda da Eco-1 e o custo do Center (0.5/HP).
- **Valores de cura dos itens** ficam para a **Eco-4** (efeito em batalha); o
  `Item` desta sessão não carrega `heal_amount`.
- **Seed `saldo_inicial`** atende a pendência anotada em 0027/0028; a **UI de
  saldo permanente (navbar)** segue fora de escopo (saldo apenas no bloco do Mart).
- **`spend`** (Eco-2/0028) é reutilizado pela compra — fecha o "gastar" do
  circuito (Center + Mart).
