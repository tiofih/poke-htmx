# Sessão 0001 — Persistir equipe em PostgreSQL (RNF-02)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Em andamento |
| Implementação | Pendente |
| Validação | Pendente |
| Sessão | Não iniciada |

---

## 1. Objetivo

Substituir a equipe em memória (`settings.team` em `server.rb`) por persistência em **PostgreSQL**, usando a gem `pg` (sem ORM). Adicionar o serviço `db` no `docker-compose.yml` e conectar via `DATABASE_URL`.

## 2. Contexto (estado atual)

- `server.rb` guarda a equipe em `settings.team` (lista Ruby em memória):
  - `POST /team` adiciona via `PokeApi.find(params[:pokeName])`
  - `GET /team` **remove** um membro pelo índice `params[:index]`
- Modelo `Pokemon` (`lib/pokemon.rb`, `Dry::Struct`): `name`, `sprite`, `number`.
- Não há banco de dados; não há gem `pg` no `Gemfile`.
- `docker-compose.yml` só tem o serviço `web`.

## 3. Critérios de aceite (referencia RF-01/RF-04 e RNF-02)

- [ ] `POST /team` com `pokeName=pikachu` persiste o registro no Postgres (dado presente após a requisição).
- [ ] A equipe **sobrevive** a um restart do servidor (não fica mais em memória).
- [ ] As rotas existentes (listar/visualizar/adicionar/remover) continuam funcionando sem regressão.
- [ ] Conexão usa `DATABASE_URL` (ex.: `postgres://pokedex:pokedex@db:5432/pokedex`).
- [ ] Tabela `team_pokemons` criada automaticamente ao subir a aplicação.
- [ ] Commit automático a cada `green`.

## 4. Decisões de refinamento

- **Sem ORM:** acesso ao Postgres com a gem `pg` e SQL puro.
- **Chave:** `team_pokemons.id` (serial) como identificador — base para a remoção semântica futura (`DELETE /team/:id`).
- **Infra:** serviço `db` Postgres 16 no `docker-compose.yml`, credenciais `pokedex/pokedex`, banco `pokedex`.
- **Arquitetura:** nova classe `TeamRepository` em `lib/` isolando T atualização de banco das rotas do Sinatra.

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) |
| --- | --- | --- |
| 1 | Banco vazio: `TeamRepository#all` retorna `[]` | Conexão `pg` via `DATABASE_URL` + `SELECT` |
| 2 | `TeamRepository#add(pokemon)` persiste e `all` o retorna | `INSERT` em `team_pokemons` |
| 3 | `TeamRepository#remove(id)` remove do banco | `DELETE ... WHERE id = $1` |
| 4 | Rotas usam repositório (teste HTTP Sinatra) | Integrar `TeamRepository` no `server.rb` |
| 5 | `POST /team` grava o dado no banco de teste | Rodar suíte integrada com `post /` |

## 6. Validação (Fase 3)

Preencher após a implementação:

- [ ] Suíte completa verde (Minitest)
- [ ] Critérios de aceite verificados (itens 1–6 acima)
- [ ] Resultados/manutenção registrados

## 7. Observações e próximo passo

- Ao concluir: marcar `RNF-02` como `Done` no `REQUIREMENTS.md`.
- `SESSIONS.md`: marcar 0001 como concluída, apontar **sessão 0002** (remoção semântica).