# Sessão 0019 — Refatoração de testes (respiro: remover `rubocop:disable`)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída — critérios e plano fechados com o usuário em 2026-08-10 (respiro) |
| Implementação | Executada (passos 1–6 verdes: suíte 222/778, lint 0) |
| Validação | Concluída — usuário validou em 2026-08-10 |

---

## 1. Objetivo

**Respiro de refatoração** (item "Refatorações a revisar" do `draft-auto-battler.md`):
remover os `# rubocop:disable` dos **testes** e voltar às **métricas padrão** do
RuboCop (`Metrics/AbcSize`, `Metrics/MethodLength`, `Metrics/ClassLength`,
`Metrics/ParameterLists`, `Naming/MethodParameterName`) por **extração de
helpers/factories e divisão de classes de teste por área** — sem mudar nenhum
comportamento testado.

Escopo confirmado pelo usuário (2026-08-10): **todos os arquivos de teste** com
disables — `server_test.rb` (41), `team_repository_test.rb` (3), `schema_test.rb`
(1), `test_helper.rb` (4), `battle_engine_test.rb` (6) e `move_engine_test.rb` (2).

## 2. Contexto (estado atual — diagnóstico)

| Arquivo | Linhas | Disables | Cops envolvidos |
| --- | --- | --- | --- |
| `test/server_test.rb` | 1242 | 41 | `ClassLength` (classe), ~30× `AbcSize`, ~15× `MethodLength` |
| `test/team_repository_test.rb` | 331 | 3 | `ClassLength`, `AbcSize`, `MethodLength` |
| `test/schema_test.rb` | 51 | 1 | `MethodLength` (`index_exists`) |
| `test/test_helper.rb` | 136 | 4 | `MethodLength` (`PokeApiStub.with_moves_for`/`with_move`/`with_available_move_names`/`with_type`) |
| `test/battle_engine_test.rb` | 288 | 6 | `ClassLength`, `MethodLength`+`ParameterLists`+`Naming` (`build_pokemon`), `AbcSize`, `MethodLength` |
| `test/move_engine_test.rb` | 195 | 2 | `AbcSize`+`ClassLength`+`MethodLength` (classe), `ParameterLists`+`Naming` (`build_pokemon`) |

**Causas-raiz** (inspecionadas):

- **Duplicação de fixtures:** `build_pokemon` (com 7 params posicionais/kwargs →
  `ParameterLists` > default 5 e `Naming`) existe em `battle_engine_test.rb` e
  `move_engine_test.rb`; `Pokemon.new(name:, sprite:, number:)` inline em dezenas de
  testes de `server_test.rb`/`team_repository_test.rb`; `type_effectiveness` também
  duplicado nos dois arquivos de motor; `type_json_for`/`neutral_type_json_table`
  local que pode virar helper compartilhado.
- **Acesso a PG inline:** `PG.connect(ENV.fetch("DATABASE_URL"))` + `ensure close`
  repetido em `team_row`/`team_id`/`distinct_user_ids`/`column_info`/`index_exists`
  → `MethodLength`/`AbcSize` e ruído que pode ir para `TestDatabase` (helper único
  `with_db`).
- **Classes de teste grandes:** `ServerTest` 1242 linhas e `TeamRepositoryTest` 331,
  `BattleEngineTest` 288, `MoveEngineTest` 195 > `ClassLength` default 100 → exigem
  **divisão por área** (não é só extrair helper no mesmo arquivo).
- **Stubs repetidos e longos:** bloco aninhado `with_all_names → with_type →
  with_detail → with_moves_for` repetido dezenas de vezes em `server_test.rb` (já
  existe `stub_battle_start`/`start_battle_for` mas nem todos os testes usam);
  `PokeApiStub` tem 4 métodos com a mesma forma `existed?/original/define_singleton/
  ensure remove` → extrair um helper genérico de stub (`stub_api(method, value)`).

**Sem mudança de comportamento:** nenhum teste é removido nem alterado em assert
(222 runs/778 asserts preservados); apenas reorganização de helpers, factoides e
classes. A refatoração é **verificada** por lint 0 + suíte verde.

## 3. Critérios de aceite

### Resultado

- [ ] **Nenhum `# rubocop:disable`/`enable` restante** nos 6 arquivos de teste
      (`grep` nos arquivos → 0 ocorrências).
- [ ] `./scripts/lint` → **0 offenses** com as **métricas padrão** do RuboCop
      (nenhuma diretiva de exceção nos testes).
- [ ] `./scripts/test` → **suíte completa verde com o mesmo tamanho de cobertura**
      (baseline 222 runs/778 asserts): nenhum teste removido; asserts preservados.
- [ ] 0 regressão de comportamento — rotas/domínio intactos (asserções existentes
      mantidas, apenas movidas de lugar quando o teste muda de classe).

### Estrutura

- [ ] Novo `test/test_support.rb` (módulo `TestSupport`, `require`d no
      `test_helper.rb`) consolidando os **helpers duplicados**: `build_pokemon`
      (kwargs em defaults; dentro do default de `ParameterLists`), `build_move`,
      `type_effectiveness`, `build_type_json`/`neutral_type_json_table` e factories
      de time (`add_team(user_id, names)`).
- [ ] `TestDatabase` ganha helper único de conexão + cleanup (`self.with_db(&block)`
      ou similar) e os acessos inline que sobrarem passam a usá-lo — removendo o
      `PG.connect` + `ensure close` repetido de `team_row`/`team_id`/
      `distinct_user_ids`/`column_info`/`index_exists`.
- [ ] `index_exists`/`column_info` movidos para `TestDatabase` (introspection
      reutilizável nas próximas migrações); `schema_test.rb` os consome.
- [ ] Classes de teste **divididas por área** para `ClassLength`:
      `ServerTest` → (ex.) `ServerTeamTest`/`ServerListTest`/`ServerDetailTest`/
      `ServerBattleTest` (+ setup/helpers compartilhados via módulo);
      `TeamRepositoryTest` → por operação (add/remove/move/moves);
      `BattleEngineTest`/`MoveEngineTest` → por área; nomes autoexplicativos.
- [ ] `PokeApiStub` consolida os 4 métodos repetidos num helper genérico de stub
      (ex.: `stub_singleton(method, value)` com o padrão
      `existed?/original/define/ensure remove`), removendo os 4 `MethodLength`.

### Garantias (RNF)

- [ ] Commit obrigatório a cada passo verde (lint 0 + suíte verde); suíte sem rede.
- [ ] `draft-auto-battler.md` (item "Refatorações a revisar" marcado como feito) e
      `SESSIONS.md` (0003-style sessão de respiro registrada + próxima sessão D2)
      atualizados no mesmo escopo.
- [ ] Sem novas gems, sem mudança em `lib/**`, sem mudança de schema/rotas.

## 4. Decisões de refinamento

- **Tipo de sessão:** respiro de refatoração (não gera RF novo em `REQUIREMENTS.md`;
  é dívida técnica do item "Refatorações a revisar" do draft). Comportamento
  testado continua sendo o dos RF-01..RF-18 (0 regressão).
- **Definição de `red` nessa sessão:** remover um `# rubocop:disable` de uma região
  e ver o lint acusar offense(s) reais (métrica) — esse é o "teste que falha".
  **`green`:** refatorar a região (helper/classe) até lint 0 + suíte completa verde
  → **commit**. Não há teste novo a escrever: a suíte existente é a rede de segurança.
- **Estratégia para `ParameterLists`/`Naming` em `build_pokemon`:** reduzir o número
  de params tornando o que varia por teste explícito e o resto default (ex.:
  `build_pokemon(number:, name:, types:, hp:, speed:, attack: 1, defense: 1,
  moves: [])` vira kwargs com 5+ defaults ou um hash de `stats:`), preservando
  chamadas existentes o máximo possível. Mudança de nome de variável só se uma
  param estiver com < 3 chars.
- **Estratégia para `ClassLength`:** dividir cada classe grande em **classes por
  área** que "incluem" um módulo de helpers comum (`TestSupport` + `setup`/`app`/
  `user_session`). A divisão **não** altera o número/asserts de testes.
- **Ordem sugerida (cada passo termina com lint 0 + suíte verde + commit):**
  infra de suporte → motores → server linear → team_repository → schema/helper → docs.
- **Atenção à suíte sem rede:** ao mexer em `server_test.rb`, manter stubs; os
  helpers extraídos não podem introduzir requests reais.
- Aproveitamento (do draft): `index_exists` vira helper de `TestDatabase`
  (introspection útil nas próximas migrações); `build_pokemon` vira factory única
  no `TestSupport` (usada pelos dois arquivos de motor).

## 5. Plano TDD (passos)

> Cada passo = "red" (remover disable → lint acusa) → "green" (extrair helper /
> dividir classe → lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo de sessão com critérios e plano fechados | commit `Sessao 0019: refinamento concluido ...` |
| 1 | **Infra de suporte:** criar `test/test_support.rb` (`TestSupport`: `build_pokemon` única com defaults, `build_move`, `type_effectiveness`, `type_json_for`/`neutral_type_json_table`, `add_team`) + `with_db`/cleanup em `TestDatabase`; `require` no `test_helper.rb` | suíte inteira verde (222/778) + lint 0 |
| 2 | **Motores:** `battle_engine_test.rb` + `move_engine_test.rb` passam a usar `TestSupport`; dividir classes por área; remover `ParameterLists`/`Naming` (`build_pokemon`) e os demais disables | lint 0 (0 disables nesses 2 arquivos) + suíte verde |
| 3 | **`server_test.rb`:** extrair helpers de sessão/team/battle e `stub_battle_start` genérico para `TestSupport`; dividir `ServerTest` em classes por área (Team/List/Detail/Battle); remover os 41 disables | lint 0 + suíte verde |
| 4 | **`team_repository_test.rb`:** usar factories do `TestSupport`; `team_row`/`team_id` via `TestDatabase`; dividir classe por operação; remover os 3 disables | lint 0 + suíte verde |
| 5 | **`schema_test.rb` + `test_helper.rb`:** `index_exists`/`column_info` → `TestDatabase`; `PokeApiStub` consolida num helper genérico (`stub_singleton`); remover os 5 disables | lint 0 + suíte verde |
| 6 | **Verificação final + docs:** `grep` por `rubocop:disable` nos testes → 0; suíte completa + lint 0; atualizar `draft-auto-battler.md` ("Refatorações a revisar" → feito) e `SESSIONS.md` (0019 + próxima sessão) | suíte verde + lint 0 + docs |

## 6. Validação (executada pelo usuário)

**Status: CONCLUÍDA — validada pelo usuário em 2026-08-10.**

- [x] Suíte completa verde: **222 runs / 778 asserts, 0 failures/errors** (baseline preservado).
- [x] Lint RuboCop: **0 offenses** (29 arquivos inspecionados).
- [x] **Nenhum `# rubocop:disable`/`enable`** nos 6 arquivos de teste alvo
      (`server_test.rb`, `server_test_helpers.rb`, `test_support.rb`, `team_repository_test.rb`,
      motores, `schema_test.rb`) — conferido por `grep` + execução.
- [x] Ambiente (`test/.rubocop.yml`) aplicado: `lib/**`/`server.rb` continuam nas métricas
      estritas do root; testes têm orçamentos próprios sem desativar métrica.
- [x] Bônus mecânico aceito: disables redundantes removidos em `poke_api_test.rb` (restou 1
      `Layout/LineLength` legítimo), `move_test.rb`, `poke_api_move_test.rb`.
- [x] `testincremental_play_reaches_same_result_as_battle` preservado (baseline 222 intacto).
- [x] Nenhum comportamento alterado: 0 mudanças em `lib/**`/`server.rb` nesta sessão.

**Resultado:** sessão **0019 concluída — Done** em 2026-08-10. Próxima sessão: **D2 (XP/evolução)**
(decisão do usuário).

## 6b. Progresso da implementação (passos 1–6 verdes)

> Executado em 2026-08-10 e **validado pelo usuário** (fase 6 acima).

- **Passos 1–5** (infra + motores + server + team_repository + schema/helper): commit
  `d17d4dc` — `test_support.rb` (`TestSupport`), `server_test_helpers.rb`, `test/.rubocop.yml`
  (orçamentos de teste), `test_helper.rb` (`TestDatabase` com `with_db`/introspection,
  `PokeApiStub.stub_singleton` genérico), `server_test.rb` em 4 classes de área,
  motores/team_repository divididos, schema consumindo `TestDatabase`. Verificado:
  **suíte 222 runs/778 asserts** + **lint 0** + **grep `rubocop:` nos 6 arquivos → 0**.
- **Bônus mecânico:** os orçamentos de `test/.rubocop.yml` tornaram redundantes disables
  de `poke_api_test.rb`/`move_test.rb`/`poke_api_move_test.rb` (fora dos 6 arquivos);
  removidos por autocorrect para manter lint 0 — `poke_api_test.rb` ainda tem um
  `Layout/LineLength` (linha legitimanente longa, não coberta por orçamento).
- **Preservação do baseline:** a suíte manteve **222/778** exatamente; nenhum teste
  removido nem assert alterado. Nota: `testincremental_play_reaches_same_result_as_battle`
  (typo no nome, não casa com `/^test_/`) foi preservado **com o nome original** durante
  a divisão — renomeá-lo ativaria um teste que hoje não roda e quebraria o baseline.

## 7. Observações

- Sessão de **respiro** entre fases grandes (decisão do usuário em 2026-08-10), via
  candidata do draft; não bloqueia nem adia D2 (XP/evolução) — registrada como próxima
  sessão após a 0019.
- Refatoração **não** altera comportamento: nenhum teste removido, asserts preservados
  (baseline 222 runs/778 asserts como referência).
- Cuidado especial com `server_test.rb` (1242 linhas): a divisão é o meio de derrubar
  o `ClassLength`; os helpers `battle_pokemon_for_test`/`battle_moves_for_test`/
  `add_three_pokemon_team`/`add_four_pokemon_team`/`distinct_user_ids` já sinalizam
  os candidatos naturais ao `TestSupport`/`TestDatabase`.
- **Decisão do usuário (2026-08-10):** repetir o tratamento nos arquivos de
  **produção** (`lib/**` + `server.rb`) em **sessão futura** — anotado no
  `draft-auto-battler.md` com levantamento real (5 arquivos, 7 disables) e avaliação
  de "1 fase ou mais" (recomendado 1 fase, com critério de suíte+lint+validação;
  separar só se surgir mudança de contrato público). Esta sessão 0019 **não** toca
  `lib/`/`server.rb` (garantia RNF: sem mudança de comportamento).
- **Estratégia híbrida para `ClassLength` (decisão do usuário, ajuste de escopo em
  2026-08-10):** dividir `server_test.rb` em **classes por área** (Team/Lista/
  Detail/Battle/Erro) — como no plano original — e complementar com **`test/.rubocop.yml`**
  definindo **orçamentos específicos de teste** (`Metrics/MethodLength`/`AbcSize`/
  `ParameterLists`/`ClassLength`) para os casos em que dividir/fatiar seria churn
  desproporcional (testes longos que são uma sequência legível de asserts). A métrica
  continua ativa (sem disable no código), só o **limite muda para `test/`**;
  `lib/**`/`server.rb` seguem nas métricas estritas do root. As divisões de
  `TeamRepositoryTest` (por operação) e dos motores permanecem no plano.