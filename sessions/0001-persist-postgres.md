# Sessão 0001 — Persistir equipe em PostgreSQL (RNF-02)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída (aguardando aprovação) |
| Implementação | Pendente |
| Validação | Pendente |
| Sessão | Não iniciada |

---

## 1. Objetivo

Substituir a equipe em memória (`settings.team` em `server.rb`) por persistência em **PostgreSQL**, usando a gem `pg` (sem ORM). Conectar via `DATABASE_URL` e adicionar infraestrutura de testes (Minitest + rack-test) exigida pelo RNF-04.

## 2. Contexto (estado atual)

- `server.rb` guarda a equipe em `settings.team` (lista Ruby em memória):
  - `POST /team` adiciona via `PokeApi.find(params[:pokeName])`
  - `GET /team` **remove** um membro pelo índice `params[:index]`
- Modelo `Pokemon` (`lib/pokemon.rb`, `Dry::Struct`): `name`, `sprite`, `number`.
- `docker-compose.yml` já tem o serviço `db` (Postgres 16) e a gem `pg` no `Gemfile`.
- **Sem infraestrutura de testes** (`RNF-04`): não há `minitest`, `rack-test` nem diretório `test/`.
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