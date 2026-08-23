# Sessão 0040 — J3: ranking S–F (balanceamento de oponentes)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-23 |
| Implementação | **Concluída** — passos 1–5 em 2026-08-23 (suíte 649/2063, lint 0) |
| Validação | **Done** — executada pelo usuário em 2026-08-23 (tabela da seção 7) |

---

## 1. Objetivo

Classificar cada Pokémon em um **rank S–F** via **`PokemonRating`** (domínio puro, no
molde de `TypeEffectiveness`) a partir de **stats ponderados + bônus dos moves
representativos (STAB-aware)**, e consumir o rating no **`OpponentGenerator`** para
**balancear os times adversários pela progressão do jogador** (banda de tier derivada
do nível médio do time) — em vez do sorteio puro do pool.

## 2. Contexto (estado atual — diagnóstico)

- `lib/opponent_generator.rb` — `team_names` sorteia `size` nomes do pool
  (`names.sample(random: @rng)`); `team` busca os detalhes via `fetcher` injetado.
  **Sorteio puro, sem noção de força** dos Pokémon.
- `lib/battle_service.rb:63` — `build_opponent` monta
  `OpponentGenerator.new(names: api.fetch_all_names, fetcher: api.method(:detail),
  rng: Random.new(user_id.sum), level: 1, parallelizer: Parallelizer)` — oponentes
  aleatórios de **todo o pool**, sempre nível 1, **independentes do progresso** do
  jogador. `average_player_level` já existe (linha 73).
- `lib/pokemon.rb` — Dry::Struct com `stats` (`[{name:, value:}]`) e `types`;
  `lib/move.rb` — `Move` com `type`/`power` (status moves têm `power: nil`).
- Gateway (`lib/gateways/poke_api.rb`): `moves_for(number)` → `[Move]` (os **últimos
  4 moves aprendidos** — os que o Pokémon usa em batalha); `fetch_all_names` →
  `[String]`. Em teste tudo é stub (sem rede).
- Drafts: `draft-auto-battler.md` §J3 (rating S–F, `PokemonRating` no molde de
  `TypeEffectiveness`) e `draft-arquitetura-design-patterns.md` §5 (Rating —
  "fórmula a definir"; pergunta em aberto: fórmula, onde computada, exposição na UI).

## 3. Escopo

### Produção

- `lib/pokemon_rating.rb` — **novo**. `PokemonRating` (domínio puro, sem rede):
  - `STAT_WEIGHTS` — `{ "HP" => 0.5, "Attack" => 1.0, "Defense" => 1.0,
    "Sp.Atk" => 1.0, "Sp.Def" => 1.0, "Speed" => 1.0 }` (stat ausente → 0).
  - `rate(pokemon, moves: [])` → `{ score: Integer, tier: Symbol }`.
    `score` = soma dos stats ponderados + bônus de moves; `tier` por thresholds.
  - Bônus de moves: considera só moves com `power > 0`; power efetivo ×1.5 quando
    `move.type ∈ pokemon.types` (STAB); bônus = média do power efetivo dos **top-4**
    (ou todos se < 4); 0 se nenhum damaging move.
  - Thresholds de tier: **S ≥ 600, A ≥ 500, B ≥ 420, C ≥ 350, D ≥ 280, F < 280**.
  - `band_for_level(level)` → banda de tiers aceitos para oponentes:
    ≤ 2 → `[:F, :D]`; 3–5 → `[:D, :C]`; 6–9 → `[:C, :B]`; 10–14 → `[:B, :A]`;
    ≥ 15 → `[:A, :S]`.
- `lib/opponent_generator.rb` — novos params opcionais: `rater:` (callable
  `(pokemon, moves) → tier`), `moves_fetcher:` (callable `(number) → [Move]`),
  `band:` (`[Symbol]`). Quando os três presentes, `team_names`:
  1. percorre o pool em ordem aleatória determinística (via `@rng`);
  2. busca detalhe (`fetcher`) + moves (`moves_fetcher`) e classifica (`rater`);
  3. coleta só nomes cuja tier ∈ `band` até atingir `size`;
  4. esgotou o pool sem completar → **preenche o resto com sorteio puro (fallback)**.
  Sem `rater`/`band` → **comportamento atual preservado** (sorteio puro).
- `lib/battle_service.rb` — `build_opponent` computa
  `band = PokemonRating.band_for_level(average_player_level(user_id, team))` e injeta
  `rater:`/`moves_fetcher:`/`band:` no `OpponentGenerator`
  (`rater` usa `PokemonRating.rate(pokemon, moves: moves)`; `moves_fetcher` =
  `api.method(:moves_for)`).

### Testes

- `test/pokemon_rating_test.rb` — **novo**: score por stats ponderados; bônus de
  moves (STAB, sem STAB, status move ignorado, sem moves → 0, top-4); thresholds →
  tier (S/A/B/C/D/F); determinismo; `band_for_level` (5 bandas).
- `test/opponent_generator_test.rb` — banda: com `rater`+`band` seleciona só tiers da
  banda; fallback quando a banda esvazia; sem `rater`/`band` → sorteio puro intacto;
  determinismo com seed.
- `test/battle_service_test.rb` — `build_opponent` usa a banda derivada do nível
  médio (com stubs de `rater`/`fetcher`/`moves_fetcher`).

### Fora de escopo (não abrir)

- Exposição do rank na UI (selo S–F no detalhe/lista), calibração fina da fórmula e
  thresholds (heurística inicial — ajuste reabre critério via S3), ondas 1–3 de UX,
  JN-3/JN-4/JN-5, J2, J4, D4, identidade, seeds/validação.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 — `PokemonRating#rate(pokemon)` classifica S–F** com score por stats
      ponderados (weights + thresholds) — prova: `test/pokemon_rating_test.rb`
      (`test_rate_stats_weighted_*`, `test_rate_tier_thresholds_*`).
- [ ] **C2 — Bônus de moves integra o score** (média do power efetivo top-4,
      STAB-aware; status/sem moves → sem bônus) — prova: `test/pokemon_rating_test.rb`
      (`test_rate_moves_*`).
- [ ] **C3 — `PokemonRating.band_for_level(level)`** mapeia nível médio → banda de
      tiers aceitos — prova: `test/pokemon_rating_test.rb`
      (`test_band_for_level_*`).
- [ ] **C4 — `OpponentGenerator` com `rater`+`band` seleciona só nomes da banda**,
      com fallback puro quando a banda esvazia; sem `rater`/`band` comportamento
      atual preservado — prova: `test/opponent_generator_test.rb`
      (`test_team_names_filters_to_band_*`, `test_team_names_fallback_*`,
      `test_team_names_without_rater_unchanged`).
- [ ] **C5 — `BattleService#build_opponent` injeta rating + banda derivada do nível
      médio do jogador** — prova: `test/battle_service_test.rb`
      (`test_build_opponent_uses_band_from_player_level`).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (626 runs/2017 asserts)** + novos
      testes e lint 0 em **todo** green; commit obrigatório por passo; 0 regressão.
- [ ] Sem gems novas / sem mudança de schema / testes sem rede / sem `rubocop:disable`.
- [ ] `REQUIREMENTS.md` + `SESSIONS.md` + `draft-auto-battler.md` atualizados no mesmo
      escopo do passo docs; *status de validação* só após o usuário validar (S4).

> **S1:** cada critério acima aponta o teste que o prova (arquivo/nome Minitest).
> Sem teste automatizado → `manual` explícito.

## 5. Decisões de refinamento (fechadas com o usuário)

- **2026-08-23 — J3 retoma a fila como 0040** (SESSIONS.md:112) — preterido:
  Onda 1 UX (jornada visível) primeiro.
- **2026-08-23 — Escopo: componente + consumo no `OpponentGenerator`** com banda de
  tier derivada do nível médio do jogador (`BattleService#build_opponent`) —
  preterido: só o componente `PokemonRating`.
- **2026-08-23 — Fórmula: stats ponderados + bônus dos moves representativos**
  (`moves_for` — últimos 4 aprendidos, top-4, STAB-aware) — preterido: só stats.
- **2026-08-23 — Retorno: `score` + `tier`, sem exposição na UI** — preteridos:
  selo S–F na UI; só tier (sem score).
- **2026-08-23 — Heurística inicial da fórmula** (calibrável via S3): pesos
  HP×0.5 / demais ×1.0; bônus = média do power efetivo top-4; thresholds
  S≥600 / A≥500 / B≥420 / C≥350 / D≥280 / F<280.
- **2026-08-23 — Banda por nível**: ≤2→F–D; 3–5→D–C; 6–9→C–B; 10–14→B–A; ≥15→A–S.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (S4) | commit `Sessao 0040: refinamento concluido — ...` |
| 1 | C1/C2 — `PokemonRating#rate`: score stats ponderados + bônus moves (STAB, top-4, sem moves) + thresholds → tier | suíte verde + lint 0, commit `Passo 1:` |
| 2 | C3 — `PokemonRating.band_for_level` (5 bandas) | suíte verde + lint 0, commit `Passo 2:` |
| 3 | C4 — `OpponentGenerator` com `rater`/`moves_fetcher`/`band` + fallback puro; sem rater/band → intacto | suíte verde + lint 0, commit `Passo 3:` |
| 4 | C5 — `BattleService#build_opponent` injeta rating + banda por nível médio | suíte verde + lint 0, commit `Passo 4:` |
| 5 | **Docs:** REQUIREMENTS.md (roadmap — J3 executado, `Planejada` até validação), SESSIONS.md (0040 fase 2 + próximas), draft-auto-battler.md (J3 executado) | suíte verde + lint 0, commit `Passo 5:` |
| — | **Fase 2 concluída** → **PARAR** para validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Concluída em 2026-08-23 — validada pelo usuário** *(S2: uma linha por critério).*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 rate stats → tier | `./scripts/test test/pokemon_rating_test.rb` | — (domínio puro) | ok |
| C2 bônus de moves | `./scripts/test test/pokemon_rating_test.rb` | — (domínio puro) | ok |
| C3 band_for_level | `./scripts/test test/pokemon_rating_test.rb` | — (domínio puro) | ok |
| C4 oponentes na banda | `./scripts/test test/opponent_generator_test.rb` | jogar batalha: oponentes coerentes com o nível do time (não só o pool aleatório) | ok |
| C5 banda por nível no service | `./scripts/test test/battle_service_test.rb` | `GET /battle` gera oponentes da banda esperada para o nível médio | ok |

> **Nota de validação:** comportamento validado, mas o **`GET /battle` demorou ~2min**
> (1ª chamada). Causa provável: a **varredura serial da banda** no `OpponentGenerator`
> (percorre o pool chamando `detail` + `moves_for` por candidato até preencher a banda)
> + re-fetch de `moves_for` por oponente escolhido — soma-se ao warm-up existente da
> PokéAPI. Anotado como limitação (RNF-04, fora de sessão) — candidato a sessão própria
> de performance (paralelizar a varredura, cap de varredura, pré-computar/cachear o
> rating ou pré-cachear a banda offline). **Não reabre critério (S3):** todos ok no
> comportamento; a lentidão é melhoria de performance anotada.

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

- Fila fechada (2026-08-18) retomada em **J3** após JN-1; depois ondas 1–3 de UX a
  critério → organizar o resto (JN-3, JN-4, JN-5, J2, J4, D4).
- Fórmula e thresholds são **heurística inicial**; se a validação mostrar times
  oponentes desbalanceados (muito fortes/fracos para o nível), reabrir o critério
  (S3) para calibrar — pesos, top-N, bandas por nível.
- `average_player_level` já existe em `BattleServicePreparation` (linha 73) — reusar.
- O `moves_for` da banda usa o mesmo `api` do `fetcher` (cache P1) — sem custo novo
  de rede além do que a batalha já faz.
- **Performance observada na validação (2026-08-23):** `GET /battle` ~2min na 1ª
  chamada — varredura serial da banda (`OpponentGenerator#rated_names` percorre o
  pool com `detail` + `moves_for` por candidato até preencher a banda, sem
  paralelismo e sem cap de varredura). Anotado em `REQUIREMENTS.md` (limitações) e
  `draft-auto-battler.md` (anotações de performance) como candidato a sessão própria
  — não abre escopo nesta sessão (RNF-04).