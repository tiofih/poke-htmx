# Sessão 0049 — Oponente novo a cada confronto (BUG-1/Q1) + máquina de estado do gameloop

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-25; **ajuste S3 em 2026-08-25** (reabertura do C1 + novo escopo) |
| Implementação | **Concluída** — passos 1–5 verdes (suíte 735/2358, lint 0) |
| Validação | **Concluída** — validada pelo usuário em 2026-08-25 (critérios C1–C7 ok, suíte 735/2358, lint 0) |

---

## 1. Objetivo

Corrigir o bug **Q1/BUG-1** (anotado 2026-08-25, confirmado no playtest 2/QA) e
entregar a **máquina de estado do gameloop**: o `BattleService` gera **oponente novo
apenas em um novo confronto** (sem batalha ativa, após "Novo confronto" ou após mudança
de time), mantendo **estável** a batalha ativa ao re-visitar `/battle` — com o time do
jogador refletindo o estado atual (HP curado) na batalha ainda não iniciada.

## 2. Contexto (estado atual — diagnóstico)

- `BattleService#build_opponent` (`lib/battle_service.rb`) usava `Random.new(user_id.sum)`
  (**seed determinística por usuário**) → o mesmo usuário recebia **sempre o mesmo time
  oponente** — bug Q1.
- A **banda** (`PokemonRating.band_for_level(average_player_level(...))`) já ajusta a
  dificuldade ao time atual; o travamento era a escolha **dentro** da banda (seed fixa).
- `OpponentGenerator` (`lib/opponent_generator.rb`) já aceita `rng:` injetável (default
  `Random.new`) e sorteia sem repetição — nada a mudar lá.
- **Máquina de estado ausente:** `GET /battle` (`server.rb:352`) chama
  `settings.battle.prepare(user_id)` **incondicionalmente** e `prepare` **sempre** cria
  engine novo (`@battles.set`), mesmo quando já existe batalha ativa no `BattleRegistry`.
  Resultados indesejados: (a) re-visitar `/battle` **regenera o oponente** (após a 0049);
  (b) se a batalha estiver **em andamento** (rounds jogados), o `prepare` a **sobrescreve
  e perde o progresso**; (c) "Novo confronto" é `hx-get="/battle"` (mesma rota do acesso).
- O `BattleRegistry` guarda a batalha por usuário, mas ninguém o consulta antes de preparar.
- Handlers de mudança de time (`add_team_member`, `remove_team_member`,
  `move_team_member`) **não limpam** o registry → batalha preparada fica desatualizada
  quando o time muda.

## 3. Escopo

### Produção

- `lib/battle_service.rb`:
  - `prepare` ganha **reuso por estado** da batalha ativa:
    - **em andamento/finalizada** (rounds > 0): retorna o engine existente como está
      (preserva progresso / mostra resultado de fim).
    - **preparada, não iniciada** (rounds == 0): re-deriva o **time do jogador** do
      estado persistido (HP curado, nível, golpes, itens) e **preserva o oponente**
      (`existing.teams[1]`).
    - **sem batalha ativa**: novo confronto (novo oponente via `opponent_rng`).
  - `new_confront(user_id)` — limpa o registry e prepara (novo oponente).
  - `invalidate(user_id)` — limpa o registry (usado pelos handlers de mudança de time).
- `lib/battle_registry.rb`: `clear_all` (limpeza total para isolamento de testes).
- `server.rb`:
  - `add_team_member`/`remove_team_member`/`move_team_member` chamam
    `settings.battle.invalidate(current_user)` quando o time muda (no add, só em sucesso).
  - rota nova `POST /battle/new` → handler `new_confront_battle` (chama `new_confront` e
    renderiza a batalha preparada).
- `views/battle.erb`: botão "Novo confronto" passa de `hx-get="/battle"` para
  `hx-post="/battle/new"`.

### Testes

- `test/battle_service_test.rb`:
  - substituir `test_prepare_generates_new_opponent_for_each_confront` (que agora falha
    com o reuso) por:
    - `test_prepare_keeps_same_opponent_when_battle_not_started` (2 `prepare` → mesmo
      oponente);
    - `test_prepare_generates_new_opponent_after_new_confront` (`prepare` → `new_confront`
      → oponente diferente);
    - `test_prepare_refreshes_player_hp_while_keeping_opponent` (cura entre `prepare`s →
      HP do jogador novo, oponente preservado);
    - `test_prepare_preserves_in_progress_battle` (após um play, `prepare` retorna o mesmo
      engine/estado);
    - `test_prepare_returns_finished_battle_as_is` (batalha finalizada → `prepare` não
      gera nova);
    - `test_invalidate_clears_active_battle` (`invalidate` → `prepare` → oponente novo).
- `test/battle_routes_test.rb`:
  - `test_battle_revisits_keep_same_opponent` (GET htmx ×2 → HTML idêntico);
  - `test_new_confront_generates_new_opponent` (GET → `POST /battle/new` → oponente
    diferente, com `opponent_rng` sequencial injetado);
  - `test_removing_member_resets_prepared_battle` (GET → `DELETE /team` → GET → novo
    confronto).
  - helper `with_seeded_battle_rng` (injeta `BattleService` com `opponent_rng` sequencial
    para testes determinísticos de rota) em `test/battle_test_helpers.rb`.
- `test/battle_registry_test.rb`: `clear_all`.

### Fora de escopo (não abrir)

- **Nível do oponente** fixo `level: 1` — decisão de game design separada.
- **Q2/BUG-2** (item perdido no remove), **Q3** (gate da jornada), **Q4** (busca formas
  base), **Q5/BUG-3** (remover 2x) — outras sessões.
- **P2** (perf da varredura da banda), "batalhar resolve a batalha inteira", M2 —
  anotações de roadmap.

## 4. Critérios de aceite

> **S3 (2026-08-25):** o critério **C1** original ("oponente novo a cada confronto: dois
> `prepare` consecutivos produzem times diferentes") foi **reprovado na validação** — a
> implementação fazia o oponente trocar a **cada acesso** a `/battle`, quebrando a
> estabilidade da batalha ativa. Reaberto e redefinido abaixo; novos critérios C4–C7
> cobrem a máquina de estado (escopo completo escolhido pelo usuário).

### Resultado

- [ ] **C1 — Oponente novo a cada NOVO confronto, não a cada acesso:** dois `prepare`
      consecutivos **sem** iniciar mantêm o mesmo oponente; após `new_confront`
      (ou sem batalha ativa), o oponente é **novo** — prova: `test/battle_service_test.rb`
      (`test_prepare_keeps_same_opponent_when_battle_not_started`,
      `test_prepare_generates_new_opponent_after_new_confront`) e
      `test/battle_routes_test.rb` (`test_new_confront_generates_new_opponent`).
- [ ] **C2 — Dificuldade ajustada ao time atual preservada:** a banda derivada do nível
      médio do jogador continua regendo a composição do oponente — prova:
      `test/battle_service_test.rb` (`test_build_opponent_uses_high_band_for_high_level_player`,
      `test_build_opponent_prioritizes_weak_band_for_low_level_player`, mantidos).
- [ ] **C3 — Determinismo do gerador preservado:** `OpponentGenerator` segue determinístico
      sob seed fixa — prova: `test/opponent_generator_test.rb`
      (`test_same_seed_generates_same_team_order`,
      `test_team_names_with_band_is_deterministic_for_seed`).
- [ ] **C4 — Batalha preparada (não iniciada) é estável e reflete o time atual:** re-visitar
      `/battle` mantém o **mesmo oponente** e **re-deriva o time do jogador** do estado
      persistido (HP curado entre visitas) — prova: `test/battle_service_test.rb`
      (`test_prepare_refreshes_player_hp_while_keeping_opponent`) e
      `test/battle_routes_test.rb` (`test_battle_revisits_keep_same_opponent`).
- [ ] **C5 — Batalha em andamento é preservada:** re-visitar `/battle` após iniciar (rounds
      jogados) retorna a **mesma batalha** (não sobrescreve/perde progresso) — prova:
      `test/battle_service_test.rb` (`test_prepare_preserves_in_progress_battle`).
- [ ] **C6 — Batalha finalizada mantém o resultado:** re-visitar `/battle` com a batalha
      terminada mostra o **resultado** (não prepara nova automaticamente); "Novo confronto"
      (`POST /battle/new`) gera novo — prova: `test/battle_service_test.rb`
      (`test_prepare_returns_finished_battle_as_is`) + manual.
- [ ] **C7 — Mudança de time invalida a batalha ativa:** adicionar/remover/reordenar membros
      limpa a batalha ativa; o próximo `GET /battle` prepara um **novo confronto** — prova:
      `test/battle_routes_test.rb` (`test_removing_member_resets_prepared_battle`) e
      `test/battle_service_test.rb` (`test_invalidate_clears_active_battle`).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (727 runs/2344 asserts) + novos
      testes** e lint 0 em **todo** green; commit obrigatório por passo; 0 regressão.
- [ ] Sem gems novas / sem mudança de schema / testes sem rede / sem `rubocop:disable`.
- [ ] `REQUIREMENTS.md` + `SESSIONS.md` + `draft-auto-battler.md` atualizados no passo
      docs; `./scripts/check_docs` ok; status de validação só após o usuário validar (S4).

> **S1:** cada critério aponta o teste que o prova (todos automatizados, exceto onde `manual`
> explícito).

## 5. Decisões de refinamento (fechadas com o usuário)

- **RNG novo por confronto (2026-08-25):** eliminar a seed fixa `Random.new(user_id.sum)`
  em `build_opponent`, com dependência injetável `opponent_rng` (default `-> { Random.new }`).
- **Teste determinístico (2026-08-25):** `opponent_rng` com seeds sequenciais (1, 2) em vez
  de RNG real (evita flakiness por colisão); validado empiricamente.
- **Ajuste S3 (2026-08-25, usuário):** a 0049 estava na validação e o comportamento
  "oponente troca a cada acesso a `/battle`" foi **reprovado**. Decisão do usuário:
  **Ajuste S3 na 0049** — reabrir C1 e ampliar a sessão para a **máquina de estado do
  gameloop** com **escopo completo** (reuso da batalha ativa + reset por mudança de time).
  "Novo confronto" vira ação explícita (`POST /battle/new`), desacoplada do acesso à tela.
- **Reuso por estado (2026-08-25):** `prepare` reusa a batalha ativa por estado
  (preparada → re-deriva time + preserva oponente; em andamento/finalizada → preserva).
  Alternativa preterida: reusar sempre o engine inteiro (não refletiria o HP curado na
  batalha não iniciada).
- **Reset por mudança de time (2026-08-25):** add/remove/move limpam o registry
  (`invalidate`); no add, só em sucesso (não invalida quando o add falha por time cheio).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** (original) — arquivo com critérios e plano fechados | commit `Sessao 0049: refinamento concluido — ...` |
| 1 | **Já feito:** `build_opponent` com `opponent_rng` (fim da seed fixa) | commit `Passo 1:` (`afff60c`) |
| 2 | **Já feito:** docs da 0049 (pré-validação) | commit `Passo 2:` (`5760e89`) |
| 3 | **S3 — reuso da batalha ativa no `BattleService`:** red — testes do reuso por estado + `new_confront`/`invalidate` (falham: `prepare` sempre gera novo); green — `prepare` com reuso, `new_confront`, `invalidate` | suíte verde + lint 0, commit `Passo 3:` |
| 4 | **S3 — rota e handlers:** red — testes de rota (`test_battle_revisits_keep_same_opponent`, `test_new_confront_generates_new_opponent`, `test_removing_member_resets_prepared_battle`) + helper `with_seeded_battle_rng` + `clear_all` no registry/setup; green — rota `POST /battle/new`, handlers invalidam no add/remove/move, botão "Novo confronto" → `hx-post` | suíte verde + lint 0, commit `Passo 4:` |
| 5 | **Docs (S3):** `REQUIREMENTS.md` (limitação Q1 corrigida + roadmap com máquina de estado), `SESSIONS.md` (tabela + "Próxima sessão"), `draft-auto-battler.md` (BUG-1 → corrigido, nota do reuso); `./scripts/check_docs` | suíte verde + lint 0 + check_docs ok, commit `Passo 5:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Concluída.** *Validada pelo usuário em 2026-08-25. Suíte executada: 735 runs / 2358
asserts, lint 0.* *(S2: uma linha por critério.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 — novo confronto ≠ acesso à tela | `./scripts/test -n /keeps_same_opponent\|after_new_confront/` (verdes) | entrar na batalha, sair e voltar → mesmo oponente; "Novo confronto" → time diferente | ok |
| C2 — banda pelo nível preservada | `./scripts/test -n /band_for_level_player/` (2 testes verdes) | — | ok |
| C3 — determinismo do gerador | `./scripts/test -n /deterministic/` (`test/opponent_generator_test.rb`, verdes) | — | ok |
| C4 — preparada estável + HP atual | `./scripts/test -n /refreshes_player_hp\|revisits_keep_same_opponent/` (verdes) | ver poke sem vida → curar → voltar: mesmo oponente e poke curado | ok |
| C5 — em andamento preservada | `./scripts/test -n /preserves_in_progress/` (verde) | iniciar batalha, jogar rodada, recarregar `/battle` → mesma rodada | ok |
| C6 — finalizada mostra resultado | `./scripts/test -n /returns_finished_battle/` (verde) | terminar batalha, re-visitar → resultado; "Novo confronto" → novo | ok |
| C7 — mudança de time reseta | `./scripts/test -n /invalidates_active_battle\|resets_prepared_battle/` (verdes) | batalha preparada, remover/add membro, voltar → oponente novo | ok |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e
> obter nova aprovação do usuário. *(Nenhum ajuste necessário na validação de 2026-08-25.)*

## 8. Observações

- **Reprovação registrada:** a validação da 0049 (C1) foi iniciada pelo usuário em
  2026-08-25 e **reprovada** — re-visitar `/battle` regenerava o oponente. Registrada a
  alteração formal de critério (seção 4, S3) em 2026-08-25.
- Bug completo em `REQUIREMENTS.md` (limitações) e `draft-auto-battler.md` (BUG-1).
- Depois da 0049, restam os demais itens do QA (Q2–Q5) e a fila de roadmap
  (J2, J4, D4, P2, M2) — a critério do usuário.