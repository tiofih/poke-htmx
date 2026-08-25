# Sessão 0049 — Oponente novo a cada confronto (BUG-1/Q1)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-25 |
| Implementação | **Concluída** — passos 1–2 verdes (suíte 727/2344, lint 0) |
| Validação | **Pendente** (executada pelo usuário) |

---

## 1. Objetivo

Corrigir o bug **Q1/BUG-1** (anotado 2026-08-25, confirmado no playtest 2/QA):
o `BattleService` passa a gerar um **oponente novo a cada confronto** para o mesmo
usuário, mantendo o ajuste de dificuldade pelo nível médio do time (banda de tiers).

## 2. Contexto (estado atual — diagnóstico)

- `BattleService#build_opponent` (`lib/battle_service.rb:64-73`) monta o
  `OpponentGenerator` com `rng: Random.new(user_id.sum)` — **seed determinística por
  usuário** — então o mesmo usuário recebe o **mesmo time oponente nível 1** em toda
  batalha, tanto via "Novo confronto" quanto ao re-entrar em `/battle` (o histórico
  mostra repetições idênticas).
- A **banda** (`PokemonRating.band_for_level(average_player_level(...))` via
  `opponent_options`) já ajusta a dificuldade ao time atual; o que trava é apenas a
  escolha **dentro** da banda, por causa da seed fixa.
- `OpponentGenerator` (`lib/opponent_generator.rb`) já aceita `rng:` injetável com
  default `Random.new` (não-seedado → novo a cada instância) e sorteia sem repetição
  (`@names.shuffle(random: @rng)` + fallback `sample`). Nenhuma mudança necessária lá.
- `test/battle_service_test.rb:178` (`test_prepare_returns_same_opponent_for_same_user`)
  **codifica o bug** (afirma que o oponente é o mesmo para o mesmo usuário) — será
  substituído pelo teste do comportamento correto.
- Testes de rota (`test/battle_routes_test.rb`) usam pool de 6 nomes via
  `PokeApiStub.with_all_names` — o oponente usa sempre os 6 (só a ordem varia), então
  as asserts de presença de nome/HP/nível continuam válidas.
- Validação empírica feita no refinamento: `Random.new(1)`, `Random.new(2)`,
  `Random.new(3)` produzem ordens (e composições na banda com fallback) **diferentes**
  para os pools usados nos testes → teste determinístico, sem flakiness.

## 3. Escopo

### Produção

- `lib/battle_service.rb`:
  - `initialize` aceita dependência opcional `opponent_rng` (callable → `Random`),
    default `-> { Random.new }` (consistente com o provider `api:`).
  - `build_opponent` usa `rng: @opponent_rng.call` — **um RNG novo por confronto**,
    eliminando a seed fixa por usuário. Banda/nível/`opponent_options` inalterados.

### Testes

- `test/battle_service_test.rb`:
  - `build_service` aceita `opponent_rng:` opcional e repassa às dependencies.
  - **Remover/substituir** `test_prepare_returns_same_opponent_for_same_user` por
    `test_prepare_generates_new_opponent_for_each_confront` (injetando
    `opponent_rng` de seeds sequenciais → dois `prepare` do mesmo usuário geram
    oponentes diferentes).
- Testes de banda existentes (`test_build_opponent_uses_high_band_for_high_level_player`,
  `test_build_opponent_prioritizes_weak_band_for_low_level_player`) e do
  `OpponentGenerator` (`test/opponent_generator_test.rb`) permanecem **intactos** e
  devem continuar verdes (garantia de regressão).

### Fora de escopo (não abrir)

- **Nível do oponente** fixo `level: 1` em `build_opponent` — não é o objeto do bug
  (a dificuldade vem da banda); mudar a escala de nível é decisão de game design separada.
- **Q2/BUG-2** (item perdido ao remover), **Q3** (gate da jornada), **Q4** (busca
  formas base), **Q5/BUG-3** (remover 2x) — catalogados no QA, outras sessões.
- **P2** (perf da varredura da banda ~2min na 1ª batalha), "batalhar resolve a
  batalha inteira", M2 (ranking/custo na lista + filtros) — anotações de roadmap.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 — Oponente novo a cada confronto do mesmo usuário:** dois `prepare`
      consecutivos de `user-1` produzem times oponentes **diferentes** (ordem e/ou
      composição) — prova: `test/battle_service_test.rb`
      (`test_prepare_generates_new_opponent_for_each_confront`).
- [ ] **C2 — Dificuldade ajustada ao time atual preservada:** a banda derivada do
      nível médio do jogador continua regendo a composição do oponente (time alto →
      banda A–S; time nível 1 → banda F–D com fallback) — prova: `test/battle_service_test.rb`
      (`test_build_opponent_uses_high_band_for_high_level_player` e
      `test_build_opponent_prioritizes_weak_band_for_low_level_player`, mantidos).
- [ ] **C3 — Determinismo do gerador preservado:** `OpponentGenerator` segue
      determinístico sob seed fixa (propriedade do gerador intacta; a variação passa a
      vir do RNG novo por confronto no service) — prova: `test/opponent_generator_test.rb`
      (`test_same_seed_generates_same_team_order`,
      `test_team_names_with_band_is_deterministic_for_seed`).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (727 runs/2344 asserts) + novos
      testes** e lint 0 em **todo** green; commit obrigatório por passo; 0 regressão.
- [ ] Sem gems novas / sem mudança de schema / testes sem rede / sem `rubocop:disable`.
- [ ] `REQUIREMENTS.md` (limitação do bug → resolvida na 0049) + `SESSIONS.md`
      (tabela + "Próxima sessão") + `draft-auto-battler.md` (BUG-1 marcado corrigido)
      atualizados no passo docs; `./scripts/check_docs` ok; status de validação só
      após o usuário validar (S4).

> **S1:** cada critério aponta o teste que o prova (todos automatizados).

## 5. Decisões de refinamento (fechadas com o usuário)

- **RNG novo por confronto (2026-08-25):** eliminar a seed fixa `Random.new(user_id.sum)`
  em `build_opponent`, gerando um RNG novo a cada `prepare` via dependência injetável
  `opponent_rng` (default `-> { Random.new }`). Alternativas preteridas: (a) trocar a
  seed por `SecureRandom.random_number` — menos testável; (b) persistir variedade no
  banco — over-engineering para o objetivo (novo a cada confronto); (c) deixar o
  `OpponentGenerator` sem `rng:` (default) — funcionaria em produção, mas sem controle
  nos testes.
- **Teste determinístico (2026-08-25):** o teste do comportamento correto injeta
  `opponent_rng` com seeds sequenciais (1, 2) em vez de RNG real (evita flakiness por
  colisão). Validado empiricamente que as seeds 1 e 2 produzem ordens diferentes nos
  pools dos testes.
- **Escopo mínimo do bug (2026-08-25):** só a variedade por confronto entra na 0049.
  `level: 1` do oponente, Q2–Q5 e P2 ficam para sessões próprias (não abrir escopo).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `Sessao 0049: refinamento concluido — ...` |
| 1 | red: substituir `test_prepare_returns_same_opponent_for_same_user` por `test_prepare_generates_new_opponent_for_each_confront` (falha com a seed fixa atual); green: `BattleService` com dependência `opponent_rng` (default `-> { Random.new }`) e `build_opponent` usando `rng: @opponent_rng.call` | suíte verde + lint 0, commit `Passo 1:` |
| 2 | Docs — REQUIREMENTS.md (limitação do bug → corrigida na 0049), SESSIONS.md (tabela da 0049 + "Próxima sessão" com Q2–Q5 em aberto), draft-auto-battler.md (BUG-1 → corrigido); rodar `./scripts/check_docs` | suíte verde + lint 0 + check_docs ok, commit `Passo 2:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 — oponente novo por confronto | `./scripts/test -n /generates_new_opponent/` | em `/battle`, "Novo confronto" e re-entrar geram oponentes com times diferentes | |
| C2 — dificuldade pela banda preservada | `./scripts/test -n /band_for_level_player/` (2 testes) | time forte vs time nível 1 → oponentes de força diferente | |
| C3 — determinismo do gerador intacto | `./scripts/test -n /deterministic/` (`test/opponent_generator_test.rb`) | — | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

- Bug completo em `REQUIREMENTS.md` (limitações, anotado 2026-08-25) e
  `draft-auto-battler.md` (BUG-1). A correção não toca a banda, o rater, o nível nem a
  UI — escopo mínimo do Q1.
- Depois da 0049, restam os demais itens do QA (Q2–Q5) e a fila de roadmap
  (J2, J4, D4, P2, M2) — a critério do usuário.