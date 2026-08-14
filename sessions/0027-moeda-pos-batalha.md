# Sessão 0027 — Moeda pós-batalha (Eco-1)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluído — 2026-08-14 (tabela `wallet` + `RewardRule#money_for` + `WalletRepository` + grant no hook `:finished` + aviso de moeda no `battle.erb`)** |
| Implementação | Pendente |
| Validação | Pendente — executada pelo usuário |

---

## 1. Objetivo

Criar a **economia pós-batalha** (Eco-1 do `draft-arquitetura-design-patterns.md`,
item 23 do roadmap; decisão 10 — moeda ao final da batalha como um todo) no **mesmo
ponto atômico onde XP/evolução/histórico já são concedidos e persistidos**:

- Nova tabela **`wallet`** — saldo de moeda por usuário (1 linha por `user_id`).
- **`RewardRule` passa a conceder XP + dinheiro** no hook `:finished`
  (`money_for(result)` ao lado de `xp_for` — um só ponto de recompensa).
- **`WalletRepository`** (padrão `BattleRepository`/`TeamRepository`):
  `balance(user_id)` e `grant(user_id, amount)` (upsert idempotente).
- **Hook no `POST /battle/play`**: na transição `:finished`, conceder a moeda
  **uma única vez** (ao lado do `grant_finished_xp`); `battle.erb` exibe o
  dinheiro ganho ao lado do XP.
- **Sem rota/UI dedicada** (saldo é exibido no fragmento da batalha terminada;
  gasto — Poke Center/Mart — é escopo das sessões Eco-2/3).

**Fora de escopo (RNF-04 — anotar, não refinar agora):** `spend`/débito do saldo
(chega com Eco-2/3), UI de saldo permanente (ex.: navbar), seed de saldo inicial
(ver Observações), itens/poções (Eco-3/4), balanceamento dos valores de moeda
(ver Decisões).

## 2. Contexto (estado atual — pós-0026)

- Suíte base **367 runs/1172 asserts**, lint 0 (D3, 2026-08-13).
- `RewardRule` (`lib/reward_rule.rb`, sessão 0023): constantes `DEFAULT_WIN_XP 50 /
  DRAW 25 / LOSE 20` e `xp_for(result)` (injetáveis); doc de que Eco-1 reaproveita
  o mesmo gancho para moeda.
- Transição `:finished` concentra toda a recompensa em `advance_battle`
  (`server.rb:228-243`): `record_finished_battle` (D3), `grant_finished_xp` (D2-A),
  `apply_evolution_and_learning` (D2-B), `rebuild_display_team` (D2-B). Guard de
  transição `was_in_progress && @engine.finished?` garante execução única.
- `settings` no `configure` (`server.rb:472-486`): `team`, `progression`, `battles`
  (registry), `battle_history`, `api`.
- Repositórios PG direto com `connection` memoizada e `DEFAULT_DATABASE_URL`
  (molde: `BattleRepository`/`ProgressionRepository`); sem ORM.
- Migrações idempotentes em `db/migrations/*.sql` (última: `0026_add_battles.sql`);
  aplicadas por `rake db:setup` e `TestDatabase.setup!`.
- `TestDatabase` (`test/test_helper.rb`): `clear_team!` truncate em cascata
  (`team_pokemons, team_pokemon_progress, battles`), `table_column_info`/
  `table_exists?`/`index_exists` para testes de schema.
- `battle.erb` já exibe `@xp_gained` quando `:finished` ("Seu Time ganhou X XP por
  Pokémon.") — o aviso de moeda entra ao lado.
- Testes sem rede: `PokeApiStub.with_gateway` genérico; `stub_battle_start` +
  `N.times post "/battle/play"` até `:finished`.

## 3. Arquitetura

### Migração `db/migrations/0027_add_wallet.sql` (idempotente, sem truncate)

```sql
CREATE TABLE IF NOT EXISTS wallet (
  user_id TEXT PRIMARY KEY,          -- 1 linha por usuário (RF-05)
  balance INTEGER NOT NULL DEFAULT 0,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

- Sem `TRUNCATE`/backfill; `user_id` como PK garante unicidade natural (saldo é
  agregação por usuário — não precisa de `SERIAL` nem índice extra).
- `rake db:setup`/`TestDatabase.setup!` aplicam automaticamente (ordem por glob).

### `lib/reward_rule.rb` — `RewardRule#money_for`

- Novas constantes injetáveis: `DEFAULT_WIN_MONEY = 100`, `DEFAULT_DRAW_MONEY = 50`,
  `DEFAULT_LOSE_MONEY = 40` (valores iniciam o circuito fechado batalha → dinheiro;
  ajustáveis na validação — decisão aberta de balanceamento).
- `initialize` ganha `win_money:`, `draw_money:`, `lose_money:` (defaults acima).
- `money_for(result)` espelha `xp_for`: `:win/:draw/:lose` → valores; `else → 0`.
- Contrato atual preservado (`xp_for`/**`initialize` antigo sem quebra** — keywords
  adicionais, sem mudança de posicional).

### `lib/wallet_repository.rb` — `WalletRepository`

Espelha `BattleRepository` (PG direto, `connection` memoizada, `DEFAULT_DATABASE_URL`):

- `balance(user_id)` — `SELECT balance FROM wallet WHERE user_id = $1`; linha
  ausente → `0` (sem criar registro).
- `grant(user_id, amount)` — **upsert atômico**: `INSERT ... (user_id, balance)
  VALUES ($1, $2) ON CONFLICT (user_id) DO UPDATE SET balance = wallet.balance +
  EXCLUDED.balance, updated_at = now()`; retorna o **novo saldo**; `amount` nulo
  ou `<= 0` → no-op (`balance` atual). Idempotente por construção (soma, não seta).

### Hook no `:finished` (`server.rb`)

- `configure`: `set :wallet, WalletRepository.new` (+ require).
- `advance_battle`, dentro da transição `:finished` já existente, ao lado de
  `grant_finished_xp`: `grant_finished_money` →
  `settings.wallet.grant(current_user, RewardRule.new.money_for(@engine.result))`
  — **uma concessão por batalha** (moeda é do usuário, não por Pokémon).
- `@money_gained = RewardRule.new.money_for(@engine.result) if @engine.finished?`
  (ao lado do `@xp_gained` existente) para a view.
- `battle.erb`: no bloco final (alvo do `@xp_gained`), exibir o saldo ganho —
  "Seu Time ganhou X XP por Pokémon" + " e Y de dinheiro." (fragmento único, sem
  `<html>`; sem JS custom — RNF-01).

### Testes

- `TestDatabase` ganha `clear_wallet!`; `clear_team!` passa a truncar também
  `wallet` (testes de rota que terminam batalha concedem moeda — isolamento igual
  ao de `battles` na 0026). Nome do método preservado.
- `server_test_helpers.rb`: `@wallet = WalletRepository.new` (padrão `@battle_history`).
- Novos `test/wallet_repository_test.rb` (persistência), ampliação do
  `test/reward_rule_test.rb` (`money_for`), `test/schema_test.rb` (tabela `wallet`),
  `test/server_test.rb` (grant no `:finished`, uma única vez; sem grant antes do fim).

## 4. Critérios de aceite

### Migração / schema

- [ ] `0027_add_wallet.sql` idempotente cria `wallet` com `user_id TEXT PRIMARY KEY`,
      `balance INTEGER NOT NULL DEFAULT 0` e `updated_at` (default `now()`);
      re-executar não quebra.
- [ ] `TestDatabase.clear_wallet!` limpa `wallet`; `clear_team!` preserva o nome mas
      passa a truncar `wallet` também.

### `RewardRule`

- [ ] `money_for(:win)` → `DEFAULT_WIN_MONEY (100)`, `money_for(:draw)` → 50,
      `money_for(:lose)` → 40; resultado desconhecido/nil → `0`.
- [ ] Valores injetáveis no construtor (`win_money:`/`draw_money:`/`lose_money:`);
      `xp_for` e demais contatos atuais preservados (0 regressão XP).

### `WalletRepository`

- [ ] `balance(user_id)` → saldo atual; usuário sem linha → `0` (sem criar registro).
- [ ] `grant(user_id, amount)` soma ao saldo via upsert e **retorna o novo saldo**
      (ex.: `grant(u, 100)` → 100; `grant(u, 50)` → 150); `amount` nulo/`<= 0` →
      no-op (saldo inalterado).
- [ ] Isolamento RF-05: saldo de um `user_id` não afeta o de outro.

### Hook / UI

- [ ] `POST /battle/play` que termina a batalha (`:finished`) concede a moeda do
      `RewardRule` para o `current_user` **uma única vez** (guard de transição);
      plays posteriores não duplicam o grant.
- [ ] Batalha **em andamento** não concede moeda.
- [ ] `battle.erb` no fim da batalha exibe o dinheiro ganho ao lado do XP
      ("... e Y de dinheiro"), fragmento sem `<html>`, sem JS custom (RNF-01).
- [ ] Time vazio/oponente vazio mantém o comportamento amigável atual (0 regressão).

### Garantias (RNF)

- [ ] Suíte completa verde (baseline 367/1172 preservado + novos) e lint 0; commit
      por green; 0 regressão RF-01..RF-18/D2/D3/0025/0026.
- [ ] Sem novas gems; sem dependência da PokéAPI nas rotas tocadas; sem
      `rubocop:disable` (padrão orçamentos).
- [ ] `REQUIREMENTS.md` (roadmap item 23 — Eco-1 executado na 0027), `SESSIONS.md`
      (tabela 0027 em fase 2 + próxima sessão), `draft-arquitetura-design-patterns.md`
      (decisão 10 atendida) e `draft-auto-battler.md` (Fase Eco — Eco-1 feita)
      atualizados no mesmo escopo.

## 5. Decisões de refinamento

- **Tabela `wallet` (1 linha por usuário) em vez de coluna em `team_pokemons`** —
  saldo é agregação **por usuário**, não por Pokémon (decisão 10: "moeda ao final
  da batalha como um todo"); espelha `battles` (D3) e prepara `inventory` (Eco-3).
- **`user_id` como PRIMARY KEY** — unicidade natural do agregado; sem `SERIAL`/
  índice extra; `ON CONFLICT (user_id)` como upsert atômico (sem select-then-update).
- **Coeda concedida 1× por batalha (não 1× por Pokémon)** — diferente do XP (que é
  por membro); o saldo é do usuário e a moeda premia o resultado da batalha.
- **Moeda entra no mesmo hook `:finished`** de XP/evolução/histórico (decisão 8/10:
  um só ponto atômico concede tudo — "homem do gancho", sem duplicar lógica de grant).
- **`RewardRule#money_for` ao lado de `xp_for`** (seções 6/6.1 do draft): a política
  de recompensa agrega XP + moeda; `initialize` injetável com keywords novas
  (sem quebrar o contrato posicional).
- **Valores iniciais win 100 / draw 50 / lose 40** — arbitrários (iniciam o circuito
  fechado batalha → dinheiro → gastar); **decisão aberta de balanceamento** a validar
  com o usuário na fase 3 (o custo do Poke Center/Mart, Eco-2/3, calibrará o valor).
- **Sem rota/UI de saldo nesta entrega** — exibir saldo permanente/navbar entra junto
  do gasto (Eco-2/3); por ora o saldo é visível via fragmento de batalha e
  `balance(user_id)`.
- **`clear_team!` passa a truncar `wallet`** — mesmo padrão da 0026 com `battles`
  (testes de rota que terminam batalha concedem moeda); nome preservado.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `Sessao 0027: refinamento concluido — Eco-1 moeda pos-batalha (tabela wallet, RewardRule#money_for, WalletRepository, grant no hook :finished + aviso no battle.erb), criterios e plano TDD fechados` |
| 1 | **Migração + helpers:** `red` — `schema_test.rb` falha (tabela `wallet` inexistente/colunas); `TestDatabase.clear_wallet!` limpa e `clear_team!` trunca `wallet`. `green` — migração `0027_add_wallet.sql` + helpers | suíte verde + lint 0, commit `Passo 1:` |
| 2 | **`RewardRule#money_for`:** `red` — `reward_rule_test.rb`: defaults win 100/draw 50/lose 40, zero p/ desconhecido, injetável; `xp_for` intacto. `green` — `lib/reward_rule.rb` | suíte verde + lint 0, commit `Passo 2:` |
| 3 | **`WalletRepository`:** `red` — `wallet_repository_test.rb` novo: `balance` (0 sem linha, sem criar registro), `grant` upsert soma + retorna saldo, no-op p/ nulo/<=0, isolamento por usuário. `green` — `lib/wallet_repository.rb` | suíte verde + lint 0, commit `Passo 3:` |
| 4 | **Hook + UI:** `red` — `server_test.rb`: batalha terminada via `stub_battle_start` + `N.times play` concede moeda 1× (saldo = `money_for(result)`), plays extras não somam; batalha em andamento não concede; fim exibe "... e Y de dinheiro." no fragmento. `green` — `set :wallet` + `grant_finished_money` no `advance_battle` + `@money_gained`/`battle.erb` | suíte verde + lint 0, commit `Passo 4:` |
| 5 | **Docs:** `REQUIREMENTS.md` (roadmap 23 — Eco-1 executado na 0027), `SESSIONS.md` (tabela 0027 fase 2 + próxima sessão), `draft-arquitetura-design-patterns.md` (decisão 10 atendida), `draft-auto-battler.md` (Fase Eco — Eco-1 feita) | suíte verde + lint 0, commit `Passo 5:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar validação do usuário (fase 3). | |

## 7. Validação (executada pelo usuário)

Em aberto — será preenchida pelo usuário na fase 3 (fase 2 concluída: suíte + lint
verdes; parada obrigatória antes da validação — regra AGENTS.md).

**Roteiro sugerido de validação manual:**
- Batalhar até `:finished` → fragmento mostra "Seu Time ganhou X XP por Pokémon
  e Y de dinheiro."
- Repetir confronto → novo grant soma ao saldo acumulado (sem duplicação por
  batalha já encerrada).
- Conferir valores win/draw/lose (decisão de balanceamento — ajustar `money_for`
  se quiser).
- `./scripts/test` + `./scripts/lint` verdes.

## 8. Observações

- **Próxima sessão após 0027:** Fase Eco — **Eco-2 (Poke Center)** — `HealService` +
  `HealCostPolicy` proporcional ao HP faltante (decisão 11), rota htmx
  `POST /team/heal` + fragmento, cobrança do saldo (usa `spend` — que Eco-2 traz).
- Centro/Poke Mart/itens em batalha (Eco-3/4) seguem **fora do escopo** desta sessão
  (RNF-04 — anotados, não refinados agora).
- **Pensar sobre seed de saldo** (ex.: `saldo_inicial` para validar o gasto sem
  batalhas): não entrou nesta entrega (sem rota/UI de saldo para exibir); avaliar
  quando Eco-2 (gasto) existir.
- `spend`/débito do saldo será preciso no Eco-2 (Poke Center) — anotado; `grant`
  (ganho) é o único débito/operação desta sessão.