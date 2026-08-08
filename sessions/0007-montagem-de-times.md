# Sessão 0007 — Montagem de times (cap 6 + slots + sem duplicados) — fundação do auto-battler

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída — decisões fechadas com o usuário em 2026-08-08 |
| Implementação | Concluída — passos 0–9 verdes (56 runs/257 asserts, lint 0 offenses) |
| Validação | Concluída — validado pelo usuário em 2026-08-08 |

---

## 1. Objetivo

Preparar a **montagem de times** como base de um futuro **auto-battler** (o game loop
será um escopo futuro). Hoje `team_pokemons` é uma lista **sem limite, sem posição
explícita e com duplicados** (ordenada pelo `id` de inserção). A sessão 0007 entrega
a estrutura que o game loop vai consumir: **time limitado a 6, com `slot` de posição
(1..6) persistido e sem duplicados por usuário**.

## 2. Contexto (estado atual)

- `team_pokemons`: `id, user_id, name, sprite, number, created_at`. `TeamRepository#all`
  ordena por `id` (ordem de inserção); `add` e `remove` sem validação de limite/duplicado.
- `POST /team` (`server.rb:68`) devolve sempre o fragmento `#team` (200), mesmo com
  time cheio ou Pokémon repetido.
- `views/team.erb` renderiza a lista de membros; o slot não existe.
- `Pokemon` (Dry::Struct) não conhece slot — o slot é atributo de *equipe*.
- Migração precedente (0003) seguiu o padrão `ADD COLUMN IF NOT EXISTS` + `TRUNCATE`
  para limpar dados dev antigos — mesmo padrão será adotado aqui.

## 3. Critérios de aceite

### Regras de montagem (domínio)

- [x] `team_pokemons` ganha **`slot INTEGER NOT NULL`** (posição 1..N, N ≤ 6), com
      migração idempotente em `db/migrations/0007_add_slot.sql`.
- [x] **Slide de unicidade:** `UNIQUE (user_id, number)` impede Pokémon repetido no
      time de um usuário; `UNIQUE (user_id, slot)` garante posições distintas.
      (Índices únicos via `CREATE UNIQUE INDEX IF NOT EXISTS`.)
- [x] `TeamRepository` ganha `MAX_TEAM_SIZE = 6`.
- [x] **Cap 6:** ao adicionar com time já com 6, `TeamRepository#add` **não insere** e
      sinaliza erro de time cheio (`TeamFullError`).
- [x] **Sem duplicados:** ao adicionar Pokémon cujo `number` já existe no time do
      usuário, `#add` não insere e sinaliza `DuplicateError`.
- [x] **Slots contíguos:** `#add` preenche o próximo slot livre (1..N, sempre 1..6);
      `#remove` **recompacta** — ao remover o slot `k`, os slots `> k` descem uma casa
      (time sempre ocupa 1..N sem lacunas).
- [x] **Ordenação:** `TeamRepository#all(user_id)` retorna membros **ordenados por slot**.

### Camada web (htmx, RNF-01)

- [x] `POST /team` bloqueado (time cheio ou duplicado) responde **200** com o fragmento
      `#team` contendo uma **mensagem de aviso** (ex.: "Time cheio (máx. 6)." /
      "<nome> já está no time.") — e **não duplica** o registro.
- [x] `POST /team` com sucesso segue devolvendo o fragmento `#team` com o novo membro;
      `GET /team` e `DELETE /team` (RF-04/RF-05) sem regressão.
- [x] O fragmento `#team` torna visível a **posição (slot)** de cada membro (ex.: badge
      `#3`), na ordem de slot — insumo visual da montagem.

### Garantias (RNF)

- [x] Testes sem rede (stub: `PokeApiStub.with_find`), suíte completa verde
      (`./scripts/test`) e lint verde (`./scripts/lint`), commit a cada green (RNF-04).
- [x] Sem regressão: RF-01..RF-06 seguem verdes (detalhe, paginação/filtro, equipe por
      usuário, remove idempotente, isolamento por sessão).
- [x] `REQUIREMENTS.md` (novo **RF-07 — Montagem de times**) e `SESSIONS.md` (0007
      concluída) atualizados no mesmo escopo.

## 4. Decisões de refinamento

- **Slot como coluna própria:** `slot INTEGER NOT NULL` em `team_pokemons` (posição
  de batalha). O rodapé do game loop futuro lê `ORDER BY slot` — ordem de ação.
- **Duplicado = mesmo `number` da PokéAPI** (id da API, mais estável que o nome).
- **`TRUNCATE` em dados antigos:** dados dev históricos não têm slot/unicidade; a
  migração trunca (mesmo padrão da 0003) antes de criar os índices únicos.
- **Schema atualizado junto:** `db/schema.sql` registra a forma final da tabela
  (`slot` incluso); testes rodam `schema.sql` + migrations (idempotente).
- **Erro domínio via exceção:** `TeamRepository::TeamFullError` e `TeamRepository`
  `::DuplicateError`; a rota rescata e re-renderiza o fragmento com aviso — mantém o
  contrato htmx (200 + `#team`), sem depender de `responseHandling`.
- **Aviso dentro do fragmento `#team`** (decisão do usuário 2026-08-08): não usar
  HTTP 409/422.
- **Compactação agora, lacunas adiadas** (decisão do usuário): remover reindexa para
  slots contíguos; "manter lacunas (sem reindex)" fica anotado como fase futura.
- **Reordenação manual é fase futura:** posicionar um Pokémon em slot arbitrário
  (mover/quem pra onde) sai do escopo desta sessão.
- **Game loop / ideias de auto-battler:** apenas anotadas no `REQUIREMENTS.md`
  (roadmap/limitações) — NÃO são refinadas agora (RNF-04: escopo grande só vira
  sessão após a atual ser validada).
- **UI: layout e estilos externo:** a antiga "0007 — UI" sai do topo do backlog
  (fica como 0008 ou posterior); a 0007 passa a ser montagem de times.

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) |
| --- | --- | --- |
| 0 | Tabela `team_pokemons` tem coluna `slot` (NOT NULL) e índices únicos `(user_id, number)` e `(user_id, slot)` após `TestDatabase.setup!`; idempotente (2ª aplicação não quebra) | `db/schema.sql` + `db/migrations/0007_add_slot.sql` |
| 1 | `Pokemon` aceita `slot` (default `nil`; preencher com valor é ok) | `lib/pokemon.rb`: `attribute :slot, ...` |
| 2 | `#add` atribui slots 1,2,3 na ordem de inserção e `#all` retorna ordenado por slot; Pokémon persistido tem `slot` preenchido | `lib/team_repository.rb`: `all` com `ORDER BY slot`, `add` calcula próximo slot |
| 3 | 6 adições ok; a 7ª levanta `TeamFullError` e **não insere** (tabela com 6) | `TeamRepository::MAX_TEAM_SIZE` + raise `TeamFullError` em `#add` |
| 4 | adicionar Pokémon com `number` já no time levanta `DuplicateError` e não insere | checagem `EXISTS (number)` por usuário + raise `DuplicateError` |
| 5 | `#remove` recompacta: time [A,B,C] slots 1,2,3; remove B → [A,C] slots 1,2; adicionar novo → slot 3 | `#remove` apaga e `UPDATE ... SET slot = slot - 1 WHERE slot > k` (por usuário) |
| 6 | isolamento: slots resetam por usuário (user-b tem slots independentes de user-a) | sem mudança (código anterior) — teste documental |
| 7 | `POST /team` com time cheio → 200, fragmento contém "Time cheio (máx. 6).", time segue 6 e **sem duplicação**; com duplicado → 200 com "<nome> já está no time" | `server.rb` `post "/team"` rescata erros e passa `@notice` → `views/team.erb` exibe aviso |
| 8 | fragmento `#team` mostra o slot (ex.: "#1") e membros em ordem de slot (GET /team e após POST/DELETE); sem regressão em remove idempotente | `views/team.erb` + sem regressão | 
| 9 | suíte completa verde + lint 0 offenses | checagem global |
| 10 | `REQUIREMENTS.md` (RF-07 + roadmap + anotações auto-battler) e `SESSIONS.md` (0007 em refinamento) atualizados | documento |

## 6. Observações e próximo passo

- O `number` da PokéAPI vira a "identidade" do Pokémon no time (unicidade + exibição).
- Após esta sessão o game loop (turno/combate) poderá ler `all(user_id)` já ordenado
  por slot — nenhuma migração de dados será necessária para iniciar combates.
- Ideias de auto-battler e a antiga sessão UI foram para `REQUIREMENTS.md`
  (roadmap/limitações) — não estarão nesta sessão.

## 7. Validação (2026-08-08)

- Suíte completa: **56 runs / 257 assertions, 0 failures/0 errors**; lint **0 offenses**.
- Critérios de aceite **todos verificados** pelo usuário (comportamento do time
  limitado a 6, sem duplicados, slots contíguos e avisos no fragmento);
  **RF-07 Done**.
- Próxima sessão: **0008** — candidatos anotados no draft/Roadmap (reordenação de
  slots A1 e/ou game loop B1; UI/layout volta ao backlog).