# Sessão 0009 — Modelo de batalha (B1) — Pokémon vira unidade de combate (domínio puro)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Em andamento — decisões com o usuário em 2026-08-08 |
| Implementação | Não iniciada |
| Validação | Não iniciada |

---

## 1. Objetivo

Criar o **`BattlePokemon`** — a unidade de combate do futuro auto-battler (draft
fase B, game loop). Hoje `Pokemon` (RF-06) carrega **types** e **stats bases** mas não
tem estado de batalha. Esta sessão transforma um `Pokemon` em um `BattlePokemon`
puro (Dry::Struct) com **`hp_max` derivado do base stat HP**, **`hp_current`** e os
métodos de combate `take_damage`, `alive?` e `fainted?`.

**Escopo:** 100% **domínio puro** — sem PostgreSQL, sem rede (PokéAPI), sem rotas.
Serve de fundação para B2 (efetividade de tipos) e B3 (motor de auto-batalha).

## 2. Contexto (estado atual)

- `Pokemon` (`lib/pokemon.rb`) é um Dry::Struct com `id, name, sprite, number, slot,
  types, stats, evolutions`. `stats` é `[{ name: "HP", value: 45 }, ...]` — labels
  normalizadas pela `STAT_LABELS` da `PokeApi` (RF-06).
- **Não existe estado de combate:** nenhum HP persistido, nenhum `take_damage`.
- `TeamRepository#all(user_id)` (sessões 0007/0008) já devolve o time ordenado por
  `slot` — será o input de construção dos `BattlePokemon` no B3.
- Convenção do projeto: `Dry::Struct` para modelos de domínio puro; Minitest puro
  para testes de unidade (padrão de `test/team_repository_test.rb`).

## 3. Critérios de aceite

### Conversão (`BattlePokemon.from`)

- [ ] `BattlePokemon.from(pokemon)` converte um `Pokemon` → `BattlePokemon` com
      `number`, `name`, `types` e `stats` preservados.
- [ ] `hp_max` = **base stat HP bruto** (ex.: Pikachu HP 45 → `hp_max 45`);
      `hp_current` inicial = `hp_max`.
- [ ] `Pokemon` **sem** stat HP (sem `stats` ou stat ausente) → `hp_max 1`
      (mínimo para ficar `alive?`).
- [ ] É um Dry::Struct imutável (atributos `hp_max`, `hp_current`, `types`,
      `stats`, `number`, `name`).

### Combate (`take_damage`, `alive?`, `fainted?`)

- [ ] `take_damage(dano)` **funcional/immutável**: retorna **nova** instância com
      `hp_current` reduzido; a original não muda.
- [ ] Dano **não leva a HP negativo**: `ahp < dano` → `hp_current = 0` (clamp).
- [ ] `dano <= 0` (0 ou negativo) → retorna instância idêntica (HP intacto, liberado).
- [ ] `alive?` é `hp_current > 0`; `fainted?` é `hp_current == 0`; coerentes entre si
      e após `take_damage` até zerar.

### Garantias (RNF)

- [ ] **Domínio puro:** sem PG (nenhuma conexão/schema), sem rede, sem PokeApi;
      apenas Dry::Struct e testes de unidade.
- [ ] Testes sem rede, suíte completa verde (`./scripts/test` + `test/...)`) e lint
      verde; commit a cada green (RNF-04).
- [ ] Nenhum comportamento existente muda (Sem regressão RF-01..RF-08).
- [ ] `REQUIREMENTS.md` (novo **RF-09 — Modelo de batalha (B1)**) e `SESSIONS.md`
      (0009) atualizados no mesmo escopo.

## 4. Decisões de refinamento

- **`hp_max` = HP bruto do base stat** (decisão do usuário): Pikachu 45 → 45. Simples,
  previsível, direto de testar; fórmula com nível fica para quando houver `"nível"`
  (anotado em draft D2 — XP/evolução).
- **`take_damage` funcional/imutável** (decisão do usuário): retorna novo
  `BattlePokemon` — coerente com a imutabilidade do Dry::Struct (padrão do projeto),
  mais testável e recompoável no B3 (estado = cadeia de transforms).
- **Default `hp_max = 1` sem stat HP:** um `Pokemon` sem `stats` (lista ou lookup de
  nome não `detail`) ainda entra em batalha vivo (minimamente). Não vira erro.
- **Sem `energy`/turno/custo nesta sessão:** o draft cita `energy` como ideia para
  jogadas futuras; fica anotado (B1/D1) — escopo atual só vida (HP).
- **Arquivo `lib/battle_pokemon.rb` + `test/battle_pokemon_test.rb`** (classe
  `BattlePokemon`, método construtor `.from`); sem alteração em `Pokemon`.

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) |
| --- | --- | --- |
| 0 | `BattlePokemon.from(pokemon)` cria instância com `number`, `name`, `types`, `stats` preservados; `hp_max` e `hp_current` = stat HP (Pikachu 45→45) | `lib/battle_pokemon.rb`: `BattlePokemon < Dry::Struct` + `.from` |
| 1 | `from` sem stat HP → `hp_max = 1` (vivo); stats/ tipos ausentes não quebram | default no `.from` |
| 2 | `take_damage(10)` → nova instância `hp_current = original - 10`; a original não muda | `take_damage` (Dry::Struct `new` com `hp_current` novo) |
| 3 | clamp: dano >= hp → `hp_current = 0`; `dano = 0` e `dano negativo` → intacto | guard no `take_damage` |
| 4 | `alive?` (hp > 0) / `fainted?` (hp == 0) e coerência pós-dano até zerar | métodos `alive?`/`fainted?` |
| 5 | suíte completa verde + lint 0 offenses | checagem global |
| 6 | `REQUIREMENTS.md` (RF-09 + roadmap/B1) e `SESSIONS.md` (0009) atualizados; `draft-auto-battler.md` B1 marcado como em execução | documento |

## 6. Observações e próximo passo

- Nenhuma mudança de schema/rota/`Pokemon`/``; somente novo arquivo de domínio.
- Os testes são puros (Minitest), sem `TestDatabase` — como o `test_helper.rb` 
  requer `Pokemon`/`PokeApi`/`team_repository` (rede não, mas requere em teste),
  o `test/battle_pokemon_test.rb` `require`s apenas o mínimo
  (`require_relative "../lib/battle_pokemon"` + `minitest/autorun`) sem tocar
  `test_helper` — para garantir domínio realmente puro.
- B2 (efetividade de tipos) e B3 (motor) consomem este `BattlePokemon` no futuro
  (ordem sugerida B1 → B2 → B3 → B4 → C1).
- Próximo passo sugerido após validação: **B2 — efetividade de tipos**.