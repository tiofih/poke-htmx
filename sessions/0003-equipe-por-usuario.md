# Sessão 0003 — Equipe por usuário (sessão/cookie)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída (validada em 2026-08-08) |
| Implementação | Concluída (TDD, validada em 2026-08-08) |
| Validação | Concluída (suíte + lint + critérios, validada em 2026-08-08) |

---

## 1. Objetivo

Tornar a equipe **por usuário**: cada navegador (sessão/cookie) passa a ter sua
própria equipe, isolada das demais. Hoje todas as requisições compartilham **uma**
tabela `team_pokemons` sem dono — `settings.team` é um `TeamRepository` global
(limitação "Estado global" de `REQUIREMENTS.md`). Com essa sessão, `POST /team` e
`DELETE /team` passam a persistir e buscar **apenas** os Pokémon do usuário
identificado pela sessão (cookie assinado `rack.session`, sem JS).

## 2. Contexto (estado atual)

- `server.rb` expõe `get "/">`, `get "/pokemon"`, `post "/team"`, `delete "/team"`;
  sem sessão habilitada e sem escopo de usuário.
- `TeamRepository` (`lib/team_repository.rb`) tem `all`, `add(pokemon)`,
  `remove(id)` — sem conceito de dono.
- `team_pokemons` (`db/schema.sql`): `id`, `name`, `sprite`, `number`, `created_at`.
- `views/team.erb` renderiza todos os registros da tabela (equipe global).
- Testes HTTP usam `PokeApiStub` (sem rede) e um único repositório no `setup`
  (`TestDatabase.setup!` recria schema; `clear_team!` limpa a tabela).
- Sessão 0002 validada; RNF-04 libera iniciar a 0003.

## 3. Critérios de aceite

- [x] `team_pokemons` ganha a coluna `user_id` (`TEXT NOT NULL`); `rake db:setup`
      aplica o schema e a migração; a migração **trunca** os registros antigos
      (dados atuais não têm usuário — decisão fechada).
- [x] `TeamRepository` opera por usuário: `all(user_id)`, `add(user_id, pokemon)`,
      `remove(user_id, id)` — filtra/insere/apaga sempre com `WHERE user_id = $X`.
- [x] **Isolamento:** o `POST /team` de um usuário não aparece na equipe de outro;
      `all(user_a)` nunca retorna Pokémon de `user_b` (e vice-versa).
- [x] **Remoção bloqueada por usuário:** `DELETE /team` só remove o membro do
      próprio usuário; `id` pertencente a outro usuário é tratado como idempotente
      (HTTP 200, equipe do usuário intacta, sem erro).
- [x] **Sessão:** servidor habilita `:sessions` (cookie assinado `rack.session`); um
      `user_id` é gerado no primeiro acesso e reutilizado nos demais; as rotas e a
      view `team.erb` usam o usuário da sessão corrente.
- [x] **Carregamento inicial (S1):** ao abrir com sessão existente, a equipe do
      usuário é carregada automaticamente via `GET /team` só-leitura no `#team`
      (`hx-trigger="load"`), sem depender de um novo POST/DELETE.
- [x] Suíte completa verde sem rede (`./scripts/test`), lint verde
      (`./scripts/lint`) e **commit a cada green** (RNF-04).
- [ ] `REQUIREMENTS.md` (novo RF da equipe por usuário + ponto de refinamento sobre
      estado global fechado) e `SESSIONS.md` (0003 em refinamento) atualizados no
      mesmo escopo.

## 4. Decisões de refinamento

- **Identidade:** sessão Sinatra (`enable :sessions`) com cookie assinado
  `rack.session`; `session[:user_id]` gerado com `SecureRandom.uuid` no primeiro
  acesso (via filtro `before`) e mantido nos demais. Nada de JS (RNF-01) — o cookie
  viaja em cada request do htmx automaticamente.
- **Secret:** `set :session_secret, ENV["SESSION_SECRET"] || "pokedex-dev-secret"`
  (fallback somente para dev; em produção via variável de ambiente).
- **Schema / migração:** `user_id TEXT NOT NULL` adicionado ao `schema.sql`;
  arquivo idempotente `db/migrations/0003_add_user_id.sql`
  (`TRUNCATE` + `ALTER TABLE ADD COLUMN IF NOT EXISTS` + `CREATE INDEX IF NOT EXISTS
  idx_team_pokemons_user_id`); `rake db:setup` passa a aplicar `db/migrations/*.sql`
  em ordem e `TestDatabase.setup!` idem (mesmo caminho de dev e testes).
- **Assinatura do repositório:** os três métodos recebem `user_id` como primeiro
  argumento; o `Pokemon` (Dry::Struct) não muda; a view continua renderizando via
  `#all`, agora do usuário da sessão.
- **Isolamento nos testes:** testes de repositório usam `user_id`s de controle
  ("user-a"/"user-b"); testes HTTP usam **dois `Rack::Test::Session`** (jars de
  cookie independentes — dois navegadores) para provar o isolamento; o 1º request de
  cada sessão gera/persistir o cookie (`SecureRandom.uuid`).
- **Sem re-criação do `GET /team` (depois da 0002, exceto uso read-only):** a
  renderização da equipe via respostas `POST/DELETE` (decisão da sessão 0002) foi
  preservada e complementada no **S1** por um `GET /team` **só-leitura** usado no
  carregamento inicial (`hx-trigger="load"` no `#team`) — sem reabrir a remoção
  ambígua por querystring (RF-04 segue intacto).
- **Sem ORM e sem infra nova:** gem `pg`, SQL puro, reutilização do
  `TeamRepository` existente, apenas com escopo por usuário.

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) |
| --- | --- | --- |
| 0 | `TeamRepository#all("user-b")` deixa de aceitar aridade antiga (testes atuais quebram); migração não aplicada → suíte red | `schema.sql` + `db/migrations/0003_add_user_id.sql` + Rake/`TestDatabase.setup!` aplicando migrações; assinatura dos métodos com `user_id` |
| 1 | `all(user_id)` não retorna pokémon de outro usuário (2 usuários, 2 pokémons) | `WHERE user_id = $1` em `all` |
| 2 | `add(user_id, pokemon)` persiste com o `user_id` (e `all` do mesmo usuário o retorna) | `INSERT ... (user_id, name, sprite, number)` |
| 3 | `remove(user_id, id)` só remove do próprio usuário; id de outro usuário permanece (mensagem) | `DELETE ... WHERE id = $1 AND user_id = $2` |
| 4 | Servidor gera cookie/sessão no 1º acesso; dois Rack::Test::Session isolados | `enable :sessions` + `before { session[:user_id] ||= SecureRandom.uuid }`; `settings` removido em favor do `session[:user_id]` |
| 5 | `POST /team` e `DELETE /team` operam no usuário da sessão (isolamento no HTTP) | rotas usam `session[:user_id]` → `settings.team` chamadas com escopo; `views/team.erb` renderiza `settings.team.all(user)` |
| 6 | Suíte completa + lint verdes; `REQUIREMENTS.md`/`SESSIONS.md` atualizados | Ajustes finais e documento |

## 6. Observações e próximo passo

- **Proveniente da 0002:** `GET /team` read-only reintroduzido no S1 apenas para o
  load inicial (equipe do usuário), mantendo a remoção somente via `DELETE /team`.
- **Ponto de refinamento do estado global:** com a 3, `REQUIREMENTS.md` marca o
  item "Estado efêmero e global" como resolvido só no que tange ao escopo de equipe
  (persistência por usuário); o tratamento de erros global segue em backlog.
- Próximo passo: **sessão 0004** — página de detalhes (tipos, stats, evoluções),
  ainda em backlog.

### Validação do refinamento (concluída em 2026-08-08)

- [x] Critérios de aceite fechados (seção 3) e decisões de design registradas (seção 4).
- [x] Plano TDD com 7 passos red/green definidos (seção 5).
- [x] `REQUIREMENTS.md` (RF-05 "Em refino", roadmap) e `SESSIONS.md` (0003 em refinamento, critérios fechados) atualizados no mesmo escopo.
- Próximo passo: **fase 2 (TDD)** — passo 0 (red): migração + assinaturas com `user_id`.

### Validação (concluída em 2026-08-08)

- **Suíte:** `./scripts/test` → 16 runs, 58 assertions, 0 failures, 0 errors (sem rede).
- **Lint:** `./scripts/lint` → 10 files inspected, no offenses detected.
- **Passos TDD:** 0 (schema/migração `0003_add_user_id.sql` + assinaturas `user_id`) →
  1–2 (isolamento em `all` + `add` persiste dono) → 3 (`remove` escopado
  `WHERE id AND user_id`) → 4 (sessão: `enable :sessions`, `session_secret`,
  `before { session[:user_id] ||= SecureRandom.uuid }`, `Rack::Test::Session`s
  isolados) → 5 (`DELETE` bloqueado por usuário no HTTP) → 6 (suíte/lint verdes).
  **S1 extra (avaliado como pequeno e incluído):** `GET /team` read-only +
  `hx-trigger="load"` no `#team` para carregar a equipe na abertura com sessão
  existente. Commits pós-green: `23b6319`, `5949fe7`, `5654b0c`, `77fdb93`,
  `2fbeb41`, `9b75b08`, `2b7fe3d`.
- **Critérios de aceite:** todos `[x]` na seção 3, verificados contra a implementação
  final.
- **Desvios do refinamento:**
  - `session_secret` dev-fallback virou **string hex de 32+ bytes**
    (`"706f…65"`, hex de `pokedex-dev-secret-0123456789abcdef`) porque o Sinatra 3.1
    usa `Rack::Protection::EncryptedCookie` (AES-256-GCM), que exige chave hex ≥ 32
    bytes — o secret curto quebrava com "key must be 32 bytes".
  - `remove` escopado por usuário: `DELETE ... WHERE id = $1 AND user_id = $2`
    (ID de outro usuário fica intacto — remoção bloqueada, como decidido no S1).
  - `GET /team` read-only reintroduzido (S1) — ver decisão atualizada acima.
- **Observação de TDD:** passos 2 e 5 ficaram verdes na 1ª execução (comportamento já
  garantido por passos anteriores); os testes foram adicionados para fixar/comprovar o
  comportamento, mesmo precedente da sessão 0002.