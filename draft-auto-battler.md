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

> **Fora do fluxo (RNF-04).** Anotado durante a validação da sessão 0045: o usuário
> equipou o **mesmo `choice-band` em 2 pokes diferentes** do time e isso foi
> permitido. Não é critério da 0045 (a 0045 trata de *uso* em batalha, não de
> *equipamento*); registrado como candidata a sessão própria.

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
- **Aberto:** nada em aberto de regra — resta fechar no refinamento apenas a
  nomenclatura exata da "quantidade livre" na UI.
- **Aguarda sessão (RNF-04).**

### JN-4. Componentes de Poke Mart e Poke Center

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
