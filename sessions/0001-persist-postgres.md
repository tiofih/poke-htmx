# Sessão 0001 — Persistir equipe em PostgreSQL (RNF-02)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída (validada em 2026-08-07) |
| Implementação | Em andamento (passos 0–1 verdes) |
| Validação | Em andamento (passos 0–1 validados — suíte verde) |
| Sessão | Em andamento (próximo: passo 2) |

---

## 1. Objetivo

Substituir a equipe em memória (`settings.team` em `server.rb`) por persistência em **PostgreSQL**, usando a gem `pg` (sem ORM). Conectar via `DATABASE_URL` e adicionar infraestrutura de testes (Minitest + rack-test) exigida pelo RNF-04.

## 2. Contexto (estado atual)

- `server.rb` guarda a equipe em `settings.team` (lista Ruby em memória):
  - `POST /team` adiciona via `PokeApi.find(params[:pokeName])`
  - `GET /team` **remove** um membro pelo índice `params[:index]`
- Modelo `Pokemon` (`lib/pokemon.rb`, `Dry::Struct`): `name`, `sprite`, `number`.
- `docker-compose.yml` já tem o serviço `db` (Postgres 16) e a gem `pg` no `Gemfile`.
- **Infra de testes já criada nesta sprint**: gems `minitest`, `rack-test`, `rake`; `Rakefile` com `rake test`/`rake lint`; `.rubocop.yml`; `test/test_helper.rb` ainda a escrever.
- **Scripts docker**: `scripts/run`, `scripts/test`, `scripts/lint` (usam o container `web` de pé ou one-off).
- As rotas chamam `PokeApi.find` no meio do request (depende de rede) — precisa ser substituível no teste.

## 3. Critérios de aceite (referencia RF-01/RF-04 e RNF-02)

- [ ] `POST /team` com `pokeName=pikachu` persiste o registro no Postgres (presente após a requisição).
- [ ] A equipe **sobrevive** a um restart do servidor (não fica mais em memória).
- [ ] As rotas existentes (listar/visualizar/adicionar/remover) continuam funcionando sem regressão.
- [ ] Conexão usa `DATABASE_URL` (ex.: `postgres://pokedex:pokedex@db:5432/pokedex`).
- [ ] Tabela `team_pokemons` criada via `rake db:setup`.
- [ ] Infra de testes: gems `minitest` + `rack-test` + `rake`, `test/` com `test_helper.rb`, tarefa `rake test`.
- [ ] Testes não dependem de rede: `PokeApi.find` substituível no teste (stub/DI).
- [ ] Commit a cada `green`.
- [ ] `REQUIREMENTS.md`/`SESSIONS.md` atualizados no mesmo escopo.

## 4. Decisões de refinamento

- **Sem ORM:** acesso ao Postgres com a gem `pg` e SQL puro.
- **Chave:** `team_pokemons.id` (serial) como identificador — base para a remoção semântica futura (`DELETE /team/:id`).
- **Infra:** serviço `db` Postgres 16 já no `docker-compose.yml`, credenciais `pokedex/pokedex`, banco `pokedex`.
- **Arquitetura:** nova classe `TeamRepository` em `lib/` isolando a atualização do banco das rotas do Sinatra (injeção via `settings`, sobrescrevível no teste).
- **Schema:** arquivo `db/schema.sql` + tarefa `rake db:setup` para criar a tabela (sem auto-criar no boot).
- **Testes:** `minitest` + `rack-test` + `rake` no `Gemfile`; `PokeApi.find` stubável nos testes HTTP.

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) |
| --- | --- | --- |
| 0 | Infra de testes (sem teste ainda) | Adicionar gems + `test/test_helper.rb` + tarefa `rake test` |
| 1 | Banco vazio: `TeamRepository#all` retorna `[]` | Conexão `pg` via `DATABASE_URL` (`db/schema.sql` + `rake db:setup`) |
| 2 | `TeamRepository#add(pokemon)` persiste e `all` o retorna | `INSERT` em `team_pokemons` |
| 3 | `TeamRepository#remove(id)` remove do banco | `DELETE ... WHERE id = $1` |
| 4 | Rotas usam `TeamRepository` (teste HTTP, `PokeApi.find` stubado) | Integrar repositório no `server.rb` via `settings` |
| 5 | `POST /team` grava o dado no banco de teste | Rodar suíte integrada completa |

## 6. Validação (Fase 3)

Preencher após a implementação:

- [ ] Suíte completa verde (Minitest)
- [ ] Critérios de aceite verificados (itens 1–6 acima)
- [ ] Resultados/manutenção registrados

## 7. Observações e próximo passo

- Ao concluir: marcar `RNF-02` como `Done` no `REQUIREMENTS.md`.
- `SESSIONS.md`: marcar 0001 como concluída, apontar **sessão 0002** (remoção semântica).

### Progresso da implementação

- **Passo 0** (infra de testes) — `test/test_helper.rb` + `test/smoke_test.rb` (commit `456c4da`).
- **Passo 1** (banco vazio: `TeamRepository#all` retorna `[]`) — green: `lib/team_repository.rb`, `db/schema.sql`, `rake db:setup`, `test/team_repository_test.rb` (commit `e666b57`). Tabela `team_pokemons` aplicada em `dev` e teste.
- **Passo 2** (`TeamRepository#add(pokemon)` persiste e `all` retorna `Pokemon`) — green: `INSERT` em `team_pokemons` e `all` mapeando para `Pokemon` (commit `1fb23e9`).
- **Próximo:** passo 3 — `TeamRepository#remove(id)` remove do banco (`DELETE ... WHERE id = $1`) — só inicia com a validação do passo 2 concluída (regra de sequência RNF-04).

### Validação dos passos 0–2 (atualizada em 2026-08-07)

- [x] Suíte completa verde (Minitest): via `./scripts/test`.
- [x] Lint verde: `./scripts/lint` sem ofensas.
- [x] `rake db:setup` idempotente — tabela `team_pokemons` presente em `dev` e teste.
- [x] Passo 2 validado: `add` persiste (INSERT com parâmetros $1–$3) e `all` mapeia linhas para `Pokemon`; suite `3 runs, 0 errors`.
- [x] Critérios de aceite do escopo entregue verificados: infra de testes (item 7) e `DATABASE_URL` + schema via `rake db:setup` (itens 4–6).
- [x] Pendente (passos 3–5): remoção por id, rotas no repositório, teste HTTP integrado — critérios 1–3 da seção 3.

### Validação do refinamento (concluída em 2026-08-07)

- [x] Critérios de aceite da sessão fechados (seção 3).
- [x] Decisões de design registradas (seção 4).
- [x] Plano TDD com passos red/green definidos (seção 5).
- [x] Infra de testes montada: `minitest`/`rack-test`/`rake` no `Gemfile`, `Rakefile` com `rake test`/`rake lint`, `scripts/test`, `scripts/lint` e docker `web` no ar (commit `e7b3f2a`).
- [x] `REQUIREMENTS.md` e `SESSIONS.md` atualizados no mesmo escopo (regra RNF-04).