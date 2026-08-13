# Sessão 0026 — Histórico/rank de batalhas (D3)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluído — 2026-08-13 (tabela `battles` + `BattleRepository` + persistência no hook `:finished` + rank local/global + seed) |
| Implementação | Fase 2 concluída em 2026-08-13 — passos 1–7 verdes (suíte 367/1172, lint 0) |
| Validação | **Pendente — executada pelo usuário (fase 3)** |

---

## 1. Objetivo

Registrar o **resultado das batalhas** por usuário e expor um **histórico + ranking**
de vitórias na UI (D3 do `draft-auto-battler.md`, item 22 do roadmap; decisões 6/7/8
do `draft-arquitetura-design-patterns.md`):

- Nova tabela **`battles`** (`user_id`, `result`, `opponent_team` serializado, `created_at`).
- **`BattleRepository`** (padrão `TeamRepository`): persistir, listar recentes,
  estatísticas (vitórias/derrotas/empates) e **rank global** por vitórias.
- Persistir o resultado no **ponto mais atômico** — a transição `:finished` do
  `POST /battle/play` (mesmo hook que já concede XP/evolução, decisão 8).
- Página/endpoint **`GET /history`** com o histórico do usuário + rank **local e
  global** (decisão 7), 100% htmx (RNF-01).
- **Seed** de batalhas históricas prontas para acelerar a validação manual (regra
  de seeds — validação da 0024).

**Fora de escopo:** alterar `BattleRegistry` (a batalha em andamento continua em
memória — ver decisões), monetizar/Eco, remover `opponent_team` por limpeza de dados
antigos, paginação do histórico (lista enxuta nesta entrega).

## 2. Contexto (estado atual — pós-0025)

- Suíte base **337 runs/1086 asserts**, lint 0 (seeds, 2026-08-10).
- `BattleEngine#result` → `:win` / `:draw` / `:lose` (ou `nil` antes de terminar);
  `BattleRegistry` (`set :battles`) guarda a batalha corrente por `user_id`.
- Transição `:finished` acontece em `advance_battle` (`server.rb:232-236`): lá são
  concedidos XP (`grant_finished_xp`), evolução/aprendizado e `rebuild_display_team`.
- `TeamRepository` (PG direto, `exec_params`, padrão `connection` memoizada) é o
  molde dos repositórios; `ProgressionRepository` idem para projeções pequenas.
- Migrações idempotentes em `db/migrations/*.sql` aplicadas por `rake db:setup` e
  `TestDatabase.setup!` (a última é `0023_add_team_pokemon_progress.sql`).
- Seeds: `SeedTeam` (insert direto) + scripts em `db/seeds/` + `rake db:seed` +
  `./scripts/seed` (sessão 0025); helper `?as=` troca `session[:user_id]`.
- Testes sem rede: `PokeApiStub.with_gateway` genérico; batalhas de rota usam
  `stub_battle_start` (stubs `all_names`/`type`/`detail`/`moves_for`) + `N.times do
  post "/battle/play"` até terminar.

## 3. Arquitetura

### Migração `db/migrations/0026_add_battles.sql` (idempotente, sem truncate)

```sql
CREATE TABLE IF NOT EXISTS battles (
  id SERIAL PRIMARY KEY,
  user_id TEXT NOT NULL,
  result TEXT NOT NULL,          -- 'win' | 'draw' | 'lose'
  opponent_team JSONB NOT NULL,  -- serialização do oponente: [{number:, name:}]
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS battles_user_created_idx
  ON battles (user_id, created_at DESC);
```

### `lib/battle_repository.rb` — `BattleRepository`

Espelha `TeamRepository` (PG direto, `connection` memoizada, `DEFAULT_DATABASE_URL`):

- `add(user_id, result, opponent_team)` — insere linha com `result` string
  (`win/draw/lose`) e `opponent_team` serializado em JSONB (`to_json`); `created_at`
  vie o default do banco.
- `recent(user_id, limit: DEFAULT_LIMIT = 10)` — registros do usuário em ordem
  `created_at DESC, id DESC`, limitado; deserializa `opponent_team` (`JSON.parse`);
  sem batalhas → `[]`.
- `stats(user_id)` → `{ wins:, losses:, draws:, total: }` (contagem por `result`).
- `ranking(limit: 10)` → top usuários **com ≥ 1 batalha**, ordenados por vitórias
  DESC, desempate total DESC, depois `user_id` ASC (determinístico):
  `{ user_id:, wins:, total: }`.
- `rank_position(user_id)` → posição 1-based no rank global **por vitórias**
  (1 + nº de usuários com ≥ 1 batalha e mais vitórias); sem batalhas → `nil`.

### Persistência no ponto mais atômico (decisão 8)

- `server.rb`: `set :battle_history, BattleRepository.new` (+ require).
- No `advance_battle`, **dentro da transição `:finished` já existente**
  (`was_in_progress && @engine.finished?`), após `grant_finished_xp`:
  `record_finished_battle` persiste **uma única vez**:
  `settings.battle_history.add(current_user, @engine.result.to_s,
  serialize_opponent(@engine.teams[1]))`.
- `serialize_opponent` → `team.map { |bp| { number: bp.number, name: bp.name } }`.
- **`BattleRegistry` NÃO é removido** — ele segue guardando a batalha **em
  andamento** entre requests (necessário para múltiplos `play`). O que o D3 resolve
  é o estado **efêmero do resultado**: o resultado passa a ser persistido no hook
  `:finished` (o ponto mais atômico, menor toque — decisões 8 do draft).

### Rota + UI (100% htmx)

- `GET /history` → fragmento `views/history.erb` (`layout: false`, sem `<html>`):
  - **Rank global:** top N (10) usuários por vitórias, posição + vitórias/total;
    destaque (`current`) para o usuário da sessão.
  - **Rank local:** vitórias/derrotas/empates do usuário + **posição global**.
  - **Histórico recente:** últimas batalhas do usuário — data formatada, resultado
    (Vitória/Derrota/Empate) e nomes do oponente serializado.
  - Time vazio sem batalhas → mensagem amigável ("Você ainda não batalhou.").
- `GET /history/close` → fragmento vazio (padrão `/battle/close`).
- `index.erb` ganha `<div id="history"> </div>`; `layout.erb` ganha link "Histórico"
  (`hx-get="/history"` no alvo `#history`).

### Seed (regra de seeds — validação da 0024)

- `db/seeds/batalhas_historico.rb` → `BatalhasHistorico.call(user_id: "seed-history",
  db_url:)`: popula `battles` com ~8 registros de resultados variados (win/lose/draw)
  e `opponent_team` hardcoded (`[{number:, name:}]`), via `BattleRepository#add`
  (após limpar as batalhas do `user_id`).
- `Rakefile`: `db:seed` roda `BatalhasHistorico` por default (user_id `seed-history`)
  e aceita `SEED=batalhas_historico` (padrão 0025).

### Testes — novos helpers

- `TestDatabase.clear_battles!` (TRUNCATE `battles`) e `battles`, `battles_user_count`
  incluídos no isolamento: `clear_team!` passa a truncar também `battles` (evita
  acúmulo entre testes de rota que terminam batalhas). Nome do método preservado
  (sem tocar nos arquivos que já o usam).

## 4. Critérios de aceite

### Migração / schema

- [ ] `0026_add_battles.sql` idempotente cria `battles` (`id`, `user_id TEXT NOT NULL`,
      `result TEXT NOT NULL`, `opponent_team JSONB NOT NULL`, `created_at` default
      `now()`) + índice `(user_id, created_at DESC)`.
- [ ] `TestDatabase.clear_battles!` limpa `battles`; `clear_team!` preserva nome mas
      passa a truncar `battles` também.

### `BattleRepository`

- [ ] `add(user_id, result, opponent_team)` persiste `result` (`win/draw/lose`) e o
      oponente serializado; round-trip `recent` devolve `opponent_team` idêntico ao
      array de `{number:, name:}` enviado; `created_at` preenchido pelo banco.
- [ ] `recent(user_id, limit:)` — ordem `created_at DESC, id DESC`, respeita o
      `limit` (default 10), só do `user_id` (isolamento RF-05); sem batalhas → `[]`.
- [ ] `stats(user_id)` → `{ wins:, losses:, draws:, total: }` só do usuário;
      sem batalhas → zeros.
- [ ] `ranking(limit:)` — top por vitórias DESC (desempate total DESC, `user_id`
      ASC), só usuários com ≥ 1 batalha; `ranking.empty?` quando não há batalhas.
- [ ] `rank_position(user_id)` — 1-based por vitórias no rank global; sem batalhas → `nil`.

### Persistência na batalha (server)

- [ ] `POST /battle/play` que termina a batalha persiste **uma única** linha em
      `battles` (resultado `win/draw/lose` correto + oponente serializado) — na
      transição `:finished`; plays posteriores não duplicam.
- [ ] Batalha em andamento (`:finished?` falso) **não** persiste registro.
- [ ] `BattleRegistry` permanece para a batalha em andamento (0 regressão);
      resultado passa a ser persistido no hook `:finished`.

### Rota / UI

- [ ] `GET /history` renderiza `history.erb` (`layout: false`, sem `<html>`) com:
      top rank global (posição + vitórias/total, destaque do usuário), rank local
      (vitórias/derrotas/empates + posição global) e recente (data, resultado,
      nomes do oponente); usuário sem batalhas → mensagem amigável.
- [ ] `index.erb` ganha `<div id="history">`; `layout.erb` ganha link "Histórico"
      (`hx-get="/history"` alvo `#history`, padrão nav).
- [ ] `GET /history/close` devolve fragmento vazio (padrão `/battle/close`);
      link "Lista" limpa `#battle` (comportamento atual preservado) e
      `#history` via `/history/close` ao sair da aba Histórico.
- [ ] Sem JS customizado (RNF-01); testes de rota sem rede (rota não toca PokéAPI;
      usa `BattleRepository` real + `TestDatabase`).

### Seed

- [ ] `db/seeds/batalhas_historico.rb` popula `battles` para o `user_id` da seed com
      resultados variados e oponente hardcoded; `rake db:seed` roda por default
      (user_id `seed-history`) e aceita `SEED=batalhas_historico` (padrão 0025).

### Garantias (RNF)

- [ ] Suíte completa verde (baseline 337/1086 preservado + novos) e lint 0; commit
      por green; 0 regressão RF-01..RF-18/D2-A/D2-B/0025.
- [ ] Sem novas gems; sem dependência da PokéAPI nas rotas novas; sem
      `rubocop:disable` (padrão orçamentos).
- [ ] `REQUIREMENTS.md` (roadmap item 22 — D3 executado na 0026), `SESSIONS.md`
      (tabela 0026 em fase 2 + próxima sessão), `draft-auto-battler.md` (D3 feita),
      `draft-arquitetura-design-patterns.md` (decisões 6/7/8 atendidas) atualizados
      no mesmo escopo.

## 5. Decisões de refinamento

- **`result` como string** (`win/draw/lose`) na tabela — bate com
  `BattleEngine#result.to_s`; sem CHECK constraint neste escopo (validação é do
  `RewardRule`/engine).
- **`opponent_team` JSONB** com `[{number:, name:}]` — só o necessário para exibir
  o histórico; **não** serializa stats/moves/HP (estado final da batalha fica no
  log efêmero do engine).
- **Ponto mais atômico = hook `:finished`** — mesmo local onde XP/evolução são
  concedidos (decisão 8: menor toque, sem tocar o `BattleRegistry` da batalha em
  andamento). `BattleRegistry` segue em memória para múltiplos `play`.
- **Rank global = vitórias** (não pontos) — decisão 7 do draft ("ranking de
  vitórias"); empate desempatado por total de batalhas, depois `user_id` ASC
  (determinístico).
- **`history.erb` fragmento próprio** com alvo `#history` (div nova) — não conflita
  com o painel `#battle`.
- **Clearing:** `GET /history/close` segue o padrão `/battle/close`; o link "Lista"
  passa a limpar também `#history` (consistência com RF-14).
- **Seed via `BattleRepository#add`** (não SQL direto) — a seed exercita o mesmo
  caminho de produção; dados de oponente hardcoded (sem PokéAPI).
- **`clear_team!` passa a truncar `battles`** — isola os testes de rota que terminam
  batalhas sem renomear o método (evita tocar nos arquivos que já o usam).
- **Nome do índice** `battles_user_created_idx` — padrão de nomes do projeto
  (`idx_` no `TestDatabase.index_exists`; manter `battles_user_created_idx`).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `Sessao 0026: refinamento concluido — D3 historico/rank de batalhas (tabela battles, BattleRepository, persistencia no hook :finished, rank local/global, seed), criterios e plano TDD fechados` |
| 1 | **Migração + helpers:** `red` — `schema_test.rb` falha (tabela `battles` inexistente): existe com colunas NOT NULL (`user_id`, `result`, `opponent_team`) + índice `battles_user_created_idx`; `TestDatabase.clear_battles!` limpa. `green` — migração `0026_add_battles.sql` + helpers | suíte verde + lint 0, commit `Passo 1:` |
| 2 | **`BattleRepository#add` + `#recent`:** `red` — `battle_repository_test.rb` novo: `add` persiste `result` + `opponent_team` com round-trip idêntico e `created_at` preenchido; `recent` ordena desc, respeita limit, isola por usuário, `[]` sem batalhas. `green` — `lib/battle_repository.rb` | suíte verde + lint 0, commit `Passo 2:` |
| 3 | **`stats` + `ranking` + `rank_position`:** `red` — stats por resultado e isolado; ranking por vitórias desc (desempate total/user_id), só ≥ 1 batalha; posição 1-based por vitórias; `nil` sem batalhas. `green` — métodos no repositório | suíte verde + lint 0, commit `Passo 3:` |
| 4 | **Persistência no `:finished`:** `red` — `server_test.rb`: batalha terminada via `stub_battle_start` + `N.times play` persiste 1 linha em `battles` (resultado + oponente serializado); plays extras não duplicam; batalha em andamento não persiste. `green` — `set :battle_history` + hook no `advance_battle` | suíte verde + lint 0, commit `Passo 4:` |
| 5 | **Rota + UI do histórico:** `red` — `GET /history` renderiza fragmento (sem `<html>`) com rank global/local + recente + destaque do usuário; sem batalhas → mensagem; `GET /history/close` vazio; `index.erb` com `#history` e `layout.erb` com link "Histórico"; link "Lista" limpa `#history`. `green` — `history.erb` + rotas `HistoryRoutes` | suíte verde + lint 0, commit `Passo 5:` |
| 6 | **Seed:** `red` — `seed_scripts_test.rb`: `BatalhasHistorico` popula `battles` para o `user_id` (resultados variados, oponente serializado); `rake db:seed` roda por default e aceita `SEED=batalhas_historico`. `green` — `db/seeds/batalhas_historico.rb` + Rakefile | suíte verde + lint 0, commit `Passo 6:` |
| 7 | **Docs:** `REQUIREMENTS.md` (roadmap 22 — D3 executado), `SESSIONS.md` (tabela 0026 fase 2), `draft-auto-battler.md` (D3 feita), `draft-arquitetura-design-patterns.md` (decisões 6/7/8 atendidas) | suíte verde + lint 0, commit `Passo 7:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar validação do usuário (fase 3). | |

## 7. Validação (executada pelo usuário)

Pendente — a ser preenchida após a implementação (fase 2) e o feedback do usuário.

**Roteiro sugerido de validação manual (com seeds):**
- `./scripts/seed` → abrir o app com `?as=seed-history`: `GET /history` mostra rank
  global (top com vitórias) + rank local (posição, vitórias/derrotas/empates) +
  recente com data/resultado/oponente.
- Batalhar de um usuário comum até `:finished` → histórico passa a listar a batalha;
  novo confronto não duplica registros.
- Navegar Lista/Time/Batalha/Histórico — htmx troca os fragmentos; sair do Histórico
  limpa o painel.

## 8. Observações

- **Próxima sessão após 0026:** Fase Eco — **Eco-1 (moeda pós-batalha)** (roadmap
  item 23): `RewardRule` passa a conceder **XP + dinheiro** no hook `:finished` —
  mesmo ponto atômico agora persistido por D3.
- O `BattleRegistry` (batalha em andamento) permanece em memória — se mais adiante
  quisermos resultado/estado persistente pós-`:finished`, o D3 já deixa o hook pronto.
- `opponent_team` guarda só nomes/números; exibir sprites no histórico (se quiser)
  seria um ajuste de serialização — anotado, sem abrir escopo.