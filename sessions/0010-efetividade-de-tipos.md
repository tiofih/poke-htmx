# Sessão 0010 — Efetividade de tipos (B2) — lookup puro + tabela via PokéAPI

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Em andamento |

---

## 1. Objetivo

Precisão de **dano por tipo** para o futuro motor de auto-batalha (B3): dado um ataque
de um tipo contra um defensor, qual o multiplicador de dano? Fraqueza **×2**, resistência
**×0.5**, imune **×0**, neutro **×1**; **STAB** = ×1.5 quando o atacante tem o tipo do golpe;
defensor com **dois tipos** multiplica os fatores de cada um.

A tabela de relações vem da PokéAPI (`GET /type/:name` → `damage_relations`), carregada
com cache (como RF-01). O domínio puro (`TypeEffectiveness`) **não faz rede** — recebe a
tabela pronta e devolve fatores. Fundação de B3 (motor de auto-batalha).

Nem rota, nem schema, nem rede em testes (stub).

## 2. Contexto (estado atual)

- `BattlePokemon` (RF-09/sessão 0009) já é a unidade de combate pura: `hp_max`, `hp_current`,
  `take_damage` funcional, `alive?`/`fainted?`. O dano em si ainda não usa tipo.
- `Pokemon` (RF-06) carrega `types` (ex.: `["grass", "poison"]`) e `stats` — principal do
  elemento do golpe vem daí.
- `PokeApi.fetch_all_names` já é memoizado (`@fetch_all_names ||=`) — padrão de cache do
  projeto (RF-01). `PokeApi.detail` existe para carregar detalhe; para B2 precisamos
  carregar os **tipos** (`/type/:name`).
- `PokeApiStub` (test_helper) stubs class-methods da `PokeApi` (`with_find`, `with_detail`,
  `with_all_names`) — será ampliado com `with_type_relations`/stub do type fetch.
- Convenção: dry::struct e módulos puros para domínio; Minitest puro (padrão de
  `test/battle_pokemon_test.rb`), com `PokeApiStub` para o que toca rede.
- Draft B2 (`draft-auto-battler.md`): fonte = PokéAPI (`damage_relations`), cache,
  lookup `(tipo_atacante, tipo_defensor) → fator`, STAB 1.5; sem rede nos testes.

## 3. Critérios de aceite

### Lookup puro (`TypeEffectiveness`)

- [ ] `TypeEffectiveness.from_relations(tabela)` monta o objeto a partir da estrutura
      de `damage_relations` da PokéAPI (attacker → `{ double/half/no_damage_to }`).
- [ ] `factor(attack_type, defender_type)` devolve **2.0** (fraqueza), **0.5** (resistência),
      **0.0** (imune) e **1.0** (neutral/quando não consta) — ex.: fire→grass = 2,
      fire→water = 0.5, electric→ground = 0, normal→ghost = 0.
- [ ] `effectiveness(attack_type, defender_types)` multiplica o fator de **cada** tipo do
      defensor (ex.: `effectiveness("fire", ["water","fire"])` = 0.5×0.5 = 0.25); lista
      vazia → 1.0.
- [ ] `stab(attack_types, move_type)` = **1.5** se `attack_types` contém `move_type`,
      senão **1.0**.
- [ ] `damage_multiplier(attacker_types:, move_type:, defender_types:)` =
      `effectiveness(move_type, defender_types)` **×** `stab(attacker_types, move_type)`
      (ex.: `damage_multiplier(["fire"], "fire", ["water"])` = 0.5×1.5 = 0.75).
- [ ] Domínio puro: `TypeEffectiveness` **sem Faraday, sem rede** — só recebe a tabela.

### Fonte & cache (`PokeApi.type_relations`)

- [ ] `PokeApi.type_relations` busca a relação dos **18 tipos** (`GET /type/:name`),
      memoização (`@type_relations ||=`) — 2ª chamada **não** refaz rede.
- [ ] `PokeApi.extract_type_relations(json)` converte `damage_relations` (puro, tesável).
- [ ] `TypeEffectiveness.load` = `from_relations(PokeApi.type_relations)` — ponto de
      entrada único (usa rede via cache; os testes invocam por stub).

### Garantias (RNF)

- [ ] Testes **sem rede** (stub `PokeApiStub`), suíte completa verde (`./scripts/test`),
      lint 0 offenses, commit a cada green (RNF-04).
- [ ] Sem regressão (RF-01..RF-09 seguem verdes; `BattlePokemon` inalterado).
- [ ] `REQUIREMENTS.md` (novo **RF-10 — Efetividade de tipos (B2)**) e `SESSIONS.md`
      (0010) atualizados no mesmo escopo; `draft-auto-battler.md` B2 marcado em execução.

## 4. Decisões de refinamento

- **Separar fetch/cache da POKÉAPI de lookup**: `PokeApi.type_relations` é a fonte com
  cache (memória, padrão `fetch_all_names`); `TypeEffectiveness` é **puro** e recebe a
  tabela via `from_relations`. Não misturar HTTP no domínio. (decisão do usuário)
- **Defensor multi-tipo**: `effectiveness` multiplica o fator de cada um dos tipos do
  defensor (ex.: `grass` contra `["water","flying"]` = 0.25) — conforme Pokémon real.
- **STAB combinado**: `stab(...)` é fator separado (1.5/1.0) e `damage_multiplier` o
  combina com `effectiveness` — já pronto para o motor B3. (decisão do usuário)
- **Tipo do atacante = `move_type` no cálculo**, `attacker_types` só entra no STAB
  (STAB é do Pokémon que atacou com golpe do seu tipo). D1 (moves) não é escopo.
- **Cache da tabela**: memoização em memória (`@type_relations ||=`), como RF-01; sem
  cache em disco/PG. Nunca em teste (stub).
- **Fundação para B3**: o motor consumirá `TypeEffectiveness.load` para calcular dano
  por golpe + STAB + multi-tipo. B3 não é escopo desta sessão.
- **Arquivo `lib/type_effectiveness.rb` + `test/type_effectiveness_test.rb`**
  (classe `TypeEffectiveness`) e método `PokeApi.type_relations` em `lib/poke_api.rb`.
  `BattlePokemon` permanece intacto.

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) |
| --- | --- | --- |
| 0 | `factor("fire","grass")==2`, `factor("fire","water")==0.5`, `factor("electric","ground")==0`, `factor normal→ghost==0`, desconhecida→1 | `lib/type_effectiveness.rb`: `from_relations` (recebe hash) + `factor` via `double/half/no_damage` |
| 1 | `from_relations` aceita a estrutura do `damage_relations` da API (atacante → hash duplo/metade/não); fator coberto para os 18 tipos da fonte | parse da estrutura no `from_relations` |
| 2 | `effectiveness("fire", ["water","fire"])==0.25`, `effectiveness("fire", [])==1`, `effectiveness("grass",["water","flying"])` coerente | multiplicar os fatores dos tipos do defensor em `effectiveness` |
| 3 | `stab(["fire"], "fire")==1.5`, `stab(["fire"], "water")==1.0`; `damage_multiplier(["fire"],"fire",["water"])==0.75` | `stab` + `damage_multiplier` |
| 4 | `PokeApi.extract_type_relations(json)` puro converte `damage_relations` | método em `PokeApi` |
| 5 | `PokeApi.type_relations` carrega 18 tipos (fetch por tipo) e memoiza (2ª chamada sem novo fetch) — stubbed via `PokeApiStub.with_type` | `type_relations` com `@type_relations ||=` e lista de tipos |
| 6 | `TypeEffectiveness.load` == `from_relations(PokeApi.type_relations)`: fator sobe da fonte (stubbed) até o `factor/effectiveness` | `TypeEffectiveness.load` |
| 7 | suíte completa verde + lint 0 | checagem global |
| 8 | `REQUIREMENTS.md` (RF-10, roadmap/B2), `SESSIONS.md` (0010), `draft-auto-battler.md` B2 marcado em execução | documento |

## 6. Observações e próximo passo

- Sem mudança de schema, sem rotas, `BattlePokemon` e `Pokemon` intactos.
- `test/type_effectiveness_test.rb` requisará apenas `TypeEffectiveness` (domínio puro)
  e, para `load`, o stub da `PokeApi` no `test_helper` (`PokeApiStub.with_type_relations`).
- O `PokeApiStub` ganha `with_type_relations(relations)` (stub do método público) — a
  memoização de `@type_relations` precisa ser resetada entre testes (armadilha: a 2ª
  chamada pega o cache do 1º teste; limpar na teardown ou stub o fetch direto).
- Próximo passo sugerido após validação: **B3 — motor de auto-batalha** (game loop 6v6),
  consumindo `TypeEffectiveness` + `BattlePokemon`.

## 7. Validação (a definir — usuário)

- Pendente (fase de validação é do usuário — ver AGENTS.md).