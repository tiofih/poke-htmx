# Sessão 0011 — Motor de auto-batalha (B3) — game loop 6v6 determinístico, domínio puro

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída — decisões fechadas com o usuário em 2026-08-08 |
| Implementação | Concluída — passos 0–9 TDD, suíte 110 runs/398 asserts e lint 0 verdes |
| Validação | Pendente (executada pelo usuário) |

---

## 1. Objetivo

Simular **combate automático 6v6** entre dois times de `BattlePokemon` — o **game loop**
do auto-battler (B3). Dado dois times (cada um já ordenado por slot, ex. `all(user_id)`
de RF-07), o motor: resolve os **turnos por rodada**, calcula **dano** a partir de
stats + tipos, aplica KO ao zerar HP, acumula um **log de ações** e devolve o
**vencedor** (ou empate). **Sem golpes** (D1 é fora de escopo) e **sem rede** —
domínio puro.

Determinístico para iterar/testar rápido; **RNG injetável fica anotado** para iteração
futura (ver Observações/draft).

## 2. Contexto (estado atual)

- `BattlePokemon` (RF-09/sessão 0009) já é unidade de combate pura: `hp_max`, `hp_current`,
  `take_damage` (funcional, clamp em 0), `alive?`/`fainted?`. **Não tem** acesso por stat
  (Speed/Attack/Defense) — o motor precisa de um helper.
- `TypeEffectiveness` (RF-10/sessão 0010) é o lookup puro: `factor`, `effectiveness`,
  `stab` e `damage_multiplier(attacker_types:, move_type:, defender_types:)`. O motor vai
  consumi-lo para o multiplicador de dano por tipo.
- `Pokemon/stats` (RF-06): array de hashes `{ name:, value: }` — HP, Attack, Defense,
  Sp.Atk, Sp.Def, Speed. `BattlePokemon.from` já extrai HP para `hp_max`.
- `TeamRepository` (RF-07/RF-08) devolve o time por slot (`all(user_id) ORDER BY slot`);
  a **ordem de slots é o input do game loop** (RF-08). O motor não toca PG — **recebe**
  os dois times (arrays de `BattlePokemon`) já ordenados.
- Draft B3 (`draft-auto-battler.md`): motor recebe dois times `[BattlePokemon]`; a cada
  rodada os vivos agem em ordem de **Speed** (empate → slot menor); dano = dano base × tipo
  × STAB; HP 0 → KO; fim quando um lado zerar; log de ações; **determinístico**
  (sem RNG por ora — RNG anotado).
- Sem rota, sem schema nesta sessão — o motor é núcleo de domínio puro (sessão 0009/0010
  no mesmo molde).

## 3. Critérios de aceite

### `BattlePokemon.stat` (extensão mínima de B1)

- [ ] `stat(name)` em `BattlePokemon` devolve o **valor** do stat `name` (ex.:
      `stat("Speed")` → 90) e `1` quando ausente (ex.: sem Attack → 1).
- [ ] Sem regressão em B1: `from`, `take_damage`, `alive?`/`fainted?` continuam idênticos;
      suíte de `test/battle_pokemon_test.rb` verde.

### `BattleEngine` — batalha 6v6

- [ ] `BattleEngine.new(team_a:, team_b:, effectiveness:)` — times são
      arrays de `BattlePokemon` ordenados por slot (posição no array = slot); a
      ordem vem do caller. `effectiveness:` é um `TypeEffectiveness` injetado (default
      `TypeEffectiveness.load`), nunca cria rede dentro do motor (sem rede no motor).
- [ ] Uma **rodada** = os vivos dos dois times agem uma vez cada. Ação de um atacante:
      escolhe o **alvo** (ver estratégia de alvo), soma o **dano** sobre ele e marca KO
      se o HP chegar a 0.
- [ ] **Ordem de ação** (determinística): vivos de **ambos os times** ordenados por
      **Speed** decrescente; desempate → time 0 primeiro, depois **slot (índice)** menor.
- [ ] **Alvo**: `primeiro vivo por slot` do time adversário (índice menor), deixando a
      estratégia de alvo isolada em chamada/classe injetável (futuro: outras estratégias).
- [ ] **Dano** por ataque = `max(1, Attack(atacante) − Defense(alvo))`
      (dano base ≥ 1); multiplicador = **melhor tipo do atacante** contra os tipos do alvo
      (inclui STAB; `TypeEffectiveness#damage_multiplier`); dano final ≥ 1.
- [ ] **Escolha de tipo**: o `move_type` do ataque é o **tipo do atacante que dá maior
      dano ao alvo** (ex.: `["grass","poison"]` contra `["water"]` usa grass ×2); se o melhor
      der multiplicador **0** (imune), usa golpe **neutro** (multiplicador 1.0, sem STAB)
      — nunca fica com dano zero e o loop nunca trava.
- [ ] **KO**: HP ≤ 0 → `fainted?`; combatente com `fainted?` não age nem é alvo na rodada.
- [ ] **Fim**: quando um lado não tem vivos → o outro **vence**; se ambos zerarem na mesma
      ação → **empate** (`winner` nil). Times vazios no início → sem ações; vence o time
      **não-vazio**; ambos vazios → **empate**.
- [ ] **Resultado**: objeto `BattleResult` com `winner` (0/1/nil), `log` completo e
      `rounds`. **Log**: array de entradas por ação com `round`, `attacker`,
      `move_type`, `damage` e `ko` (bool) — ordem de ação efetiva.

### Garantias (RNF)

- [ ] Motor **100% domínio puro** — sem PG, sem rede; só recebe os times e a efetividade.
- [ ] **Determinístico**: mesma entrada → mesmo resultado e mesmo log (sem RNG).
- [ ] Testes **sem rede** (`TypeEffectiveness.from_relations` injetado), suíte completa
      verde (`./scripts/test`), lint 0 offenses, commit a cada green (RNF-04).
- [ ] Sem regressão (RF-01..RF-10 seguem verdes; `BattlePokemon`/`TypeEffectiveness`
      intactos — a única adição é `stat`).
- [ ] `REQUIREMENTS.md` (novo **RF-11 — Motor de auto-batalha (B3)**), `SESSIONS.md`
      (0011) e `draft-auto-battler.md` (B3 em execução + nota de RNG) atualizados no
      mesmo escopo.

## 4. Decisões de refinamento

- **Dano base = `max(1, Attack − Defense)`** — stats de ataque/defesa importam de
  verdade; nunca abaixo de 1 (o loop não trava). (decisão do usuário)
- **Dano mínimo 1 por ataque**, independentemente do multiplicador: quando o melhor tipo
  do atacante der ×0 (imune), o golpe vira **neutro** (×1, sem STAB). Dano zero não
  existe → **sem loop infinito**.
- **Alvo = primeiro vivo por slot** do adversário; seleção fica **injetável** (formato
  strategy/callable) para o futuro trocar de estratégia sem refazer o motor. (decisão do
  usuário)
- **Determinístico agora, RNG depois**: motor sem seed/aleatoriedade; **RNG injetável**
  fica anotado no `draft-auto-battler.md` para iteração futura (variar dano/jogadas). (decisão do usuário)
- `BattlePokemon` ganha **`stat(name)`** (default `1`) — o motor lê `stat("Speed")`,
  `stat("Attack")`, `stat("Defense")` com clareza. Pequena extensão de B1 (RF-09), sem
  mudar o contrato existente. (decisão do usuário)
- **`move_type` é o melhor tipo** do atacante para o alvo — sem golpes (D1 fora de
  escopo), cada atacante "usa" o tipo que garante o maior multiplicador (fraqueza ×2 >
  neutro > ×0.5). Determinístico e testável. (decisão do usuário)
- **Ordem por Speed global entre os dois times**: Speed desc, desempate time 0
  primeiro, depois índice/slot. Simples, determinístico, alinhado ao draft.
- **Rodada completa**: todos os vivos agem uma vez por rodada; o fim é verificado **a
  cada ação** (se um lado zera no meio, o que segue não age — vencedor declarado na
  hora).
- `effectiveness` é **injetado** no construtor (default `TypeEffectiveness.load`) — o
  motor nunca faz rede; nos testes, `TypeEffectiveness.from_relations(...)` de stubs.
- **Arquivos**: `lib/battle_engine.rb` (`BattleEngine`, `BattleResult`) +
  `test/battle_engine_test.rb`; `lib/battle_pokemon.rb` só ganha `stat`.
- Fora de escopo: rota/UI (C1), moves (D1), RNG, PG, rede.

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) |
| --- | --- | --- |
| 0 | `BattlePokemon#stat("Speed")` devolve 90 (com valor) e 1 (sem o stat); testes de B1 já existentes seguem passando | `stat(name)` em `lib/battle_pokemon.rb` (find no array `stats`, default 1) |
| 1 | `BattleEngine.new` aceita os dois times e um `TypeEffectiveness` (default `load`); times preservam ordem; 1v1: atacante (Speed maior) ataca o único alvo, dano aplica, log/winner | esqueleto de `lib/battle_engine.rb` + `battle` com rodada única |
| 2 | **Dano**: `(Attack − Defense)` com mínimo 1; exemplos: A(100)/D(40) → 60; A(20)/D(40) → 1; multiplicador do melhor tipo inclui STAB | cálculo `damage_for(attacker, target)` usando `TypeEffectiveness` |
| 3 | **move_type**: atacante `["grass","poison"]` vs `["water"]` usa "grass" (×2); melhor tipo imune (×0) → neutro (×1.0, dano ≥1) | seletor de `move_type` + dano mínimo |
| 4 | **Ordem por Speed** com desempate: time 0 primeiro, depois índice; 2v2 com Speed variado age na ordem certa | sorteio/ordenação dos vivos por rodada |
| 5 | **Loop 6v6**: times parciais (menos de 6 membros) rodam até um lado zerar; winner/loss; KO na hora (fainted não age) | loop de rodadas até a vitória |
| 6 | **log**: cada ação com `round`, `attacker`, `move_type`, `damage`, `ko`, na ordem de execução; `rounds` correto | montagem do `log` no `BattleResult` |
| 7 | **Edge/empate**: time sem vivos → derrota; ambos vazios → `winner` nil (empate); fim de ação | cobertura de casos parciais/vazios + vencedor |
| 8 | suíte completa verde + lint 0 | checagem global |
| 9 | `REQUIREMENTS.md` (RF-11, roadmap/B3), `SESSIONS.md` (0011), `draft-auto-battler.md` B3 em execução + nota RNG (aguardando a validação) | documento |

## 6. Observações e próximo passo

- O motor é **núcleo de domínio puro**: nada de rota/UI/PG/rede. O C1 (batalha na web,
  htmx) volta ao draft como próxima após a validação de B3 — será a camada que chama
  `BattleEngine` com `TypeEffectiveness.load` e os times do usuário/oponente (B4).
- **RNG injetável (anotado para o futuro)**: hoje o motor é 100% determinístico. Quando
  quisermos variar as partidas, o `BattleEngine` e o seletor de golpe/move recebem um
  `rng` (default `Random.new(0)`/seed fixa), preservando os testes com seeds. Registro no
  `draft-auto-battler.md`.
- Exemplo de log esperado (1v1, A speed 90 vs B 10, A=fire vs B=grass):
  `[{ round: 1, attacker: 0, move_type: "fire", damage: 2, ko: false }]`.
- Ao rodar `./scripts/test test/battle_engine_test.rb` o passo respectivo deve ficar
  verde antes do próximo passo (TDD); `./scripts/lint` no final.
- Próxima sessão sugerida após validação: **B4 — Oponente automático** (gera time adversário
  para o usuário) e/ou **C1 — Batalha na web (htmx)** consumindo o `BattleEngine`.

## 7. Validação (a preencher pelo usuário)

- Pendente. Implementação TDD concluída em 2026-08-08 (passos 0–9; suíte completa 110
  runs/398 asserts e lint 0 verdes; commits por green). Critérios de aceite da seção 3
  implementados (marcados `[x]` em `REQUIREMENTS.md` como "aguardando validação").
- Aguardando feedback do usuário para verificar os critérios e fechar a sessão.