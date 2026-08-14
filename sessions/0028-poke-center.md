# Sessão 0028 — Poke Center (Eco-2)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluído — 2026-08-14 (persistência de HP pós-batalha + `HealCostPolicy` proporcional ao HP faltante + `WalletRepository#spend` + `HealService` + rota `POST /team/heal`) |
| Implementação | Pendente |
| Validação | Pendente (executada pelo usuário) |

---

## 1. Objetivo

Criar o **Poke Center** (Eco-2 do `draft-arquitetura-design-patterns.md`, item 23 do
roadmap; decisão 11 — custo **proporcional ao HP faltante**) — o segundo elo do
circuito fechado **batalha → `:finished` → XP + dinheiro → gastar → batalhar de novo**:

- **Persistir o HP do time após a batalha** (Eco-2 "reforça persistir HP/status do
  time" — a 0027 anotou que o `spend` chega com esta sessão): o dano sofrido passa
  a **sobreviver** ao fim da batalha e a **entrar na próxima batalha** (time
  danificado enfrenta o próximo confronto; nunca batalhou = HP cheio).
- **`HealCostPolicy`** pura: custo **proporcional ao HP faltante** (decisão 11),
  rate injetável (default 0.5 moeda/HP — balanceamento aberto, calibra com
  win 100 / draw 50 / lose 40 da Eco-1).
- **`WalletRepository#spend`** — débito do saldo (Eco-2 traz o gasto que a 0027
  anotou como pendente), nunca negativo, espelhando o no-op do `grant`.
- **`HealService`** (caso de uso, molde `RewardRule`): soma o HP faltante do time,
  calcula o custo, cobra do saldo e cura — retorna resultado (curado/saldo
  insuficiente/já curado).
- **Rota htmx `POST /team/heal`** + entrada no `team.erb` (HP por membro + botão
  "Curar") — cobra do saldo e re-renderiza `#team` com aviso.

**Fora de escopo (RNF-04 — anotar, não refinar agora):** reavivar com custo
diferenciado (fainted é tratado como HP `0` → mesmo custo), Poke Mart (Eco-3),
itens/poções em batalha (Eco-4), UI de saldo permanente (navbar), seed de saldo
inicial (rever em Eco-3).

## 2. Contexto (estado atual — pós-0027)

- Suíte base **386 runs/1216 asserts**, lint 0 (Eco-1, 2026-08-14).
- **HP hoje é efêmero**: `player_team` monta `BattlePokemon.from(detail, ...)` com
  `hp_current = hp_max` (cheio) a cada `GET /battle`; o dano da batalha vive só no
  `BattleRegistry` em memória. `rebuild_display_team` (`server.rb:280`) reflete o
  HP pós-batalha no engine, mas **nada persiste**.
- **`team_pokemon_progress`** (D2-A/0023) já é o estado persistente **por membro**
  (`level`, `xp`), chaveado por `team_pokemon_id` (estável à evolução) e com
  `ON DELETE CASCADE` — molde natural para `hp_max`/`hp_current`.
- **`ProgressionRepository`** (`lib/progression_repository.rb`): `get(user_id, id)`
  → `{ level:, xp: }`; `grant(...)` recalcula nível por XP. Aditivo para HP.
- **`WalletRepository`** (`lib/wallet_repository.rb`, sessão 0027): `balance` e
  `grant` (upsert atômico, retorna novo saldo, no-op p/ nulo/<=0). Falta `spend`.
- **`RewardRule`** (0027): `xp_for`/`money_for` por resultado
  (win 100 / draw 50 / lose 40).
- Transição `:finished` (`advance_battle`, `server.rb:233-241`) já concentra
  `record_finished_battle`, `grant_finished_xp`, `grant_finished_money`,
  `apply_evolution_and_learning`, `rebuild_display_team` — **um só ponto atômico**.
- `settings` no `configure` (`server.rb:489-493`): `team`, `progression`, `battles`,
  `battle_history`, `wallet`, `api`.
- Migrações idempotentes em `db/migrations/*.sql` (última: `0027_add_wallet.sql`).
- `TestDatabase` (`test/test_helper.rb`): `clear_team!` trunca
  `team_pokemons, team_pokemon_progress, battles, wallet`; `progress_row`/
  `progress_count`; `table_column_info`/`table_exists?` para schema.
- `team.erb` é o fragmento de time (alvo `#team`, carregado com `hx-trigger="load"`).
- Testes sem rede: `PokeApiStub.with_gateway` genérico; `stub_battle_start` +
  `N.times post "/battle/play"` até `:finished`.

## 3. Arquitetura

### Migração `db/migrations/0028_add_team_hp.sql` (idempotente, sem truncate)

```sql
-- 0028: HP persistente por membro (Eco-2 — Poke Center). Idempotente; sem truncate.
-- hp_max/hp_current = 0 significa "nunca batalhou" (HP cheio); 0029+ não precisa.

ALTER TABLE team_pokemon_progress ADD COLUMN IF NOT EXISTS hp_max INTEGER NOT NULL DEFAULT 0;
ALTER TABLE team_pokemon_progress ADD COLUMN IF NOT EXISTS hp_current INTEGER NOT NULL DEFAULT 0;
```

- `ALTER ADD COLUMN IF NOT EXISTS` — não duplica em re-execução; sem `TRUNCATE`.
- HP vive no estado persistente por membro (D2 já persiste nível/XP); evolução muda
  `number`/`name`/`sprite` mas a chave `team_pokemon_id` é estável.

### `Pokemon` + `TeamRepository#all` — HP no fragmento

- `Pokemon` ganha `hp_max`/`hp_current` (`Types::Coercible::Integer`, default `0`).
- `TeamRepository#all(user_id)` passa a **`LEFT JOIN team_pokemon_progress`** para
  popular `hp_max`/`hp_current` (membro sem progresso → `0` = nunca batalhou).
- Sem mudança no contrato das demais rotas (`add`/`remove`/`move`/`set_moves`).

### `lib/heal_cost_policy.rb` — puro (decisão 11)

- `DEFAULT_COST_PER_HP = 0.5` (moeda por HP faltante) — injetável.
- `missing_hp(hp_max, hp_current)` → `max(hp_max - hp_current, 0)`; `hp_max <= 0`
  (nunca batalhou) → `0` (HP cheio).
- `cost(missing_hp)` → `(missing_hp * cost_per_hp).round` — **proporcional ao HP
  faltante**; sem rede.

### `lib/progression_repository.rb` — HP por membro

- `get(user_id, id)` passa a incluir `hp_max`/`hp_current` no hash retornado
  (aditivo — contratos atuais `[:level]`/`[:xp]` intactos).
- `update_hp(user_id, id, hp_max, hp_current)` — `UPDATE ... WHERE team_pokemon_id
  = $1` (progresso não existe → no-op); usado no hook `:finished` e no heal.

### `lib/wallet_repository.rb` — `spend`

- `spend(user_id, amount)` — débito atômico e retorna o **novo saldo**; saldo
  insuficiente → **no-op** (saldo inalterado, nunca negativo); `amount` nulo/`<= 0`
  → no-op (saldo atual). Espelha o no-op do `grant`.

### `lib/heal_service.rb` — caso de uso

- `HealService.new(team:, progression:, wallet:, policy: HealCostPolicy.new)`.
- `heal(user_id)` → hash de resultado:
  - sem HP faltante → `{ healed: false, notice: "Seu time já está curado." }`;
  - faltante > 0 e saldo insuficiente → `{ healed: false, cost:, balance:,
    notice: "Dinheiro insuficiente para curar (custo N, saldo M)." }`;
  - faltante > 0 e saldo suficiente → `spend` + `update_hp` (cheio) de cada
    membro → `{ healed: true, cost:, balance:, notice: "Time curado por N de
    dinheiro. Saldo: M." }`.
- Sem rede (repos PG + policy pura — padrão `RewardRule`/caso de uso).

### Hook no `:finished` (`server.rb`) — persistir HP

- Em `advance_battle`, dentro da transição `:finished`, ao lado de
  `rebuild_display_team`: `persist_finished_hp` — para cada fighter de
  `@engine.teams[0]`, `update_hp(current_user, member.id, fighter.hp_max,
  fighter.hp_current)` (alinhamento por índice, mesmo de `rebuild_display_team`).
- **Batalha em andamento** não persiste HP (mesmo guard de transição).

### `player_team` — batalha começa com o HP persistido

- Após `BattlePokemon.from(detail, ...)`, se o progresso tem `hp_max > 0`, aplicar
  `fighter.new(hp_current: [persisted_hp_current, hp_max].min)` — o time danificado
  entra **no próximo confronto** com o dano que sofreu; nunca batalhou → cheio.

### Rota `POST /team/heal` + `team.erb`

- `TeamRoutes.register_heal` → `POST /team/heal` → `HealService#heal(current_user)`,
  `@notice` do resultado + `@team = settings.team.all(current_user)` → re-renderiza
  `team.erb` (`layout: false`, alvo `#team`).
- `configure`: `set :heal, HealService.new(team: settings.team, progression:
  settings.progression, wallet: settings.wallet)`.
- `team.erb`: bloco "Poke Center" (quando time não-vazio) — HP por membro
  (`HP cur/max`, quando `hp_max > 0`) + botão "Curar" (`form hx-post="/team/heal"`
  → alvo `#team`); `@notice` existente exibe o aviso do resultado.

### Testes

- `TestDatabase.progress_hp(user_id, id)` (helper de leitura); `clear_team!` já
  trunca `team_pokemon_progress` (sem mudança).
- Novos `test/heal_cost_policy_test.rb` (puro), ampliação de
  `test/wallet_repository_test.rb` (`spend`), `test/schema_test.rb` (colunas hp),
  `test/progression_repository_test.rb` (`get` com hp + `update_hp`),
  `test/heal_service_test.rb` (caso de uso), `test/server_test.rb` (persistência no
  `:finished`, batalha começa com HP persistido, `POST /team/heal`).

## 4. Critérios de aceite

### Migração / schema

- [ ] `0028_add_team_hp.sql` idempotente adiciona `hp_max INTEGER NOT NULL DEFAULT 0`
      e `hp_current INTEGER NOT NULL DEFAULT 0` em `team_pokemon_progress`;
      re-executar não quebra (sem `TRUNCATE`).
- [ ] `Pokemon` ganha `hp_max`/`hp_current` (default `0`); `TeamRepository#all`
      popula ambos via `LEFT JOIN team_pokemon_progress` (membro sem progresso → `0`).

### `HealCostPolicy` (puro, decisão 11)

- [ ] `missing_hp(hp_max, hp_current)` → diferença (≥ 0); `hp_max <= 0` (nunca
      batalhou) → `0`; `hp_current >= hp_max` → `0`.
- [ ] `cost(missing_hp)` → `(missing_hp × cost_per_hp).round` (default
      `DEFAULT_COST_PER_HP = 0.5`); `cost_per_hp` injetável; sem rede.

### `ProgressionRepository`

- [ ] `get` inclui `hp_max`/`hp_current` no hash (aditivo — `[:level]`/`[:xp]`
      preservados).
- [ ] `update_hp(user_id, id, hp_max, hp_current)` atualiza; progresso inexistente
      → no-op.

### `WalletRepository#spend`

- [ ] `spend(user_id, amount)` debita e retorna o novo saldo; saldo insuficiente →
      no-op (saldo inalterado, nunca negativo); `amount` nulo/`<= 0` → no-op.
- [ ] Isolamento RF-05: débito de um `user_id` não afeta o de outro.

### `HealService`

- [ ] Sem HP faltante → `{ healed: false, notice: "Seu time já está curado." }`
      (sem `spend`).
- [ ] Faltante > 0 e saldo suficiente → `spend` + `update_hp` cheio de cada membro;
      `{ healed: true, cost:, balance: }` com os valores corretos (ex.: time com
      10 de HP faltante, rate 0.5 → custo 5).
- [ ] Faltante > 0 e saldo insuficiente → `{ healed: false, cost:, balance:,
      notice: "Dinheiro insuficiente..." }`; nada é debitado nem curado.
- [ ] Time vazio → `{ healed: false, ... }` sem erro (0 regressão).
- [ ] Sem rede (policy pura + repos PG via `TestDatabase`).

### Hook `:finished` / batalha com HP persistido

- [ ] Batalha que termina (`:finished`) persiste `hp_max`/`hp_current` de cada
      membro do time A (dano sobrevive ao fim); plays posteriores não re-persistem
      (guard de transição).
- [ ] Batalha **em andamento** não persiste HP.
- [ ] `GET /battle` seguinte começa com o HP persistido (`hp_current` danificado);
      membro que nunca batalhou entra cheio (0 regressão).
- [ ] Após curar o time, a próxima batalha começa cheia.

### Rota / UI

- [ ] `POST /team/heal` cura o time, cobra do saldo (`spend`) e re-renderiza
      `team.erb` (fragmento, alvo `#team`, 200, sem `<html>`) com `@notice` do
      resultado (curado/custo/saldo, saldo insuficiente, já curado).
- [ ] `team.erb` exibe bloco "Poke Center" com HP por membro (`HP cur/max`, quando
      `hp_max > 0`) + botão "Curar" (`form hx-post="/team/heal"` → `#team`); sem JS
      custom (RNF-01); time vazio → fragmento normal sem o bloco.
- [ ] Time vazio/oponente vazio mantém o comportamento amigável atual (0 regressão).

### Garantias (RNF)

- [ ] Suíte completa verde (baseline 386/1216 preservado + novos) e lint 0; commit
      por green; 0 regressão RF-01..RF-18/D2/D3/0025/0026/0027.
- [ ] Sem novas gems; sem dependência da PokéAPI nas rotas tocadas (Poke Center
      usa HP persistido, sem rede); sem `rubocop:disable` (padrão orçamentos).
- [ ] `REQUIREMENTS.md` (roadmap item 23 — Eco-2 executado na 0028), `SESSIONS.md`
      (tabela 0028 em fase 2 + próxima sessão), `draft-arquitetura-design-patterns.md`
      (decisão 11 atendida) e `draft-auto-battler.md` (Fase Eco — Eco-2 feita)
      atualizados no mesmo escopo.

## 5. Decisões de refinamento

- **Persistir HP em `team_pokemon_progress`** (`hp_max`/`hp_current`) em vez de
  nova tabela — já é o estado persistente **por membro** (D2); `ALTER ADD COLUMN
  IF NOT EXISTS` idempotente, sem truncate. Molde da decisão 3 (D2).
- **Batalha começa com o HP persistido** — fecha o circuito (batalhar → dano
  persiste → curar → batalhar de novo); "reforça persistir HP/status do time"
  (draft, impacto Eco-2). Sem o carryover, o gasto no Center seria decorativo.
- **HP `0` = nunca batalhou (HP cheio)** — evita `hp_max` derivado na montagem
  (detalhe da PokéAPI é carregado só no `GET /battle`); `HealCostPolicy` e
  `player_team` tratam `hp_max <= 0` como cheio.
- **`HealCostPolicy` proporcional ao HP faltante (decisão 11)** com
  `DEFAULT_COST_PER_HP = 0.5` — **balanceamento aberto**: calibra com win 100 /
  draw 50 / lose 40 (Eco-1); a validar com o usuário na fase 3.
- **`spend` no-op (nunca negativo)** em vez de erro — espelha o `grant` da 0027
  (no-op p/ inválidos); `HealService` checa o saldo antes de debitar (o caminho
  comum não levanta exceção).
- **`HealService` injeta repos + policy** (molde `RewardRule`/caso de uso, seção
  Rule/Policy objects do draft); sem rede (tudo PG/puro) → testável com
  `TestDatabase` e sem `PokeApiStub`.
- **Entrada do Poke Center no `team.erb`** (HP por membro + botão "Curar") — alvo
  `#team`, padrão fragmento htmx; sem rota/UI dedicada de saldo (navbar fica p/
  depois, anotado desde 0027).
- **Fainted = HP `0` → mesmo custo** (reavivar diferenciado anotado como fora de
  escopo); `HealService` cura do `hp_current` até `hp_max`.
- **`get` aditivo com hp** — sem mudança de contrato dos consumidores
  (`member_level`/`evolution_target`/`learn_moves_for_member` usam `[:level]`).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `Sessao 0028: refinamento concluido — Eco-2 Poke Center (persistencia de HP pos-batalha, HealCostPolicy proporcional ao HP faltante, WalletRepository#spend, HealService, rota POST /team/heal), criterios e plano TDD fechados` |
| 1 | **Migração + `Pokemon` + `all`:** `red` — `schema_test.rb` (colunas `hp_max`/`hp_current` em `team_pokemon_progress`), `pokemon_test.rb` (attributes hp default 0), `team_repository_test.rb` (`all` popula hp via JOIN). `green` — `0028_add_team_hp.sql` + `Pokemon` + `TeamRepository#all` | suíte verde + lint 0, commit `Passo 1:` |
| 2 | **`HealCostPolicy`:** `red` — `heal_cost_policy_test.rb` novo: `missing_hp` (diff, `hp_max<=0` → 0, cheio → 0) e `cost` proporcional (rate default 0.5 e injetável). `green` — `lib/heal_cost_policy.rb` | suíte verde + lint 0, commit `Passo 2:` |
| 3 | **`ProgressionRepository`:** `red` — `progression_repository_test.rb`: `get` inclui hp (aditivo) e `update_hp` persiste/no-op. `green` — `lib/progression_repository.rb` | suíte verde + lint 0, commit `Passo 3:` |
| 4 | **`WalletRepository#spend`:** `red` — `wallet_repository_test.rb`: debita e retorna novo saldo, insuficiente → no-op, nulo/<=0 → no-op, isolamento. `green` — `lib/wallet_repository.rb` | suíte verde + lint 0, commit `Passo 4:` |
| 5 | **`HealService`:** `red` — `heal_service_test.rb` novo (injeção `team`/`progression`/`wallet`/`policy`): já curado, cura com custo correto (spend + `update_hp` cheio), saldo insuficiente (nada debitado/curado), time vazio. `green` — `lib/heal_service.rb` | suíte verde + lint 0, commit `Passo 5:` |
| 6 | **Hook `:finished` + carryover:** `red` — `server_test.rb`: batalha terminada via `stub_battle_start` persiste hp por membro (dano), plays extras não re-persistem, em andamento não persiste; novo `GET /battle` começa com hp persistido. `green` — `persist_finished_hp` em `advance_battle` + `player_team` aplica hp persistido | suíte verde + lint 0, commit `Passo 6:` |
| 7 | **Rota + UI:** `red` — `server_test.rb`: `POST /team/heal` cura + cobra saldo + `@notice` (curado/custo, saldo insuficiente, já curado), fragmento sem `<html>`; `team.erb` com bloco Poke Center (HP + botão). `green` — `TeamRoutes.register_heal` + `set :heal` + `team.erb` | suíte verde + lint 0, commit `Passo 7:` |
| 8 | **Docs:** `REQUIREMENTS.md` (roadmap 23 — Eco-2 executado na 0028), `SESSIONS.md` (tabela 0028 fase 2 + próxima sessão), `draft-arquitetura-design-patterns.md` (decisão 11 atendida), `draft-auto-battler.md` (Fase Eco — Eco-2 feita) | suíte verde + lint 0, commit `Passo 8:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar validação do usuário (fase 3). | |

## 7. Validação (executada pelo usuário)

_Pendente — aguardando o usuário após a fase 2._

## 8. Observações

- **Próxima sessão após 0028:** Fase Eco — **Eco-3 (Poke Mart)** — `Item`
  (Dry::Struct), catálogo estático, compra com dinheiro, `InventoryRepository`,
  fragmentos htmx. Eco-4 (itens em batalha) em seguida.
- **Balanceamento do `DEFAULT_COST_PER_HP`** (0.5) a validar com o usuário na fase
  3 — o custo do Center calibra os valores de moeda da Eco-1 (anotado desde 0027).
- **Reavivar diferenciado** (fainted com custo próprio) — fora de escopo; hoje
  fainted = HP `0` = mesmo custo proporcional.
- **Seed de saldo inicial** (validar o gasto sem batalhas) — segue pendente
  (anotado em 0027); reavaliar em Eco-3.
- **`spend`** passou a existir nesta sessão (débito anotado em 0027 como
  dependência do Eco-2); Eco-3 reutiliza para a compra do Poke Mart.
