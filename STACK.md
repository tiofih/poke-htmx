# STACK.md — especialização por área (Poke-HTMX)

Os agentes genéricos `frontend` e `backend` leem este arquivo para se especializar.
Stacks futuras (love2d, godot, tmod) ganham um arquivo igual no próprio repo.

## Frontend (`htmx`)

- **Paths:** `views/`, `public/` (só). Nunca `lib/`, `server.rb`, `db/`.
- **Stack:** ERB + CSS sobre base sakura (CDN), **sem JavaScript próprio**; fragmentos via `hx-get/post/delete`, modais `:target`, juice em keyframes.
- **Tokens/componentes:** `DESIGN.md` (canônico); produto/voz em `PRODUCT.md`.
- **Verificar:** `./scripts/test` (contratos de markup quando houver) + chrome-devtools/browser-harness; skill `audit` antes de validar sessão com UI.
- **Lint:** `lint` universal (stylelint) — baseline 13 warnings no CSS.

## Backend (`ruby/sinatra`)

- **Paths:** `lib/`, `server.rb`, `db/` (só). Nunca `views/`, `public/`.
- **Stack:** Sinatra + repositórios por usuário (`lib/*_repository.rb`), serviços (`lib/*_service.rb`), regras puras (`RewardRule`, `ExperienceCurve`), Postgres via `DATABASE_URL`.
- **Descoberta:** CBM Scout (`search_graph limit10` → `snippet` → `trace` → `check_index_coverage`); literal → `zvec rg`.
- **Verificar:** `./scripts/test` (Minitest, stub `PokeApi`, sem rede) + `./scripts/lint` (RuboCop 0). Nunca `rake`/`rubocop` no host.
- **Schema:** migração idempotente em `db/migrations/` (`IF NOT EXISTS`); `rake db:setup` via `./scripts/rake`.
