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
- **Status:** Done — **RF-17** (sessão 0017), validado pelo usuário em 2026-08-09
  (suíte final 199 runs/708 asserts, lint 0). Durante a validação: link "Time" do nav
  passou a apontar para o gerenciador (o botão interno "Gerenciar" sumia ao navegar)
  e `pokemon_data` ficou tolerante (nil em status ≠ 200) para a rota não 500 quando a
  PokéAPI responde falha.
- **Objetivo:** criar uma **página própria** para gerenciar o time onde o usuário possa
  **escolher a posição (slot) de cada Pokémon** e **escolher os golpes de cada um**
  (hoje: posição só via ▲/▼ no fragmento `#team` (A1/RF-08) e golpes são fixos —
  últimos 4 da PokéAPI — com escolha determinística pelo motor (D1/RF-15)).
- **Decisões (fechadas com o usuário em 2026-08-09):** golpes **persistem** no
  Postgres (`team_pokemons.moves TEXT[]`, migração idempotente 0017); fonte dos
  golpes = **lista completa** da PokéAPI (`PokeApi.available_move_names`, só nomes,
  sem carregar cada `/move`; detalhe via `PokeApi.move` memoizado só para os
  escolhidos); página com **golpes + slots** (reusa `POST /team/:id/move`);
  `MAX_MOVES_PER_POKEMON = 4`; `PokeApi.move` tolerante (nil em status ≠ 200, padrão
  0014); `GET /battle` usa os golpes salvos do jogador (fallback `moves_for`).
- **Implementado:** `GET /team/manage` + `views/team_manage.erb` (checkbox de golpes
  + ▲/▼ de slot + Voltar, alvo `#team`), link "Gerenciar" no `team.erb`;
  `POST /team/:id/moves` (valida ≤ 4 e nomes disponíveis, aviso quando inválido);
  `TeamRepository#set_moves` + `Pokemon#moves`; stubs `with_available_move_names`/
  `with_move`.
- **Impacto:** revisita A1 (slots), D1 (golpes) e a camada web/rotas; cruza com a
  futura D2 (XP) — os golpes escolhidos já estão persistidos por linha do time.
- **Próximo:** D2 (XP/evolução) — visão anotada abaixo; o time inimigo acompanha o
  nível do jogador.

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

> **Nota (em execução — sessão 0016 / RF-16): melhorar os logs de batalha.**
> Hoje o log de cada ação mostra apenas o **lado** atacante ("Seu Time" / "Oponente"),
> o golpe e o dano — não diz **qual Pokémon** bateu em **qual Pokémon**. Melhoria
> desejada (validada pelo usuário em 2026-08-09, durante a validação da sessão 0015):
> o log deve indicar **quem atacou quem**, com **qual golpe** e o **dano causado**
> (ex.: "Seu Time: pikachu usou thunder-shock em bulbasaur, 12 de dano").**Implementado
> e validado na sessão 0016 (2026-08-09):** `BattleEngine` grava
> `attacker_name`/`target_name` em toda entry (contrato uniforme) e `battle.erb`
> re-renderiza o log com os dois nomes — suíte 172 runs/614 asserts, lint 0, validado
> pelo usuário.

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
- **Nota (anotado — iteração futura):** puxar **mais informações dos golpes** além de
  nome/tipo/power/accuracy/pp — p.ex. **nivel em que o Pokémon pode aprender** o golpe
  (cada entry de `moves` da PokéAPI já traz `version_group_details` com
  `level_learned_at` e método de aprendizado), PP/PP máximo, dano etc. Relevante quando
  D2 (XP/nível) entrar, para decidir o que o Pokémon pode aprender em cada nível.
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
- **Divisão A/B (decisão do usuário, 2026-08-10):** **D2-A (sessão 0023)** = XP/nível
  persistidos (`team_pokemon_progress` por `team_pokemon_id`, curva linear `nível*100`,
  `RewardRule` no `:finished`, stats escalam, oponente escala); **D2-B (sessão 0024)** =
  evolução por nível + aprendizado de golpes por nível com **dados oficiais da species**
  (`evolution_chain` + `level_learned_at` — ver `draft-arquitetura-design-patterns.md`
  seção 8, decisão 15).
- **D2-A executada e validada (sessão 0023, 2026-08-10 — TDD passos 1–9 + fase 3 do
  usuário, suíte 292/941, lint 0):** tabela nova `team_pokemon_progress` (migração 0023,
  chave por `team_pokemon_id`, FK `ON DELETE CASCADE`); `ExperienceCurve` linear
  (`xp_needed = level*100`); `TeamRepository#add` cria progresso (nível 1/xp 0) na mesma
  transação; `ProgressionRepository` (`get`/`grant` por usuário, no-op para estranho);
  `BattlePokemon` com `level` (stats escalam `base + (level−1)*0.5`, redondo); `RewardRule`
  (`:win 50 / :draw 25 / :lose 20`, hook `:finished` estruturado p/ Eco-1);
  `BattleEngine#result` (half-FSM terminal `nil`/`:win`/`:lose`/`:draw`);
  `OpponentGenerator(level:)`; `GET /battle` monta o time com o nível de cada membro,
  oponente no **nível médio** do jogador, e `POST /battle/play` concede XP **uma única
  vez** na transição para `:finished` (guard). `battle.erb` exibe "Nível N" por lutador e
  "Seu Time ganhou X XP por Pokémon" ao fim. **Balanceamento adiado (decisão 5):**
  usuário não venceu batalha na validação — sem defeito, XP/nível funcionam (derrota +20).
  **Próxima: D2-B (sessão 0024)** — evolução/aprendizado com dados oficiais da species.
- **Visão (anotado — decidida em 2026-08-09, fora do fluxo):** os Pokémon escolhidos
  são **sempre a primeira evolução** (ou os sem evolução), **sempre nível 1** na
  montagem. **A cada batalha** o time ganha **XP**: os Pokémon **aprendem novos
  movimentos** (config. do nível de aprendizado), **aprimoram automáticamente os
  atributos** (stats escalam com o nível) e **podem evoluir**. O **time inimigo
  acompanha o nível do time do jogador** (difícil balancear evolução/leveling com o
  oponente). Isso redefine a relação com B/C: batalha deixa de ser só simulação e vira
  loop de progressão persistida (cruza com D1 para golpes aprendíveis por nível).

### D3. Histórico/rank de batalhas
- **Objetivo:** registrar resultado das partidas por usuário.
- **Pontos:** nova tabela `battles` (`user_id, result, opponent_team(serialize),
  created_at`); página/endpoint de histórico + ranking de vitórias.
- **Status:** **sessão 0026 implementada e VALIDADA em 2026-08-13 (fase 2 TDD, suíte
  367/1172 + lint 0)** — tabela `battles` + índice, `BattleRepository` (`add`/`recent`/
  `stats`/`ranking`/`rank_position`), persistência no hook `:finished`, `GET /history`
  + `GET /history/close` 100% htmx + seed `batalhas_historico`. **Sessão 0026 Done.**

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
- **Status:** **sessão 0019 (respiro)** — escopo ampliado pelo usuário para **todos os
  arquivos de teste** (6 arquivos; `grep` 69 ocorrências no total, 2 já resolvidas na
  0017). Estratégia: extrair helpers/factories (`TestSupport`), `with_db`/introspection
  em `TestDatabase`, `PokeApiStub` genérico, dividir classes de teste por área
  (abaixo do `Metrics/ClassLength` default 100) + orçamentos em `test/.rubocop.yml`.
  **Executada (passos 1–6 verdes: suíte 222/778 + lint 0) e VALIDADA pelo usuário em
  2026-08-10 — sessão 0019 Done.** Confirmado também que `lib/**`/`server.rb` não
  foram tocados (RNF: sem mudança de comportamento) e que o bônus mecânico renderizou
  disables redundantes removidos em 3 arquivos adicionais.

### Refatoração dos arquivos de produção (lib/ + server.rb) — anotada 2026-08-10

> **Sessão futura**, após a 0019 e fora desta: aplicar o mesmo tratamento aos
> arquivos **não-teste**. Levantamento real (2026-08-10): 5 arquivos, 7 disables —
> `server.rb` (1: `ClassLength`), `lib/battle_engine.rb` (1 região:
> `ClassLength`+`AbcSize`+`MethodLength`+`ParameterLists`), `lib/battle_pokemon.rb`
> (1: `MethodLength`), `lib/poke_api.rb` (2 regiões: `ClassLength`+`AbcSize`+
> `MethodLength`), `lib/team_repository.rb` (2: `ClassLength`+`MethodLength`).
- **Avaliação (1 fase ou mais):** recomendo **uma única fase** — volume pequeno
  (7 disables em 5 arquivos, região localizada cada), sem dependência entre arquivos,
  mesma mecânica da 0019 (remoção de `aggregate`/extração de métodos/módulos sob a
  rede de segurança da suíte). **Porém com critério próprio**: ao contrário da 0019
  (respiro, só testes), isso é refactor de **produção** — a suíte completa + lint 0
  + atenção do usuário na validação como critérios, sem abrir outra sessão no meio.
  **Separar em mais fases** apenas se, durante a fase, algum arquivo exigir mudança
  de contrato público (rotas/lib) ou refactor estrutural grosso (ex.: implodir
  `PokeApi`/`BattleEngine` em módulos) — aí a parte afetada vira sessão própria.
  Decisão mantida como anotação para sessão futura (0019 validada em 2026-08-10 sem
  abrir nova sessão).
- **Status:** **concluída e validada como sessão 0020 em 2026-08-10** — os 7
  `rubocop:disable` removidos de `lib/**` + `server.rb` (5 arquivos) via extração de
  métodos/módulos por área (`ServerCommon`/`ServerListActions`/
  `ServerTeamActions`/`ServerBattleActions` + rotas em módulos `registered`;
  `BattleActions`; `SlotOperations`; `PokeApiParsing`/`PokeApiMoves`/`PokeApiTypes`;
  `BattlePokemon.from`/`attributes_for`/`base_hp`), com suíte **222/778** + lint **0**
  preservados e `grep 'rubocop:'` em `lib`/`server.rb` → 0. Validação do usuário em
  2026-08-10 (comportamentos, testes e lint OK). Constantes apontadas no
  levantamento de arquitetura (`draft-arquitetura-design-patterns.md`, seções 1.1/2/8).

---

## Cadastro de ideias emergentes (levantamento de roadmap, 2026-08-10)

### J1. Seleção inicial de time (fim do dropdown + busca paginada)

- **Ideia:** no **começo de cada partida**, em vez do dropdown + busca paginada (RF-01/RF-06),
  apresentar uma **lista de Pokémon base** para o jogador **escolher e montar o time
  inicial de 6** e seguir a jornada.
- **Impacto:** redefinição da entrada do jogo (RF-01/RF-06 e navegação `#pokemon-list`/
  `#pokemon`). Muda o fluxo: seleção inicial → jornada → batalhas → (Eco) serviços.
  A listagem que conhecemos deixa de ser o "hub".
- **Aberto:** a lista base é fixa (ex.: iniciais/famílias clássicas), sorteada do pool
  total, ou por gen? Quantas opções por tela? Cruz com **D4 (draft temático)**.
- **Aguarda sessão (RNF-04).**

### J2. Personalização de Pokémon entre batalhas (terceira opção)

- **Ideia:** além de Batalha e (futuro) Poke Center/Poke Mart, uma **terceira opção de
  personalização entre batalhas**: dar **itens seguráveis** (hold items), **adicionar/
  trocar skills aprendidas**, **usar itens**, **mudar a estratégia de ataque do time** e
  **reordenar os Pokémon**.
- **Impacto:** estende A3 (gerência de time — hoje só slots + golpes) e Eco-3/Eco-4
  (itens). A **estratégia de ataque do time** vira escolha do jogador (já decidida na
  seção 6.1 do draft de arquitetura: automático no início, depois selecionável).
- **Aberto:** onde mora esta tela (extensão de `/team/manage` ou tela própria)? Estratégia
  é por time ou por Pokémon? Skills trocadas com custo (Eco) ou livre?
- **Aguarda sessão (RNF-04).**

### J3. Ranking S–F para balanceamento (pokémon + times adversários)

> **Implementado na sessão 0040 (2026-08-23, suíte 649/2063, lint 0 — **concluída e
> validada pelo usuário em 2026-08-23**):** `PokemonRating#rate(pokemon, moves:) → {score:, tier:}`
> (stats ponderados HP×0.5/demais ×1.0 + bônus da média do power efetivo top-4
> STAB ×1.5; thresholds S≥600/A≥500/B≥420/C≥350/D≥280/F<280) + `band_for_level`
> (≤2→F–D; 3–5→D–C; 6–9→C–B; 10–14→B–A; ≥15→A–S); `OpponentGenerator` com
> `rater`/`moves_fetcher`/`band` (em `options:`) e fallback puro; `build_opponent`
> deriva a banda do nível médio. Rank **não** exposto na UI (decisão 0040). Perf da
> 1ª batalha ~2min anotada (varredura serial da banda — ver P2 nas anotações).

- **Ideia:** **classificar cada Pokémon em um rank de S a F** considerando **stats e
  moves**, para **balancear os times de adversários** que aparecem ao longo do caminho.
- **Impacto:** vira fonte de verdade para o `OpponentGenerator` (B4) e para o balanceamento
  por progressão (D2/Eco) — hoje o oponente sorteia nomes do pool e escala "com o nível".
  Sugere um **componente de rating** (ex.: `PokemonRating#rate(pokemon) → :S..:F`) no
  domínio puro, tábua de balanceamento consultada pelo gerador de oponentes.
- **Aberto:** fórmula do rating (stats ponderados + power dos moves aprendíveis?),
  granularidade (rank puro vs pontos), onde a classificação é computada (offline/na
  montagem do oponente), se expõe o rank na UI uma hora.
- **Aguarda sessão (RNF-04).**

---

## Cadastro de ideias emergentes (levantamento de roadmap, 2026-08-09)

- **Cache local de detalhes da PokéAPI (E1):** `GET /battle`/RF-06 fazem N requests na
  PokéAPI (1 por membro do time); hoje só a listagem/nomes têm cache — os detalhes (por
  membro e por golpe) são buscados a cada request. Emergiu da observação da sessão 0013
  ("fora do escopo" na época). Pernosso quando D2 (XP/evolução) aumentar o volume de
  requests (cada batalha monta times + golpes repetidos). **Implementado em 2026-08-10
  (E1-A sessão 0021 + E1-B sessão 0022): gateway `PokeApi` (interface) + `PokeApiHttp`
  (adapter real estateless) + decorator `PokeApiCache` (TTL 600s / LRU máx 1000 fixos);
  validado pelo usuário em 2026-08-10.**
- **Tratamento de erros (E2):** nome inválido, rate-limit da PokéAPI, time sem membros,
  duplicados — hoje sem tratamento global (backlog). Transversal e barato; candidato a
  requisito/sessão própria antes dos demais. **Virou RF-18/sessão 0018, `Done` (validado
  em 2026-08-09)** — robustez da fonte + fragmentos amigáveis 200 + handler global `error 500`.

---

## Próximos passos (fora deste arquivo)

1. **Sessão 0027 (Eco-1 — moeda pós-batalha) concluída e validada em 2026-08-14**
   (passos 1–5, suíte 386/1216, lint 0): tabela `wallet` + `WalletRepository`
   (`balance`/`grant` upsert) + `RewardRule#money_for` (win 100/draw 50/lose 40) **no
   mesmo hook `:finished` de XP/evolução/histórico** + aviso de moeda em `battle.erb`.

   **Sessão 0028 (Eco-2 — Poke Center) concluída e validada em 2026-08-14**
   (passos 1–8, suíte 428/1333, lint 0): HP persistente por membro
   (`team_pokemon_progress.hp_max/hp_current`) + carryover p/ a próxima batalha;
   `HealCostPolicy` (custo proporcional ao HP faltante, 0.5/Hp, decisão 11);
   `WalletRepository#spend`; `HealService`; rota htmx `POST /team/heal` + bloco Poke
   Center no `team.erb`.

   **Sessão 0029 (Eco-3 — Poke Mart) concluída e validada em 2026-08-14**
   (passos 1–5, suíte 459/1432, lint 0): catálogo estático (`Item` + `ItemCatalog`,
   potion 20 / super-potion 50 / hyper-potion 100), compra com dinheiro
   (`MartService` via `spend`), `InventoryRepository` (tabela `inventory`), rota
   `POST /mart/buy` + bloco Poke Mart no `team.erb`, seed `saldo_inicial`.

   **Sessão 0030 (Eco-4-A — itens em batalha) concluída e validada em 2026-08-17**
   (passos 0–7, suíte 493/1525, lint 0): poções como ação **automatizada** no
   motor — `Item#heal_amount` (potion 20 / super-potion 50 / hyper-potion 100),
   `BattlePokemon#heal` (clamp no `hp_max`), `ItemUsePolicy` determinística
   injetável (decisão 12 — 1ª parte), `BattleEngine` ação `:item` (half-FSM 6.1,
   sem ramificar `#act`), `InventoryRepository#use` (débito min 0 no `POST
   /battle/play`), branch `:item` + estoque (`Itens:`) no `battle.erb`.

   **Sessão 0031 (Eco-4-B — item atribuído por membro) concluída e validada em
   2026-08-18 (passos 0–6, suíte 524/1599, lint 0):** estratégia selecionável via
   atribuição por membro — coluna `assigned_item` (0031_add_assigned_item),
   `TeamRepository#assign_item`, `BattlePokemon#assigned_item`, `ItemUsePolicy
   #decide` prefere o item atribuído com fallback ao pool comum (decisão 12 — 2ª
   parte), `POST /team/:id/item` + select no `team_manage.erb`, `battle.erb`
   (`carrega: <display>`).
   **Sessão 0032 (Eco-4-C — seguráveis/hold items) concluída e validada em
   2026-08-18 (passos 0–6 + seed, suíte 559/1696, lint 0):** `Item`
   `stat`/`multiplier` + `ItemCatalog.can_hold` (choice-band Attack ×1.5 /
   choice-scarf Speed ×1.5, preço 80), coluna `held_item` (0032_add_held_item),
   `TeamRepository#assign_held_item` (posse exigida, não consome), `BattlePokemon
   #held_item` com modulação de `stat` via **Strategy/Decorator** (motor sem
   mudança), `POST /team/:id/held-item` + select "Segurável:" no `team_manage.erb`,
   `battle.erb` (`segura: <display>`), seed `team_duelo` (forte x fraco com saldo
   p/ comprar).
   **Fase Eco concluída (Eco-1..4)** → próximos: candidatos futuros (D4, D1, J1,
   J2, J3) — J2 (personalização) ampliará a UI de equipamento.

   **Respiro 2 anotado em 2026-08-18 (avaliação de arquitetura pós-Eco):** candidato
   de sessão — `server.rb` retomou crescimento (723 linhas, 3 `rubocop:disable`:
   `advance_battle`/`rebuild_display_team`/`ServerBattleActions`) e `server_test.rb`
   chegou a 1925 linhas. Extrair `BattleService`/`TeamService` (use cases, molde da
   sessão 0020) e fatiar `server_test.rb` por área. Ver `draft-arquitetura-design-
   patterns.md` (seção "Respiro 2026-08-18").
2. Logo após decidir: **elencar o que fica e o que sai** da lista acima,
   definir ordem e transformar os escolhidos em **documentos de sessão** com
   critérios fechados e plano TDD (como a 0007).
3. **Nota:** B3 (motor) destrav não depende de B1/B2 sequenciais A/B — ordem sugerida:
   B1 → B2 → B3 → B4 → C1. A1/A2 podem entrar em paralelo ao game loop se desejado.

---

## Anotações de jornada/experiência — 2026-08-18 (após respiro de arquitetura)

> **Fora do fluxo (RNF-04).** Anotações do usuário para das próximas fases, no padrão
> do cadastro de ideias acima. Não geram critérios de aceite nem plano TDD agora.
> Revisar ao fechar as fases correntes.

### Ordem decidida das próximas sessões (2026-08-18, usuário)

> **Sequência fechada pelo usuário:** ~~**1. Respiro 2**~~ (feito — sessão 0033
> concluída e validada em 2026-08-19) → ~~**2. D1 parcial (nível de
> aprendizado)**~~ (feito — sessão 0034, **concluída e validada em 2026-08-19**) →
> ~~**3. J1 (seleção inicial)**~~ (feito — sessão 0036, **concluída e validada
> em 2026-08-22**, com ajustes S3: só formas base + 27 iniciais gen 1–9) →
> ~~**4. JN-2 (golpes em lista)**~~ (feito — sessão 0037, **concluída e validada
> em 2026-08-22**) → ~~**5. J3 (ranking S–F)**~~ (implementado — sessão 0040,
> **implementada em 2026-08-23 — suíte 649/2063, lint 0, aguardando validação do
> usuário**; `PokemonRating` stats+moves STAB, banda por nível no
> `OpponentGenerator`) → ~~**6. JN-1 (telas próprias,
> fim do empilhamento)**~~ (feito — sessão 0039, **concluída e validada
> em 2026-08-22**) → depois
> **organizar o resto** (JN-3, JN-4, JN-5, J2, J4, D4 e demais).
> Ao concluir cada sessão, atualizar esta ordem no roadmap (`REQUIREMENTS.md`).

### JN-1. Telas próprias de Time, Batalha e Histórico (fim do empilhamento)

- **Problema:** `index.erb` mantém 5 `<div>` empilhados na página única (`#pokemon-list`,
  `#pokemon`, `#team`, `#battle`, `#history`); cada aba do nav preenche o seu próprio
  alvo e os painéis **acumulam um embaixo do outro** ao navegar (Time + Batalha +
  Histórico visíveis simultaneamente).
- **Ideia:** cada área vira **tela própria** (rota + fragmento/layout dedicado) e a
  navegação **troca a área exibida** em vez de somar. Revisita RF-14 (nav único) e as
  rotas `GET /team|/battle|/history` (hoje fragmentos parciais em alvos fixos).
- **Impacto:** UI/UX + rotas/views; sem mudança de regra de negócio (domínio intacto).

### JN-2. Gerenciamento de golpes: lista no lugar de checkboxes

- **Problema:** `team_manage.erb` usa **vários checkboxes** por Pokémon para escolher
  os golpes (RF-17) — ruim para explorar a lista completa da PokéAPI (pode ter dezenas).
- **Ideia:** seletor de golpes vira **lista de uma seleção** (ex.: `select multiple`
  amigável, ou lista clicável com marcação simples) mantendo limite de 4 (RF-17).
- **Impacto:** só `views/team_manage.erb` + rota `POST /team/:id/moves` (validação
  idêntica). Baixo risco.

### JN-3. Itens de uso único por Pokémon (quantidade usada × comprada)

> **Executada na sessão 0045 (2026-08-24) e VALIDADA pelo usuário em 2026-08-24.**
> Regra estrita de **1 uso de item curativo por Pokémon por batalha**: o
> `BattleEngine` rastreia quem já usou (`@items_used_by_member`) e bloqueia novo uso
> do mesmo membro na mesma batalha, valendo para o pool comum **e** o item atribuído;
> badge "já usou item" por membro no painel do lutador (`FighterPresenter#item_used?`).
> Suíte 701/2222, lint 0. Anotação **resolvida — removida da fila**.

- **Problema:** hoje poções são consumíveis automáticos (`ItemUsePolicy`) e o
  `InventoryRepository#use` debita do estoque, mas não há trava de **"usar apenas 1 vez
  por Pokémon"** — a batalha pode drenar o estoque repetidamente no mesmo lutador.
- **Ideia:** regra de consumo **1 uso por Pokémon por batalha** (ou por limite de
  estoque), alinhada à quantidade **comprada** — usar o item consome a qtd comprada até
  zerar; sem refill infinito no mesmo confronto.
- **Impacto:** `ItemUsePolicy`/motor (registrar uso por membro) + `battle.erb` (exibir
  qtd restante). Cruza com Eco-4-A/B.

### JN-3-B. Equipamento limitado pela quantidade do estoque (anotado 2026-08-24, pós JN-3)

> **Executada na sessão 0046 (2026-08-24) e VALIDADA pelo usuário em 2026-08-24.**
> Suíte 714/2281, lint 0. **Regra aplicada:** itens/seguráveis são por poke (1 de
> cada); **equipar debita do estoque** (`TeamItemOperations`, `assign_with_swap`),
> **desequipar repõe**, **trocar repõe o antigo e debita o novo**, **re-equipar o
> mesmo item não debita de novo**; item atribuído consumido em batalha **não debita
> de novo** e **limpa o `assigned_item`** (`battle_items` soma atribuídos +
> `debit_used_items` por `attacker_index`); UI mostra a quantidade livre e desabilita
> (×0) itens esgotados. Anotação **resolvida — removida da fila**.

- **Problema:** `TeamService#assign_item`/`assign_held_item` só fazem `SET` no membro
  (`team_pokemons.assigned_item`/`held_item`) — **sem respeitar a quantidade do
  estoque**: o mesmo item (poção, super-potion...) e o mesmo segurável
  (choice-band/choice-scarf) podem ser equipados em mais pokes do que a quantidade
  comprada do time.
- **Ideia (regra do usuário):** itens e seguráveis são **por poke**, não por time —
  o time compra `n` unidades de um item/segurável, **cada poke pode equipar 1 de cada**
  (1 item + 1 segurável), e os pokes **só equipam conforme a quantidade disponível no
  time** (estoque): o nº de pokes equipados com o mesmo item/segurável não pode
  ultrapassar a quantidade comprada.
- **Decisões de regra (usuário, 2026-08-24):** **equipar debita do estoque**; **itens
  usados em batalha são consumidos** (débito já existente no `debit_used_items`) e o
  poke **fica sem item atribuído após o consumo** (limpar `assigned_item` ao usar em
  batalha); **seguráveis continuam equipados e ativos em batalha até serem
  desequipados** (o desequipar devolve a unidade ao estoque). **UI:** no select do
  `team_manage.erb`, o option de item/segurável já equipado em outro poke fica
  **desabilitado**, e a quantidade exibida é a **livre** (total comprado − já
  equipados em outros pokes) — ex.: com "Choice Band ×2", equipar no 1º poke mantém
  "Choice Band ×2" (o próprio), no 2º poke mostra "Choice Band ×1" e nos demais a
  opção some/desabilita.
- **Impacto:** `TeamService` (no `assign_item`/`assign_held_item`: validar
  disponibilidade do estoque e **debita** na atribuição; no clear, **reponha** a
  unidade no estoque) + `BattleService`/`debit_used_items` (limpar `assigned_item` do
  poke quando o item atribuído é consumido na batalha) + `team_manage.erb` (no option,
  indicar **em uso por outro poke** e/ou **quantidade livre** = estoque − já equipados)
  + `InventoryRepository` (débito/repõe reutilizando `use`/`add`) + testes de
  service/rotas do manage. Cruza com Eco-3/Eco-4.

### JN-4. Componentes de Poke Mart e Poke Center

> **Executada na sessão 0047 (2026-08-24) e VALIDADA pelo usuário em 2026-08-24.**
> Suíte 724/2329, lint 0. Blocos de
> `views/team.erb` viram partials reutilizáveis `_mart.erb`/`_center.erb` no painel
> do time (`#team-view`), **sem rotas/páginas novas**. **Cura (HP × custo):** HP
> atual/máx por membro + **custo total antecipado** via `HealService#preview_cost`
> (0.5/HP sem mutar); botão Curar `disabled` quando já curado (custo 0) ou saldo <
> custo. **Compra (stock × saldo):** preço × **quantidade comprável** (`saldo/preço`,
> ex. "×5"); botão `disabled` quando saldo < preço. `team_hp.erb` absorvido pelo
> `_center.erb` (removido).

- **Ideia:** as seções de Poke Mart (Eco-3) e Poke Center (Eco-2) hoje vivem como
  blocos dentro de `team.erb` — virar **componentes próprios** (telas/fragmentos
  reutilizáveis), completando visualmente compra (stock × saldo) e cura (HP × custo).
- **Impacto:** views + rotas; cruza com JN-1 (telas próprias) e JN-3 (itens).

### JN-5. Gameloop: montagem → batalha → loja/cura → repete

- **Ideia:** o fluxo de navegação deve seguir a ordem do circuito fechado:
  **montagem de time → batalha → opções (Poke Mart/Poke Center) → repete** — em vez de
  abas livres. Torna a jornada (J1) e o circuito Eco (batalha → XP+dinheiro → gastar)
  explícitos na UI.
- **Impacto:** define o fluxo navegacional (JN-1) e pode dar destino ao `OpponentGenerator`
  (novo confronto respeitando a ordem). Alto valor, cruza com J1/J2/Eco.

---

## Anotações de performance — 2026-08-19 (durante validação da sessão 0034)

> **Fora do fluxo (RNF-04).** Anotado durante a validação da sessão 0034. A 0034 foi
> **concluída e validada em 2026-08-19**; a P1 passa a ser **candidata a sessão** (entrar
> antes na ordem J1/J2/J3 fica a critério do usuário — ver seção 8 da 0034 e roadmap).

### P1. Paralelismo ou cache mais agressivo no gateway da PokéAPI

> **Executada na sessão 0035 (2026-08-19) e VALIDADA pelo usuário em 2026-08-19.**
> Estratégia escolhida: **combinar ambos**
> (paralelismo + cache persistente). Implementada: `Parallelizer` (pool de threads,
> resultados na ordem, exceção propagada — stdlib) + `PokeApiCache` thread-safe (lock
> por chave, dedup in-flight) + `PersistentJsonStore` em `tmp/` (TTL 7d, write-through,
> tolera arquivo corrompido) + choke point `http_get` (boot com `POKEAPI_CACHE_PATH`)
> + fonte paralela (`type_relations` 18 tipos, `OpponentGenerator`, `BattleService`
> prepare/finalize com prefetch). Passos 1-5 verdes (suíte 586/1787, lint 0).
> **Validação: `GET /battle` ~38s (era ~93s), 2º play ~4s.** Anotação **resolvida —
> removida da fila**.

- **Problema observado (validação da 0034):** `GET /battle` (prepare) demorou ~1.6min e a
  2ª rodada de `POST /battle/play` (finalize: evolução + aprendizado) ~1.2min.
- **Causa raiz (medida):** fan-out **serial** de ~133 requisições HTTP à PokéAPI por
  prepare — 6 `detail` do jogador (cada = `/pokemon` + species + chain + `find` por
  estágio ≈ 5) ≈ 30, 6 `detail` do oponente ≈ 24, 6 `moves_for` do jogador (pokemon +
  últimos 4 moves) ≈ 30, 6 do oponente ≈ 30, 18 `type_relations` seriais, 1
  `fetch_all_names` — ≈ 93s a 0.7s/RTT. O finalize soma ~36 seriais
  (`next_evolutions` = species + chain + find, `learnable_moves` + `detail` de evolução).
- **Agravante:** `PokeApiCache` é **em memória** (TTL 600s) e o `scripts/reboot` faz
  `docker compose down` → **cache zerado a cada iteração** de validação; toda batalha
  reaquece do zero.
- **Caminhos candidatos (decisão do usuário ao refinar):**
  1. **Paralelismo:** disparar os fetches independentes em threads (details dos 6 membros,
     6 do oponente, 18 tipos, moves) — reduzir o walk-time de ~133 RTTs para a profundidade
     do grafo (~10–20). Impacto em `PokeApiHttp`/`BattleService` (+ cache thread-safe).
  2. **Cache mais agressivo:** persistir o cache (arquivo/Redis/Postgres em vez de
     memória) e/ou aumentar o TTL — dados da PokéAPI são praticamente imutáveis
     (`type_relations`, `move`, species/evo). Sobrevive ao `scripts/reboot`.
  3. **Combinar ambos:** paralelizar o warm-up + cache persistente longo (TTL alto).
- **Garantias desejáveis (esboço):** testes seguem sem rede (stubs existentes —
  `PokeApiStub`/`PokeApiCache` com clock fake); suíte/lint verdes; zero mudança de
  contrato da interface `PokeApi`.
- **Impacto estimado:** prepare de ~93s → poucos segundos (paralelo) e o cache
  persistente elimina o re-warm a cada reboot.
- **Candidate order suggestion:** após J1/J2/J3 (impacto de UX alto; não depende delas —
  pode entrar antes se o usuário preferir).

### P2. Varredura da banda do oponente (J3) sem paralelismo (anotado 2026-08-23)

> **EXECUTADO na sessão 0050 (2026-08-25) e VALIDADO pelo usuário em 2026-08-25.**
> Estratégia fechada: A+B+cache — `OpponentGenerator` com novo caminho `ratings:`
> (nome→tier) avaliando a banda em **lotes paralelos** via `Parallelizer`
> (determinístico por seed) + **cap de varredura** `max_candidates:` (default 256 no
> `BattleService`) com fallback puro + **`PokemonRatingCache`** (persistente, keyed por
> nome, TTL 7d, write-through) injetado no `BattleService#opponent_options`. Caminho
> `rater`/`moves_fetcher` preservado. Caminho **4 (evitar o duplo fetch de `moves_for`
> na montagem)** ficou de fora — ganho marginal, rever se desejado.
>
> **Ajuste S3 (C4-b, 2026-08-25):** benchmark mostrou a 1ª batalha ainda em ~55-63s —
> o gargalo real é o **write-through do `PersistentJsonStore`** (`pokeapi_cache.json`,
> 260MB, 3788 entradas): `store` reescrevia o arquivo inteiro (~1.45s/miss: generate
> 0.98s + write 0.47s) sob `@store_mutex` a cada miss; a 1ª batalha faz ~50-100 misses.
> Fix implementado e validado: **escrita coalescida** — `store` atualiza só em memória,
> writer em background (intervalo 30s) + `flush!` síncrono (testes/exit),
> `PokeApiHttp#flush!`. **Resultado validado:** 1ª batalha ~60s → **2.81s** (frio real
> **1.64s**), 2ª **0.01s**. Resíduos: boot parse 260MB (~3s) e `PokemonRatingCache` com o
> mesmo padrão (arquivo ~20KB, não é gargalo).

> **Fora do fluxo (RNF-04).** Observado na **validação da sessão 0040 (J3)**: o
> `GET /battle` passou de ~38s (P1) para **~2min** na 1ª chamada.

- **Problema:** com o J3, `OpponentGenerator#rated_names` percorre o pool em ordem
  aleatória chamando `detail` + `moves_for` por candidato até preencher a banda —
  **serial** (um RTT por candidato), **sem cap de varredura**, e depois a montagem
  do time re-faz `moves_for` de cada oponente escolhido. Bandas estreitas (ex.:
  A–S em nível alto) podem varrer centenas de nomes antes de completar 6.
- **Caminhos candidatos (decisão do usuário ao refinar):**
  1. **Paralelizar a varredura** com o `Parallelizer` existente (fan-out dos
     `detail` + `moves_for` por candidato em lotes) mantendo ordem determinística.
  2. **Cap de varredura:** limitar o nº de candidatos avaliados; se não completar a
     banda dentro do cap, completar com sorteio puro (fallback já existe).
  3. **Pré-computar/cachear o rating** por número (ex.: cache persistente do
     `PokemonRating` — `PokeApiCache`/`PersistentJsonStore`), evitando re-ratear a
     cada batalha; ou **pré-cachear a banda** offline (pré-warm por tier).
  4. Reduzir o custo por candidato: o `moves_for` do oponente já é buscado na
     montagem — evitar o duplo fetch (rating + time).
- **Garantias desejáveis (esboço):** determinismo por seed preservado; testes sem
  rede; suíte/lint verdes; comportamento da banda inalterado (critérios C4/C5 da 0040).

---

## Anotações de integração com IA — 2026-08-20

> **Fora do fluxo (RNF-04).** Anotação do usuário para fases futuras. Não gera critérios
> de aceite nem plano TDD agora. Revisar ao fechar as fases correntes.

### IA-1. API ou WebSocket para uma IA jogar o jogo

- **Ideia:** expor o jogo por **API (REST/JSON) ou WebSocket** para que uma **IA
  (agente externo)** consiga **jogar** — montar time, batalhar (escolher golpes/ações),
  usar Poke Mart/Poke Center etc., sem depender da UI htmx.
- **Pontos em aberto:** REST vs WebSocket (turnos request/response ou eventos
  assíncronos?); autenticação da IA (token por agente?); escopo exposto (só batalha vs
  game loop completo — JN-5); reuso dos services existentes (`BattleService`/
  `TeamService` da 0033 como camada de aplicação); observabilidade das partidas da IA
  (histórico/log separados?).
- **Impacto:** nova fronteira de transporte além do htmx; cruza com JN-5 (gameloop) e
  Eco (loja/cura). O motor determinístico (B3/D1) facilita replay/teste de agentes.
- **Aguarda sessão (RNF-04).**

---

## Anotações do usuário — 2026-08-25 (durante a validação da 0048)

> **Fora do fluxo (RNF-04).** 4 ideias novas, **não refinadas** — viram sessão própria
> após a 0048 concluir/validar, a critério do usuário. Cruzam com Eco (moeda/Mart),
> D4 (draft temático), B3 (motor) e C1 (batalha por htmx).

### UX-1. Poke Center / Poke Mart como janelas flutuantes + gerência de golpes/itens

> Ver `draft-ui-ux.md` §6 (anotadas na mesma ocasião). Center/Mart como **modais** em
> vez de levar à tela de lista/time; estender para **editar golpes no Center** e
> **gerenciar itens no Mart**; **4 selects** para os golpes (reestruturar o
> `team_manage`).

### M1. Itens de evolução no Poke Mart (pedras e outros) — aparecem aleatoriamente por rodada

- **Ideia:** incluir **mais itens** (pedras de evolução — fire/water/thunder/leaf
  stone etc. — e outros itens de evolução específicos) no **Poke Mart**, com **oferta
  aleatória por rodada** (rotatividade: nem todos os itens sempre disponíveis; o
  catálogo muda a cada rodada/confronto).
- **Pontos em aberto:** modelagem de pedra como item consumível por evolução
  (`EvolutionRule` hoje é por nível — estender para item-gated); como o sorteio da
  oferta interage com o nível do jogador/banda; preço das pedras; persistência da
  oferta por rodada vs por usuário.

### M2. Sistema de custo para montagem de time

- **Ideia:** cada Pokémon tem um **custo** na montagem — **fortes mais caros, fracos
  mais baratos**, e os com **restrição de evolução (pedras/itens específicos) muito
  baratos ou gratuitos**. Balanceia o draft e a jornada (dá destino ao `PokemonRating`
  do J3 — custo derivado do tier).
- **Pontos em aberto:** fonte do custo (tier S–F × tipo × restrição de evolução);
  onde entra o custo (na montagem inicial J1 / na troca de membros); orçamento
  inicial do jogador; interação com a moeda Eco e com o draft temático (D4).

### B5. "Batalhar" resolve a batalha inteira (fim das rodadas manuais)

> **Implementado e validado na sessão 0069 (2026-09-02 — suíte 985/3831, lint 0, revisor Aprovado, validado pelo usuário).**
> `BattleService#resolve` (teto 100, débito de itens de todas as rodadas, `finish_effects` 1×),
> `POST /battle/play` resolve tudo num request, log completo (`BattleLogPresenter#entries_all`,
> `DEFAULT_LIMIT = 3` preservado), botão "Jogar" removido, revelação do log com animação CSS
> escalonada + `prefers-reduced-motion`. `BattleEngine#battle` intocado (35 callers).

- **Ideia:** mudar o sistema de rodadas — ao apertar **"batalhar"**, **cada ação
  ocorre até o fim da batalha**, sem precisar clicar de novo (execução automática até
  o resultado; o log mostra a sequência). Oposta ao fluxo atual de clicar "Jogar" por
  rodada.
- **Pontos em aberto:** animação/escalonamento da resolução (instantânea vs passo a
  passo com atraso); persistência de HP/estado entre rodadas (já existe — D2/Eco-2);
  como isso interage com as recompensas (XP/dinheiro) no fim.

### C2. Animações nos ataques

> **Implementado e validado na sessão 0063 (2026-09-08 — suíte 995/3938, lint 0, revisor Aprovado, validado pelo usuário).**
> Juice de batalha CSS-only — HP animado (dano/cura), projéteis (**só ≥900px**; <900px
> flash no alvo), flash de dano, KO fade/grayscale, número de dano flutuante e
> screenshake leve; origem/alvo derivados no servidor (replay do log via
> `BattleJuicePresenter`), reusa `--log-delay`/stagger da 0069, `prefers-reduced-motion`
> desliga tudo, zero JS/polling/SSE.

- **Ideia:** **animar os ataques** de cada Pokémon na batalha, indicando **de onde
  saiu e para qual foi** (projétil/efeito entre os painéis Seu Time ↔ Oponente).
- **Pontos em aberto:** CSS/animação pura (preferência do projeto, sem lib JS) vs
  técnica com htmx; dado de origem/alvo (o log do `BattleLogPresenter` já tem
  atacante/golpe — falta o alvo explícito); acessibilidade (redução de movimento).

### UX-2. Custo/ranking na lista + filtros avançados + alinhamento das caixas (2026-08-25)

> Anotações do encerramento do dia (RNF-04), dependentes do **custo de montagem de time**
> (M2) e do ranking (J3).

- **Exibir ranking/custo dos pokes na lista após implementar o custo por time:** quando
  o **sistema de custo** (M2) entrar, a **listagem** deve mostrar o **custo/ranking** de
  cada Pokémon (derivado do `PokemonRating`/tier), para o jogador montar o time sabendo
  quanto custa cada um.
- **Filtros além da busca por nome:** a lista hoje só filtra por nome (`q`). Serão
  necessários filtros por **tipo, geração, custo e ranking** (e possivelmente
  habilidade/moves) — UI de filtros combináveis com a busca e a paginação.
- **Alinhar a caixa da lista com a caixa do time:** alinhar/equalizar o layout das duas
  colunas da página `/` (lista vs painel do time) — largura/altura/rolagem coerentes.

### BUG-1. Oponente SEMPRE o mesmo por usuário (sem variedade nem escala)

- **CORRIGIDO na sessão 0049 (2026-08-25).** Fim da seed fixa
  `Random.new(user_id.sum)` em `BattleService#build_opponent` — o service usa a
  dependência injetável `opponent_rng` (default `-> { Random.new }`). Para o oponente
  novo vir **apenas em um novo confronto** (não a cada acesso a `/battle`), a 0049
  entregou a **máquina de estado da batalha ativa**: `prepare` reusa a batalha por
  estado (preparada não iniciada → re-deriva o time do jogador preservando o oponente;
  em andamento/finalizada → preserva o engine), "Novo confronto" virou ação explícita
  `POST /battle/new` (limpa e prepara novo) e add/remove/move **invalidam** a batalha
  ativa (`BattleService#invalidate`). Histórico do bug abaixo.
- **Bug (anotado 2026-08-25, confirmado no playtest 2):** toda batalha de um mesmo
  usuário repete **o mesmo time oponente nível 1** (mesmas espécies), tanto via "Novo
  confronto" quanto ao re-entrar em `/battle`. `BattleService#build_opponent`
  (`lib/battle_service.rb:64`) usa `Random.new(user_id.sum)` — **seed determinístico
  por usuário** — então o `OpponentGenerator` devolve sempre o mesmo oponente a cada
  `prepare`, independente do time atual/nível (a banda varia, mas a escolha dentro dela
  é determinística).

### BUG-2. Remover Pokémon com itens equipados perde os itens (estoque)

- **Bug (anotado 2026-08-25, durante a preparação do playtest 2):** ao **remover um
  Pokémon com itens/seguráveis equipados, todos os itens somem** (não voltam ao
  estoque). `assigned_item`/`held_item` vivem na própria linha do `team_pokemons`;
  `TeamRepository#remove` (`lib/team_repository.rb:188`) faz o `DELETE` sem **repor**
  os itens ao inventário (`InventoryRepository`), e o handler `remove_team_member`
  (`server.rb:263`) não restaura. Corrigir = nova sessão (TDD): na remoção, devolver os
  itens equipados (assigned + held) ao estoque antes do delete.

### BUG-4. App vaza conexões PG em produção (ConnectionRegistry sem limpeza)

- **Bug (observado 2026-08-25, durante benchmark da 0050) e CORRIGIDO na sessão 0051
  (2026-08-25, validado pelo usuário):** o `ConnectionRegistry`
  (`lib/connection_registry.rb`) registra **uma conexão por (repositório, thread)** —
  a limpeza (`close_all!`) só rodava no `after_teardown` do Minitest (`test_helper.rb`).
  Em **produção o app nunca fechava**: sob o `run!` do Sinatra/Puma, cada request em
  thread nova cria conexões e **acumula** (7 repos × threads). No benchmark da 0050 o
  app chegou a **80 conexões no `pokedex`** → somado ao limite 100 do PG, derrubou a
  suíte com "too many clients already". **Fix:** `after { ConnectionRegistry.release_current_thread! }`
  no `server.rb` (cada request fecha as conexões da sua thread) + teto
  **`MAX_CONNECTIONS`** (30, env `PG_MAX_CONNECTIONS`) com **evicção** (thread morta
  primeiro, senão LRU). Isolamento por thread (0044) preservado. Manual de validação:
  `pg_stat_activity` estável após requests e a suíte roda verde com o `web` ativo.

### Futuras — Ajuste de XP/dinheiro e dificuldade dinâmica (anotado 2026-08-28, fora do fluxo — RNF-04)

> **Pedido do usuário (2026-08-28):** anotar como mudanças futuras, não refinadas agora.

- **Ajuste da tabela de XP e dinheiro:** revisar `ExperienceCurve` (hoje `level*100` linear) e `RewardRule#money_for` (win 100/draw 50/lose 40, Eco-1) — progressão pode ficar rápida/lenta demais com o novo pool e escalonamento; balancear custo de curva vs recompensa por vitória/derrota/empate, mantendo `BattleService`/`ProgressionRepository` como fronteira.
- **Dificuldade dinâmica por desempenho da batalha anterior:** além da banda estática `PokemonRating.band_for_level(average_player_level)` (F–D até A–S), ajustar o oponente seguinte pelo **desempenho da batalha anterior** (ex.: vitória fácil → sobe banda/nível, derrota → mantém/desce, placar/HP restante como sinal). Cruza com `OpponentGenerator` (`band`/`level`/`ratings:`), `BattleService#build_opponent` e `BattleEngine#result`. Não abrir na 0066; fica para sessão futura dedicada.

### BUG-3. Remover do time às vezes exige clicar 2x

- **Bug (anotado 2026-08-25):** por vezes é preciso **clicar 2x no botão "Remover do
  time"** para o membro sair. `views/team.erb:40` usa `hx-delete="/team"` (alvo
  `#team-view`, `hx-include=".list-state"`, `hx-params="*"`); o handler
  `remove_team_member` (`server.rb:263`) só age se `params[:id]`. **Hipótese (a
  confirmar no QA):** o 1º clique dispara o delete mas o swap/estado não atualiza o
  painel (ou o `id` chega vazio/duplicado no 1º request), então o jogador clica de novo
  e só então o membro sai. Investigar no playtest de QA (evento htmx, params, OOB).

---

## Anotações do usuário — 2026-08-25 (durante a validação da 0050)

> **Fora do fluxo (RNF-04).** 8 pedidos novos, **não refinados** — viram sessão própria
> após a 0050 concluir/validar, a critério do usuário. **0050 validada em 2026-08-25**
> (perf da 1ª batalha resolvida — C4-b/write-through, ~60s → ~2s).

### IA-2. IA usa todos os golpes / zera todos os PP antes de usar Struggle

- **Pedido:** a IA do oponente (e o motor) deve **esgotar todos os golpes/PP antes de
  cair em Struggle**. Hoje `BattleActions#choose_move` (`lib/battle_engine.rb:30`)
  considera só moves com `power.to_i.positive? && pp.positive?` e usa `struggle_move`
  (linha 37) quando não há nenhum **damaging** move com PP — ou seja, o Struggle pode
  entrar antes de a IA ter "usado todos os golpes". Confirmar o caso real no playtest
  (quando o Struggle apareceu cedo) e fechar a regra de escolha (ex.: usar o melhor
  damaging disponível; Struggle só quando **todos** os moves, incluindo status, tiverem
  PP zerado — conforme o pedido).

### IA-3. Golpes de debuff (status moves que reduzem stats)

- **Pedido (ligado ao IA-2):** implementar **moves de debuff** (ex.: Growl, Tail Whip —
  reduzem Attack/Defense do alvo). Hoje `choose_move` **filtra** `power.to_i.positive?`
  (`lib/battle_engine.rb:31`), então todo status move (power `nil`) é **ignorado** pela
  IA. Implica modelar o efeito de stat (novo campo no `Move`? tabela de efeitos),
  aplicar no alvo por N rodadas e a IA decidir quando usar. Determinar o alcance
  (só oponente ou também o jogador — hoje o jogador só escolhe golpes de dano).

### IA-4. Sistema de crítico e RNG

- **Pedido:** dano hoje é **determinístico** (`move_damage_for`, `lib/battle_engine.rb:45`).
  Implementar **chance de crítico** (multiplicador, ex. ×1.5/×2, chance ~6.25%) e **RNG
  de variação de dano**, mantendo determinismo testável (rng injetável, como `opponent_rng`
  da 0049). Definir regras (crit só em damaging? STAB/type intactos) e exposição no log.

### OPP-1. Oponentes não devem ser evoluções (Silcoon nível 1 apareceu)

- **Bug/pedido:** numa batalha apareceu **Silcoon nível 1** — é evolução e **não deveria
  estar no pool de oponentes**. O pool do oponente usa `fetch_all_names` **sem filtro**
  (`BattleService#build_opponent`, `lib/battle_service.rb`) — a lista do jogador filtra
  `base_form?`, o oponente não. Aplicar o mesmo filtro de **forma base** (reusar
  `base_form?` do gateway) ao pool adversário.

### OPP-2. Filtrar lendários, G-Max, V-Max e variações dependentes de evolução anterior

- **Pedido (refino do OPP-1):** além de evoluções, **excluir do pool** lendários/míticos,
  formas G-Max/V-Max e demais **variações que dependem de um Pokémon anterior**
  (cross-gen evolutions, regional forms derivados etc.). Definir a lista/regra de exclusão
  (reusar `base_form?` + blacklist de slugs especiais) e aplicar a **lista e ao pool de
  oponentes** (e talvez ao rating/banda). Interage com a 0044 (paginação) e com o
  `PokemonRating`.

### GL-1. Game over quando a vida de todos os pokes zerar

- **Pedido:** fluxo explícito de **derrota** quando **todos os Pokémon do time zeram a
  vida**. Hoje `BattleResult#result` devolve `:win`/`:lose` (`lib/battle_engine.rb:210`)
  e o fim de batalha só recompensa (`xp_for`/`money_for` do `RewardRule`) — não há tela/
  estado de "game over" da jornada (ver JN-5/0048: fim de batalha mostra CTAs Center/
  Mart/"Novo confronto"). Definir o que muda ao perder (jornada termina? retry? fila de
  derrota no histórico?) e a UI.

### CURA-1. Outros modos de cura ou poções fora de batalha

- **Pedido:** hoje a cura fora de batalha é **só o Poke Center** (heal total via
  `HealService` no painel `_center.erb`) e **poções só funcionam em batalha**
  (`ItemUsePolicy`). Implementar **outros modos de cura** ou **permitir usar poções no
  painel do time** (fora de batalha, debitando do estoque — reusar `TeamItemOperations`/
  `HealService`). Definir quais itens curam fora de batalha e as regras de consumo.

### GL-2. Trava para time com HP zerado não poder ir batalhar

- **Pedido (validado na 0050, 2026-08-25):** impedir que um time com **todos os pokes em
  0 HP** entre em batalha. Hoje o gate do `GET /battle` só checa
  `settings.journey.started?` = `user_state.started? || team.size >= 6`
  (`lib/journey_service.rb:10`; `server.rb:353` → `journey_gate_fragment`) — **sem
  verificar HP**. Após uma derrota (GL-1/`persist_finished_hp`, `battle_service.rb:233`),
  o time pode ficar todo zerado e ainda disparar `GET /battle`. Definir a regra (ex.:
  gate estende `started?` com "pelo menos 1 poke com `hp_current > 0`"; UX: aviso "cure
  seu time no Poke Center" + CTA) e o teste.

### Flag `user_state` vestigial para o gate da jornada (anotado 2026-08-25, sessão 0052)

- **Refatoração futura:** após a 0052 (Q3), `JourneyService#started?` passou a ser
  **derivado apenas do tamanho do time** (`team >= 6`); a flag `user_state` deixou de ser
  lida pelo gate (escrita em `mark_started`/`mark_started_when_full` preservada e hoje
  inerte). Considerar **remover a tabela `user_state`, o repositório e as escritas** (rota
  `POST /team` → `mark_started_when_full`) ou redefinir o papel do marcador (ex.: marcar
  "primeira jornada completada" para outro propósito). Interage com a migração 0036
  (`user_state`), seeds e `TestDatabase.clear_user_state!`.

### INFRA-1. Cache da PokéAPI em Redis (anotado 2026-08-26, fora do fluxo)

- **Contexto:** `tmp/pokeapi_cache.json` cresceu para `322M/4324` chaves (2026-08-26) e o
  `PersistentJsonStore:PersistentJsonStore` faz `JSON.parse(File.read)` síncrono no boot
  (`lib/gateways/persistent_json_store.rb:100` + `lib/gateways/poke_api.rb:29`).
  Custo medido: `3.26s` só de parse dentro do `web` — pago 54× na suíte (`./scripts/test`
  = 1 `docker compose run` por arquivo) → minutos. Isolar `POKEAPI_CACHE_PATH` em teste
  resolveu o sintoma; o arquivo continua compartilhado em dev/prod e cresce sem
  `max_entries` (ao contrário do `PokeApiCache:lib/gateways/poke_api_cache.rb:7` 600s/1000).
- **Ideia (intenção do usuário: regras novas + colocar online):** substituir o
  `PersistentJsonStore` (arquivo + `Thread sleep 30s` flush) por `RedisJsonStore`
  (`SETEX` com `DEFAULT_TTL=7d`, `EXISTS`/`GET`, `JSON.generate` só do valor), mantendo
  `PokeApiCache` como L1 em memória e `PokeApiHttp:lib/gateways/poke_api_http.rb:17` como
  choke point. Cache passa a ser compartilhado entre réplicas `web`, TTL/evicção nativos,
  sem parse de 300M no boot.
- **Impacto/escopo:** infra (`docker-compose.yml:2` + `redis:7-alpine`, `ENV REDIS_URL`),
  `Gemfile:1` (`gem "redis"`), novo `lib/gateways/redis_json_store.rb` com mesma interface
  `#get/#flush!` de `PokeApiHttp:47`, `lib/gateways/poke_api.rb:29` injeta `Redis` quando
  `ENV["REDIS_URL"]` presente (fallback p/ `transport_get:57` se Redis cair), testes com
  `fakeredis`/`mock_redis` ou `FLUSHDB` por suite. Memória Redis ~400M para o dataset
  atual (precisa `maxmemory`+`allkeys-lru`).
- **Decisão:** **não fazer agora** — tratar como sessão própria após a correção de
  velocidade dos testes. Primeiro validar o fix isolado (`POKEAPI_CACHE_PATH` de teste +
  cap do arquivo). Se escalar para N réplicas `web` ou cache quente compartilhado for
  necessário no deploy, refinar INFRA-1 como sessão SDD (critérios: boot <1s, suíte sem
  rede <30s, fallback sem Redis OK, `docker compose up` com `redis`).
- **Aberto:** usar `Redis` vs reaproveitar o próprio `Postgres` (`pokeapi_cache` com
  `jsonb`) vs manter arquivo com `max_entries`; preço/run de `REDIS_URL` em produção.

### M2b. Balanceamento economia — remover trava hard de 3× S via custo (playtest 01, 2026-08-27)

- **Playtest:** browser-harness + simulações `sim_economia.rb`/`sim3.rb`/`sim100.rb` via `docker compose exec web ruby`. Foco: achar número mágico onde max 3 S caiba por orçamento, sem `S_LIMIT`.
- **Estado atual (`lib/team_budget.rb:7-15`):** `BUDGET 450`, `TIER_COST S 120 / A 70 / B 55 / C 40 / D 30 / F 20`, `cost_for` com `restricted ? base/2 : base` (◆). `server.rb:593` bloqueia `S_LIMIT` antes de `fits?`. UI `team.erb` mostra `S n/3`.
- **Furo comprovado:** `4×S 480 >450` bloqueia, mas `4×S_r 60 =240` e `6×S_r 360` cabem. `curl -c /tmp/c POST /team` sequencial `growlithe 60 → onix 60 → porygon 60 =180`, 4º `magnemite 120` projetaria `300` (<450) mas trava hard bloqueia — sem trava, 4º S entraria. `GET /pokemons?tier=S` confirma mix 120/60◆.
- **Magic number:** com desconto 50% não existe `B` que satisfaça `3S+3F≤B<4S_r+2F` (exige `B<420` e `B≥420` ao mesmo tempo). Threshold p/ `B 450` é `S_r ≥108` (`4×108+20=452`).
- **Decisão do playtest (2026-08-27):** subir `S_r` para **110** (desconto ~8% p/ S, demais tiers mantêm 50%). Mantém números redondos e fecha:
  - `3S+3F = 420 ≤450 OK`, `4S+2F = 520 bloq`
  - `3S_r+3F = 390 ≤450 OK`, `4S_r+2F = 480 bloq` (`4×110+40`)
  - `4S_r+2Fr(10)=460 bloq`, `6S_r=660 bloq`
  - Alternativa `S_r 100` descartada: `4×100+40=440 FURO` com `B 450`; só fecharia com `F 30` ou `B <420` que quebra `3S`.
- **Mudança proposta (próxima sessão refinamento):**
  - `TeamBudget.cost_for`: `restricted ? (line_tier=="S" ? 110 : base/2) : base` (ou `max(base/2,110)` p/ S) — floor 110 p/ S restrito.
  - Remover `S_LIMIT = 3` e `s_limit_ok?` / `s_limit_notice` (`server.rb:611-614`, `team_budget.rb:34`) e UI `S n/3` → `S n` (ou remover contador).
  - Bloqueio de 4º S passa a ser só `budget_notice` ("Orçamento insuficiente").
  - Atualizar `test/team_budget_test.rb` (expect 60→110 p/ S restrito, `s_limit_ok?` removido) e `team_routes_test.rb` (4º S bloqueado por budget, não por S_LIMIT).
- **Status:** Draft — aguardando refinamento SDD (fase 1) após validar playtest. Não abre escopo na sessão corrente (RNF-04).

### RESP-1. Responsividade (playtest 02, 2026-08-27)

- **Playtest:** browser-harness CDP 375/768/1024/1440, `public/style.css:11-384`, `views/layout.erb`. Sem `meta viewport` — mobile renderiza 980.
- **Achados (levantamento):** grid 6 col até 720 quebra tablet 768 (42px), filtros 7 controles 165px em 320, `list-team-grid` 2 col espremida em 768, `battle-layout 3×1fr` sem breakpoint.
- **Proposta (draft-ui-ux §7, playtest-02):** P0 viewport+grid auto-fill+team collapse 960; P1 filtros drawer+battle stack 900; P2 barras fluidas.
- **Status:** Draft — sessão SDD futura após M2b.

### PLAYTEST-03. Rodada completa de gameplay (2026-08-27)

- **Loop:** montar 6 starters 420/450 → batalha 6 rounds lose 40 XP/40$ → heal 131 > saldo 40 → Game Over softlock; buy/sell 20/10 não recupera; history/manage/remove 5/6 escapa.
- **Achados design:** economy death spiral (lose 40 vs heal 131), XP 50/40 grind ok, oponente band F/D mas venceu A, itens 80 inacessíveis early.
- **Achados UI:** lista+time ok mas filtros 117px, grid 6 col tablet, battle 3 col sem breakpoint, manage lista longa, histórico UUID, nav sem badge.
- **Bugs P0:** heal trap, remove escapa Game Over, HP zero persistente; P1: pokemon.erb sem aspas, sem viewport, grid, manage, UUID; P2: race add, OPP pool, PP Struggle.
- **Artefato:** `playtest-03-gameplay.md` — virará sessões `RESP-1`, `M2b`, `ECO` rebalance.

### Próximas 2026-08-29 — progressão inicial (validado em 0066, fora desta — RNF-04)

> **Anotado em 2026-08-29 na validação da 0066 (não refinado agora).**

- **Times iniciam no nível 5:** `TeamRepository#add` + `ProgressionRepository#create` devem criar progresso `level: 5` (não 1). Afeta `RewardRule`/`ExperienceCurve`, `average_player_level`, `band_for_level`/`generation_for_level` e custo inicial. Sem migração retroativa automática (times existentes ficam no nível atual).
- **Vitórias +2 níveis, derrotas +1:** `BattleService#grant_finished_xp` / `RewardRule` ou `ProgressionRepository#grant` — vitória concede XP equivalente a 2 níveis (`level*100*2` ou `grant` 2×), derrota 1 nível (hoje win 50/draw 25/lose 20 com curva `level*100`). Definir curva pós-mudança (manter `level*100` ou ajustar) e interação com evolução/aprendizado por nível. Testes novos: `progressao_inicial_e_recompensa_test.rb`.

### Encerramento — HTMX 4.0 + skills (anotado 2026-08-29, fora do fluxo — RNF-04)

> **Anotado em 2026-08-29 (fim de projeto, não refinado agora).**

- **Atualizar para HTMX 4.0:** `public/` + `views/layout.erb` (CDN/script) migrar de 1.x para **4.0** (breaking changes: `hx-*` → novo sintaxe se houver, `htmx.config` , `hx-indicator`/`hx-swap-oob` preservados). Testes htmx (`hx-get`/`hx-trigger="load"` em `#team` e `hx-delete`/`hx-sync`) devem continuar verdes. Sem mudar rotas/domínio.
- **Adicionar skills da atualização:** mapear e instalar as **skills** (Agent Skills) da atualização HTMX 4.0 — inventariar `/.agents/skills`, `/.claude/skills` e `.opencode/skills` afetados, atualizar `AGENTS.md`/`CLAUDE.md` routing se mudar.

### 0069 (resolver batalha) — ideias fora de escopo anotadas (2026-09-02, RNF-04)

> **Anotado no refinamento da 0069 (não refinado agora — fora do escopo fechado pelo usuário).**

- **Animação de painéis/HP/barras e projéteis durante a resolução** — a 0069 anima só o **log** (fade/slide-in escalonado). Animar painéis/HP e projéteis fica para o **0063 juice** e a ideia **C2** (animações nos ataques, § acima) — fora.
- **Polling/SSE/streaming da resolução** — a 0069 resolve num **único request** (decisão D1). Se o log ficar muito longo no futuro, avaliar streaming — ideia anotada, fora.
- **Persistência do log de batalha em DB** — hoje o log é derivado do engine em memória (`BattleLogPresenter`); persistir rodadas em tabela fica como ideia futura — fora.
- **Mudanças na economia (XP/dinheiro/recompensas)** — a 0069 preserva `finish_effects` 1× (D4); ajustar valores/curvas segue para sessão futura dedicada — fora.
- **Mecânica de batalha em si (`BattleEngine`)** — a 0069 não toca `BattleEngine#battle` (157-164; 35 callers, contador `@rounds` local); mudar o motor é sessão futura — fora.
