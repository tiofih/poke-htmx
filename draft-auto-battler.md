# Draft — Fases do auto-battler (detalhamento)
---

## Fase A — Esquadrão (montagem do time)

### A1. Reordenação manual de slots
- **Objetivo:** permitir mover um membro do time entre slots (1..6) — hoje a 0007 só
  reindexa na remoção. A ordem resultante é input explícito do combate.
- **Decisões de design:** rota `POST /team/:id/move` (ou `PATCH`) com `new_slot`;
  reposicionar e reindexar os demais; slot fora de 1..6 ou id de outro usuário →
  idempotente (mantém o time). UI: botões ▲/▼ por membro no fragmento `#team` (htmx,
  RNF-01).
- **Critérios de aceite (esboço):**
  - `[ ]` `#move(user_id, id, new_slot)` reordena e mantém slots contíguos 1..N.
  - `[ ]` Slot alvo `1..size(team)` válido; fora disso não quebra (mantém time).
  - `[ ]` Só afeta o time do próprio usuário; isolamento (RF-05).
  - `[ ]` ▲/▼ (e numeração) re-renderizam `#team` na ordem nova, sem JS customizado.
  - `[ ]` Testes sem rede + suíte/lint verdes + commit por green.
- **Plano TDD [0]** repo `#move` + documento; **[1]** rota; **[2]** UI ▲/▼; **[3]** isolamento/regressão.

### A2. UI: layout e estilos externos
- **Objetivo:** extrair layout/navbar/estilos compartilhados (a antiga "0007-UI",
  estrada como 0008+). Preparar telas mais ricas (batalha não acontece em página crua).
- **Decisões:** layout único em `views/layout.erb`, CSS externo (substitui sakura CDN ou
  embolha sobre ele); fragmentos mantêm o mesmo contrato htmx.
- **Critérios:** `[ ]` `GET /` usa layout único; `[ ]` navegação (lista/time/detalhe)
  consistente; `[ ]` 0 regressão nas rotas/fragmentos atuais.

---

## Fase B — Núcleo do game loop (domínio, SEM rede)

### B1. Modelo de batalha
- **Status:** em execução — sessão 0009 (RF-09), implementado aguardando validação.
- **Objetivo:** transformar `Pokemon` em unidade de combate (covarde = do board).
- **Decisões:** `BattlePokemon` pura (Dry::Struct ou dado simples): `hp_max` derivado do
  base stat HP, `hp_current`, `types`, `stats`, `energy`... estado por rodada; métodos
  `take_damage`, `alive?`, `fainted?`. (em 0009: `hp_max` = HP bruto, `take_damage`
  funcional/imutável; `energy` ficou anotado para jogadas futuras — fora do escopo 0009).
- **Critérios:** `[x]` conversão de `Pokemon` → `BattlePokemon` (`hp_max` calculado) — sessão 0009;
  `[x]` `take_damage` reduz HP sem ir negativo; `[x]` `alive?`/`fainted?`
  coerentes; `[x]` 100% de domínio puro (sem PG, sem rede).
- **Plano TDD:** passos 0–5 verdes (75 runs/319 asserts) — aguardando validação.

### B2. Efetividade de tipos
- **Status:** Done — sessão 0010 (RF-10) validada em 2026-08-08.
- **Objetivo:** precisão de dano por tipo (fraqueza x2, resistência x0.5, imune x0, STAB).
- **Decisões:** fonte = tabela da PokéAPI (`damage_relations` de `GET /type/:name`),
  carregada com cache (como RF-01); lookup `(tipo_atacante, tipo_defensor) → fator`;
  STAB = 1.5 quando o atacante tem o tipo do golpe. `PokeApi.type_relations` carrega os
  18 tipos (memoizado) e `TypeEffectiveness` é puro (domínio) — `from_relations`,
  `factor`, `effectiveness` (multi-tipo), `stab` e `damage_multiplier`. Sem rede nos
  testes (stub `PokeApiStub.with_type`).
- **Critérios:** `[x]` fator correto para (fire → grass)=2, (fire→water)=0.5,
  (electric→ground)=0, STAB quando senão; tabela completa para os 18 tipos; cache —
  validado em 2026-08-08.
- **Plano TDD:** passos 0–7 verdes (93 runs/357 asserts) — lint 0 offenses.

### B3. Motor de auto-batalha (o game loop)
- **Status:** Done — sessão 0011 (RF-11), validado em 2026-08-08.
- **Implementado:** `BattleEngine` + `BattleResult` (`lib/battle_engine.rb`); `BattlePokemon#stat` (extensão B1); cobertura `test/battle_engine_test.rb`.

> **Nota RNG (anotado — iteração futura):** hoje o motor é 100% determinístico para
> testar/iterar rápido (decisão do usuário). Quando quiser variar as partidas, o
> `BattleEngine` (e o seletor de golpe) ganha um `rng` injetável (default
> `Random.new(0)`/seed fixa), preservando os testes com seeds. Não é escopo da 0011.
- **Objetivo:** simular 6v6 automático usando os 6 slots; retorna log + vencedor.
- **Decisões:** `BattleEngine` recebe dois times (`[BattlePokemon]` ordenados por slot);
  a cada rodada: todos os vivos agem em ordem de **Speed** (empate → time 0, depois slot
  menor); dano = `max(1, Attack−Defense)` × multiplicador do **melhor tipo** do atacante
  para o alvo (inclui STAB; melhor tipo imune → neutro); alvo = **primeiro vivo por slot**
  do adversário (estratégia injetável no futuro); HP 0 → KO; fim quando um lado zerar
  (danos nunca zeram → sem loop); log de ações (`round`, atacante, move_type, dano, KO);
  **100% determinístico** (sem RNG) — validado em 2026-08-08.
- **Critérios:** `[x]` `BattlePokemon#stat(name)` (default 1); `[x]` dano base
  `max(1, Attack−Defense)` com multiplicador por melhor tipo (STAB incluso); `[x]` ordem
  por Speed (desempate time 0 → slot); `[x]` 6v6 não perde com times parciais; `[x]` log
  completo e vencedor; `[x]` times vazios → derrota/empate; `[x]` domínio puro, sem rede;
  coberto 100% por unit tests; determinístico.
- **Plano TDD [0]**: `stat`; **[1]** esqueleto + rodada única; **[2]** dano (A−D min 1 +
  multiplicador); **[3]** move_type melhor tipo + neutro; **[4]** ordem por speed;
  **[5]** loop 6v6/winner; **[6]** log; **[7]** edge (times vazios/empate); **[8]** suíte/lint;
  **[9]** docs.

### B4. Oponente automático
- **Status:** Done — sessão 0012 (RF-12), validado em 2026-08-08.
- **Objetivo:** gerar adversário para o usuário enfrentar sem montar time próprio.
- **Decisões:** `OpponentGenerator` recebe `names:` (slugs candidatos, ex.
  `PokeApi.fetch_all`) + `size` (default 6) + `rng` injetável (default `Random.new`, seed
  em testes) + `fetcher` (default `PokeApi.method(:detail)`, stub nos testes);
  `team` sortear `size` slugs **sem repetição** e devolve `[BattlePokemon]` na ordem do
  sorteio (posição = slot, pronto p/ `team_b` do `BattleEngine`); domínio puro (sem
  rede/PG); determinístico sob seed.
- **Critérios:** `[x]` gera time do tamanho definido (default 6; `names` menor → total
  disponível); `[x]` sem duplicados no time; `[x]` `names == []`/`size <= 0` → `[]`; `[x]` mesmo
  seed → mesmo time/ordem; `[x]` domínio puro (stubs nos testes); `[x]` RF-01..RF-11 sem
  regressão.

## Fase C — Batalha na web (htmx)

### C1. Batalha por htmx
- **Objetivo:** expor a simulação na UI com 100% htmx.
- **Decisões:** `GET /battle` (escolhe oponente/define os lados), `POST /battle/play`
  (avança rodada rumando o motor) → fragmento com dois painéis (time x oponente),
  HP atual, log do último round; fim de batalha mostra vencedor e botão "Rematch".
  O saque é server-rendered; htmx troca `#battle` (innerHTML).
- **Critérios:** `[ ]` estados (pre/battle, playing, fim) gerenciados no servidor;
  `[ ]` cada "jogar" avança 1 rodada e devolve fragmento; `[ ]` HP/time/resultado
  visíveis; `[ ]` sem JS custom (RNF-01); testes via stub do motor.
- **Status (sessão 0013):** implementado como **RF-13** — steps 0–7 verdes (135
  runs/481 asserts) e lint 0; **validado pelo usuário em 2026-08-09**.

## Fase D — Opcionais (anotados — NÃO agendar agora)

### D1. Golpes (moves/PP) por Pokémon
- **Objetivo:** dar "multi-move" à simulação (em vez de só atacar). 
- **Pontos:** PokéAPI `/move` (nome, tipo, power, accuracy, pp); memoizar 4 moves por
  Pokémon; o motor escolhe (aleatório/peso por estado/estratégia); pp decai.
- **Impacto:** revisita B2/B3; tabela de moves é pesada → cache.
- **Critérios (esboço):** `[ ]` pokémon com lista de moves limitada (ex.: 4); `[ ]`
  motor usa o gasto correto de `pp`; `[ ]` escolha determinística testável.

### D2. XP/evolução que melhora stats
- **Objetivo:** progressão entre batalhas (XP → melhorar stats, evoluir o Pokémon).
- **Pontos:** tabela ou fragmento de progressão por usuário; vitória/derrota aplica
  XP; stats derivados dos base + nível; evolução collapsa evolutions (RF-06).
- **Risco:** persistir progressão por usuário em nova tabela `team_pokemons` (coluna
  level/xp) ou `battle_stats`.

### D3. Histórico/rank de batalhas
- **Objetivo:** registrar resultado das partidas por usuário.
- **Pontos:** nova tabela `battles` (`user_id, result, opponent_team(serialize),
  created_at`); página/endpoint de histórico + ranking de vitórias.

### D4. Modos de draft temático
- **Objetivo:** composição com restrição (ex.: 1 Pokémon por tipo, "time aquático",
  ban de lendiários...).
- **Pontos:** regras de validação na montagem (estende RF-07); pode cruzar com A1.

---

## Refatorações a revisar (anotadas na sessão 0007)

- **Reduzir `rubocop:disable` nos testes:** em `test/server_test.rb`,
  `test/team_repository_test.rb` e `test/schema_test.rb` há disables de
  `Metrics/AbcSize` / `Metrics/MethodLength` / `Metrics/ClassLength`. Refatorar para
  extrair helpers/builder de fixture (ex.: `build_pokemon(n)`, montar times via
  loop único) e reduzir asserts por método, com objetivo de remover os disables e
  voltar a métricas padrão. Fora do fluxo (RNF-04); vira sessão própria após a 0007.
- **Sugestões:** teste de schema (`index_exists`) encapsular em `TestDatabase`
  (helper de introspection, aproveitável nas próximas migrações); `team_repository_test`
  ganhar factories simples (`build_pokemon(name, number)`).

---

## Próximos passos (fora deste arquivo)

1. **0007**: implementar + validar (TDD) — montagem de times é pré-requisito de B/C.
2. Logo após validar: **elencar o que fica e o que sai** da lista acima,
   definir ordem e transformar os escolhidos em **documentos de sessão** com
   critérios fechados e plano TDD (como a 0007).
3. **Nota:** B3 (motor) destrav não depende de B1/B2 sequenciais A/B — ordem sugerida:
   B1 → B2 → B3 → B4 → C1. A1/A2 podem entrar em paralelo ao game loop se desejado.
