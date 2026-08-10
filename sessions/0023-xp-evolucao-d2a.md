# Sessão 0023 — D2-A: Progressão persistida (XP/nível) — `team_pokemon_progress` + `ExperienceCurve` + `RewardRule`

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluído — decisões do usuário em 2026-08-10 (D2 dividida em A/B; tabela nova; curva linear; recompensa simples) |
| Implementação | Pendente |
| Validação | Pendente |

---

## 1. Objetivo

**Criar a base de progressão entre batalhas (**D2-A** do roadmap — item 21; decisões 2–5
da seção 8 do `draft-arquitetura-design-patterns.md`): XP → nível persistidos por usuário,
com **`ExperienceCurve` linear**, **`RewardRule`** concedendo XP no hook `:finished` da
batalha (half-FSM) e **stats que escalam com o nível**. O **oponente escala com o nível
médio do time do jogador**.**

Hoje a batalha é pura simulação (B/C/D1, sessões 0009–0017): `BattleEngine` roda, devolve
`winner`/`log`, e nada é persistido — `BattleRegistry` é efêmero. Ela deixa de ser só
simulação e vira **loop de progressão persistida**: a cada batalha o membro do time ganha
XP, o nível sobe, os stats escalam — e o próximo confronto já reflete o progresso.

**D2-B (sessão 0024 — NÃO nesta sessão, RNF-04):** evolução por nível e aprendizado de
golpes por nível, com **dados oficiais da species** (decisão do usuário em 2026-08-10:
`evolution chain` + `level_learned_at`). D2-A **não** altera `Pokemon`/`BattlePokemon` com
evolução nem mexe na lista de moves.

**Sequência mantida:** E1-A/B (feitas) → **D2-A (esta)** → **D2-B (0024)** → D3 → Eco-1..4.

## 2. Contexto (estado atual — pós-0022)

- Suíte base **256 runs/849 asserts**, lint 0 (E1-B, 2026-08-10). Tabela `team_pokemons`
  (`id, user_id, name, sprite, number, slot, moves TEXT[]`, sessões 0003/0007/0017).
- `TeamRepository` (`lib/team_repository.rb`): `all(user_id)`, `add(user_id, pokemon)`,
  `remove(user_id, id)`, `move`, `set_moves` — tudo por usuário; `SlotOperations` em transação.
- `BattleEngine` (`lib/battle_engine.rb`): `finished?`/`winner` **computados por inspeção**
  (0 = time A/jogador, 1 = time B, `nil` = empate); puro e determinístico.
- `BattlePokemon` (`lib/battle_pokemon.rb`): `from(pokemon, moves:)` deriva `hp_max` do stat
  HP; `stat(name)` devolve o valor do stat. **Sem nível**.
- `OpponentGenerator` (`lib/opponent_generator.rb`): `(names:, size:, rng:, fetcher:)` → `team`
  monta `BattlePokemon.from(fetcher.call(name))` — **sem nível**.
- `server.rb` (C1/RF-13): `GET /battle` monta o time do jogador via
  `BattlePokemon.from(detail, moves: battle_moves_for(member))`, oponente via
  `OpponentGenerator(..., fetcher: settings.api.method(:detail))`, engine em `BattleRegistry`;
  `POST /battle/play` chama `@engine.play_round` e re-renderiza `battle.erb`.
- `TestDatabase.clear_team!` faz `TRUNCATE team_pokemons` — **precisa ganhar a tabela nova
  (CASCADE/listar) quando a FK existir**.

## 3. Critérios de aceite

### Resultado

- [ ] **Migração idempotente `0023_add_team_pokemon_progress.sql`**: tabela nova
      `team_pokemon_progress` (`team_pokemon_id INTEGER PRIMARY KEY REFERENCES
      team_pokemons(id) ON DELETE CASCADE`, `level INTEGER NOT NULL DEFAULT 1`,
      `xp INTEGER NOT NULL DEFAULT 0`, `created_at`/`updated_at TIMESTAMPTZ NOT NULL DEFAULT
      now()`) — sem `TRUNCATE`; `TestDatabase.clear_team!` atualizado (lista `team_pokemons,
      team_pokemon_progress` ou `CASCADE`) para a FK não quebrar o truncate.
- [ ] **`lib/experience_curve.rb`** — política pura `ExperienceCurve` (molde
      `TypeEffectiveness`): `xp_needed(level) = level * 100` (XP para passar de `level` a
      `level+1`); `level_for_xp(xp)` inverso (0–99→1, 100–299→2, 300–599→3, 600+→4); `Default`
      em `lib/` raiz (sem novo diretório — reorganização em `lib/repositories/` fica anotada).
- [ ] **`TeamRepository#add` cria a linha de progresso** (level 1, xp 0) **na mesma
      transação** do `INSERT` em `team_pokemons` (invariante da decisão 4 — "sempre nível 1 na
      montagem"); `#remove` limpa via `ON DELETE CASCADE`. Registro em `team_pokemons` sem
      progresso → não deve existir no fluxo.
- [ ] **`lib/progression_repository.rb`** — `ProgressionRepository` espelha `TeamRepository`
      (PG, por usuário): `get(user_id, team_pokemon_id)` → `{level:, xp:}` ou `nil` (valida
      dono via `team_pokemons.user_id`); `grant(user_id, team_pokemon_id, xp)` soma XP,
      recalcula nível via `ExperienceCurve`, persiste e devolve `{level:, xp:}` novos;
      membro de outro usuário / id inexistente → `no-op` (padrão RF-05/RF-08).
- [ ] **`RewardRule`** (`lib/reward_rule.rb`) — política pura que **já estrutura o hook
      `:finished`** (seção 6.1; Eco-1 reaproveitará para moeda): `xp_for(result)` → `:win`
      50, `:draw` 25, `:lose` 20 (constantes `DEFAULT_*`, opcionalmente injetáveis); XP **por
      membro do time** (todos os membros, vivos ou desmaiados; balanceamento fino adiado —
      decisão 5).
- [ ] **`BattleEngine#result`** (half-FSM leve, seção 6.1): devolve `nil` enquanto
      `:in_progress`; após o fim, `:win`/`:draw`/`:lose` **da perspectiva do time A** (0→win,
      1→lose, `nil`+finished→draw). Simples enum/valor — **não** é FSM GoF; `finished?`/`winner`/
      `battle` intactos (0 regressão em B3/C1). `:preparing` não se aplica ao motor (é
      construído pronto) — anotado.
- [ ] **`BattlePokemon` com nível**: attribute `level` (default 1, em `from(pokemon, moves:,
      level: 1)`); stats **escalam**: `(base + (level - 1) * 0.5).round`; `hp_max`/`hp_current`
      derivados do HP escalado; `stat(name)` devolve o valor escalado (dano/ordem usam o
      escalado). Sem `level`/`level: 1` → stats idênticos aos de hoje (0 regressão)
      e `battle_pokemon_test`/`battle_engine_test` verdes sem edição.
- [ ] **`OpponentGenerator` com `level:`** (default 1): `team` monta `BattlePokemon.from(fetcher
      .call(name), level: @level)` — oponente no nível do jogador sem novas chamadas à API.
- [ ] **`server.rb` (C1 + XP)**: `settings.progression = ProgressionRepository.new`;
      `GET /battle` monta o time do jogador com o **nível de cada membro**
      (`progression.get(current_user, member.id)`), oponente com `level` = **nível médio
      (arredondado)** do time do jogador; `POST /battle/play` — ao **transicionar** para
      `finished?` (era `finished? == false` antes do round e virou `true`), concede XP **uma
      única vez** por engine (guard de transição): `RewardRule.xp_for(@engine.result)` × cada
      membro via `progression.grant`; `battle.erb` mostra "Nível N" por lutador e aviso
      "Seu Time ganhou X XP" ao fim; sem regressão nas rotas existentes.
- [ ] Linha de progresso **atualizada após a batalha**: `GET /battle` (novo confronto) reflete
      o XP/nível acumulado dos confrontos anteriores (persistência real, não só memória).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (256 runs/849 asserts)** + novos testes
      e lint 0 em **todo** green; commit obrigatório por passo; 0 regressão RF-01..RF-18.
- [ ] Sem novas gems; políticas puras testadas **sem rede** (ao molde de `TypeEffectiveness`);
      testes de rota com stubs existentes (`PokeApiStub.with_gateway`/`with_detail`/`with_moves_for`).
- [ ] `TeamRepository#all`/`battle_engine` com `BattlePokemon` sem nível seguem sem mudança
      (0 regressão); só `add`/`from`/rotas de batalha tocam o novo estado.
- [ ] `draft-arquitetura-design-patterns.md` (seções 2/6/8 — D2-A feita, D2-B próxima),
      `REQUIREMENTS.md` (roadmap 21 = D2-A executado em 0023; D2-B fica Planejada),
      `SESSIONS.md` (tabela 0023 + próxima sessão 0024) e `draft-auto-battler.md` (D2 visão
      parcial — XP/nível em 0023, evolução/aprendizado em 0024) atualizados no mesmo escopo;
      *status de validação* só após o usuário validar.

## 4. Decisões de refinamento (fechadas com o usuário em 2026-08-10)

- **D2 dividida em D2-A e D2-B** (decisão do usuário): esta sessão (0023) = XP/nível
  persistidos + `ExperienceCurve` linear + `RewardRule` no hook `:finished` + stats escalam
  + oponente escala. **D2-B (0024)** = evolução por nível e aprendizado de golpes por nível
  — fora do escopo desta sessão (RNF-04).
- **Tabela nova `team_pokemon_progress`** (draft decisão 3), **chave por `team_pokemon_id`**
  (decisão do usuário): FK `REFERENCES team_pokemons(id) ON DELETE CASCADE` — a progressão
  segue o membro; remover o membro limpa o progresso; evolução (D2-B) muda o `number` sem
  quebrar a chave (id é estável). Isolamento por usuário via join com `team_pokemons.user_id`.
- **Estado de montagem** (draft decisão 4, confirmado): 1ª evolução, sempre nível 1, xp 0 na
  montagem — `TeamRepository#add` cria a linha de progresso na mesma transação.
- **Curva linear "por ora"** (draft decisão 5 + defaults do usuário): `xp_needed(level) = level
  × 100`; recompensa `RewardRule`: vitória +50/pokémon, derrota +20, empate +25; stats escalam
  `base + (nível − 1) × 0.5` arredondado. Balanceamento fino adiado.
- **Fonte da D2-B (mobilizada neste refinamento, aplicada na 0024):** **dados oficiais da
  species** — `evolution_chain` + `level_learned_at` (decisão do usuário) em vez de níveis
  fixos padrão; registrado no draft para a sessão 0024.
- **Half-FSM leve (seção 6.1 do draft) só no terminal:** `BattleEngine#result`
  (`nil`/`:win`/`:draw`/`:lose`) como guard/valor para o hook `:finished` — sem FSM estrita
  (anti-padrão, YAGNI); `finished?`/`winner` preservados.
- **`RewardRule` estrutura o hook único de recompensa** (seções 6/6.1): XP hoje; Eco-1
  (moeda) adiciona o dinheiro no mesmo `xp_for`/grant sem duplicar.

## 5. Plano TDD (passos)

> Cada passo = `red` → `green` (lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo de sessão com critérios e plano fechados + nota de D2-B no draft | commit `Sessao 0023: refinamento concluido — D2-A (XP/nivel): tabela team_pokemon_progress + ExperienceCurve linear + RewardRule no hook :finished + stats escalam + oponente escala; D2-B (evolucao/aprendizado, species oficial) fica para 0024` |
| 1 | **Migração + `TestDatabase.clear_team!`:** `0023_add_team_pokemon_progress.sql` (tabela nova idempotente com FK cascade); `clear_team!` lista a tabela nova. `red`: teste de schema/introspection falha (tabela/colunas ausentes) e `clear_team!` quebra com FK. `green`: migração + ajuste | suíte verde + lint 0 |
| 2 | **`ExperienceCurve` (puro):** `xp_needed(level)`/`level_for_xp(xp)` linear. `red`: `experience_curve_test.rb` novo falha (classe inexistente). `green`: implementar | suíte verde + lint 0, commit `Passo 2:` |
| 3 | **`TeamRepository#add` cria progresso (level 1/xp 0) na mesma transação; `#remove` limpa (cascade):** `red`: `team_repository_test` novo assere registro de progresso após `add` e ausência após `remove`. `green`: implementar (INSERT + progresso no mesmo tx) | suíte verde + lint 0, commit `Passo 3:` |
| 4 | **`ProgressionRepository`:** `get(user_id, team_pokemon_id)` (dono/isolamento) e `grant(user_id, team_pokemon_id, xp)` (soma + nível via `ExperienceCurve`, no-op para estranho). `red`: `progression_repository_test.rb` novo falha. `green`: implementar | suíte verde + lint 0, commit `Passo 4:` |
| 5 | **`BattlePokemon` com nível + stats escalam:** attribute `level` default 1; `from(pokemon, moves:, level: 1)` escala `stats`/`hp_max` (`base + (level-1)*0.5` round); `stat` devolve escalado; sem nível → idêntico. `red`: `battle_pokemon_test` novo. `green`: implementar | suíte verde + lint 0, commit `Passo 5:` |
| 6 | **`RewardRule` (puro):** `xp_for(:win/:draw/:lose)` → 50/25/20. `red`: `reward_rule_test.rb` novo. `green`: implementar | suíte verde + lint 0, commit `Passo 6:` |
| 7 | **`BattleEngine#result` (half-FSM terminal):** `nil` no início, `:win`/`:lose`/`:draw` quando `finished?`; `winner`/`finished?`/`battle` intactos (0 regressão B3/C1). `red`: `battle_engine_test` novo. `green`: implementar | suíte verde + lint 0, commit `Passo 7:` |
| 8 | **`OpponentGenerator#level:`** default 1 → `BattlePokemon.from(fetcher.call(name), level: @level)`; `level:` explícito escala. `red`: `opponent_generator_test` novo. `green`: implementar | suíte verde + lint 0, commit `Passo 8:` |
| 9 | **`server.rb`: progressão na batalha** — `settings.progression`; `GET /battle` com nível de cada membro + oponente no nível médio; `POST /battle/play` concede XP (transição única → `:finished`) via `RewardRule`+`grant`; `battle.erb` mostra "Nível N" + "ganhou X XP". `red`: `server_test` novo (stubs). `green`: rotas + view | suíte completa verde + lint 0, commit `Passo 9:` |
| 10 | **Docs:** `draft-arquitetura` (D2-A feita; D2-B próxima com species oficial), `REQUIREMENTS.md` (roadmap 21 D2-A em 0023, D2-B Planejada), `SESSIONS.md` (tabela 0023 em fase 2 + próxima 0024), `draft-auto-battler.md` (D2 visão parcial) | suíte verde + lint 0, commit `Passo 10:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar `Done`/commitar conclusão antes. |

## 6. Validação (executada pelo usuário)

**Aguardando o usuário — não preencher até o feedback.**

## 6b. Progresso da implementação (passos 1–10)

> Preenchido durante a fase 2 (TDD). Não marcar como validado até o usuário validar. Ainda **não iniciado** (fase 2 pendente).

## 7. Observações

- **D2-B já decidida (não refinar agora, RNF-04):** evolução por nível + aprendizado de golpes
  por nível com **dados oficiais da species** (`evolution_chain`, `level_learned_at`) —
  anotado no `draft-arquitetura-design-patterns.md` para a sessão 0024.
- **`BattleRegistry` (efêmero) permanece** nesta sessão (draft decisão 8): a persistência aqui
  é a **progressão** (XP/nível); histórico de batalhas e/o rank são D3 — resolver no D3
  (registro persiste pelo time do jogador em `team_pokemon_progress`, não pelo confronto).
- **`lib/repositories/` (visão da seção 6)** fica anotado: `ProgressionRepository` nasce em
  `lib/` (padrão atual, `TeamRepository` em `lib/`); mover para diretório próprio é refatoração
  futura, fora do escopo.
- **XP por membro (vivos ou desmaiados):** decisão "simples por ora" — todos os membros do
  time ganham o valor do `RewardRule`; opções mais finas (só sobreviventes, escalonado por
  participação) ficam para balanceamento posterior (decisão 5).