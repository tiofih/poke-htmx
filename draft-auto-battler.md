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
- **Status:** Done — **RF-14** (sessão 0014), validado pelo usuário em 2026-08-09
  (suíte final 146 runs/553 asserts, lint 0). Durante a validação: ajustes de robustez
  — `GET /battle/close` limpa `#battle` ao sair da aba, `PokeApi.find` tolera espécie
  sem `/pokemon` (404) e sprite `front_default` nulo.
- **Objetivo:** extrair layout/navbar/estilos compartilhados (a antiga "0007-UI",
  estrada como 0008+). Preparar telas mais ricas (batalha não acontece em página crua).
- **Decisões:** layout único em `views/layout.erb` (+ nav Lista/Time/Batalha na página
  única, sem novas rotas), CSS externo (sakura CDN como base + `public/style.css`
  sobreposto — decisão do usuário); fragmentos mantêm o mesmo contrato htmx
  (`layout: false`, resposta parcial).
- **Critérios:** `[x]` `GET /` usa layout único (um único `<html>`); `[x]` navegação
  (lista/time/detalhe) consistente; `[x]` 0 regressão nas rotas/fragmentos atuais.

### A3. Página própria de gerenciamento de time (slot + golpes)
- **Status:** anotado — não agendar agora (fora do fluxo, RNF-04).
- **Objetivo:** criar uma **página própria** para gerenciar o time onde o usuário possa
  **escolher a posição (slot) de cada Pokémon** e **escolher os golpes de cada um**
  (hoje: posição só via ▲/▼ no fragmento `#team` (A1/RF-08) e golpes são fixos —
  últimos 4 da PokéAPI — com escolha determinística pelo motor (D1/RF-15)).
- **Pontos:** UI dedicada por membro do time (não mais fragmento único); seleção de
  golpes usando `PokeApi.moves_for(number)` como candidatos; persistir a escolha de
  golpes por usuário (novo dado na `team_pokemons` ou por Pokémon escolhido — cruza
  com D1, D2, sobretudo se XP/level entrar); reordenar slots dentro da página própria.
- **Decisão a tomar em refinamento:** os golpes escolhidos devem **persistir** (estado
  persistente) ou vale o seletor runtime por batalha? **Fonte dos golpes** (lista
  completa vs 4 defaults da D1)? Como a escolha do usuário interage com o motor
  determinístico (D1) — o usuário escolhe o **conjunto** de golpes, o motor continua
  escolhendo qual usar a cada ação.
- **Impacto:** revisita A1 (slots), D1 (golpes) e a camada web/rotas; candidata forte
  a sessão própria após a 0015 (e depende de que more gems/schema decididas em
  refinamento). Anotado em 2026-08-09 durante a validação da sessão 0015.

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

> **Nota (anotado — iteração futura): melhorar os logs de batalha.** Hoje o log de
> cada ação mostra apenas o **lado** atacante ("Seu Time" / "Oponente"), o golpe e o
> dano — não diz **qual Pokémon** bateu em **qual Pokémon**. Melhoria desejada
> (validada pelo usuário em 2026-08-09, durante a validação da sessão 0015): o log
> deve indicar **quem atacou quem**, com **qual golpe** e o **dano causado**
> (ex.: "Seu Time: pikachu usou thunder-shock em bulbasaur, 12 de dano"). Exige
> carregar o nome do atacante e do alvo no entry do `BattleEngine` (ou resolver via
> `teams[team_index][index]`) e re-renderizar em `battle.erb`. Fora do fluxo
> (RNF-04): vira sessão própria após a 0015 ser validada.

## Fase D — Opcionais (anotados — NÃO agendar agora)

### D1. Golpes (moves/PP) por Pokémon
- **Status:** Done — **RF-15** (sessão 0015), validado pelo usuário em 2026-08-09
  (suíte completa 171 runs/610 asserts, lint 0).
- **Decisões (fechadas com o usuário em 2026-08-09):** escolha do golpe
  **determinística** (maior dano esperado = power × efetividade × STAB; desempate
  power/ordem; sem RNG); fallback **Struggle determinístico** (power 10, tipo do
  atacante, sem PP) quando todos PP zerados ou só status moves; logo + PP no painel
  (sem seletor). `BattlePokemon` sem `moves` mantém o caminho legado (0 regressão).
- **Implementado:** `lib/move.rb` (`Move` Dry::Struct: name/type/power/accuracy/pp);
  `BattlePokemon#moves` + `from(pokemon, moves:)` + `use_move(index)` (PP decai);
  `PokeApi.moves_for(number)` (até 4, últimos da lista, memoizado) + `PokeApi.move(name)`
  (memoizado); `BattleEngine` escolhe golpe (dano esperado), dano usa o power do golpe
  (`max(1, A−D) × power/50 × multiplicador`), log ganha `move`; Struggle fallback;
  `GET /battle` carrega golpes dos dois lados e `battle.erb` mostra `move — PP n` +
  nome do golpe no log.
- **Nota RNG (anotado — iteração futura):** escolha de golpe é determinística neste
  escopo (decisão do usuário). Variar partidas/falhas de golpe (accuracy) fica para
  iteração com `rng` injetável.
- **Objetivo:** dar "multi-move" à simulação (em vez de só atacar). 
- **Pontos:** PokéAPI `/move` (nome, tipo, power, accuracy, pp); memoizar 4 moves por
  Pokémon; o motor escolhe (aleatório/peso por estado/estratégia); pp decai.
- **Impacto:** revisita B2/B3; tabela de moves é pesada → cache.
- **Critérios (esboço):** `[x]` pokémon com lista de moves limitada (4); `[x]`
  motor usa o gasto correto de `pp`; `[x]` escolha determinística testável.

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
