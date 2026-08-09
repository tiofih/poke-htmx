# Sessão 0012 — Oponente automático (B4) — gerador de time adversário `[BattlePokemon]`

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída — decisões fechadas com o usuário em 2026-08-08 |
| Implementação | Pendente |
| Validação | Pendente — executada pelo usuário |

---

## 1. Objetivo

Gerar o **time adversário** para o usuário enfrentar sem montar time próprio — o lado
`team_b` do `BattleEngine` (RF-11/sessão 0011) quando o jogador atacar no futuro C1
(batalha na web). Um **sorteio** de Pokémon a partir de uma lista de candidatos,
sem repetição, que vira `[BattlePokemon]` na mesma forma que o motor consome
(posição no array = slot). **Domínio puro** (sem PG, sem rede): a lista e o
fetcher de detalhes são **injetados**; o sorteio é **determinístico sob seed**
(RNG injetável) para iterar/testar rápido e, em produção, variar a partida trocando a seed.

Sem rota, sem UI, sem schema — o gerador é o plugin de entrada da batalha (C1 fica
para a próxima sessão).

## 2. Contexto (estado atual)

- `BattleEngine` (RF-11/B3, sessão 0011) recebe `team_a:`/`team_b:` como arrays de
  `BattlePokemon` ordenados por slot (posição no array = slot); devolve `BattleResult`.
  O lado `Player` vs `Opponent` de um futuro C1 usará `OpponentGenerator#team` como
  `team_b`.
- `BattlePokemon.from(pokemon)` (B1/RF-09) converte `Pokemon` completo (com `types` e
  `stats`) em unidade de combate (`hp_max` = stat HP, `stats` preservados).
- `PokeApi` (RF-01/RF-06): `fetch_all` devolve a lista de nomes da PokéAPI e `detail(name)` o
  `Pokemon` completo. O gerador **não chama** a PokéAPI — recebe `names:` (candidatos)
  e `fetcher:` (name → `Pokemon`) injetados na construção.
- Draft (`draft-auto-battler.md`): B4 sorteia N slugs da lista de candidatos (cache RF-01),
  busca o detalhe e monta o time adversário. **Decisões de sorteio shim: `names` + `rng`
  injetados, `fetcher` stubável nos testes (sem rede).
- Sem rota neste passo — o gerador é núcleo de domínio puro (molde da sessção 0011).

## 3. Critérios de aceite

### `OpponentGenerator` (lib/opponent_generator.rb, testes sem rede)

- [ ] `OpponentGenerator.new(names:, size: DEFAULT_TEAM_SIZE, rng: Random.new, fetcher: PokeApi.method(:detail))` —
      `names:` é o array de slugs candidatos (ex.: `PokeApi.fetch_all`); `size` default **6**
      (cap do RF-07); `rng` injetável (default `Random.new`); `fetcher` usada com
      `fetcher.call(name)` e injetável nos testes (default `PokeApi.method(:detail)`).
- [ ] `team` devolve `[BattlePokemon]` — para cada nome sorteado, `BattlePokemon.from(fetcher.call(name))`,
      na **ordem do sorteio** (= ordem dos slots do adversário).
- [ ] Sorteio **sem repetição**: um mesmo slug nunca aparece duas vezes no mesmo time,
      mesmo quando `size > names.size` (usa o total disponível, sem erro).
- [ ] `names` vazio → `team == []`; `size <= 0` → `team == []` (sem erro).
- [ ] **Determinístico sob seed**: `rng` fixo (ex.: `Random.new(42)`) → mesma `team`
      (mesma ordem de sorteio); seeds diferentes → (provável) times diferentes.
- [ ] **Domínio puro**: o gerador não abre PG nem rede — `names` e `fetcher` são injetados
      e o teste stubba `fetcher` (nunca `PokeApi` real); sem `with_*` special beyond `#team`.

### Garantias (RNF)

- [ ] 100% domínio puro (sem PG, sem rede); RNG injetável determina o sorteio.
- [ ] Testes **sem rede** (stub `fetcher`), suíte completa verde (`./scripts/test`), lint
      0 offenses, commit a cada green (RNF-04).
- [ ] Sem regressão: `BattlePokemon`/`BattleEngine` intactos; RF-01..RF-11 seguem verdes.
- [ ] `REQUIREMENTS.md` (novo **RF-12 — Oponente automático (B4)**), `SESSIONS.md` (0012)
      e `draft-auto-battler.md` (B4 em refinamento) atualizados no mesmo escopo.

## 4. Decisões de refinamento

- **`team` = `[BattlePokemon]` na ordem do sorteio** — mesmíssima forma que o array do
  `BattleEngine` espera (`team_b`); ordens de slot = posição no array. (decisão do usuário)
- **Sorteio sem repetição com o vetor candidato**: `names.sample` com o `rng` injetado
  garante slugs únicos; se `size > names.size`, `sample` já devolve o total disponível
  (sem erro, sem duplicado). Determinístico sob mesma seed. (decisão do usuário)
- **`rng` injetável, default `Random.new`** (aleatório); produção variará a seed a cada
  confronto; testes fixam `Random.new(seed)` para asserções repetíveis.
- **`fetcher` injetável, default `PokeApi.method(:detail)`** — o gerador nunca decide DNS;
  o teste injeta um callable `name → Pokemon` de fixture. Isso preserva o princípio
  `sem rede no domínio` de B1..B3.
- **`size` default 6** — cap do time de RF-07 (`TeamRepository::MAX_TEAM_SIZE`), default
  local `DEFAULT_TEAM_SIZE = 6` no gerador.
- **Files**: `lib/opponent_generator.rb` (`OpponentGenerator`) + `test/opponent_generator_test.rb`.
- Fora do escopo: rota/UI (C1), `PokeApi` real não tocado, PG, moves (D1), RNG interno ao motor (B3 já anotado).

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) |
| --- | --- | --- |
| 0 | `new` aceita `names`, `size` (default 6) e `rng`; `team_names` sorteia sem repetição com seed fixa | esqueleto `opponent_generator.rb` com sorteio |
| 1 | `team` converte cada nome sorteado via `fetcher` (stub) com `BattlePokemon.from` na ordem do sorteio | chamada ao `fetcher` + `from` |
| 2 | determinista: `Random.new(42)` → mesma `team`/ordem; `names` menor que hsize → total | reuso do sorteio com `rng` injetado |
| 3 | edge: `names == []` → `[]`; `size <= 0` → `[]` | clamps/no-op |
| 4 | domínio puro: só `names`/`fetcher` injetados, stub completo, sem rede | padrão já garantido |
| 5 | suíte completa (`./scripts/test`) + `./scripts/lint` 0 | checagem |
| 6 | docs: `REQUIREMENTS.md` (RF-12), `SESSIONS.md` (0012), `draft-auto-battler.md` (B4 em refinamento) | documento |

## 6. Observações e próximo passo

- `OpponentGenerator#team` alimenta o `team_b` do `BattleEngine` — o `efeito do oponente
  com Ja `rng` é re-utilizado para variar confrontos no futuro C1.
- **Nenhuma mudança em B1..B3**: o gerador só cria `BattlePokemon` a partir do
  `fetcher` + `BattlePokemon.from`.
- Próxima sessão sugerida após a validação de B4: **C1 — Batalha na web (htmx)**
  consumindo `BattleEngine` + `OpponentGenerator` (rota, painéis, encerramento). A2
  (layout/estilos, do roadmap/item 12) permanece no backlog.

## 7. Validação (a preencher pelo usuário)

- **(pendente)** — o usuário roda a suíte completa e confirma critérios de aceite.