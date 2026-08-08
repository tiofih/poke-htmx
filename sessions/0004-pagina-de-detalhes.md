# Sessão 0004 — Página de detalhes (tipos, stats, evoluções)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Em andamento |
| Implementação | — |
| Validação | — |

---

## 1. Objetivo

Criar a **página de detalhes de um Pokémon**: ao clicar no nome/sprite do Pokémon
(no fragmento `#pokemon` da listagem ou na equipe), o usuário vê, no mesmo alvo
`#pokemon`, tipos, os 6 stats base (HP, Attack, Defense, Sp.Atk, Sp.Def, Speed) e a
**cadeia de evolução** (sprite + nome de cada forma). A interação continua
100% htmx (RNF-01), o botão "Add to Team" é preservado no detalhe e o `GET
/pokemon?name=` atual (fragmento "Add to Team") permanece intacto. A nova rota
usa o **id único da API** (`GET /pokemon/:poke_id`), mais estável que o nome
(ex.: `farfetch'd`, `nidoran-f`).

## 2. Contexto (estado atual)

- `server.rb` expõe `GET /` (lista), `GET /pokemon?name=` (fragment add),
  `GET /team` (read-only load inicial), `POST /team`, `DELETE /team` — todos
  escopados por `session[:user_id]` (RF-05).
- `PokeApi.find(name)` retorna um `Pokemon` (Dry::Struct) com
  `name`, `sprite`, `number` (o `number` é o id da PokéAPI) — sem tipos, stats
  nem evoluções.
- `Pokemon` (`lib/pokemon.rb`) é usado pelo time/equipe (persistência).
- Visualizações: `views/index.erb` (single page), `views/pokemon.erb`
  (fragment add), `views/team.erb` (membros + remoção).
- Testes HTTP usam `PokeApiStub` (sem rede) — hoje só `with_find`; rotas de
  equipe já provam isolamento por sessão com `user_session`.
- Sessão 0003 validada; RNF-04 libera iniciar a 0004.

## 3. Critérios de aceite

- [ ] **Rota de detalhe:** `GET /pokemon/:poke_id` responde com o fragmento de
      detalhe (`#pokemon`) contendo sprite, nome, tipos, stats e evoluções do
      Pokémon — sem rede, via stub.
- [ ] **Tipos:** o fragmento exibe **todos** os tipos do Pokémon (ex.: pikachu →
      "electric"; bulbasaur → "grass", "poison").
- [ ] **Stats:** o fragmento exibe os **6 base stats** com nome e valor (HP,
      Attack, Defense, Sp.Atk, Sp.Def, Speed).
- [ ] **Evoluções:** o fragmento exibe a cadeia de evolução do Pokémon
      (sprite + nome de cada forma), obtida via `pokemon-species` →
      `evolution_chain`; Pokémon sem evoluções não quebra a página.
- [ ] **Navegação htmx:** os nomes no fragment `pokemon.erb` e em `team.erb`
      tornam-se clicáveis com `hx-get="/pokemon/:poke_id"` (alvo `#pokemon`); sem
      JS customizado (RNF-01).
- [ ] **Add to Team preservado:** o fragmento de detalhe mantém o form
      `hx-post /team` (pokeName = nome) para adicionar à equipe (mesmo
      comportamento do RF-03).
- [ ] `GET /pokemon?name=` (fragment add atual) permanece funcional — sem
      regressão no fluxo da listagem.
- [ ] Suíte completa verde sem rede (`./scripts/test`), lint verde
      (`./scripts/lint`) e **commit a cada green** (RNF-04).
- [ ] `REQUIREMENTS.md` (novo RF de detalhes) e `SESSIONS.md` (0004 em
      refinamento) atualizados no mesmo escopo.

## 4. Decisões de refinamento

- **Rota:** `GET /pokemon/:poke_id` é a nova página de detalhe (o `poke_id` é o
  `number` do `Pokemon`, id único da PokéAPI). O target/swap
  é o mesmo `#pokemon` usado pelo fragment add — troca de conteúdo no mesmo
  container, mantendo a natureza de página única htmx. `GET /pokemon?name=`
  **não muda** (fragment add da listagem).
- **Navegação:** cliques vêm de dois pontos: o fragmento `pokemon.erb`
  (nome clicável no fragment add) e `team.erb` (nome do membro vira link).
  Ambos usam `hx-get="/pokemon/:poke_id"` → `hx-target="#pokemon"` → swap
  `innerHTML`.
- **Como obter evoluções:** `PokeApi.detail(poke_id)` é o novo método público que
  monta o `Pokemon` completo numa única fonte de dados: (1) `GET /pokemon/:id`
  → `types` + `stats` + `species.url`; (2) `GET pokemon-species`
  → `evolution_chain.url`; (3) `GET evolution-chain` → cadeia aninhada
  `chain → species`, com `evolves_to`; (4) para cada `species` da cadeia, buscar
  o sprite de `GET /pokemon/{nome}`. Evita expor a cadeia remota dentro da view.
- **Modelo `Pokemon`:** ganha atributos opcionais `types` (Array[String]),
  `stats` (Array de {name, value}) e `evolutions` (Array de `Pokemon`, com
  sprite+number). Atributos com default `[]` — o construtor atual
  (`Pokemon.new(name:, sprite:, number:)`) **continua válido** nos testes e na
  persistência (sem quebra da suíte existente).
- **Sem schema/DB:** detalhe é visualização pura da PokéAPI; não há migração.
  `team_pokemons` continua como está.
- **Stub:** `PokeApiStub` ganha `with_detail(pokemon)` (análogo do `with_find`),
  que stubs `PokeApi.detail` para o corpo do detalhe — testes HTTP do detalhe
  nunca tocam rede.
- **Sem ORM e sem infra nova:** mesma stack (Faraday, Dry::Struct, Sinatra).

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) |
| --- | --- | --- |
| 0 | `GET /pokemon/25` responde 404 hoje (rota não existe); `Pokemon` sem campos de detalhe | `Pokemon` com `types`/`stats`/`evolutions` `default []`; `PokeApi.detail(25)` (preenche tipos/stats, evoluções vazias); rota `get "/pokemon/:poke_id"` → `erb pokemon_detail` com sprite+nome |
| 1 | fragmento de detalhe de pikachu contém `electric` | renderização do `types` na `views/pokemon_detail.erb` |
| 2 | fragmento contém os 6 stats base nome+valor (hp=35, attack=55 em pikachu) | renderização dos `stats` na view |
| 3 | fragmento da cadeia de evolução de charizard contém `charmander`, `charmeleon`, `charizard` (com sprites) | `PokeApi.detail` preenche `evolutions` via species → chain → sprites; view renderiza cadeia |
| 4 | nomes em `pokemon.erb` e `team.erb` são links `hx-get="/pokemon/:poke_id"` (alvo `#pokemon`) | views atualizadas; form add mantido no detalhe |
| 5 | suíte completa + lint verdes; `REQUIREMENTS.md`/`SESSIONS.md` atualizados | ajustes finais e documento |

## 5b. Observações de TDD

- Passo 3 exige stub mais robusto: `with_detail` deve devolver `Pokemon` já com
  `evolutions` preenchidas; a prova da cadeia é no fragmento renderizado, não
  na chamada Faraday (stub em `PokemonApi`).
- Pokémon sem evolução: `PokeApiStub.with_detail` com `evolutions: []`.

## 6. Observações e próximo passo

- **Parcial do RF-06:** tipos e stats vêm do mesmo endpoint `GET /pokemon/:name`;
  apenas evoluções exigem saltos de `pokemon-species` e `evolution-chain`.
- Próximo passo após validação: **fase 2 (TDD)** — passo 0 (red): `Pokemon`
  com os campos + `PokeApi.detail` + rota `GET /pokemon/:poke_id`.

### Validação do refinamento (a ser preenchida quando o usuário validar)

- [ ] Critérios de aceite fechados (seção 3) e decisões de design registradas (seção 4).
- [ ] Plano TDD com 6 passos red/green definidos (seção 5).
- [ ] `REQUIREMENTS.md` (novo RF) e `SESSIONS.md` (0004 em refinamento) atualizados no mesmo escopo.