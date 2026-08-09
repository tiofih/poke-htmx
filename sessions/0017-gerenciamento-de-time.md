# Sessão 0017 — Página de gerenciamento de time (slot + golpes) — A3/RF-17

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída — decisões fechadas com o usuário em 2026-08-09 |
| Implementação | Pendente |
| Validação | Pendente (executada pelo usuário) |

---

## 1. Objetivo

Criar uma **página própria de gerenciamento do time** (A3 do `draft-auto-battler.md`,
anotada na validação da 0015) onde o usuário possa **escolher a posição (slot) de
cada Pokémon** e **escolher os golpes de cada um**. Hoje a posição só muda via ▲/▼
no fragmento `#team` (RF-08) e os golpes são fixos — últimos 4 da PokéAPI, com os
quais o motor escolhe deterministicamente o uso (D1/RF-15).

Esta sessão **revisita A1** (slots — reusa `POST /team/:id/move`), **D1** (golpes —
seletor em vez de 4 fixos) e **C1** (`GET /battle` deixa de usar os 4 defaults do
jogador quando ele escolheu golpes). As escolhas do usuário **persistem** entre
batalhas/sessões.

## 2. Contexto (estado atual)

- `TeamRepository` (`lib/team_repository.rb`) persiste `Pokemon` em `team_pokemons`
  (id, user_id, name, sprite, number, slot); `all(user_id)` ordena por slot e monta
  `Pokemon`; `move(user_id, id, new_slot)` reordena slots 1..N (RF-08).
- `Pokemon` (`lib/pokemon.rb`, Dry::Struct): `id/name/sprite/number/slot/types/stats/
  evolutions` — **não tem `moves`**.
- `PokeApi.moves_for(number)` (`lib/poke_api.rb:84`) devolve os **últimos 4** moves
  (carrega cada `/move`, memoizado). Servidor usa `battle_moves_for` em `GET /battle`
  (`server.rb:40-46`) para os dois lados.
- `battle.erb` (`views/battle.erb`) e painel mostram `move — PP n` (RF-15); o motor é
  determinístico, escolhe o golpe de maior dano esperado entre os `moves` do
  `BattlePokemon` (`lib/battle_engine.rb:102-107`).
- Stubs: `PokeApiStub.with_moves_for`/`with_detail`/`with_type`/`with_find`/
  `with_all_names` (`test/test_helper.rb`) — **não há** stub para `available_move_names`
  nem para `PokeApi.move` por nome (será criado).
- RNF-04: TDD (red → green → commit), suíte via `./scripts/test`, lint `./scripts/lint`;
  fragmentos htmx com `layout: false` (RF-14).

## 3. Critérios de aceite

### Schema e modelo (persistência da escolha)

- [ ] Migração idempotente `db/migrations/0017_add_moves.sql`:
      `ALTER TABLE team_pokemons ADD COLUMN IF NOT EXISTS moves TEXT[] NOT NULL DEFAULT '{}'`
      — **sem** `TRUNCATE` (default cobre as linhas existentes).
- [ ] `Pokemon` ganha attribute `moves` (`Array.of(String)` default `[]`); `all`
      devolve os moves persistidos; `add` persiste `pokemon.moves` (default `[]`).
- [ ] `TeamRepository::MAX_MOVES_PER_POKEMON = 4`; `TeamRepository#set_moves(user_id, id, moves)`
      persiste no máximo 4 nomes (corta o excedente), só do próprio usuário; id de
      outro usuário / inexistente → no-op idempotente (sem raise).

### API (fonte dos golpes)

- [ ] `PokeApi.available_move_names(number)` devolve **todos** os nomes de moves do
      Pokémon (de `pokemon_data(number)["moves"]`, **sem** carregar cada `/move`),
      ordenados alfabeticamente, memoizado por número (2ª chamada sem nova rede).
- [ ] `PokeApi.move(name)` volta `nil` em status ≠ 200 (robustez, consistência com
      `find`/`detail` da 0014) — nomes fora da lista disponível não quebram a batalha.

### Página de gerenciamento (rota + fragmento)

- [ ] `GET /team/manage` renderiza o fragmento `views/team_manage.erb` (alvo `#team`,
      `layout: false`) listando cada membro com: sprite + nome, **checkbox de golpes**
      (todos os `available_move_names` do Pokémon, marcados os atuais), botão salvar e
      controle de **slot** (▲/▼ reusando `POST /team/:id/move`), além de link "Voltar"
      (`hx-get="/team"`).
- [ ] `POST /team/:id/moves` (body `moves=<nome>`×N) salva a seleção via
      `TeamRepository#set_moves` e re-renderiza `team_manage.erb`; mais de 4 selecionados
      ou nomes fora da lista disponível → **não salva**, re-renderiza com aviso (`@notice`,
      pad) — sem JS customizado (RNF-01).
- [ ] Entrada na página: link "Gerenciar" dentro do fragmento `#team`
      (`hx-get="/team/manage" hx-target="#team"`); layout/nav de RF-14 **intactos**.

### Batalha usa os golpes escolhidos

- [ ] `GET /battle` monta os golpes do **jogador** a partir dos `moves` persistidos
      (nome → `PokeApi.move`, memoizado); lista vazia → fallback atual
      (`PokeApi.moves_for`, sem regressão). Oponente mantém os 4 defaults (D1).
- [ ] Comportamento do motor inalterado (RF-11/15): a escolha determina o **conjunto**;
      o motor continua escolhendo deterministicamente qual usar a cada ação.

### Garantias (RNF)

- [ ] Testes sem rede (stubs novos `with_available_move_names`/`with_move`); suíte
      completa verde (`./scripts/test`) e lint 0; commit a cada green.
- [ ] Sem regressão: RF-01..RF-16 verdes (asserts de shape do log e do repo preservados).
- [ ] `REQUIREMENTS.md` (**RF-17 — Página de gerenciamento de time (A3)**),
      `SESSIONS.md` (0017 + progresso) e `draft-auto-battler.md` (A3) atualizados no
      mesmo escopo.

## 4. Decisões de refinamento (fechadas com o usuário em 2026-08-09)

- **Persistir os golpes escolhidos no Postgres** (decisão do usuário): nova coluna
  `moves TEXT[] NOT NULL DEFAULT '{}'` em `team_pokemons` (migração idempotente, sem
  truncate). A escolha vale entre requests/batalhas e cruza com a futura D2 (XP).
- **Fonte dos golpes = lista completa da PokéAPI** (decisão do usuário):
  `available_move_names(number)` usa o `moves` de `GET /pokemon/:id` (só nomes, sem
  carregar cada `/move`); o seletor oferece a lista (ordenada) e o detalhe é carregado
  só dos escolhidos (`PokeApi.move`, memoizado). Lista inclui golpes de status —
  selecionáveis, mas o motor os trata como hoje (D1: inutilizáveis → Struggle se todos
  forem status).
- **Golpes + slots na página** (decisão do usuário): ganchos da página própria com
  seleção de golpes por membro E reordenação de posição (reusa
  `TeamRepository#move`/`POST /team/:id/move`); `#team` continua funcional.
- **Cap de 4 golpes** (`MAX_MOVES_PER_POKEMON`), consistente com D1 (moves_for max 4);
  excedente é cortado no `set_moves`; na rota, >4 selecionados → aviso e não salva
  (sem JS — RNF-01).
- **Entrada pela própria `#team`** (link "Gerenciar"), não no nav global: mantém o
  contrato de RF-14 e não mexe nos testes de nav/index.
- **`PokeApi.move` tolerante** (nil em status ≠ 200): consistência com a robustez da
  0014 (`find`/`detail`); protege a batalha de nomes salvos obsoletos.
- Fora do escopo: seletor runtime dentro da batalha (a escolha é persistida e vale
  entre batalhas), XP/evolução (D2), histórico/rank (D3), accuracy/RNG (D1 segue
  determinístico), persistência de logs.

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) | Status |
| --- | --- | --- | --- |
| 0 | repo/schema: `set_moves` persiste (até 4, isolamento, no-op p/ outro usuário); `all` devolve `moves`; `Pokemon` com `moves` default `[]` | migração `0017_add_moves.sql` + attribute `moves` em `Pokemon` + `set_moves`/parse na `all`/insert na `add` | pendente |
| 1 | api: `available_move_names` lista completa, ordenada, memoizada; `move` → `nil` em status ≠ 200 | `PokeApi.available_move_names` (cache) + guarda de status em `move`; stubs `with_available_move_names`/`with_move` | pendente |
| 2 | rota/UI: `GET /team/manage` renderiza fragmento com checkboxes (disponíveis + atuais) e ▲/▼ por membro + Voltar; link "Gerenciar" no `team.erb` | rota `GET /team/manage` + `views/team_manage.erb` + link em `team.erb` | pendente |
| 3 | rota/UI: `POST /team/:id/moves` salva seleção (≤4); >4 ou nome fora da lista → aviso e não salva; re-renderiza manage | rota `POST /team/:id/moves` + `@notice` | pendente |
| 4 | battle: `GET /battle` usa os golpes salvos do jogador (nome → `PokeApi.move`); vazio → fallback `moves_for`; oponente = defaults | `battle_moves_for` lê `pokemon.moves` persistidos | pendente |
| 5 | docs: `REQUIREMENTS.md` (RF-17), `SESSIONS.md` (0017 + progresso + próxima), `draft-auto-battler.md` (A3) | documento | pendente |

## 6. Observações

- **Sem nova tabela:** a escolha de golpes é um array de nomes na linha do membro do
  time (1:1 com `team_pokemons`), não uma relação N:N — `moves TEXT[]` cobre o escopo.
- **Cost da lista completa:** `available_move_names` lê só o `/pokemon/:id` (já
  cacheado padrão RF-01 é por nome em `fetch_all_names`; aqui o cache é por número no
  `available_move_names_cache`), sem explosão de requests — o detalhe de cada `/move`
  só entra para os escolhidos (memoizado).
- **`Pokemon.moves` default `[]`** não muda os construtores existentes nem `PokeApi.find/
  detail` (0 regressão).
- Após 0017: **D2 (XP/evolução)**, **D3 (histórico/rank)** seguem como candidatas do
  draft.