# Poké-HTMX

Pokedex + auto-battler **server-rendered** com [htmx](https://htmx.org) — sem JavaScript
customizado. Você monta um time de Pokémon vindo da [PokéAPI](https://pokeapi.co), enfrena
batalhas automáticas por rodadas, ganha XP e dinheiro, cura o time no Poke Center e compra
itens no Poke Mart, num circuito fechado de progressão.

## Stack

| Item | Tecnologia |
| --- | --- |
| Linguagem | Ruby 3.3.6 |
| Framework web | Sinatra (`server.rb`) |
| HTTP client | Faraday (`lib/gateways/poke_api_http.rb`, gateway com interface `PokeApi`) |
| Modelo | `Dry::Struct` (`lib/pokemon.rb`, `lib/move.rb`, `lib/item.rb`) |
| Persistência | PostgreSQL (gem `pg`, sem ORM) |
| Testes | Minitest |
| Frontend | htmx 2.0.3 (CDN) + sakura.css + `public/style.css` |
| Servidor | Puma |
| Infra | Docker / docker-compose (porta 3000) |

## O jogo: circuito fechado

```
montar time (cap 6) → batalha (auto, 6v6) → XP + dinheiro → Poke Center (cura) / Poke Mart (itens) → repete
```

Progressão básica:

- **Batalha** avança 1 rodada por clique ("Jogar") — os dois lados atacam na ordem do
  Speed, com tipos (`×2 / ×0.5 / ×0 / STAB`), golpes com PP, e itens consumíveis entram
  automaticamente quando o HP do time cai abaixo do limiar.
- **XP/evolução** — cada Pokémon sobe de nível (stats escalam), evolui e aprende golpes
  usando dados oficiais da `species` da PokéAPI quando a espécie está disponível.
- **Economia** — vitória/derrota/empate pagam dinheiro (`RewardRule: win 100 / draw 50 /
  lose 40`); o saldo paga cura (Poke Center) e itens (Poke Mart).
- **Itens** — poções (consumíveis em batalha), item atribuído por membro e seguráveis
  (hold items: choice-band / choice-scarf modulam stats).
- **Histórico/rank** — cada batalha é persistida; `GET /history` mostra rank local
  (suas vitórias) e global (líderes).

## Rodando

```bash
./scripts/run          # docker compose up --build — app na porta 3000
./scripts/rake db:setup   # aplica db/schema.sql + db/migrations/*.sql em ordem
./scripts/rake db:seed    # seeds de validação (times de exemplo, saldo, histórico)
```

Primeira vez: `./scripts/run` e, em outro terminal, `./scripts/rake db:seed`.

> Banco: `postgres://pokedex:pokedex@db:5432/pokedex` (definido no docker-compose via
> `DATABASE_URL`). Em produção, defina `SESSION_SECRET` (string hex ≥ 32 bytes — Sinatra 3.1
> usa `Rack::Protection::EncryptedCookie`).

### Seeds de validação

`rake db:seed` aplica todas; `SEED=<nome> USER_ID=<id> rake db:seed` aplica uma só:

| Seed | user_id | O que cria | Oponentes (banda J3) |
| --- | --- | --- | --- |
| `team_basico` | `seed-basic` | Time inicial simples nível 1 | banda **F–D** |
| `team_evolucao` | `seed-evol` | Time pronto para evoluir em 1 vitória | banda **A–S** |
| `team_niveis_mistos` | `seed-mixed` | Time com níveis variados (média 20) | banda **A–S** |
| `batalhas_historico` | `seed-history` | Batalhas para o rank do histórico | — |
| `saldo_inicial` | `seed-shop` | Saldo inicial 200 no Poke Mart | — |
| `team_duelo` | `seed-strong` / `seed-weak` | Time forte (média 28) × fraco (média 1), saldo p/ comprar | **A–S** / **F–D** |

A coluna "Oponentes" reflete o resultado da sessão 0040 (J3 — ranking S–F): a banda é
derivada do **nível médio do time** (`PokemonRating.band_for_level`); oponentes são
sempre nível 1, mas a **espécie** é filtrada pela banda (fim do sorteio puro).

Troque de usuário na validação anexando `?as=<user_id>` (ex.: `http://localhost:3000/?as=seed-strong`).

## Comandos

Tudo roda via `./scripts/*` (usa o container `web` / sobe o `db`) — não rode `rake`/`rubocop` no host.

| Comando | O que faz |
| --- | --- |
| `./scripts/test` | Suíte Minitest completa, sem rede. Filtros: `./scripts/test test/server_test.rb` (arquivos) e `./scripts/test -n /regex/` (por nome). |
| `./scripts/rake` | Rake no container (sem args = `test`). Ex.: `rake db:setup`, `rake lint`. |
| `./scripts/lint` | RuboCop (objetivo: 0 offenses). |
| `./scripts/check_docs` | Consistência do SDD (roda no host): `sessions/` ↔ tabela de progresso do `SESSIONS.md` ↔ "Próxima sessão". Rodar ao fechar refinamento/validação. |
| `./scripts/run` | `docker compose up --build` — app na porta 3000. |
| `./scripts/seed` | Atalho para `rake db:seed`. |

## Estrutura

```
server.rb                Rotas Sinatra + sessão + helpers de orquestração
lib/
  battle_engine.rb       Motor de auto-batalha 6v6 (pure domain, determinístico) + half-FSM (:item)
  battle_pokemon.rb      Unidade de combate (BattlePokemon, dry-struct imutável)
  team_repository.rb     Persistência do time por usuário (slots, moves, itens, evolução)
  battle_repository.rb   Histórico/rank de batalhas
  progression_repository.rb  XP/nível por membro
  wallet_repository.rb   Saldo (moeda)
  inventory_repository.rb   Itens comprados (estoque)
  gateways/              Interface PokeApi + adapter PokeApiHttp + cache TTL/LRU
  item_catalog.rb, item_use_policy.rb, item.rb   Itens (consumíveis/seguráveis) e política
  heal_service.rb, mart_service.rb              Use cases de cura e compra
  reward_rule.rb, evolution_rule.rb,
  experience_curve.rb, heal_cost_policy.rb      Policies puras
views/                   Fragmentos htmx + layout único
db/                      schema.sql + migrations/*.sql + seeds/*.rb
test/                    Minitest (sem rede — stubs do gateway PokéAPI)
```

## Testes

```bash
./scripts/test               # suíte completa (ex.: 559 runs / 1696 asserts)
./scripts/test test/server_test.rb   # apenas um arquivo
./scripts/test -n /battle/           # por regex de nome
./scripts/lint               # RuboCop, objetivo 0 offenses
```

- Testes **sem rede**: rotas que tocam a PokéAPI usam stubs (`PokeApiFake`, swap de
  `Server.api`).
- Base herda de `test/test_helper.rb` (`TestDatabase` aplica schema + migrações em ordem).

## Como contribuir com o fluxo do projeto

O projeto segue um fluxo de sessões em **TDD estrito** (red → green → commit por passo),
com **validação feita pelo usuário** ao fim de cada requisito. Documentação viva:

- `REQUIREMENTS.md` — requisitos (RF), status, roadmap e backlog.
- `SESSIONS.md` — registro de todas as sessões (refinamento → TDD → validação).
- `draft-auto-battler.md` + `draft-arquitetura-design-patterns.md` — ideias e decisões de
  arquitetura embrionárias (antes de virarem sessão).
- `docs/screens/` — descrições de tela (inspiração para as futuras telas da jornada).

Convenções de commit (uma linha): `Passo N: ...` (green), `Sessao 00NN: refinamento...`,
`Validacao sessao 00NN: ...`, `Draft: ...`, `Regra: ...`. Idioma: português.