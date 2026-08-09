# Sessão 0013 — Batalha na web (C1, RF-13) — game loop exposto na UI via htmx

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída — decisões fechadas com o usuário em 2026-08-09 |
| Implementação | Concluída — passos 0–7 TDD, suíte 135 runs/481 asserts e lint 0 verdes |
| Validação | Concluída — validada pelo usuário em 2026-08-09 |

---

## 1. Objetivo

Expor o **motor de auto-batalha** (RF-11/B3, sessão 0011) e o **oponente automático**
(RF-12/B4, sessão 0012) na UI com **100% htmx** (RNF-01): o usuário entra em uma
batalha contra um time adversário, e cada "jogar" avança **uma rodada** do
`BattleEngine`, re-renderizando o fragmento `#battle` (innerHTML) com os dois
painéis (time do jogador × oponente), **HP atual** de cada Pokémon, o **log do último
round** e, ao fim, o **vencedor** + botão "Rematch". Sem JavaScript customizado —
estado (antes/em batalha/fim) gerenciado no servidor.

Não é uma reescrita do motor: o `BattleEngine` ganha uma API **incremental**
(round a round) mantendo `battle` intacto (0 regressão nos testes da sessão 0011).

## 2. Contexto (estado atual)

- Rotas atuais (server.rb): `GET /`, `GET /pokemons`, `GET /pokemon`, `GET /pokemon/:poke_id`,
  `GET /pokemon/close`, `GET /team`, `POST /team`, `DELETE /team`, `POST /team/:id/move`.
- `BattleEngine#battle` (0011) executa a batalha inteira de uma vez e devolve
  `BattleResult` (winner/log/rounds); `@log` e os times são **privados** — a rota não
  tem como avançar e ler HP a cada rodada.
- `BattlePokemon` (B1, session 0009): `from(pokemon)` exige `Pokemon` **com** `stats`
  (`hp_max` = stat HP) e `types`.
- `TeamRepository#all(user_id)` devolve `Pokemon` **sem** `stats`/`types` (só
  name/sprite/number/slot). Para batalhar é preciso buscar o detalhe completo de
  cada membro via `PokeApi.detail(number)` (mesmo caminho de RF-06).
- `OpponentGenerator` (0012): `team` devolve `[BattlePokemon]` usando `names`/`fetcher`
  injetados (`PokeApi.fetch_all_names` + `PokeApi.method(:detail)` por default).
- `PokeApiStub` já tem `with_find`, `with_detail`, `with_all_names` e `with_type`.
- `index.erb` é página única; `#team` é carregado via `hx-get="/team" hx-trigger="load"`.
  A entrada da batalha será um fragmento `#battle`.
- RNF-04: TDD obrigatório, commit após cada green, suíte Minitest via `./scripts/test`.

## 3. Critérios de aceite

### `BattleEngine` incremental (lib/battle_engine.rb, testes purros sem rede)

- [ ] `play_round` público: executa **apenas uma rodada**, incrementa `rounds_reforgest`
      (rounds), aoementa `@log`, e devolve/expóe o estado dos times (HP por membro).
- [ ] `finished?`, `winner`, `rounds` públicos (leem o estado corrente, não só o final).
- [ ] `battle` continua igual: loop de `play_round` até `finished?` → mesmo
      `BattleResult` de antes (testes existentes da 0011 seguem verdes sem edição).
- [ ] Repetir `play_round` após o fim é **idempotente** (não quebra, não gera log novo).

### `BattleRegistry` (lib/battle_registry.rb — estado em memória)

- [ ] `battle_registry.rb` guarda por `user_id` a batalha corrente (engine + lados),
      com `get_user_id`/`set`/`clear`.
- [ ] `open` (GET /battle) cria/recria a batalha; `POST /battle/play` avança o estado existente.

### Rotas e fragmento (server.rb + views/battle.erb)

- [ ] `GET /battle` abre/recria a batalha (Novo confronto): monta time do jogador via
      `BattlePokemon.from(PokeApi.detail(member.number))` para cada membro de
      `TeamRepository#all(user_id)`; monta oponente via `OpponentGenerator`; cria o
      `BattleEngine`; re-renderiza `battle.erb` no alvo `#battle`.
- [ ] `POST /battle/play` avança **uma rodada** e re-renderiza `battle.erb` (innerHTML
      no `#battle`): painéis mostram nome + sprite + **HP current/max** de cada membro
      dos dois lados; log mostra as ações do último round.
- [ ] Batalha finalizada (vazio de `finished?`): fragmento mostra **vencedor**
      (Seu Time / Oponente) e botão **Reset** (recria via `GET /battle`).
- [ ] Time vazio → mensagem amigável ("Forme seu time para batalhar") sem erro.
- [ ] `index.erb` ganha link/trim para a batalha (`hx-get="/battle" hx-target="#battle"`).
- [ ] S/ JS custom — 100% htmx (verificável nos atributos do fragmento).

### Garantias (RNF)

- [ ] Testes **sem rede**: server stubs `with_all_names`/`with_detail`/`with_type`.
- [ ] Suíte completa verde (`./scripts/test`), lint 0 offenses e commit a cada green.
- [ ] 0 regressão: testes de B1..B4 (0011/0012) e rotas anteriores seguem verdes.
- [ ] `REQUIREMENTS.md` (**RF-13 — Batalha na web (C1)**), `SESSIONS.md` (0013)
      e `draft-auto-battler.md` (C1 em refinamento) no mesmo escopo.

## 4. Decisões de refinamento

- **API incremental no motor** (em vez de wrapper). `BattleEngine` já guarda o estado
  (times, log); tornar `play_round`, `finished?`, `winner`, `rounds` públicos e
  transformar `battle` num loop de `play_round` mantém o domínio único e o disparo do
  passo (uma rodada por request). BattleResult continua a ser a saída final do `grid`.
- **Estado em memória (BattleRegistry)** em vez de sessão: cookie é pequeno (não cabe
  `[BattlePokemon]` de 6v6) e battle não é estado persistente de RF-02. Perde em
  multi-process/multi-instance — aceito para o MVP (anotado em Observações).
- **Time do jogador via `PokeApi.detail(number)`** por membro — `TeamRepository#all`
  não carrega `stats`/`types`; reuso do fetch de RF-06 (um request por membro por GET).
  Oponente segue o portão de `OpponentGenerator` (B4).
- **Fragments**: `views/battle.erb` único serve pre/playing/fim (condicionais no view);
  alvo `#battle` no `index.erb`, entrada via link htmx ao lado do #battle.
- Fora do escopo: persistência de batalha (PG), movimentos/PP (D1), XP (D2),
  histórico/rank (D3), A2 (layout/estilos fica no backlog), RNG do oponente fixo na
  UI (usa default do `OpponentGenerator`).

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) |
| --- | --- | --- |
| 0 | engine incremental: `play_round` avança 1 round + expõe HP/`finished?`/`winner`; `battle` = loop; repetir após fim é idempotente | 0013: tornar `play_round`/acessores públicos; `battle` vira loop |
| 1 | `BattleRegistry` get/set/clear por `user_id` | lib/battle_registry.rb simples (hash) |
| 2 | `GET /battle` cria a partida (time jogador via `with_detail` por membro + oponente via `with_all_names`) e renderiza painéis com HP nos dois lados | rota `get "/battle"` + `views/battle.erb` + setup (BattlePokemon.from(detail)) |
| 3 | `POST /battle/play` avança 1 round (HP muda), log da rodada visível | rota `post "/battle.play"` + `play_round` + re-render `#battle` |
| 4 | fim: após rounds chegar ao fim, vencedor + botão Reset; time vazio → mensagem amigável | view lógica fim/vazio + `get "/battle"` recriando |
| 5 | `index.erb` link batalha (`hx-get="/battle" hx-target="#battle"`) + `# `#battle` div | edição do index |
| 6 | suíte completa (`./scripts/test`) + `./scripts/lint` 0 erros | checagem |
| 7 | docs: `REQUIREMENTS.md` (RF-13 C1), `SESSIONS.md` (0013), `draft-auto-battler.md` (C1) | documento |

## 6. Observações e próximo passo

- Dependência: `GET /battle` faz N requests na PokéAPI (1 por membro do time;
  RF-06 já é o padrão). Não há cache local de detalhes hoje; anotado como fora do escopo.
- Pós-sessão 0013: **A2 — UI: layout e estilos externos** (roadmap item 13) volta ao
  topo do backlog para polir a tela de batalha; D1/D2/D3 (golpes, XP, histórico) seguem
  no draft-auto-battler.md.
- Estado em memória: documentar limitação (batalha é por process). Concorrência de
  acionamento não é alvo.

## 7. Validação (a preencher pelo usuário)

- **Validada pelo usuário em 2026-08-09** ("ok, comportamento validado também").
  Suíte completa verde (135 runs/481 asserts) e lint 0 confirmados; critérios de
  aceite da seção 3 verificados contra a implementação (`BattleEngine#play_round`
  incremental idempotente, `BattleRegistry` por user, `GET /battle` + `POST /battle/play`
  com fragmento `#battle`, HP/log/vencedor visíveis, Reset recriando, time vazio
  amigável, entrada htmx no index). RF-01..RF-12 sem regressão.
- Sessão 0013 **concluída**; próxima sessão sugerida: **A2 — UI: layout e estilos
  externos** (roadmap item 13) e/ou itens D1–D3 do draft.