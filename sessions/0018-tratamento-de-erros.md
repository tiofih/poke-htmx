# Sessão 0018 — Tratamento de erros (E2) — RF-18

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída — decisões fechadas com o usuário em 2026-08-09 |
| Implementação | Pendente |
| Validação | Pendente (executada pelo usuário) |

---

## 1. Objetivo

Implementar o **tratamento de erros** de ponta a ponta (E2 do `draft-auto-battler.md`,
anotado no levantamento de roadmap de 2026-08-09): **nenhuma rota deve devolver 500**
quando a fonte (PokéAPI) falha ou recebe input inválido; cada falha devolve um
**fragmento amigável com status 200** (padrão htmx do projeto: `@notice`/`@message`,
swap normal) e um **handler global** cobre erros não previstos — empresa: nenhuma
exceção escapa em produção como página de erro crua.

## 2. Contexto (estado atual — diagnóstico)

Diagnóstico do tratamento de erros hoje (levantado em 2026-08-09):

| Falha | Rotas/ponto | Hoje |
| --- | --- | --- |
| Nome inválido | `GET /pokemon?name=xyz` | `find` → `nil` → `pokemon.erb` acessa `@pokemon.number` → **500** |
| Espécie inexistente | `GET /pokemon/:poke_id` | `detail` → `nil["name"]` (NoMethodError) → **500** |
| PokéAPI fora/rate-limit (HTML no body) | `GET /` / `GET /pokemons` | `all` faz `JSON.parse` sem checar status → **500** |
| PokéAPI fora na batalha | `GET /battle` | `fetch_all_names`/`detail` → **500** |
| `evolution_chain` falha | dentro de `detail` | `JSON.parse` sem checar status → `detail` → **500** |
| `fetch_type_json` falha | `type_relations` (default do `BattleEngine`) | `JSON.parse` sem checar status → **500** |
| Rede (timeout/`ConnectionFailed`) | qualquer método `Faraday` | exceção não resgatada → **500** |
| `POST /team` nome inválido | `add(current_user, nil)` | `pokemon.name` em `nil` → **500** |
| Qualquer erro inesperado | servidor | **500 cru** (sem handler global) |

**Já tolerantes (sem regressão):** `find` (status != 200 → nil), `pokemon_data`
(status != 200 → nil), `fetch_move_json` (status != 200 → nil), `moves_for`/
`available_move_names` (`nil.to_h["moves"]` → `[]`), time vazio em `GET /battle`
(`@message`), duplicados/cap em `POST /team` (`@notice`).

**Dinâmica do Sinatra 3.1 confirmada no código (`gems/sinatra/base.rb`):**
- `error 500 do ... end` casa via `error_block!(status)` e **roda antes** do
  `raise boom if settings.raise_errors?` — testável no env `test` (`raise_errors` true).
- `error StandardError do` / `error do` registram a **classe exata** (`@errors[key]`)
  e só casam pelo fallback final `error_block! Exception` — que no env `test` acontece
  **depois** do `raise` (`raise_errors?` true) → **não** testável sem desligar
  raise_errors. Por isso a escolha: **`error 500 do`**.

## 3. Critérios de aceite

### Robusteza da fonte (PokéAPI — sem regressão nos sucessos)

- [ ] `all` devolve `[]` quando a resposta tem status ≠ 200 (rate-limit/HTML/404) ou o
      body não é JSON — nunca levanta `JSON::ParserError`; rede (`Faraday::Error`,
      incl. `ConnectionFailed`/`TimeoutError`) → `[]`.
- [ ] `find`/`pokemon_data`/`detail` resgatam rede → `nil` (mantêm o guard de status); **`detail` nunca
      acessa campos de `nil`** — `pokemon_data` → nil ⇒ `detail` → `nil`.
- [ ] `evolution_chain` retorna `[]` em status ≠ 200/rede/parse inválido (protege `detail`).
- [ ] `move`/`fetch_move_json` resgatam rede → `nil` (mantêm o guard de status); `moves_for`/
      `available_move_names` seguem `[]` quando `pokemon_data` é `nil` (já tolerante, sem regressão).
- [ ] `fetch_type_json` resgata rede e tolera status ≠ 200 → `nil`; `type_relations` **pula
      o tipo que falhou** (tabela parcial; `TypeEffectiveness.factor` já devolve 1.0 para
      relação ausente ⇒ batalha segue neutra, sem 500).
- [ ] `fetch_all_names` **memoiza apenas lista não-vazia**: falha transitória → `[]` no
      request corrente, mas tenta de novo no próximo (não trava a lista para o processo).

### Rotas (fragmento amigável + status 200)

- [ ] `GET /` e `GET /pokemons`: fonte indisponível (lista vazia) **e sem filtro** (`q` vazio)
      → fragmento com aviso (`@notice`), select vazio, status 200 — sem 500. Filtro sem
      match continua como hoje (`q` não-vazio, select vazio sem aviso: 0 regressão).
- [ ] `GET /pokemon?name=` com `find` → `nil` → fragmento amigável (aviso "Pokémon não
      encontrado."), status 200, sem `<html>`.
- [ ] `GET /pokemon/:poke_id` com `detail` → `nil` → fragmento amigável, status 200, sem `<html>`.
- [ ] `POST /team` com `find` → `nil` → re-renderiza `#team` com aviso (`@notice`), sem
      inserir, status 200 — não chama `add` com `nil`.
- [ ] `GET /battle` com fontes falhando: membro do jogador com `detail` → `nil` ou oponente
      vazio → mensagem amigável (status 200) em vez de batalha quebrada; time vazio segue
      com "Forme seu time para batalhar." (0 regressão).

### Handler global

- [ ] `error 500 do ... end` no `server.rb` → renderiza `views/error.erb` (fragmento,
      `layout: false`, status 200, sem `<html>`), mensagem amigável; o erro original deve
      ficar logado (`logger.error`/`env["sinatra.error"]`), sem vazar stacktrace ao usuário.
- [ ] Em **dev** o comportamento padrão do Sinatra (página de erro) continua valendo
      (`show_exceptions` → raise antes do handler); em **prod/teste** o fragmento amigável
      é servido.

### Garantias (RNF)

- [ ] Testes sem rede (stubs novos/uso de `Faraday.define_singleton_method(:get)` e
      `PokeApiStub`); suíte completa verde (`./scripts/test`) e lint 0; commit a cada green.
- [ ] Sem regressão: RF-01..RF-17 verdes — sucessos da PokéAPI e caminhos já tolerantes
      preservados (asserts de shape/contrato intactos).
- [ ] `REQUIREMENTS.md` (**RF-18 — Tratamento de erros (E2)**; limitação
      "Sem tratamento de erros" → resolvida), `SESSIONS.md` (0018 + progresso + próxima) e
      `draft-auto-battler.md` (E2 Done) atualizados no mesmo escopo.

## 4. Decisões de refinamento (fechadas com o usuário em 2026-08-09)

- **Estratégia web: fragmento amigável + status 200** (decisão do usuário). Mantém o padrão
  do projeto (`@notice`/`@message`, `layout: false`) e o swap do htmx funciona sem
  configuração extra (`HX-*`). Erros reais seguem logados no servidor.
- **Handler global via `error 500 do`** (não `error StandardError`/`error do`): a DSL do
  Sinatra casa por status (500) **antes** do `raise_errors` no env `test` → testável com a
  suíte atual; `error do` só casaria no fallback final, após o `raise` do teste.
- **Escopo: falhas de fonte + handler global** (decisão do usuário). Inclui listagem,
  fragment add, detalhe, manage (já tolerante — sem regressão), batalha, `evolution_chain`
  e `type_relations`; **fora do escopo**: erros 404 de rota inexistente, validações de
  duplicado/cap/time vazio (já tratadas em RF-07/0013), cache de detalhes (E1 — própria
  sessão).
- **`detail` nil-safe de forma explícita**: `pokemon_data` retornando nil não vira
  `NoMethodError` dentro do `detail` — guard antes de montar o `Pokemon`.
- **`fetch_all_names` não memoiza falha**: `||=` só para lista não-vazia, senão a app ficaria
  sem lista para sempre após um rate-limit transitório.
- **Rótulo funcional:** tratado como **RF-18** (transversal, sem tabela/gem nova — só
  robustez em `lib/poke_api.rb` + handlers em `server.rb` + fragmento `error.erb`).
- Fora do escopo (anotado no draft): 404 customizado, tratamento global de erros do
  **Postgres** (backlog), página de erro com layout para navegação não-htmx.

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) | Status |
| --- | --- | --- | --- |
| 0 | fonte: `all` → `[]` em status ≠ 200 / body HTML / rede; `fetch_all_names` memoiza só não-vazio (falha → `[]` e 2ª chamada tenta de novo) | `lib/poke_api.rb`: guard de status + rescue `Faraday::Error` em `all`; memoização condicional em `fetch_all_names` | ⬜ |
| 1 | fonte: `detail` → `nil` quando `pokemon_data` → `nil`; `evolution_chain` → `[]` em status ≠ 200/rede/parse; `fetch_type_json` → `nil` em status ≠ 200/rede e `type_relations` pula tipo falho (neutro 1.0) | guards + rescues em `detail`/`evolution_chain`/`fetch_type_json`/`type_relations`; `find`/`fetch_move_json` resgatam rede | ⬜ |
| 2 | rotas: `GET /pokemon?name=` com `find` nil → 200 fragmento com aviso (sem `<html>`); `GET /pokemon/:poke_id` com `detail` nil → 200 fragmento; `POST /team` nome inválido → 200 + aviso, não insere | `server.rb`: nil-guards + `@notice`/`@message`; novo `views/error.erb` (fragmento genérico amigável) | ⬜ |
| 3 | rotas: `GET /`/`GET /pokemons` com lista vazia e `q` vazio → 200 + aviso; filtro sem match (q não-vazio) sem aviso (0 regressão); `GET /battle` com fonte falhando → 200 mensagem amigável | `pokemon_list.erb` aviso quando vazio sem `q`; `GET /battle` filtro de membros nil/oponente vazio + `@message` | ⬜ |
| 4 | handler global: rota que lança exceção inesperada → 200 fragmento `error.erb` (sem `<html>`), erro logado, stack não vaza | `error 500 do ... end` no `server.rb` + `views/error.erb` | ⬜ |
| 5 | docs: `REQUIREMENTS.md` (RF-18 + limitação resolvida), `SESSIONS.md` (0018 + progresso + próxima), `draft-auto-battler.md` (E2 Done) | documento | ⬜ |

## 6. Observações

- **Sem nova tabela/gem**: E2 é robustez transversal — escopo em `lib/poke_api.rb` e
  `server.rb` + um fragmento novo (`views/error.erb`).
- **`error 500 do` cobre RNF-04/semântica htmx**: fragmento `layout: false` + 200 permite
  o htmx fazer swap; em dev o `show_exceptions` continua exibindo a página de erro do Sinatra.
- **E1 (cache de detalhes) e 404 customizado** seguem no draft/backlog para sessões próprias.
- Após 0018: candidatas seguem **D2 (XP/evolução)** (provável próxima), **D3 (histórico/rank)**,
  **D4 (modos de draft temático)** e respiro de refatoração de testes (`rubocop:disable`).