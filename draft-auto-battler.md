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
- **Objetivo:** transformar `Pokemon` em unidade de combate (covarde = do board).
- **Decisões:** `BattlePokemon` pura (Dry::Struct ou dado simples): `hp_max` derivado do
  base stat HP, `hp_current`, `types`, `stats`, `energy`... estado por rodada; métodos
  `take_damage`, `alive?`, `fainted?`.
- **Critérios:** `[ ]` conversão de `Pokemon` → `BattlePokemon` (hp_max calculado);
  `[ ]` `take_damage` reduz HP sem ir negativo; `[ ]` `alive?`/`fainted?` coerentes;
  `[ ]` 100% de domínio puro (sem PG, sem rede).
- **Plano TDD:** testes de unidade puros.

### B2. Efetividade de tipos
- **Objetivo:** precisão de dano por tipo (fraqueza x2, resistência x0.5, imune x0, STAB).
- **Decisões:** fonte = tabela da PokéAPI (`damage_relations` de `GET /type/:name`),
  carregada com cache (como RF-01); lookup `(tipo_atacante, tipo_defensor) → fator`;
  STAB = 1.5 quando o atacante tem o tipo do golpe. Sem rede nos testes (stub).
- **Critérios:** `[ ]` fator correto p/ (fire → grass)=2, (fire→water)=0.5, (electric
  → ground)=0, STAB quando senão; tabela completa para os 18 tipos; cache.
- **Plano TDD [0]**: lookup pure; **[1]** fetcher+stub; **[2]** STAB; **[3]** cache.

### B3. Motor de auto-batalha (o game loop)
- **Objetivo:** simular 6v6 automático usando os 6 slots; retorna log + vencedor.
- **Decisões:** `BattleEngine` recebe dois times (`[BattlePokemon]` ordenados por slot
  e computed por Speed); a cada rodada: todos os vivos agem em ordem de **Speed**
  (empate → slot menor); golpe aplica `danobase * tipo * STAB`; HP 0 → KO; fim quando
  um lado zerar; log de ações (`t` rodada, atacante, alvo, dano, KO).
- **Critérios:** `[ ]` resultado determinístico (seed) e/ou com RNG injetável;
  `[ ]`6v6 não quebra com times parciais; `[ ]` log completo e vencedor; `[ ]` domínio
  puro, ~sem rede; coberto 100% por unit tests.
- **Plano TDD [0]**: rodada single (ataque+danor); **[1]** ordem por speed; **[2]**
  loop até KO do side; **[3]** log/vencedor; **[4]** edge (times vazios).

### B4. Oponente automático
- **Objetivo:** gerar adversário para o usuário enfrentar sem montar time próprio.
- **Decisões:** sorteia N slugs da lista da PokéAPI (cache RF-01), busca dados
  (PokeApi.detail, pode ser stub/offline? aparando campo limitado) e monta 6v6 com
  o `BattleProvider`; `Opponent<generato `race` random seed p/ variar partida.
- **Critérios:** `[ ]` gera time de tamanho definido (ex.: 6); `[ ]` não repete
  Pokémon iguais no mesmo time; `[ ]` respeita a tabela de tipos disponível; stubs nos
  testes.

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

## Próximos passos (fora deste arquivo)

1. **0007**: implementar + validar (TDD) — montagem de times é pré-requisito de B/C.
2. Logo após validar: **elencar o que fica e o que sai** da lista acima,
   definir ordem e transformar os escolhidos em **documentos de sessão** com
   critérios fechados e plano TDD (como a 0007).
3. **Nota:** B3 (motor) destrav não depende de B1/B2 sequenciais A/B — ordem sugerida:
   B1 → B2 → B3 → B4 → C1. A1/A2 podem entrar em paralelo ao game loop se desejado.
