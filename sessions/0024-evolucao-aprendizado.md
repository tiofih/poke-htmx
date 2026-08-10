# Sessão 0024 — D2-B: Evolução por nível + aprendizado de golpes por nível (dados oficiais da species)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluído — decisões do usuário em 2026-08-10 (fonte species oficial — dec. 15 do draft-arquitetura, fechada na 0023; unicidade `UNIQUE (user_id, number)` mantida) |
| Implementação | Concluída — passos 1–7, suíte 327/1018, lint 0 (2026-08-10) |
| Validação | Pendente — aguardando feedback do usuário |

---

## 1. Objetivo

**D2-B do roadmap (item 21b): evolução por nível + aprendizado de golpes por nível, com
dados oficiais da species** (`evolution_chain` + `level_learned_at` — decisão 15 da seção
8 do `draft-arquitetura-design-patterns.md`, já mobilizada na refinamento da sessão 0023).
No mesmo gancho da 0023 — a transição `:finished` de `POST /battle/play` (via half-FSM
`BattleEngine#result` + `RewardRule`) — o membro do time passa a:

- **Evoluir:** ao atingir o `min_level` oficial de um estágio da cadeia evolutiva, o
  `number`/`name`/`sprite` do membro mudam **sem romper a identidade do membro** —
  a chave `team_pokemon_id` é estável, então `team_pokemon_progress` (XP/nível) e
  `team_pokemons.moves` (golpes salvos) seguem o membro (invariante garantido pela
  migração 0023).
- **Aprender golpes:** ao atingir um nível, aprende os golpes oficiais com
  `level_learned_at <= nível` e método de aprendizado `level-up`; os golpes aprendidos
  entram na **lista persistida `team_pokemons.moves`** (cruz com D1/RF-15/RF-17),
  respeitando o cap `MAX_MOVES_PER_POKEMON` (4) — e a `battle.erb` passa a usar os
  golpes salvos (RF-17).

**Fora de escopo (RNF-04 — não abrir):** `BattleEngine` (motor puro intacto, 0
regressão); `RewardRule`/XP da 0023; a UI de gerenciamento de time (lista completa
RF-17 mantida); evolução/aprendizado do **oponente** (mantém os 4 defaults da RF-15 —
stats já escalam por nível da 0023); evoluções não-`level-up` (pedra/troca/amizade);
troca automática de golpes quando o cap está cheio.

**Sequência mantida:** E1-A/B (feitas) → D2-A (0023) → **D2-B (esta)** → D3 → Eco-1..4.

## 2. Contexto (estado atual — pós-0023)

- Suíte base **292 runs/941 asserts**, lint 0 (D2-A, 2026-08-10). Tabela `team_pokemons`
  (`id, user_id, name, sprite, number, slot, moves TEXT[]`, sessões 0003/0007/0017) +
  `team_pokemon_progress` (`team_pokemon_id INTEGER PRIMARY KEY REFERENCES
  team_pokemons(id) ON DELETE CASCADE`, `level`, `xp`).
- Índices únicos de RF-07: `idx_team_pokemons_user_number (user_id, number)` e
  `idx_team_pokemons_user_slot (user_id, slot)` — **ambos preservados** (decisão desta
  sessão: manter unicidade e não evoluir em conflito).
- `TeamRepository` (`lib/team_repository.rb`): `all`/`add`/`remove`/`move`/`set_moves`
  por usuário; `all(user_id)` devolve `Pokemon` com `id/name/sprite/number/slot/moves`
  (`ORDER BY slot`).
- `ProgressionRepository#grant` recalcula nível via `ExperienceCurve` (0023); `server.rb`
  concede XP **na transição única** para `:finished` em `POST /battle/play`
  (`was_in_progress && @engine.finished?`); `battle.erb` já mostra "Nível N" por lutador
  e o resumo "Seu Time ganhou X XP por Pokémon".
- Gateway `PokeApi` (interface em `lib/gateways/poke_api.rb`) + `PokeApiHttp` (parsing
  dividido em `PokeApiParsing`/`PokeApiMoves`/`PokeApiTypes`) + `PokeApiCache` (TTL
  600s/LRU 1000, decora `PokeApi.instance`) + `PokeApiFake`/`PokeApiStub.with_gateway`
  nos testes (sessões 0021/0022/0019).
- `PokeApiParsing#evolution_chain(species_url)` devolve `[Pokemon]` **flat** (nome/sprite
  por estágio, para o detalhe RF-06) — **sem** `trigger`/`min_level` → o dado novo
  (`next_evolutions`) precisa de parsing próprio do mesmo endpoint `evolution-chain`
  (deixa `evolution_chain` intacto, 0 regressão RF-06/RF-18).
- `PokeApiMoves#available_move_names(number)` devolve todos os nomes de moves — **sem**
  `level_learned_at`; `pokemon_data(number)` já resolve `GET /pokemon/:id`, cujas
  entries `moves[].version_group_details[]` trazem `level_learned_at` e
  `move_learn_method.name` — a base para `learnable_moves` está na mesma resposta.
- `server.rb` orquestra a batalha em `ServerBattleActions` (módulos por área, 0020):
  `playable_engine`, `player_team`, `opponent_team`, `grant_finished_xp` — onde o hook
  D2-B entra.

## 3. Critérios de aceite

### Resultado

- [ ] **Sem migração nesta sessão** (decisão do usuário em 2026-08-10): `UNIQUE
      (user_id, number)` e `UNIQUE (user_id, slot)` **mantidos** — a evolução respeita a
      unicidade com guard na `UPDATE` (sem 500).
- [ ] **`TeamRepository#evolve(user_id, id, pokemon)`** — atualiza `number`/`name`/`sprite`
      do membro do usuário em `team_pokemons`; `id`/`slot`/`moves`/linha de progresso
      **intactos** (FK stable); devolve `true` quando evolui; **no-op/`false`** quando o id
      não pertence ao usuário (RF-05) **ou** outro membro do mesmo time já tem
      `pokemon.number` (UNIQUE preservado — decisão do usuário; evita 500).
- [ ] **`TeamRepository#learn_move(user_id, id, move_name)`** — adiciona o move à lista
      salva `moves TEXT[]` quando: ainda não presente **e** `moves.size <
      MAX_MOVES_PER_POKEMON` (4); devolve `true` quando aprendeu; **no-op/`false`** quando
      já tem o move, cap cheio, ou id não é do usuário (isolamento RF-05).
- [ ] **`lib/evolution_rule.rb`** — política pura (molde `ExperienceCurve`/`RewardRule`):
      `EvolutionRule.next_stage(current_number:, level:, evolutions:)` → `{number:, name:}`
      do estágio **level-up alcançado** (`min_level` presente e `<= level`) com **menor
      `min_level`** (desempate: menor `number` — determinístico em cadeias ramificadas);
      `nil` quando nenhum alcançado ou `evolutions` vazio; ignora estágios sem `min_level`
      (pedra/troca/amizade — anotado, fora de escopo).
- [ ] **Gateway `next_evolutions(number)`** (em `PokeApiParsing`, entrada na interface
      `PokeApi`): devolve `[{number:, name:, min_level:}]` dos **próximos** estágios do
      `number` atual — somente estágios com `trigger == "level-up"` e `min_level` presente;
      `[]` quando sem evolução/espécie inexistente/status ≠ 200/rede/parse inválido
      (robustez RF-18); `evolution_chain`/`detail` **intactos** (0 regressão RF-06/RF-18).
- [ ] **Gateway `learnable_moves(number)`** (em `PokeApiMoves`, entrada na interface
      `PokeApi`): `[{level:, name:}]` — por move, **menor `level_learned_at`** entre as
      entries `version_group_details` com `move_learn_method.name == "level-up"`;
      ordenado por `[level, name]`; métodos machine/tutor/egg **não** entram (anotado);
      `[]` quando `pokemon_data` → `nil`/sem moves; `available_move_names`/`moves_for`
      intactos (0 regressão).
- [ ] **`PokeApiCache`** decora os 2 métodos novos (`next_evolutions`, `learnable_moves`)
      com cache TTL/LRU (contrato E1-B); **`PokeApiFake`** ganha configs
      `next_evolutions:`/`learnable_moves:` (resolução por número, como `detail`) e
      **`PokeApiStub`** ganha helpers (`with_next_evolutions`/`with_learnable_moves`) —
      testes sem rede.
- [ ] **`server.rb` (hook `:finished` estendido, 0023):** `POST /battle/play` — após o
      grant de XP (uma única vez), para **cada membro** do time: (1) lê o nível novo via
      `progression.get`; (2) **evolui em loop** (um estágio por vez): `api.next_evolutions
      (number)` → `EvolutionRule.next_stage` alcançado → `api.detail(target.number)` →
      `team.evolve` (se `false`, para — unicidade) — repete até `nil`/recusa;
      (3) **aprende** com a species final: `api.learnable_moves(number)` filtrando
      `level <= nível novo` → `team.learn_move` (coleta os moves efetivos). Acumula
      `@evolution_news`/`@learned_news` para o fragmento; sem regressão nas rotas.
- [ ] **`battle.erb`**: ao fim (`@engine.finished?`) mostra os avisos — evolução
      ("X evoluiu para Y!") e aprendizado ("X aprendeu Z!"); http quando a evolução
      esbarra na unicidade, "X não evoluiu — Y já está no time."; 0 regressão nos
      painéis/Nível/XP/log (formato da RF-16 preservado).
- [ ] **Ordem determinística**: evolução **antes** do aprendizado (species final define os
      golpes aprendíveis); um só ponto de gancho (o `:finished` da 0023).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (292 runs/941 asserts)** + novos
      testes e lint 0 em **todo** green; commit obrigatório por passo; 0 regressão
      RF-01..RF-18.
- [ ] Sem novas gems; política pura (`EvolutionRule`) testada **sem rede**; parsing com os
      mesmos stubs de `Faraday` de `poke_api_test`; rotas com `PokeApiStub.with_*`
      (sem rede); sem `rubocop:disable`.
- [ ] `TeamRepository#evolve`/`#learn_move` seguem o padrão por usuário (RF-05): no-op
      para id de outro usuário; `set_moves`/`add`/`remove` intactos.
- [ ] `draft-arquitetura-design-patterns.md` (seções 2/6/8 — D2-B feita, D3 próxima),
      `draft-auto-battler.md` (D2 visão fechada — evolução/aprendizado em 0024),
      `REQUIREMENTS.md` (roadmap 21b = D2-B executado em 0024; **status `Planejada` até a
      validação do usuário**), `SESSIONS.md` (tabela 0024 em fase 2 + próxima sessão D3)
      atualizados no mesmo escopo; *status de validação* só após o usuário validar.

## 4. Decisões de refinamento (fechadas com o usuário)

- **Fonte da D2-B (decisão 15 do draft-arquitetura, fechada na 0023 e aplicada aqui):**
  **dados oficiais da species** — `evolution_chain` (species → evolution-chain, dá o
  `min_level`/`trigger` por estágio) + `level_learned_at` (entries `moves` do
  `GET /pokemon/:id`, com `version_group_details`) — **não** níveis fixos padrão.
- **Só evolução por `level-up`**: estágios sem `min_level` (pedra/troca/amizade/
  condição especial) ficam **fora de escopo** — anotado no draft (itens evolutivos
  podem entrar na fase Eco-3/Poke Mart).
- **Evolução um estágio por vez**: `next_evolutions` devolve os **próximos** estágios do
  `number` atual; a orquestração **loop** evolui um de cada vez até o topo alcançado
  (sem saltar a cadeia — charmander → charmeleon → charizard por etapas).
- **`EvolutionRule.next_stage`** escolhe o estágio level-up alcançado de **menor
  `min_level`** (determinístico; cadeias ramificadas — ex. eevee — resolvem por número).
- **Evolução preserva identidade**: muda só `number`/`name`/`sprite` via
  `TeamRepository#evolve`; `team_pokemon_id` estável → progresso (XP/nível da 0023) e
  `moves` continuam — base da migração 0023.
- **UNIQUE `(user_id, number)` MANTIDO — decisão do usuário (2026-08-10):** sem
  migração; `evolve` com guard — se um membro já tem o `number` da evolução no mesmo
  time, **não evolui** e o fragmento avisa ("X não evoluiu — Y já está no time.").
  RF-07 intacto (montagem sem duplicado) e sem 500. **Alternativa descartada:** dropar
  o índice e permitir duplicados pós-evolução.
- **Aprendizado só por método `level-up`**, com o **menor `level_learned_at`** entre os
  version groups; machine/tutor/egg não entram (anotado).
- **Cap 4 (`MAX_MOVES_PER_POKEMON`)**: aprende enquanto a lista salva tiver < 4; já
  tem o move → no-op; cap cheio → não aprende e avisa (sem troca automática — a troca
  segue no gerenciamento RF-17; candidato futuro anotado).
- **Ordem no hook**: evolui primeiro (species final), depois aprende (golpes da species
  final com `level <= nível novo`).
- **Oponente sem evolução/aprendizado** neste escopo (mantém 4 defaults da RF-15 via
  `battle_moves_for`; stats já escalam por nível — 0023).
- **UI só em `battle.erb`** (avisos ao fim da batalha); manage continua mostrando a
  lista completa da RF-17 — o jogador pode escolher golpe acima do nível (liberdade
  preservada; gating por nível fica como candidato — D1 parcial/nível de aprendizado).
- **Sem FSM GoF**: `EvolutionRule` é política pura determinística (mesmo princípio da
  0023); `BattleEngine` não muda.

## 5. Plano TDD (passos)

> Cada passo = `red` → `green` (lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo de sessão com critérios e plano fechados | commit `Sessao 0024: refinamento concluido — D2-B (evolucao por nivel + aprendizado por nivel, species oficial): evolution_chain + level_learned_at, UNIQUE mantido, garra no :finished da 0023` |
| 1 | **`TeamRepository#evolve` + `#learn_move`:** `red` — `team_repository_test` novo falha (métodos ausentes): evolve muda `number/name/sprite` (id/slot/moves/progresso intactos; `true`); no-op/`false` para outro usuário e para number já no time (UNIQUE); learn_move adiciona até o cap 4 (sem dup, `true`); no-op/`false` para dup, cap cheio e outro usuário. `green` — implementar | suíte verde + lint 0, commit `Passo 1:` |
| 2 | **`EvolutionRule` (puro):** `red` — `evolution_rule_test.rb` novo falha (classe inexistente): menor `min_level` alcançado, `nil` sem estágio alcançado / `evolutions` vazio, ignora `min_level` nulo, desempate por número. `green` — implementar | suíte verde + lint 0, commit `Passo 2:` |
| 3 | **Gateway `next_evolutions(number)`:** `red` — `poke_api_test` novo falha: parsing do chain (`trigger == "level-up"`, `min_level`, `[{number:, name:, min_level:}]`); `[]` sem evolução/espécie/id fora da cadeia/status ≠ 200/rede/parse. `green` — `PokeApiParsing#next_evolutions` | suíte verde + lint 0, commit `Passo 3:` |
| 4 | **Gateway `learnable_moves(number)`:** `red` — `poke_api_test` novo falha: `min(level_learned_at)` por move só `level-up`, ordenado `[level, name]`; `[]` p/ `pokemon_data → nil`/sem moves. `green` — `PokeApiMoves#learnable_moves` | suíte verde + lint 0, commit `Passo 4:` |
| 5 | **Plumbing:** `red` — `poke_api_cache_test`/fake falha: `PokeApiCache#next_evolutions/#learnable_moves` usam cache; `PokeApiFake` resolve por número; `PokeApiStub.with_next_evolutions/with_learnable_moves`. `green` — decorator + fake + stubs | suíte verde + lint 0, commit `Passo 5:` |
| 6 | **`server.rb` + `battle.erb`:** `red` — `server_test` novo falha (stubs): ao `:finished`, membro em níveis que atravessam `min_level` **evolui** (DB com `number/name/sprite` novos; id/moves/progresso intactos); sem estágio alcançado não muda; unicidade → não evolui + aviso; `learnable_moves` com `level <= nível` **aprende** (moves salvos crescem até 4); `battle.erb` exibe "X evoluiu para Y!"/"X aprendeu Z!". `green` — loops no hook + view | suíte completa verde + lint 0, commit `Passo 6:` |
| 7 | **Docs:** `draft-arquitetura` (D2-B feita; D3 próxima), `draft-auto-battler.md` (D2 visão fechada), `REQUIREMENTS.md` (roadmap 21b D2-B executado em 0024 — status `Planejada` até validação), `SESSIONS.md` (tabela 0024 em fase 2 + próxima D3) | suíte verde + lint 0, commit `Passo 7:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar `Done`/commitar conclusão antes. |

## 6. Validação (executada pelo usuário)

**Pendente.** Ao final da fase 2, o usuário roda `./scripts/test` (suíte completa) e
`./scripts/lint`, confere o comportamento manualmente (batalha com membro que atravessa
`min_level` de evolução e/ou aprende golpe) e verifica os critérios de aceite (seção 3).
Resultado e status desejado preenchidos aqui após o feedback.

## 7. Observações

- **Próxima sessão após 0024:** **D3 — histórico/rank de batalhas** (decisões 2/9–13 do
  `draft-arquitetura-design-patterns.md`), depois Fase Eco (Eco-1 moeda, Eco-2 Poke
  Center, Eco-3 Poke Mart, Eco-4 itens em batalha), depois candidatos (D4, D1 nível de
  aprendizado gating, J1, J2, J3).
- **Notas para o draft (fora do fluxo desta sessão, RNF-04):**
  - Evoluções não-`level-up` (pedra/troca/amizade) e **itens evolutivos** → candidatos
    para a Fase Eco (Eco-3 Poke Mart).
  - Cap de golpes cheio: **troca automática** (golpe novo substitui o mais fraco/antigo)
    como candidato futuro (hoje: não aprende + aviso).
  - **Gating do manage por nível** (checkbox só dos `level <= nível`) como candidato
    (D1 parcial / nível de aprendizado) — hoje a lista completa da RF-17 permanece.
  - `version_group_details`: usar **menor `level_learned_at`** (mais cedo que aprende em
    alguma geração) — decisão simples e determinística; seguindo a nota da D1.