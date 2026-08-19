# Sessão 0033 — Respiro 2: extrair `BattleService`/`TeamService` + split de `server_test.rb` por área

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída (commit `dba4dbd`, 2026-08-19) |
| Implementação | Concluída (passos 1–4, suíte 559/1696, lint 0, commits `ef4341a`/`e0d1ca6`/`c2c4a5e`) |
| Validação | Concluída — **executada pelo usuário em 2026-08-19** (fase 3) |

---

## 1. Objetivo

**Respiro de arquitetura pós-Eco** (anotado em 2026-08-18 — ver `draft-arquitetura-design-patterns.md`,
seção "Respiro 2026-08-18", e `draft-auto-battler.md`, item 1 da ordem fechada): aplicar o
**molde da sessão 0020** à retomada de crescimento de `server.rb` e `test/server_test.rb` —
**sem mudança de comportamento**:

1. **Produção:** extrair **`BattleService`** e **`TeamService`** (Application Services — use cases,
   molde de `lib/heal_service.rb`/`lib/mart_service.rb`) absorvendo a orquestração dos handlers de
   `server.rb`, e remover os **3 `# rubocop:disable`** de `server.rb`.
2. **Testes:** dividir **`test/server_test.rb`** (1925 linhas) por **área** em arquivos
   `*_test.rb` próprios.

**Baseline** (sessão 0032, validada em 2026-08-18): suíte **559 runs / 1696 asserts**, lint 0.

## 2. Contexto (estado atual — diagnóstico)

| Arquivo | Linhas | Problema | Disables |
| --- | --- | --- | --- |
| `server.rb` | 723 | 6 módulos de ações com orquestração inline; `ServerBattleActions` retomou crescimento; handlers gordos | **3**: `:283` `Metrics/ModuleLength` (`ServerBattleActions`); `:373` `Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength, Metrics/PerceivedComplexity` (`advance_battle`); `:435` `Metrics/AbcSize, Metrics/MethodLength` (`rebuild_display_team`) |
| `test/server_test.rb` | 1925 | 10 classes de rota + módulo helper (`ServerBattleTestHelpers`) em arquivo único; orçamento `ClassLength` 500 em `test/.rubocop.yml` | 0 (métrica ativa via orçamento) |

**Causas-raiz (inspecionadas):**

- **`advance_battle`** (`server.rb:373`) orquestra: engine da registry → `play_round` → débito de
  itens → (no `:finished`) recordar batalha + XP + moeda + evolução/aprendizado + rebuild do display
  + persistir HP → `@xp_gained`/`@money_gained` → `HX-Trigger` → render. 6+ responsabilidades.
- **`rebuild_display_team`** (`:435`): reconstrói o display (fighter atualizado por slot após
  evolução) e chama `replace_team_a` — ciclo com tamanho variável → `AbcSize`/`MethodLength`.
- **`ServerBattleActions`** (`:283`): acumula prepare + play + efeitos de `:finished`
  (23 métodos) → `ModuleLength`.
- **`server_test.rb`**: um arquivo único para Teams (3 classes), Detail, List, Battle (3 classes),
  History e Mart + helpers.
- **Duplicação no time:** `team_manage_data` e `team_member_for_item` definidos **2× cada**
  (`ServerTeamItemActions` `:204`/`:209` e `ServerTeamHeldActions` `:250`/`:255`), e `moves_for_team`
  (`:102`) puxado daqui e dali — contaminam a montagem de dados da tela de gerenciamento.

**O molde já existe:** `HealService`/`MartService` (PORO, deps no construtor, método de use case,
hash de resultado com `notice`) fiados via `set :heal, ...`/`set :mart, ...` no `configure`.

## 3. Escopo

### Produção — `BattleService` (`lib/battle_service.rb`)

- **Use cases:**
  - `prepare(user_id)` → `BattleEngine` ou `nil`: monta o time do jogador (`player_team` com moves/
    nível/HP persistido/`assigned_item`/`held_item`), o oponente (`opponent_team` via `OpponentGenerator`
    com `rng` por usuário), `TypeEffectiveness.load(api)` e o estoque de itens; **registra na `battles`
    registry** quando monta.
  - `advance(user_id)` → hash `{ engine:, xp_gained:, money_gained:, evolution_news:, learned_news: }`:
    `play_round` + débito de itens usados + efeitos de `:finished` (record, XP, moeda, evolução/
    aprendizado, rebuild do display, persistir HP).
- **Deps injetadas (construtor):** `api`, `battles`, `team`, `progression`, `battle_history`,
  `wallet`, `inventory`.
- **Métodos que migram de `ServerBattleActions` para privados do service:** `playable_engine`,
  `player_team`, `battle_fighter_from`, `apply_persisted_hp`, `member_level`, `opponent_team`,
  `inventory_stock`, `debit_used_items`, `record_finished_battle`, `grant_finished_xp`,
  `grant_finished_money`, `apply_evolution_and_learning`, `rebuild_display_team`,
  `persist_finished_hp`, `save_fighter_hp`, `evolve_member`, `evolution_target`, `try_evolve`,
  `learn_moves_for_member`, `try_learn`; **`battle_moves_for`** (hoje em `ServerCommon`) também migra
  (só é usado em contexto de batalha).
- **Handlers viram thin:** `render_battle_fragment` = `@engine = settings.battle.prepare(current_user)`
  → nil → fragmento vazio/erro, senão render; `advance_battle` (rota `/battle/play`) = recebe o hash
  do service, seta ivars (`@engine`/`@xp_gained`/`@money_gained`/`@evolution_news`/`@learned_news`) +
  `HX-Trigger` → `erb :battle`.

### Produção — `TeamService` (`lib/team_service.rb`)

- **Use cases:**
  - `manage_data(user_id)` → hash `{ members:, available_moves:, inventory:, balance: }`: consolida
    `team_manage_data` (dup) + `moves_for_team` + `mart_data`.
  - `save_moves(user_id, member_id, selected)` → valida `MAX_MOVES_PER_POKEMON` + nomes disponíveis;
    `team.set_moves`; devolve `notice` (nil se ok) — absorve `apply_move_selection`/`move_choice_error`.
  - `assign_item(user_id, member, item_name)` e `assign_held_item(user_id, member, item_name)` →
    limpam com vazio/nil; validam catálogo (`heal_amount`/`category == "held"` + posse no inventário);
    devolvem `notice` — absorvem `assign_*`/`clear_*`/`team_member_for_item` (dup).
- **Deps injetadas:** `api`, `team`, `inventory`, `wallet`, `catalog: ItemCatalog`.
- **Handlers thin:** `save_team_moves`/`save_team_item`/`save_team_held_item`/`render_team_manage`
  montam os dados via service e renderizam.

### Testes — split de `test/server_test.rb` por área

| Novo arquivo | Classes movidas | ~Linhas |
| --- | --- | --- |
| `test/team_routes_test.rb` | `ServerTeamTest` | 494 |
| `test/team_strategy_routes_test.rb` | `ServerTeamItemTest` + `ServerTeamHeldItemTest` | 192 |
| `test/pokemon_routes_test.rb` | `ServerDetailTest` + `ServerListTest` | 240 |
| `test/battle_routes_test.rb` | `ServerBattleTest` | 570 |
| `test/battle_strategy_routes_test.rb` | `ServerBattleItemTest` + `ServerBattleHeldItemTest` | 96 |
| `test/history_routes_test.rb` | `ServerHistoryTest` | 65 |
| `test/mart_routes_test.rb` | `ServerMartTest` | 64 |

- `ServerBattleTestHelpers` (usado pelas 3 classes de batalha) → **`test/battle_test_helpers.rb`**
  (não casa com `*_test.rb`, não entra na suíte como teste).
- `ServerTestHelpers` permanece em `server_test_helpers.rb`.
- `server_test.rb` é **removido** após mover tudo (0 perda de teste).
- O Rakefile já descobre `test/**/*_test.rb`; cada novo arquivo faz o `require_relative` correto.

## 4. Critérios de aceite

### Resultado

- [x] **Nenhum `# rubocop:disable`/`enable` restante** em `server.rb`
      (`grep 'rubocop:' server.rb` → 0 ocorrências).
- [x] `./scripts/lint` → **0 offenses** com as **métricas padrão do root** (`.rubocop.yml`);
      **nenhum orçamento novo** de produção.
- [x] `./scripts/test` → **suíte completa verde com o mesmo tamanho de cobertura**
      (baseline **559 runs/1696 asserts**): nenhum teste removido, renomeado ou adicionado; o split
      apenas **move classes de arquivo**.
- [x] 0 regressão de comportamento — rotas/domínio/schema intactos (a suíte existente é a rede de
      segurança; nada de novo a escrever nesta sessão).

### Estrutura — produção

- [x] `lib/battle_service.rb` — `BattleService` PORO com `prepare(user_id)` e `advance(user_id)`
      (molde HealService/MartService); concentra toda a orquestração hoje em `ServerBattleActions`
      (prepare + play + efeitos de `:finished` + rebuild do display); os 3 `rubocop:disable` de
      `server.rb` deixam de existir.
- [x] `lib/team_service.rb` — `TeamService` PORO com `manage_data`/`save_moves`/`assign_item`/
      `assign_held_item`; elimina as duplicações `team_manage_data`/`team_member_for_item`/
      `moves_for_team`; handlers de time/estratégia thin.
- [x] `server.rb` — `configure` ganha `set :battle, BattleService.new(...)` e
      `set :team_strategy, TeamService.new(...)` com as **mesmas instâncias de `settings`**;
      `battle_moves_for` deixa o `ServerCommon`; contrato de rotas **idêntico** (mesmos paths,
      `layout: false`, fragmentos, alvos htmx, `@notice`/`@message`, `HX-Trigger`).

### Estrutura — testes

- [x] `test/server_test.rb` fatiado por área nos 7 arquivos da tabela do escopo;
      `ServerBattleTestHelpers` em `test/battle_test_helpers.rb`; `server_test.rb` removido;
      cada arquivo com os `require_relative` corretos.
- [x] `test/.rubocop.yml` inalterado (orçamentos continuam somente para `test/`).

### Garantias (RNF)

- [x] Commit obrigatório a cada passo verde (lint 0 + suíte completa verde).
- [x] Sem novas gems, sem mudança de schema/rotas/contrato público.
- [ ] `draft-auto-battler.md` (anotação "Respiro 2" → marcada como feita), `SESSIONS.md` (0033
      registrada + próxima sessão **D1 parcial — nível de aprendizado**) e `REQUIREMENTS.md`
      (roadmap item 25 — Respiro 2 marcado como 1º da ordem) atualizados no mesmo escopo; sessão
      registrada como concluída **só após a validação do usuário**.

## 5. Decisões de refinamento

- **Tipo de sessão:** respiro de arquitetura (produção + testes), molde 0020 — não gera RF novo em
  `REQUIREMENTS.md`; comportamento continua o dos RF-01..RF-18/Eco (0 regressão).
- **Definição de `red` nesta sessão:** remover um `# rubocop:disable` de `server.rb` e ver o lint
  acusar offense(s) reais (métrica) — esse é o "teste que falha". **`green`:** extrair o método/
  módulo/service/área até **lint 0 + suíte completa verde** → **commit**. Não há teste novo a
  escrever: a suíte existente é a rede de segurança (mesma mecânica da 0020).
- **Fronteira service × handler:** toda a orquestração vai para os services; o handler só faz
  sessão → chamada ao service → ivars → `erb`. `current_user`/`session` continuam no handler
  (services são POROs stateless que recebem `user_id` por parâmetro).
- **Instâncias compartilhadas obrigatórias:** os services recebem as **mesmas instâncias** de
  `settings` — em especial `settings.battles` (`BattleRegistry` guarda estado em memória por
  `user_id`; instância nova quebraria `GET /battle` → `POST /battle/play`).
- **Nomes dos setters:** `set :battle` (BattleService) e `set :team_strategy` (TeamService — não
  colidir com o `set :team` que é o `TeamRepository`).
- **`battle_moves_for` migra** do `ServerCommon` para privado do `BattleService` (só aparece em
  contexto de batalha — `roadmap` confirmado por grep: usado apenas em `player_team`/`opponent_team`).
- **`average_player_level`** (`server.rb:358`, método privado sem chamadores) é **preservado** como
  privado do `BattleService` (0 mudança de comportamento nesta sessão); candidato a remoção anotado
  nas observações.
- **Ordem sugerida (cada passo termina com lint 0 + suíte verde + commit):** `BattleService` (resolve
  os **3 disables de uma vez**, todos em `ServerBattleActions`) → `TeamService` (dedup + thin
  handlers) → split de `server_test.rb` (organizacional) → docs + verificação final.
- **Contrato público intocado:** assinaturas públicas, rotas, paths, fragmentos, `@notice`/
  `@message`/`HX-Trigger` e respostas não mudam — se no meio de um passo algum arquivo exigir mudança
  de contrato público ou refactor estrutural grosso, a parte afetada **vira sessão própria**
  (critério do draft para "1 fase ou mais") e o passo corrente para no estado verde.

## 6. Plano TDD (passos)

> Cada passo = "red" (remover disable → lint acusa) → "green" (extrair service/método/área →
> lint 0 + suíte completa verde) → commit. Nenhum fluxo novo de teste na fase de produção; o split
> de testes apenas move classes.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo de sessão com critérios e plano fechados | commit `Sessao 0033: refinamento concluido — Respiro 2 (BattleService/TeamService + split server_test.rb), criterios e plano fechados` |
| 1 | **`BattleService`:** criar `lib/battle_service.rb` (`prepare`/`advance` + privados). `red` — remover os 3 disables de `server.rb` (`:283`/`:373`/`:435`) → lint acusa. `green` — extrair toda a orquestração de `ServerBattleActions` para o service; handlers thin (`render_battle_fragment`/`advance_battle`); `set :battle` no `configure`; mover `battle_moves_for` | lint 0 + suíte completa verde (559/1696), commit |
| 2 | **`TeamService`:** criar `lib/team_service.rb` (`manage_data`/`save_moves`/`assign_item`/`assign_held_item`). Extração pura (sem disable a remover): refatorar em fatias pequenas mantendo a suíte verde a cada fatia (a suíte é a rede de segurança — qualquer divergência de comportamento na dedup do `team_manage_data`/`moves_for_team` é pega pelos testes); `green` ao finalizar — extratir os use cases, handlers thin e `set :team_strategy` | lint 0 + suíte completa verde, commit |
| 3 | **Split `test/server_test.rb`** por área (7 arquivos) + `ServerBattleTestHelpers` → `test/battle_test_helpers.rb`; `server_test.rb` removido. `red` — arquivo atual removido (suíte quebra: classes não carregadas); `green` — novos arquivos com os mesmos testes | suíte completa verde **559/1696** + lint 0, commit |
| 4 | **Verificação final + docs:** `grep 'rubocop:' server.rb` → 0; suíte completa + lint 0; atualizar `REQUIREMENTS.md` (roadmap item 25 — Respiro 2 marcado como 1º executado), `SESSIONS.md` (0033 + próxima sessão D1 parcial) e `draft-auto-battler.md` (anotação "Respiro 2" → feito) | suíte verde + lint 0 + docs, commit |

## 7. Validação (executada pelo usuário)

> **Validado pelo usuário em 2026-08-19** (fase 3).

- [x] Suíte completa verde (**559 runs/1696 asserts**, 0 failures/errors — baseline preservado).
- [x] Lint RuboCop: **0 offenses** (métricas padrão do root).
- [x] `grep 'rubocop:' server.rb` → **0 ocorrências** (nenhum disable de produção).
- [x] Nenhum comportamento alterado: rotas/domínio/schema intactos; `test/server_test.rb` fatiado
      sem perda de testes (mesmos IDs de teste em novos arquivos).
- [x] `server.rb` funcionando em dev (`./scripts/run` + navegação Lista/Time/Batalha/Mart/Histórico).

## 8. Observações

- Sessão de **respiro de arquitetura** (decisão do usuário em 2026-08-18), 1ª da ordem fechada no
  roadmap (item 25 de `REQUIREMENTS.md`); não abre escopo novo no meio (RNF-04). Após a validação, a
  próxima sessão é **D1 parcial — nível de aprendizado de golpes**.
- **`average_player_level`**: método privado morto em `server.rb` (só a definição existe, sem
  chamadores) — preservado no `BattleService` nesta sessão; anotado como candidato a remoção em um
  respiro futuro.
- A suíte é a rede de segurança da extração: nenhum teste novo em produção; o split de `test/` só
  **move** classes (runs/asserts idênticos).
- Atenção ao split: `ServerBattleTestHelpers`/`ServerTestHelpers`/stubs são compartilhados entre os
  novos arquivos — cada um precisa do `require_relative` correto para não repetir duplicação nem
  perder o setup (`TestDatabase.setup!`/`clear_team!`).
- No passo 1, como os 3 disables vivem no **mesmo módulo** (`ServerBattleActions`) e o `BattleService`
  absorve tudo, a remoção é feita de uma vez no mesmo `red` → `green`.