# Sessão 0050 — P2: performance da varredura da banda do oponente

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-25 |
| Implementação | **Concluída** — passos 1–5 em 2026-08-25 (suíte 748/2387, lint 0) |
| Validação | **Pendente** (executada pelo usuário) |

---

## 1. Objetivo

Reduzir o custo da **primeira batalha** (`GET /battle` ~2min, observado na validação da
0040) sem mudar o comportamento da banda: **varredura paralela em lotes** da banda do
`OpponentGenerator` (via `Parallelizer`, determinística por seed) + **cap de varredura**
com fallback puro + **cache de rating por Pokémon** (`PokemonRatingCache`, persistente)
que evita re-ratear (re-fetch de `detail` + `moves_for`) espécies já avaliadas.

## 2. Contexto (estado atual — diagnóstico)

- `lib/opponent_generator.rb:45` — `rated_names` percorre o pool **serial** em ordem
  aleatória (`@names.shuffle(random: @rng).each`) chamando `in_band?` por candidato —
  `in_band?` (linha 58) faz `@fetcher.call(name)` (detail) + `@moves_fetcher.call(number)`
  + `@rater.call(pokemon, moves)` — até preencher `size`; sem paralelismo e **sem cap**.
  Esgotou o pool → fallback puro (`remaining.sample`, linha 55). Bandas estreitas
  (A–S em nível alto) podem varrer centenas de nomes antes de completar 6.
- Depois da banda, `team` (linha 31) re-busca `detail` dos escolhidos (via `@parallelizer`),
  e `BattleService#opponent_team` (`lib/battle_service.rb:55`) re-faz `moves_for` de cada
  oponente. Com a rede fria (1ª batalha), o serial domina o tempo.
- `lib/battle_service.rb:80` — `build_opponent` deriva a banda do nível médio e injeta
  `rater:`/`moves_fetcher:`/`band:`/`parallelizer:` em `opponent_options` (linha 91).
- Cache existente (P1/0040): `PokeApiCache` em memória (TTL 600s, LRU 1000) sobre
  `PokeApiHttp` com `PersistentJsonStore` em arquivo (`tmp/pokeapi_cache.json`, TTL 7d)
  — já cobre `detail`/`moves_for`/`fetch_all_names` entre boots. O rating em si
  (`PokemonRating.rate`, `lib/pokemon_rating.rb`) é recomputado a cada batalha.
- O rating é **função estável da espécie** (`stats` + `moves_for` são constantes por
  número) → cacheável por nome.
- Anotação P2: `draft-auto-battler.md` ("P2. Varredura da banda do oponente (J3) sem
  paralelismo", 2026-08-23) — caminhos candidatos A (paralelizar), B (cap), C
  (pré-computar/cachear rating), D (evitar duplo fetch).

## 3. Escopo

### Produção

- `lib/opponent_generator.rb` — novo caminho **`ratings:`** (callable `(name) → tier`):
  quando presente (com `band:`), `rated_names`:
  1. embaralha o pool com `@rng` (ordem determinística por seed — intacta);
  2. avalia os candidatos **em lotes paralelos** via `@parallelizer` (lote = fatia do
     pool embaralhado), coletando os nomes na **ordem do lote** até preencher `size`;
  3. interrompe ao completar a banda **ou** ao atingir `max_candidates:` (opção nova,
     default `nil` = sem cap → comportamento atual);
  4. não completou dentro do cap/pool → **preenche o resto com sorteio puro (fallback
     existente)**.
  `in_band?` no caminho `ratings` = `tier = @ratings.call(name); tier && @band.include?(tier)`
  (sem fetch de detail/moves na varredura). Sem `ratings` → **caminho atual
  (`rater`/`moves_fetcher`) preservado intacto** (serial, backward-compat).
- `lib/pokemon_rating_cache.rb` — **novo**. `PokemonRatingCache` persistente (molde
  `PersistentJsonStore`/P1, **sem** Faraday): `initialize(path:, ttl: DEFAULT_TTL = 7d,
  clock: nil, fetcher:, moves_fetcher:, rater: PokemonRating.method(:rate))`;
  `rating_for(name) → tier | nil` — miss computa (`fetcher` detail → `moves_fetcher` →
  `rater`) e grava em arquivo (write-through tmp+rename); hit devolve o tier sem re-fetch;
  `detail` nulo → `nil` e **não** cacheia; thread-safe (lock por chave).
- `lib/battle_service.rb` — `opponent_options(band)` passa a injetar `ratings:` (lambda
  sobre o `@rating_cache`) e `max_candidates: RATING_SCAN_CAP` (constante, default **256**,
  heurística ajustável via S3); nova dependência `dependencies[:rating_cache]` (default
  memoizado: `PokemonRatingCache.new(path: ENV["POKERATING_CACHE_PATH"] ||
  "tmp/pokemon_rating_cache.json", fetcher: api.method(:detail),
  moves_fetcher: api.method(:moves_for))`).

### Testes

- `test/opponent_generator_test.rb` — novos testes do caminho `ratings`: seleciona só a
  banda; varredura em lotes via parallelizer de plumbagem (registra os lotes); cap corta
  a varredura e completa com fallback puro; determinismo com seed; `ratings` recebe nome.
- `test/pokemon_rating_cache_test.rb` — **novo**: computa no miss e retorna no hit (hit
  não re-chama fetcher/moves); `nil` para detail nulo sem cachear; TTL expira; persiste
  entre instâncias (novo objeto lê o arquivo); determinístico.
- `test/battle_service_test.rb` — `build_opponent` usa o `ratings` provider + cap,
  **preservando a banda do nível médio** (novo teste + os existentes de banda seguem
  verdes — `test_build_opponent_uses_high_band_for_high_level_player` etc.).

### Fora de escopo (não abrir)

- Evitar o **duplo fetch** de `moves_for` na montagem do time do oponente (caminho D da
  anotação — ganho marginal ~6 chamadas, anotar no draft se desejado).
- Pré-cache da banda offline / pré-warm por tier; calibração fina do cap (via S3).
- Resto do QA (Q2–Q5), J2, J4, D4, M2 e demais itens da fila.
- Mudança de comportamento da banda (critérios C4/C5 da 0040) — preservada.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 — `OpponentGenerator` com `ratings:` seleciona só nomes da banda via varredura
      em lotes paralelos**, com resultado/ordem determinísticos para a mesma seed — prova:
      `test/opponent_generator_test.rb` (`test_team_names_filters_to_band_with_ratings*`,
      `test_ratings_scan_uses_parallelizer_in_batches*`,
      `test_team_names_with_ratings_is_deterministic_for_seed`).
- [ ] **C2 — Cap de varredura**: `max_candidates:` limita os candidatos avaliados e o que
      faltar é completado com sorteio puro (fallback) — prova: `test/opponent_generator_test.rb`
      (`test_team_names_caps_scan_and_falls_back*`).
- [ ] **C3 — `PokemonRatingCache#rating_for(name)`** computa uma vez e cacheia por nome
      (hit não re-chama fetcher/moves; TTL; persistência entre instâncias; `nil` quando
      detail é nulo, sem cachear) — prova: `test/pokemon_rating_cache_test.rb` (novo).
- [ ] **C4 — `BattleService#build_opponent` injeta `ratings:` (cache) + `max_candidates:`
      no `opponent_options`, preservando a banda derivada do nível médio do jogador** —
      prova: `test/battle_service_test.rb` (novo `test_build_opponent_uses_ratings_provider*`
      + os testes de banda da 0040 seguem verdes).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (735 runs/2358 asserts)** + novos
      testes e lint 0 em **todo** green; commit obrigatório por passo; 0 regressão.
- [ ] Caminho `rater`/`moves_fetcher` (sem `ratings`) **intacto** — testes existentes do
      `OpponentGenerator` seguem verdes sem alteração; determinismo por seed preservado;
      sem gems novas / sem mudança de schema / testes sem rede / sem `rubocop:disable`.
- [ ] `REQUIREMENTS.md` + `SESSIONS.md` + `draft-auto-battler.md` atualizados no mesmo
      escopo do passo docs; *status de validação* só após o usuário validar (S4).

> **S1:** cada critério acima aponta o teste que o prova (arquivo/nome Minitest).
> Sem teste automatizado → `manual` explícito.

## 5. Decisões de refinamento (fechadas com o usuário)

- **2026-08-25 — P2 entra como 0050** (fila maior escolhida no lugar do QA Q2–Q5).
- **2026-08-25 — Estratégia: A+B+cache** — varredura paralela em lotes determinísticos
  + cap de varredura com fallback puro + cache de rating persistente por espécie.
  Preteridos: só paralelizar; A+B + reaproveitar moves do rating na montagem (ganho
  marginal); pré-cache da banda offline.
- **2026-08-25 — API do generator: novo caminho `ratings:` (nome→tier)**, opcional; o
  caminho atual (`rater`/`moves_fetcher`) permanece intacto para backward-compat e testes
  existentes. Preterido: substituir `rater`/`moves_fetcher` pelo `ratings`.
- **2026-08-25 — `PokemonRatingCache` novo, persistente, keyed por nome, retorna tier**,
  sem acoplamento a Faraday (molde do `PersistentJsonStore` adaptado a compute-block);
  default `tmp/pokemon_rating_cache.json`, TTL 7d. Preterido: reusar `PersistentJsonStore`
  (acoplado a HTTP) ou cache só em memória.
- **2026-08-25 — Cap default `RATING_SCAN_CAP = 256` no `BattleService`** (heurística —
  ajustável via S3 como a fórmula da 0040).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (S4) | commit `Sessao 0050: refinamento concluido — ...` |
| 1 | C1 — `OpponentGenerator` com `ratings:`: varredura em lotes paralelos, ordem do lote, determinismo por seed; path atual intacto | suíte verde + lint 0, commit `Passo 1:` |
| 2 | C2 — `max_candidates:` + fallback puro quando o cap/pool esgota antes de completar a banda | suíte verde + lint 0, commit `Passo 2:` |
| 3 | C3 — `PokemonRatingCache` (novo): miss computa/grava, hit devolve sem re-fetch, TTL, persistência, `nil` sem cachear | suíte verde + lint 0, commit `Passo 3:` |
| 4 | C4 — `BattleService` injeta `ratings:` (cache memoizado) + `RATING_SCAN_CAP`; banda do nível médio preservada | suíte verde + lint 0, commit `Passo 4:` |
| 5 | **Docs:** REQUIREMENTS.md (roadmap — P2 executado), SESSIONS.md (0050 fase 2 + próximas), draft-auto-battler.md (P2 executado) | suíte verde + lint 0, commit `Passo 5:` |
| — | **Fase 2 concluída** → **PARAR** para validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 varredura paralela da banda | `./scripts/test test/opponent_generator_test.rb` | — (domínio puro) | |
| C2 cap + fallback puro | `./scripts/test test/opponent_generator_test.rb` | — (domínio puro) | |
| C3 cache de rating | `./scripts/test test/pokemon_rating_cache_test.rb` | — (componente puro) | |
| C4 ratings + cap no service, banda preservada | `./scripts/test test/battle_service_test.rb` | `GET /battle` 1ª chamada mais rápida (~2min → segundos); oponentes da banda do nível | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

- Verificar na implementação a contagem real da suíte (baseline documentado 735/2358 da
  0049) e o tamanho do pool `fetch_all_names` (para calibrar o cap, se preciso).
- O `ratings` provider evita o fetch de `detail`/`moves_for` na varredura; o `team`
  (montagem dos escolhidos) segue usando `detail` — já coberto pelo cache P1.
- O duplo fetch de `moves_for` na montagem do oponente (caminho D da anotação) ficou de
  fora — anotar no draft se o usuário quiser.