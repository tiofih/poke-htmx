# Sessão 0016 — Logs de batalha detalhados (C1)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída — decisões fechadas com o usuário em 2026-08-09 |
| Implementação | Pendente |
| Validação | Pendente (executada pelo usuário) |

---

## 1. Objetivo

Melhorar os **logs de batalha** (C1, anotado em `draft-auto-battler.md` durante a
validação da 0015): hoje o log de cada ação mostra apenas o **lado** atacante
("Seu Time" / "Oponente"), o golpe (ou `move_type`) e o dano — não diz **qual
Pokémon** bateu em **qual Pokémon**. O log passa a indicar **quem atacou quem**,
com **qual golpe** e o **dano causado** (ex.: "Seu Time: pikachu usou
thunder-shock em bulbasaur, 12 de dano").

Esta sessão **revisita B3** (shape do log do `BattleEngine`) e **toca C1**
(`battle.erb`) — mas **sem regressão de comportamento**: dano, vencedor, ordem de
ação e rounds continuam exatamente iguais. O que muda é o **contrato do entry**
(decisão do usuário: uniforme — nomes sempre presentes) e a **renderização** do
log.

## 2. Contexto (estado atual)

- `BattleEngine#act` (`lib/battle_engine.rb:80-100`): monta a entry via
  `action_entry` — hoje `{round, attacker (índice 0/1), move_type, damage, ko}` +
  `move` quando há golpe. No momento da ação, `act` conhece `attacker_index` e
  `target_index` (logo, os nomes dos dois lados).
- `BattleResult.log` (loop `battle`) e `BattleEngine#log` (incremental,
  `play_round`) compartilham a mesma shape — comparados por igualdade em
  `battle_engine_test.rb:237`.
- `battle.erb` (`views/battle.erb:41-49`): log do último round renderiza apenas
  "Seu Time/Oponente atacou (move/move_type), damage de dano".
- Asserts de shape **exato** do entry: `battle_engine_test.rb:162-163` (caminho
  legado, `%i[round attacker move_type damage ko]`) e `move_engine_test.rb:100`
  (caminho com moves, `%i[round attacker move_type damage ko move]`).
- Testes de rota de batalha usam `PokeApiStub.with_detail`/`with_moves_for`
  (`server_test.rb` — ex.: `test_battle_log_shows_used_move_name`).
- RNF-04: TDD (red → green → commit), suíte via `./scripts/test`, lint
  `./scripts/lint`.

## 3. Critérios de aceite

### Motor (B3 — shape do log)

- [ ] Toda entry do log ganha **`attacker_name`** e **`target_name`** (nome do
      `BattlePokemon` atacante e do alvo), em **todos** os caminhos (legado e com
      moves) — **contrato uniforme** (decisão do usuário).
- [ ] Novas chaves adicionadas **no fim** do entry; as chaves existentes
      (`round`/`attacker`/`move_type`/`damage`/`ko`; `move` quando houver golpe)
      são preservadas com os mesmos valores.
- [ ] Comportamento da batalha **inalterado**: dano, vencedor, rounds e ordem de
      ação idênticos (o entry só ganha metadados de identidade).
- [ ] Asserts de shape exato atualizados para o novo contrato:
      `battle_engine_test.rb:162-163` e `move_engine_test.rb:100` — chaves novas
      acrescentadas à lista/ao hash esperado (não é regressão: é o deliverable da
      sessão).
- [ ] `battle` (loop) e `play_round` (incremental) seguem produzindo logs idênticos
      desde que a sequência seja a mesma (teste `batch.log == engine.log` verde).

### UI (C1 — battle.erb)

- [ ] `battle.erb` (log do último round) mostra: lado ("Seu Time"/"Oponente"),
      **nome do atacante**, "usou" + **golpe** (`entry[:move]` quando presente,
      senão `entry[:move_type]`), "em" + **nome do alvo**, **dano** causado e KO
      — ex.: "Seu Time: pikachu usou thunder-shock em bulbasaur, 12 de dano".
- [ ] Caminho legado (sem `move`) também exibe nomes (ex.: "Seu Time: a usou fire
      em d, 60 de dano").
- [ ] Sem JS customizado (RNF-01); testes de rota sem rede (stubs
      `with_detail`/`with_moves_for`) verificando que o fragmento de `GET /battle`
      e `POST /battle/play` contém o nome do atacante e do alvo no log.
- [ ] Demais elementos do fragmento intactos: painéis com HP, golpes com PP,
      vencedor e botões (Jogar/Novo confronto).

### Garantias (RNF)

- [ ] Testes sem rede; suíte completa verde (`./scripts/test`) e lint 0; commit a
      cada green.
- [ ] Sem regressão de **comportamento** em RF-01..RF-15 (apenas o shape do log
      muda; asserts de shape atualizados de forma explícita e comentada).
- [ ] `REQUIREMENTS.md` (**RF-16 — Logs de batalha detalhados (C1)**),
      `SESSIONS.md` (0016) e `draft-auto-battler.md` (nota C1) atualizados no
      mesmo escopo.

## 4. Decisões de refinamento (fechadas com o usuário em 2026-08-09)

- **Contrato uniforme do entry** (decisão do usuário): `attacker_name` e
  `target_name` **sempre** presentes em toda entry — legado e com moves. Mantém
  um shape único, simples de renderizar e testar. Isso toca os dois asserts de
  shape exato, que são atualizados no passo 0.
- **Identidade gravada no entry, não resolvida na view**: o `BattleEngine`
  registra os nomes no momento da ação (via `act`), em vez de a view resolver
  `teams[team_index][index]` — mais testável e estável (o entry é autossuficiente).
- **Campos usados:** `BattlePokemon#name`. Times sem duplicados (RF-07) e
  oponente sem repetição (B4) → nomes únicos por time; não há ambiguidade.
- **Golpe exibido:** `entry[:move]` quando existe golpe; senão `entry[:move_type]`
  (legado). Em produção `moves` nunca é `[]` (rota sintetiza Struggle), mas a
  renderização cobre o legado.
- Fora do escopo: mudar fluxo/ordem/dano/RNG da batalha (D1 continua
  determinístico), XP/evolução (D2), histórico/rank (D3), seletor de golpes (A3),
  persistência de logs.

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) | Status |
| --- | --- | --- | --- |
| 0 | engine: entry ganha `attacker_name`/`target_name` em todos os caminhos; asserts de shape exato (`battle_engine_test.rb:162-163`, `move_engine_test.rb:100`) atualizados com as novas chaves | `BattleEngine#action_entry` (recebe os nomes de `act`) | pendente |
| 1 | rota/UI: fragmento de batalha mostra "Lado: atacante usou golpe em alvo, dano" (com move e no legado) | `views/battle.erb` (bloco do log do último round) | pendente |
| 2 | regressão: suíte completa `./scripts/test` + `./scripts/lint` 0 | checagem geral | pendente |
| 3 | docs: `REQUIREMENTS.md` (RF-16), `SESSIONS.md` (0016), `draft-auto-battler.md` (nota C1) | documento | pendente |

## 6. Observações e próximo passo

- **Nota sobre a garantia da 0015:** a regra "suíte 0011 verde sem editar
  `battle_engine_test.rb`" valia para o escopo da 0015 (caminho legado intacto).
  Aqui o *deliverable* é exatamente o shape do log, então os dois asserts de shape
  são atualizados de forma explícita — sem alterar nenhum valor/assert de
  comportamento (dano, vencedor, rounds, ordem).
- **Sem custo extra de rede/schema/persistência:** é metadado no log em memória.
- **PP/golpes:** nada muda na escolha determinística do motor (RF-15).
- Após 0016 validada: **D2 (XP/evolução)**, **D3 (histórico/rank)** e **A3
  (página de gerenciamento de time)** seguem como candidatas do draft.

## 7. Validação (a preencher pelo usuário)

- Pendente — executada pelo usuário (fase 3).