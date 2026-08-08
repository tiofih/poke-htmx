# Poke-HTMX — MANDATORY workflow rules

## Validação é do usuário — PARE na fase de validação

- A **fase de validação** (fase 3 do ciclo de cada sessão) é executada pelo **usuário**.
- Ao concluir a fase de **implementação (TDD, fase 2)** — todos os passos red→green→commit
  feitos e suíte/lint verdes — o agente **DEVE PARAR** e **aguardar o feedback do usuário**.
- **Não** marcar fases como `Concluída`/`Done` no arquivo da sessão, **não** atualizar
  `REQUIREMENTS.md`/`SESSIONS.md` com status de validação e **não** commitar a
  conclusão da sessão até o usuário validar explicitamente.
- Ao receber o feedback, registrar a validação no arquivo da sessão e só então
  atualizar `REQUIREMENTS.md`/`SESSIONS.md` e commitar a validação.

## Ideias, melhorias e escopos grandes — anotar, refinar depois

- Ideias, melhorias e escopos **grandes** identificados durante uma sessão (em qualquer
  fase) são **anotados** — no `REQUIREMENTS.md` (limitações/roadmap) ou na seção de
  observações do arquivo da sessão — mas **não** são refinados nem seguem o fluxo
  (novo arquivo de sessão + critérios de aceite + plano TDD) **enquanto a sessão atual
  não estiver concluída e validada**.
- A **regra da fase atual** continua valendo (RNF-04): nada de abrir novo escopo no meio
  de uma sessão; a anotação não bloqueia nem altera o fluxo corrente.
- Somente **após** a conclusão/validação da sessão corrente, a anotação pode virar uma
  **nova sessão** (refinamento → TDD → validação).

## Formato de commit (regra do projeto)

- **Idioma:** português (sem exigir acentuação no título).
- **Formato:** uma linha `Contexto: descrição concisa`. **Sem** prefixos
  genéricos (`feat:`, `fix:`, `chore:`). Descrever o que mudou e por quê
  (resultado), não "teste"/"implementação".
- **Corpo opcional:** linha em branco + bullets para detalhar decisões.

| Contexto | Quando usar | Exemplo |
| --- | --- | --- |
| `Passo N:` | green do passo TDD `N` | `Passo 1: TeamRepository#all via PostgreSQL (schema.sql + rake db:setup)` |
| `Passos N-M:` | green de passos agrupados | `Passos 3-4: testes de DELETE idempotente (id inexistente e ausente)` |
| `Sessao 00NN: refinamento concluido — ...` | refinamento (fase 1) fechado | `Sessao 0002: refinamento concluido — DELETE /team (RF-04), criterios e plano TDD fechados` |
| `Validacao sessao 00NN: ...` | validação do usuário (fase 3) | `Validacao sessao 0002: RF-04 Done, implementacao + criterios verificados, prox sessao 0003` |
| `Sessao 00NN concluida: ...` | sessão fechada | `Sessao 0001 concluida: RNF-02 e RF-03 Done, validacao integrada, proxima sessao 0002` |
| `Regra: ...` | mudança de convenção/regra | `Regra: validacao e feita pelo usuario — parar ao chegar na fase 3 e aguardar feedback` |
| `Atualizar progresso da sessão 00NN (...)` | checkpoint de progresso | `Atualizar progresso da sessão 0001 (passo 4 verde e validado)` |

---

# Projeto — índice rápido (leia na abertura de cada sessão)

## Comandos

Tudo roda **via `./scripts/*`** (usa o container `web` / sobe o `db`) — **não** rodar `rake`/`rubocop` no host.

| Comando | O que faz |
| --- | --- |
| `./scripts/test` | Suíte Minitest completa sem rede. Filtro por arquivo: `./scripts/test test/server_test.rb` (aceita vários). Por nome (regex): `./scripts/test -n /regex/` (ou `--name=`). |
| `./scripts/rake` | Rake genérico no container: sem args roda `test` (suíte total); com args passa adiante (`db:setup`, `lint`, `test TEST=...`). |
| `./scripts/lint` | RuboCop (mesmo fluxo docker). Objetivo: 0 offenses. |
| `./scripts/run` | `docker compose up --build` — sobe o app (porta 3000) para validação manual. |
| `rake db:setup` | Aplica `db/schema.sql` + `db/migrations/*.sql` em ordem (idempotente) — via `./scripts/rake db:setup`. |

## Mapa do código

| Caminho | Papel |
| --- | --- |
| `server.rb` | Rotas Sinatra + sessão: `enable :sessions` e `before { session[:user_id] \|\|= SecureRandom.uuid }`; helper `current_user`. Rotas: `GET /` (lista), `GET /pokemon?name=` (fragment add), `GET /team` (read-only, load inicial), `POST /team` (add), `DELETE /team` (remove). |
| `lib/team_repository.rb` | Tudo por usuário: `all(user_id)`, `add(user_id, pokemon)`, `remove(user_id, id)` com `WHERE user_id = $N`. |
| `lib/poke_api.rb` / `lib/pokemon.rb` | PokéAPI via Faraday (`.all`, `.find`) → `Pokemon` (Dry::Struct). Nunca em teste. |
| `db/schema.sql` + `db/migrations/*.sql` | Schema + migrações idempotentes; `rake db:setup` e `TestDatabase.setup!` aplicam ambos em ordem. |
| `views/index.erb` | Página única; `#pokemon`/`#team` são alvos htmx; `#team` tem `hx-get="/team" hx-trigger="load"`. |
| `views/pokemon.erb`, `views/team.erb` | Fragmentos htmx re-renderizados (`hx-swap="innerHTML"`). |
| `test/test_helper.rb` | `TestDatabase` (setup + `TRUNCATE`) e `PokeApiStub` (hoje só `with_find` — criar `with_all` se precisar). |
| `test/server_test.rb` | Rotas: injeta sessão via `user_session(user_id)`; isolamento com `Rack::Test::Session` próprios. |
| `test/team_repository_test.rb` | Persistência/isolamento por usuário. |

## Armadilhas conhecidas (lições da sessão 0003)

- **`session_secret`**: Sinatra 3.1 usa `Rack::Protection::EncryptedCookie` (AES-256-GCM) → valor **string hex ≥ 32 bytes**; string livre estoura com `ArgumentError: key must be 32 bytes`. Override p/ prod: `ENV["SESSION_SECRET"]`.
- **Sessão em teste**: injetar `"rack.session" => { "user_id" => "..." }` no env do request; vários navegadores = `Rack::Test::Session.new(Rack::MockSession.new(app))`.
- **Mudança de schema**: adicionar migração idempotente em `db/migrations/` (`ADD COLUMN IF NOT EXISTS` / `CREATE INDEX IF NOT EXISTS`); `rake db:setup`/`TestDatabase.setup!` já aplicam todas — não duplicar.
- **Sem rede em testes**: rotas que tocam `PokeApi` exigem stub (`PokeApiStub.with_find`).
- **RuboCop em testes**: seguir o padrão local (`# rubocop:disable Metrics/AbcSize, Metrics/MethodLength`; `Metrics/ClassLength` na classe) em vez de reestruturar.

---

# context-mode — MANDATORY routing rules

context-mode MCP tools available. Rules protect context window from flooding. One unrouted command dumps 56 KB into context.

## Think in Code — MANDATORY

Analyze/count/filter/compare/search/parse/transform data: **write code** via `context-mode_ctx_execute(language, code)`, `console.log()` only the answer. Do NOT read raw data into context. PROGRAM the analysis, not COMPUTE it. Pure JavaScript — Node.js built-ins only (`fs`, `path`, `child_process`). `try/catch`, handle `null`/`undefined`. One script replaces ten tool calls.

## BLOCKED — do NOT attempt

### curl / wget — BLOCKED
Shell `curl`/`wget` intercepted and blocked. Do NOT retry.
Use: `context-mode_ctx_fetch_and_index(url, source)` or `context-mode_ctx_execute(language: "javascript", code: "const r = await fetch(...)")`

### Inline HTTP — BLOCKED
`fetch('http`, `requests.get(`, `requests.post(`, `http.get(`, `http.request(` — intercepted. Do NOT retry.
Use: `context-mode_ctx_execute(language, code)` — only stdout enters context

### Direct web fetching — BLOCKED
Use: `context-mode_ctx_fetch_and_index(url, source)` then `context-mode_ctx_search(queries)`

## REDIRECTED — use sandbox

### Shell (>20 lines output)
Shell ONLY for: `git`, `mkdir`, `rm`, `mv`, `cd`, `ls`, `npm install`, `pip install`.
Otherwise: `context-mode_ctx_batch_execute(commands, queries)` or `context-mode_ctx_execute(language: "javascript", code: "...")`. Use `language: "shell"` only when code matches the host shell.

### File reading (for analysis)
Reading to **edit** → reading correct. Reading to **analyze/explore/summarize** → `context-mode_ctx_execute_file(path, language, code)`.

### grep / search (large results)
Use `context-mode_ctx_execute(language: "javascript", code: "...")` in sandbox for portable filtering/counting.

## Tool selection

0. **MEMORY**: `context-mode_ctx_search(sort: "timeline")` — after resume, check prior context before asking user.
1. **GATHER**: `context-mode_ctx_batch_execute(commands, queries)` — runs all commands, auto-indexes, returns search. ONE call replaces 30+. Each command: `{label: "header", command: "..."}`.
2. **FOLLOW-UP**: `context-mode_ctx_search(queries: ["q1", "q2", ...])` — all questions as array, ONE call (default relevance mode).
3. **PROCESSING**: `context-mode_ctx_execute(language, code)` | `context-mode_ctx_execute_file(path, language, code)` — sandbox, only stdout enters context.
4. **WEB**: `context-mode_ctx_fetch_and_index(url, source)` then `context-mode_ctx_search(queries)` — raw HTML never enters context.
5. **INDEX**: `context-mode_ctx_index(content, source)` — store in FTS5 for later search.

## Parallel I/O batches

For multi-URL fetches or multi-API calls, **always** include `concurrency: N` (1-8):

- `context-mode_ctx_batch_execute(commands: [3+ network commands], concurrency: 5)` — gh, curl, dig, docker inspect, multi-region cloud queries
- `context-mode_ctx_fetch_and_index(requests: [{url, source}, ...], concurrency: 5)` — multi-URL batch fetch

**Use concurrency 4-8** for I/O-bound work (network calls, API queries). **Keep concurrency 1** for CPU-bound (npm test, build, lint) or commands sharing state (ports, lock files, same-repo writes).

GitHub API rate-limit: cap at 4 for `gh` calls.

## Output

Write artifacts to FILES — never inline. Return: file path + 1-line description.
Descriptive source labels for `search(source: "label")`.

## Session Continuity

Skills, roles, and decisions persist for the entire session. Do not abandon them as the conversation grows.

## Memory

Session history is persistent and searchable. On resume, search BEFORE asking the user:

| Need | Command |
|------|---------|
| What did we decide? | `context-mode_ctx_search(queries: ["decision"], source: "decision", sort: "timeline")` |
| What constraints exist? | `context-mode_ctx_search(queries: ["constraint"], source: "constraint")` |

DO NOT ask "what were we working on?" — SEARCH FIRST.
If search returns 0 results, proceed as a fresh session.

## ctx commands

| Command | Action |
|---------|--------|
| `ctx stats` | Call `stats` MCP tool, display full output verbatim |
| `ctx doctor` | Call `doctor` MCP tool, run returned shell command, display as checklist |
| `ctx upgrade` | Call `upgrade` MCP tool, run returned shell command, display as checklist |
| `ctx purge` | Call `purge` MCP tool with confirm: true. Warns before wiping knowledge base. |

After /clear or /compact: knowledge base and session stats preserved. Use `ctx purge` to start fresh.
