# Sessão 0032 — Eco-4-C: seguráveis/hold items (decisão 13)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Done** (commit `82b4d4e`) — critérios de aceite e plano TDD fechados |
| Implementação | **Concluída** — 2026-08-18, passos 1–6 verdes (suíte 557/1688, lint 0) |
| Validação | **Concluída em 2026-08-18 — validada pelo usuário** |

---

## 1. Objetivo

Atender a **decisão 13** (`draft-arquitetura-design-patterns.md`, seção 8 — **itens
seguráveis**) com o **escopo simples** acordado: **1 slot de segurável por Pokémon**
(coluna separada de `assigned_item`), **modulando somente Attack e Speed** por ora,
via **Strategy/Decorator sobre `BattlePokemon` (stats)** — o motor não muda.

- Novos itens no catálogo (categoria `"held"`): **choice-band** (Attack ×1.5) e
  **choice-scarf** (Speed ×1.5).
- A modulação entra no ponto único `BattlePokemon#stat(name)`: quando o membro tem
  `held_item` no catálogo com `stat == name`, o valor base é multiplicado e
  arredondado — **sem tocar o núcleo do `BattleEngine`** nem o cálculo de golpes
  (dano/ordem/speed consomem `stat`, então a modulação propaga naturalmente).
- **Posse/custo (decisão do usuário nesta sessão):** equipar **exige** ter o item no
  inventário (`quantity > 0`) e **não consome** — nem ao equipar, nem a cada rodada
  (efeito passivo permanente durante a batalha). Não debita o inventário.
- Compra continua no Poke Mart (catálogo único `ItemCatalog` → o Mart já lista todos
  os itens automaticamente, sem mudança de rota de compra).

**Fora de escopo (RNF-04 — anotar, não refinar agora):** outros seguráveis com outros
fatos (onda de velocidade, cura passiva, item de revival); seguráveis no oponente;
restrição de unicidade do segurável por time (vários membros podem equipar o mesmo
item, se cada um tiver posse); modulação de outros stats (Sp.Atk/Defensa/etc).

## 2. Contexto (estado atual — pós-0031)

- Suíte base **524 runs/1599 asserts**, lint 0 (Eco-4-B, 2026-08-18).
- **`Item`** (Dry::Struct, `lib/item.rb`): `name/display_name/category/price/
  heal_amount` — **sem** `stat`/`multiplier` (seguráveis não têm representação).
- **`ItemCatalog`** (`lib/item_catalog.rb`): só consumíveis (`category: "consumable"`),
  `heal_amount` 20/50/100.
- **`Pokemon`** (Dry::Struct): `assigned_item` (nullable) — **sem `held_item`**.
- **`TeamRepository`**: `assign_item(user_id, id, item_name)` (limpa com vazio/nil,
  isolamento por usuário, no-op em id alheio/inexistente); `all(user_id)` colapsa
  `assigned_item` no `Pokemon`. **Sem `assign_held_item`.**
- **`BattlePokemon`** (Dry::Struct, `lib/battle_pokemon.rb`): `assigned_item` +
  `stat(name)` (busca no array de stats, default 1) — **sem `held_item`** e **sem
  modulação de stat**.
- **Motor** (`lib/battle_engine.rb`): Dano `attacker.stat("Attack") − target.stat("Defense")`;
  ordem `stat("Speed")`; tipo efetividade. O motor **já consome `stat`** — segurável
  entra por aí, zero mudança no engine.
- **Rotas**: `POST /team/:id/item` (consumível, `ServerTeamItemActions` valida
  `heal_amount > 0` e persiste `assigned_item`); `playable_engine` monta
  `BattlePokemon.from(detail, moves:, level:, assigned_item:)`; `battle.erb` mostra
  `carrega:` quando `assigned_item` presente.
- **Inventário/Mart**: `InventoryRepository` (`all/add/count/use`), `MartService#buy`
  opera sobre `ItemCatalog.find`; `team.erb` lista `@catalog` no Poke Mart — qualquer
  item do catálogo vira comprável sem mudança de rota.
- Stubs de rota padrão 0031 (`ServerBattleTestHelpers`): `stub_battle_start`
  (all_names + type + detail + moves_for) e `@inventory.add` local (sem rede).

## 3. Arquitetura

### Catálogo — `Item` ganha `stat`/`multiplier` (itens `held`)

- **`Item`**: attributes `stat` (`Types::Coercible::String.optional.default(nil)`) e
  `multiplier` (`Types::Coercible::Float.default(1.0)`). Retrocompatível: itens
  consumíveis continuam sem `stat` (nil) e `multiplier` 1.0 (0 regressão 0029/0030/0031).
- **`ItemCatalog.can_hold`** (nova): itens com `category == "held"` (ex.: filtro do
  select de equipar). `all` continua devolvendo o catálogo completo (Mart já o usa).
- Novos itens: `choice-band` ("Choice Band", held, price 80) e `choice-scarf`
  ("Choice Scarf", held, price 80). Balanceamento aberto (anotado).

### Persistência — `held_item` por membro

- **Migração idempotente** `db/migrations/0032_add_held_item.sql`:
  `ALTER TABLE team_pokemons ADD COLUMN IF NOT EXISTS held_item TEXT;` (nullable,
  sem `TRUNCATE`).
- **`Pokemon`** ganha a attribute `held_item`
  (`Types::Coercible::String.optional.default(nil)`).
- **`TeamRepository#assign_held_item(user_id, id, item_name)`**: mesmo contrato do
  `assign_item` — persiste (só do próprio usuário; id alheio/inexistente → no-op);
  vazio/`nil` → limpa (NULL). `all(user_id)` devolve `held_item` no `Pokemon`.
  Validação de posse (inventário) fica na rota (padrão `assign_item`).

### `BattlePokemon` — modulação de stat via segurável (Strategy/Decorator)

- Attribute `held_item` (`Types::Coercible::String.optional.default(nil)`); `from(...,
  held_item:)` repassa (via `attributes_for`). Caminho sem `held_item` → `nil`
  (0 regressão 0009/0011/0015/0030/0031).
- **`stat(name)`** passa a aplicar o multiplicador do segurável quando existir:
  - resolve `ItemCatalog.find(held_item)`;
  - se o item tem `stat == name` → `(base * multiplier).round`;
  - senão/sem `held_item`/item inexistente → valor base inalterado.
- **Ponto único de extensão**: a modulação vive em `stat` (decorator sobre os stats)
  — novos seguráveis/fatos futuros entram por aqui ou por policy, **sem tocar o
  `BattleEngine`** (nota de refinamento, molde de 6.1 do draft).
- Funcional (imutável — Dry::Struct): `take_damage`/`heal` preservam `held_item`.

### Rotas / UI

- **`POST /team/:id/held-item`** (novo, padrão `POST /team/:id/item`): recebe
  `item_name`; valida:
  - `item_name` vazio → limpa (`assign_held_item(..., nil)`), sem aviso;
  - item **fora** do catálogo, ou `category != "held"`, **ou sem posse no inventário**
    (`settings.inventory.count(user_id, item_name) <= 0`) → `@notice` ("Item não
    disponível para equipar.") e **não** persiste;
  - item `held` no catálogo **com** posse → `assign_held_item(..., item_name)`.
  Re-renderiza `team_manage.erb` (alvo `#team`, 200, sem `<html>`).
- **`team_manage.erb`**: por membro, um **segundo select "Segurável:"** — "Nenhum"
  (default) + itens `held` do **inventário do usuário** (`@inventory`, `category ==
  "held"`, com `×quantidade`) + botão "Salvar segurável"
  (`hx-post="/team/:id/held-item"` no alvo `#team`). O valor atual do membro fica
  selecionado. O select de consumível (`ItemSelect`) continua filtrando
  `heal_amount > 0` (itens `held` não aparecem lá — sem conflito com Eco-4-B).
- **`playable_engine`** (`server.rb`): `battle_fighter_from` passa
  `held_item: member.held_item` ao `BattlePokemon.from`.
- **`battle.erb`**: painel "Seu Time" mostra `segura: <display>` ao lado de
  `carrega:`; `rebuild_display_team` preserva `held_item` no `BattlePokemon`
  reconstruído (display após o fim).

### Testes

- **Sem rede**: `TeamRepository#assign_held_item` (PG local), `Item`/`ItemCatalog`
  (puro), `BattlePokemon#stat` (puro), `BattleEngine` (puro, asserts de modulação via
  `stat`). Rota: inventário/catálogo locais + stubs de batalha existentes
  (`stub_battle_start`) — sem stubs novos.
- Novos/ampliados: `schema_test` (coluna `held_item`), `item_catalog_test`
  (held/stat/multiplier/can_hold), `team_repository_test` (`assign_held_item`),
  `battle_pokemon_test` (`held_item` + modulação de `stat`), `battle_engine_test`
  (membro com choice-band causa mais dano; com choice-scarf age antes), `server_test`
  (equipar via rota com/sem posse + batalha modula + `segura:` no fragmento).

## 4. Critérios de aceite

### Catálogo / `Item`

- [ ] `Item` ganha attributes `stat` (opcional, default `nil`) e `multiplier`
      (default `1.0`); consumíveis existentes preservam comportamento (0 regressão).
- [ ] `ItemCatalog` ganha `choice-band` (Attack, ×1.5) e `choice-scarf` (Speed, ×1.5),
      ambos `category: "held"`; `ItemCatalog.can_hold` devolve apenas itens `held`.
- [ ] Mart lista os seguráveis automaticamente (catálogo único) e a compra funciona
      (`MartService` inalterado).

### Persistência

- [ ] Migração idempotente `0032_add_held_item.sql` — `team_pokemons.held_item TEXT`
      (nullable, sem `TRUNCATE`).
- [ ] `Pokemon` com attribute `held_item` (default `nil`); `all` devolve o segurável
      do membro.
- [ ] `TeamRepository#assign_held_item(user_id, id, item_name)` persiste/limpa só do
      próprio usuário; outro usuário/id inexistente → no-op (isolamento RF-05).

### `BattlePokemon` (Strategy/Decorator nos stats)

- [ ] Attribute `held_item` (default `nil`); `from(..., held_item:)` repassa; caminho
      sem segurável → `nil` (0 regressão).
- [ ] `stat(name)` com `held_item` no catálogo e `item.stat == name` → devolve
      `(base × multiplier).round` (ex.: Attack 55 + choice-band → 83; Speed 90 +
      choice-scarf → 135); sem segurável/item inexistente/outro stat → valor base
      (0 regressão).
- [ ] Funcional: `take_damage`/`heal` preservam `held_item`; `stat` outros stats
      (HP/Defense/Sp) intactos (modula só Attack/Speed por ora — decisão 13).
- [ ] **Ponto único de extensão**: modulação em `stat` — novos seguráveis entram
      sem tocar o `BattleEngine`.

### Rotas / UI

- [ ] `POST /team/:id/held-item` com `item_name` válido + posse no inventário persiste
      e re-renderiza `team_manage.erb` (200, sem `<html>`); vazio → limpa; item fora
      do catálogo/`category != "held"`/sem posse → `@notice` e não persiste.
- [ ] `team_manage.erb`: select "Segurável:" por membro ("Nenhum" + itens `held` do
      inventário com `×qty`, valor atual selecionado) + botão "Salvar segurável"
      (htmx no alvo `#team`, sem JS custom — RNF-01); select de consumível inalterado
      (0 regressão Eco-4-B).
- [ ] `GET /battle` monta o engine com `held_item` dos membros; membro com choice-band
      dá mais dano e com choice-scarf age antes (asserts via log/ordem);
      `battle.erb` exibe `segura: <display>` no painel "Seu Time".
- [ ] Equipar/não consome: `POST /battle/play` **não** debita o segurável do
      inventário (nem em rodada, nem no fim).

### Garantias (RNF)

- [ ] Suíte completa verde (baseline 524/1599 preservado + novos) e lint 0;
      commit por green; 0 regressão RF-01..RF-18/D2/D3/0027..0031.
- [ ] Sem novas gems; rotas sem dependência de rede nova; sem `rubocop:disable`
      novo (padrão orçamentos — `ServerTeamItemActions` ainda dentro do ModuleLength
      120; se estourar, extrair `ServerTeamHeldActions`).
- [ ] `REQUIREMENTS.md` (roadmap 23 — Eco-4-C na 0032), `SESSIONS.md` (tabela 0032
      fase 2 + próxima sessão), `draft-arquitetura-design-patterns.md` (decisão 13
      atendida) e `draft-auto-battler.md` (Fase Eco — Eco-4-C feita) atualizados no
      mesmo escopo.

## 5. Decisões de refinamento

- **Segurável = item `held` com 1 slot por Pokémon, modula só Attack/Speed**
  (decisão 13, escopo simples acordado nesta sessão). Implementado como decorator
  sobre `BattlePokemon#stat` — o motor (dano/ordem) já consome `stat`, então a
  modulação propaga **sem nenhuma mudança no `BattleEngine`**.
- **Coluna separada `held_item`** (decisão do usuário nesta sessão): o segurável
  convive com o consumível atribuído (`assigned_item`, Eco-4-B) — o membro pode
  equipar **um consumível (usado em batalha) **E** um segurável (efeito passivo
  permanente) simultaneamente.
- **Equipa se tiver, não consome** (decisão do usuário nesta sessão): posse no
  inventário é exigida no momento de equipar; **não** debita ao equipar nem a cada
  rodada. O efeito é passivo e permanente durante a batalha.
- **Catálogo**: `choice-band` (Attack ×1.5) e `choice-scarf` (Speed ×1.5), preço 80
  cada (balanceamento aberto — calibrado contra win 100/draw 50/lose 40 e heal 0.5/HP).
- **Multiplicador arredondado** (`.round`) para inteiros determinísticos no dano e na
  ordem — sem RNG, TDD puro.
- **Oponente não usa segurável** nesta sessão (escopo simples; anotado para futura
  iteração se desejado).
- **Sem restrição de unicidade** do segurável por time: cada membro equipa
  independentemente (desde que possua o item), como o `assigned_item` atual.
- **Compra no Mart sem mudança**: `ItemCatalog.all` já alimenta o Mart — seguráveis
  entram compráveis automaticamente (0 mudança em `MartService`/`POST /mart/buy`).
- **Melhoria futura anotada:** outros seguráveis com efeitos passivos (heal por
  rodada, speed control, revivals), segurável no oponente, restrição de unicidade e
  modulação de outros stats — iterações futuras de Eco-4-C/D ou J2 (personalização).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `82b4d4e` |
| 1 | **Migração + `Item``held` + catálogo:** `red` — `schema_test` (coluna `held_item`) + `item_catalog_test` (items held com `stat`/`multiplier`, `can_hold`, `find`). `green` — `0032_add_held_item.sql` + `Item` (`stat`/`multiplier`) + `ItemCatalog` (choice-band/choice-scarf + `can_hold`) | suíte verde + lint 0, commit `3f1692c` |
| 2 | **`TeamRepository#assign_held_item` + `Pokemon.held_item`:** `red` — `team_repository_test` (persiste/limpa, isolamento, `all` devolve) + `Pokemon` attribute. `green` — `team_repository.rb` (`assign_held_item` + `row_to_pokemon`) + `pokemon.rb` | suíte verde + lint 0, commit `5c5b684` |
| 3 | **`BattlePokemon#held_item` + modulação de `stat`:** `red` — `battle_pokemon_test`: attribute default `nil`, `from(held_item:)` repassa, `stat` modula Attack/Speed (round), outros stats intactos, preserva em `take_damage`/`heal`. `green` — `lib/battle_pokemon.rb` (`stat` decorator + attribute) | suíte verde + lint 0, commit `e486a5e` |
| 4 | **Motor modulado via `stat` (sem tocar o engine):** `red` — `battle_engine_test`: membro time A com choice-band causa dano maior que sem; com choice-scarf age antes (asserts de log/ordem/dano); time B sem segurável (0 regressão). `green` — asserts + ajustes (engine já orquestra via `stat`) | suíte verde + lint 0, commit `d87119d` |
| 5 | **Rota + UI + batalha web:** `red` — `server_test`: `POST /team/:id/held-item` (atribui/limpa/sem posse → notice), `team_manage.erb` com select "Segurável:" (item held do inventário selecionado, consumível select intacto), `GET /battle` monta com `held_item` e `battle/play` não debita; `battle.erb` `segura:`. `green` — rota nova (`ServerTeamHeldActions`) + `team_manage.erb` (select held) + `playable_engine` (`held_item:`) + `battle.erb` (`segura:` + `rebuild_display_team`) | suíte verde + lint 0, commit `b1f67a9` |
| 6 | **Docs:** `REQUIREMENTS.md` (roadmap 23 — Eco-4-C na 0032 + decisão 13), `SESSIONS.md` (tabela 0032 fase 2 + próxima sessão), `draft-arquitetura-design-patterns.md` (decisão 13 atendida; escopo simples), `draft-auto-battler.md` (Fase Eco — Eco-4-C feita) | suíte verde + lint 0, commit `529f91e` |
| — | **Fase 2 concluída** → **PARAR** e aguardar validação do usuário (fase 3). | |

## 7. Validação (executada pelo usuário)

**Validada em 2026-08-18 pelo usuário.** Fase 3 concluída — critérios de aceite
(seção 4) verificados:

- **Catálogo / `Item`:** attributes `stat` (opcional, default `nil`) e `multiplier`
  (default `1.0`); consumíveis existentes preservam comportamento (0 regressão
  0029/0030/0031); `ItemCatalog` com `choice-band` (Attack ×1.5) e `choice-scarf`
  (Speed ×1.5), ambos `category: "held"`, price 80; `ItemCatalog.can_hold` devolve
  apenas itens `held`; Mart lista os seguráveis automaticamente (catálogo único) e a
  compra funciona (`MartService` inalterado).
- **Persistência:** migração idempotente `0032_add_held_item.sql`
  (`ADD COLUMN IF NOT EXISTS held_item TEXT`, nullable, sem `TRUNCATE`); `Pokemon`
  com attribute `held_item` (default `nil`); `all(user_id)` devolve o segurável do
  membro; `TeamRepository#assign_held_item` persiste/limpa (vazio/`nil` → NULL) só do
  próprio usuário, outro usuário/id inexistente → no-op (isolamento RF-05).
- **`BattlePokemon` (Strategy/Decorator nos stats):** attribute `held_item` (default
  `nil`); `from(..., held_item:)` repassa; caminho sem segurável → `nil` (0 regressão);
  `stat(name)` com `held_item` no catálogo e `item.stat == name` → `(base ×
  multiplier).round`; sem segurável/item inexistente/outro stat → valor base;
  funcional — `take_damage`/`heal` preservam `held_item`; `stat` de HP/Defense/Sp
  intactos (modula só Attack/Speed por ora — decisão 13); ponto único de extensão
  (motor não mudou).
- **Rotas/UI:** `POST /team/:id/held-item` com `item_name` de item `held` do catálogo
  **com posse no inventário** persiste e re-renderiza `team_manage.erb` (200, sem
  `<html>`); vazio → limpa (sem aviso); item fora do catálogo/`category != "held"`/
  sem posse → `@notice` e não persiste; select "Segurável:" por membro ("Nenhum" +
  itens `held` do inventário com `×qty`, valor atual selecionado) + botão "Salvar
  segurável" (htmx no alvo `#team`, sem JS custom — RNF-01); select de consumível
  inalterado (0 regressão Eco-4-B); `GET /battle` monta o engine com `held_item` dos
  membros; `battle.erb` exibe `segura: <display>` no painel "Seu Time"; equipar **não
  consome** — `POST /battle/play` não debita o segurável (nem em rodada, nem no fim).
- **Garantias:** suíte completa **559/1696** + lint 0 (pós-Passo 6 557/1688 + seed
  `team_duelo`); commit por green; sem novas gems; rotas sem dependência de rede
  nova; sem `rubocop:disable` novo (padrão orçamentos — extração
  `ServerTeamHeldActions`/`ServerTeamHeldItemTest`/`ServerBattleHeldItemTest`).

**Roteiro de validação manual executado:**

- Seed **`team_duelo`** (`./scripts/seed team_duelo` ou no `rake db:seed` completo):
  time forte (`seed-strong`, níveis 15–40) x time fraco (`seed-weak`, nível 1), ambos
  com saldo 400 no Mart — alternar usuário via `?as=seed-strong`/`?as=seed-weak`.
- Comprar choice-band (80) e choice-scarf (80) no Mart; equipar via `/team/manage`
  (select "Segurável:" mostra `×N`), entrar em batalha → painel "Seu Time" mostra
  `segura: Choice Band` / `segura: Choice Scarf`.
- Batalhar com o time forte x oponente nível 1: dano maior com choice-band (Attack
  ×1.5) e ordem antecipada com choice-scarf (Speed ×1.5) — vitória rápida; sem
  segurável o dano/ordem voltam ao base (comparação no `seed-weak`).
- Equipar sem posse no inventário → notice "Item não disponível para equipar." e não
  persiste; limpar ("Nenhum") → membro volta ao base; inventário do segurável não
  debita ao equipar nem em rodada/fim de batalha.

## 8. Observações

- **Escopo fechado pela decisão 13** (1 slot/membro, só Attack/Speed): segurável é
  uma "coluna a mais" + decorator em `stat` — não toca schema de inventário, motor
  ou golpes (mudança mínima e reversível).
- **Sem novas gems / rede:** `ItemCatalog` é estático (molde de `TYPE_NAMES`);
  `BattlePokemon#stat` resolve o catálogo em memória (sem PG, sem rede) — TDD puro.
- **Regra de refinamento (2026-08-10):** todo refinamento deve incluir seeds nos
  cenários de validação — para a 0032: `rake db:seed` + comprar choice-band/scarf no
  Mart (saldo inicial 200) para equipar e validar a modulação na batalha.
- **Possível pressão de lint no passo 5:** `ServerTeamItemActions` cresce com os
  métodos de equipar — se o `Metrics/ModuleLength` estourar, extrair
  `ServerTeamHeldActions` (mesmo padrão da 0031) e testes em `ServerTeamHeldTest`.
- **Anotado para candidatos futuros:** J2 (personalização entre batalhas) vai
  ampliar a UI de equipamento; D1 parcial (nível de aprendizado) segue em backlog.
- **Lint no passo 5 (orçamentos mantidos, sem `rubocop:disable` novo):** lógica de
  segurável da rota extraída p/ `ServerTeamHeldActions` (`server.rb`, módulo dedicado)
  — `ServerTeamActions`/`ServerTeamItemActions` permanecem dentro dos limites; testes
  de rota em `ServerTeamHeldItemTest` e de batalha em `ServerBattleHeldItemTest`
  (`test/server_test.rb`, alvos `ServerTeamTest`/`ServerBattleTest` intactos).