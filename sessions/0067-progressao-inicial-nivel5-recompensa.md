# Sessão 0067 — progressao-inicial-nivel5-recompensa (Onda 2 Economia #4: progressão inicial nível 5 + recompensa +2/+1 via bypass grants)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-29 (D1 A, D2 A, D3 B, D4-D6 A, D7-D9 A) |
| Implementação | Pendente — aguardando fase 2 (TDD) |
| Validação | Pendente — parar ao fim da fase 2 e aguardar validação do usuário (fase 3) |

---

## 1. Objetivo

Time inicial passa a nascer no **nível 5 com xp 1000** (`cumulative_xp_for(4)=1000`, invariante `level_for_xp(1000)=5`) e **recompensa de batalha vira bypass de XP** — `RewardRule#levels_for` (`win +2 / draw +1 / lose +1`, `money_for` preservado) aplicado via `ProgressionRepository#grant_levels(user_id, id, delta)` direto no `level` (sem recalcular `level_for_xp`), chamado **uma única vez** por `:finished` em `BattleService#grant_finished_xp` (guard), refletindo em `average_player_level` / banda / geração do oponente; `ExperienceCurve` vira display apenas; pedras/modais ficam para 0068.

## 2. Contexto (estado atual — diagnóstico)

- **Baseline pós-0066:** suíte **934/3636** lint 0, revisor **Aprovado** (round 2/3, S3 C13 ok) — pool oponente alinhado (`OpponentGenerator` base_form+geração+orçamento ≤450 + level `average+delta` + paridade golpes). Roadmap Onda 2 Economia: 0064 vida zerada → 0065 death spiral → 0066 pool oponente → **0067 progressão** → 0068 pedras+modais → 0069 resolver batalha → 0063 juice, Onda 3 Estabilidade (0069→0072). `SESSIONS.md:377` "Próxima sessão: 0067 pedras+modais → 0068 resolver batalha → 0063 juice"; `draft-auto-battler.md` 2026-08-29 anotado "times iniciam nível 5, vitórias +2 / derrotas +1".
- **Progressão hoje nível 1:** `lib/team_repository.rb:171` `add` via `create_progress(team_pokemon_id)` insere `level 1, xp 0` (`INSERT INTO team_pokemon_progress (team_pokemon_id, level, xp) VALUES ($1,1,0)`); `lib/experience_curve.rb:3-19` `xp_needed(level)=level*100`, `cumulative_xp_for(level)=level*(level+1)*100/2`, `level_for_xp(total_xp)` loop `while total_xp >= cumulative` ; `cumulative_xp_for(4)=1000 → level_for_xp(1000)=5` (invariante). `lib/progression_repository.rb:31-43` `grant(user_id, id, amount)` soma `xp` e recalcula `level=level_for_xp(total)`; `lib/reward_rule.rb:3-33` `DEFAULT win_xp 50/draw 25/lose 20` `win_money 100/draw 50/lose 40` `xp_for(result)/money_for(result)`; `lib/battle_service.rb:235-240` `grant_finished_xp` itera `@team.all` e chama `@progression.grant(user_id, member.id, RewardRule.new.xp_for(engine.result))` sem guard explícito por `:finished` (depende de `finish_effects` só em `finishing && finished?`), `average_player_level` `lib/battle_service.rb:158-163` média arredondada, `band_for_level` `lib/pokemon_rating.rb:34-42`, `generation_for_level` `lib/battle_service.rb:142-155` mapeamento 1-2→1 ... 42+→9, oponente `level=avg+band_offset`.
- **Oportunidade D2 A + D3 B:** elevar `add` para `level 5 xp 1000` (novos membros), sem migração retroativa; substituir economia XP por **bypass**: `RewardRule#levels_for(result) → {win:2, draw:1, lose:1}` + `ProgressionRepository#grant_levels(user_id, id, delta)` incrementa `level` direto (`level + delta`, `xp` acompanha para consistência ou mantém invariante de display), `BattleService#grant_finished_xp` chama `grant_levels` **1× por `:finished`** (guard `finished?` + `already_granted?` ou `result` presente), `ExperienceCurve` deixa de ditar level (vira display). Mantém `restricted S110` (`lib/team_budget.rb` S_rest 110) e `TeamBudget BUDGET 450` intactos.
- **Arquivos atuais (índice Users-tiofih-workspace-poke-htmx 5196 nodes, generation 2026-08-29T21:16:44Z, full):** `lib/team_repository.rb:171` `add`/`create_progress:217-222`, `lib/experience_curve.rb:3` `xp_needed/level_for_xp/cumulative_xp_for`, `lib/reward_rule.rb:3` `DEFAULT/money_for/xp_for`, `lib/progression_repository.rb:14` `get/update_hp/grant/progress_row`, `lib/battle_service.rb:235` `grant_finished_xp`/`average_player_level:158`/`band_offset:129`/`generation_for_level:142`, `lib/pokemon_rating.rb:34` `band_for_level`, índice verificado `check_index_coverage` nos 5 paths → `no_recorded_issue` (`metadata_match`, `indexed_at 2026-08-29T21:16:44Z`).
- **Preservar:** `TeamRepository` sem regra além de `create_progress` nível 5, `ExperienceCurve` sem mudar thresholds, `TeamBudget` S_rest 110 intacto, `HealService`/`JourneyService`/`OpponentGenerator`/`PokemonRatingCache` intactos, suíte/lint verdes, sem `db/migrations` nova.

## 3. Escopo

### Produção

- `lib/team_repository.rb:217-222` — **D2 A:** `create_progress(team_pokemon_id)` passa a inserir `level 5, xp 1000` (`INSERT ... VALUES ($1, 5, 1000)`); `add` mantém slot/dup check/transaction. Sem `UPDATE` retroativo, sem migração.
- `lib/progression_repository.rb:31-43` — **D3 B:** novo `grant_levels(user_id, team_pokemon_id, delta)` — `SELECT level, xp` via `progress_row`, `new_level = level + delta.to_i`, `new_xp = xp` ou `xp + delta*100` coerente com display (preserva `level_for_xp(new_xp)` ≥ new_level ou mantém `xp` para display via `cumulative_xp_for(new_level-1)` — escolher uma e documentar; recomendada `new_xp = ExperienceCurve.cumulative_xp_for(new_level-1)` para manter invariante display), `UPDATE team_pokemon_progress SET level=$2, xp=$3, updated_at=now() WHERE team_pokemon_id=$1`, retorna `{level:new_level, xp:new_xp}`; `grant(user_id, id, amount)` legado mantém-se mas não usado pela batalha (ou vira alias). Fail-safe `return unless current`.
- `lib/reward_rule.rb:3-33` — **D3 B:** adicionar `DEFAULT` `win_levels:2, draw_levels:1, lose_levels:1` + método `levels_for(result)` espelhando `money_for` (`case result when :win then 2 when :draw then 1 when :lose then 1 else 0`), preservando `money_for` e `xp_for` (xp_for pode ficar deprecado/display). `ExperienceCurve` não muda — vira display.
- `lib/battle_service.rb:235-240,158,142,129` — **D3 B:** `grant_finished_xp(user_id, engine)` passa a `delta = RewardRule.new.levels_for(engine.result)` e para cada `member` chama `@progression.grant_levels(user_id, member.id, delta)` **uma única vez** por `:finished` (guard `return unless engine.finished? && engine.result` + idempotência por `engine.finished?` já garante 1× via `finish_effects` `finishing && engine.finished?`; documentar guard). `average_player_level` / `band_for_level` / `generation_for_level` / `band_offset` / `opponent_team` escalam naturalmente (avg 5 → banda C-B/B-A/A-S conforme `band_for_level(5)` + `generation_for_level(5)=2` + `level=avg+delta`). Sem tocar `EvolutionRule`/`TeamBudget`.
- Sem tocar `lib/experience_curve.rb` thresholds, `lib/team_budget.rb` (`BUDGET 450`, `S_rest 110`), `lib/heal_service.rb`, `lib/journey_service.rb`, `lib/opponent_generator.rb`, `lib/pokemon_rating.rb`, `db/schema.sql`/`db/migrations/*`, `Gemfile*`, `views/*`, `lib/battle_engine.rb`.

### Testes

- `test/team_repository_test.rb` — **C1 add cria level 5 xp 1000:** `team.add(user_id, pokemon)` → `progression.get(user_id, id) => {level:5, xp:1000}` e `ExperienceCurve.level_for_xp(1000)==5` invariante; `test_add_creates_progress_at_level_five`.
- `test/progression_repository_test.rb` — **C2 existentes não migrados (sem UPDATE retroativo):** seed com `level 1 xp 0` permanece 1/0 após `add` novo; `test_existing_progress_not_migrated_to_level_five` (ou `test_grant_levels_does_not_migrate_existing`).
- `test/reward_rule_test.rb` — **C3 RewardRule levels_for:** `RewardRule.new.levels_for(:win)==2`, `:lose==1`, `:draw==1`, `:unknown==0`, `money_for` preservado 100/50/40; `test_levels_for_win_is_two`, `test_levels_for_lose_is_one`, `test_levels_for_draw_is_one`.
- `test/progression_repository_test.rb` — **C4 grant_levels incrementa direto sem recalcular level_for_xp:** `grant_levels(user_id, id, 2)` de `5/1000 → 7`, `grant_levels(...,1) 5→6`, draw 1; `xp` acompanha display (ou mantém); tester `test_grant_levels_increments_level_directly` + `test_grant_levels_sets_xp_consistent`.
- `test/battle_service_test.rb` — **C5 grant_finished_xp 1× guard por :finished:** `engine.result=:win` → cada membro `+2` uma vez; `engine.result=:lose → +1`; `:draw → +1`; chamar `grant_finished_xp` 2× não duplica (guard `finished?`); `test_grant_finished_xp_increments_two_on_win_once`, `test_grant_finished_xp_increments_one_on_lose`, `test_grant_finished_xp_guard_prevents_double_grant` (fake `progression` com contador).
- `test/battle_service_test.rb` — **C6 average/banda/gen refletem 5:** `average_player_level` com time 3× level 5 → `5`; `band_for_level(5)` → banda esperada (ex. C-B conforme thresholds `lib/pokemon_rating.rb:34-42`) + `generation_for_level(5)==2` + oponente `level = avg + band_offset`; `test_average_reflects_level_five`, `test_band_and_generation_for_level_five`, `test_build_opponent_level_scales_from_average_five`.
- G1/G2/G3 inclusos (suíte+lint, sem migração, S4/S5).

### Fora de escopo (não abrir)

- Oferta 3 pedras/rodada preço 80 etc — **D4-D6 A:** módulo `StoneOffer`/`MartService` pedras + modais de evolução (D4 preço 80, D5 oferta 3/rodada, D6 modais) ficam para **0068**.
- M1/B5/juice/dificuldade dinâmica/TeamBudget/EvolutionRule: `TeamBudget BUDGET 450` e `EvolutionRule` sem mudança; `restricted S110` intacto; juice/animações (0063) fora.
- Migração retroativa de `team_pokemon_progress` (UPDATE existentes `1/0 → 5/1000`) — preterida (D2 A).
- `ExperienceCurve` recalcular level (D3 B preterido — bypass); `xp_for` legado não dita progressão.
- Nova rota/página, `db/migrations`, `Gemfile`, `ConnectionRegistry`, CSRF/identidade, CI.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 add cria progress level 5 xp 1000 com invariante (D2 A):** `TeamRepository#add` insere `team_pokemon_progress level=5 xp=1000` e `ExperienceCurve.level_for_xp(1000)==5` (`cumulative_xp_for(4)=1000`). — prova: `test/team_repository_test.rb` `test_add_creates_progress_at_level_five`.
- [ ] **C2 existentes não migrados (sem UPDATE retroativo):** membros criados antes de 0067 com `level 1 xp 0` permanecem `1/0` após novo `add`; sem migração `db/migrations`. — prova: `test/progression_repository_test.rb` `test_existing_progress_not_migrated`.
- [ ] **C3 RewardRule levels_for + money_for preservado (D3 B):** `RewardRule#levels_for(:win)==2`, `:lose==1`, `:draw==1`, else `0`; `money_for` segue 100/50/40. — prova: `test/reward_rule_test.rb` `test_levels_for_win_is_two` + `test_levels_for_lose_is_one` + `test_levels_for_draw_is_one`.
- [ ] **C4 grant_levels incrementa level direto (bypass, sem recalcular level_for_xp):** `ProgressionRepository#grant_levels(user_id, id, delta)` faz `level += delta` direto (`5+2→7`, `5+1→6`) e `xp` consistente para display; `grant(user_id,id,amount)` legado não usado pela batalha. — prova: `test/progression_repository_test.rb` `test_grant_levels_increments_level_directly`.
- [ ] **C5 grant_finished_xp 1× por :finished com guard (D3 B):** `BattleService#grant_finished_xp` chama `grant_levels` **uma única vez** por batalha `:finished` (`win +2 / lose +1 / draw +1`); 2ª chamada não duplica; sem `:finished` não concede. — prova: `test/battle_service_test.rb` `test_grant_finished_xp_increments_two_on_win_once` + `test_grant_finished_xp_guard_prevents_double_grant`.
- [ ] **C6 average/banda/gen escalam de 5 (D3 B efeito em oponente):** `average_player_level` com time nível 5 → `5`; `band_for_level(5)` + `generation_for_level(5)==2` + `opponent level = avg + band_offset(band)` refletem nível 5 sem mocks adicionais. — prova: `test/battle_service_test.rb` `test_average_reflects_level_five` + `test_build_opponent_level_scales_from_average_five`.

### Garantias — teste que prova (S1)

| Critério | Teste que prova | Manual |
| --- | --- | --- |
| C1 (add level 5 xp 1000) | `test/team_repository_test.rb` `test_add_creates_progress_at_level_five` | — |
| C2 (existentes não migrados) | `test/progression_repository_test.rb` `test_existing_progress_not_migrated` | — |
| C3 (RewardRule levels_for) | `test/reward_rule_test.rb` `test_levels_for_win_is_two` + `test_levels_for_lose_is_one` + `test_levels_for_draw_is_one` | — |
| C4 (grant_levels bypass) | `test/progression_repository_test.rb` `test_grant_levels_increments_level_directly` | — |
| C5 (grant_finished_xp 1× guard) | `test/battle_service_test.rb` `test_grant_finished_xp_increments_two_on_win_once` + `test_grant_finished_xp_guard_prevents_double_grant` | — |
| C6 (average/banda/gen refletem 5) | `test/battle_service_test.rb` `test_average_reflects_level_five` + `test_build_opponent_level_scales_from_average_five` | — |
| G1 (suíte+lint) | `./scripts/test` suíte completa (baseline 934/3636 + novos) + `./scripts/lint` 0 por green | — |
| G2 (sem migração) | `git diff -- db/` vazio + `grep -rn "UPDATE team_pokemon_progress" lib/team_repository.rb` só `create_progress` 5/1000 | — |
| G3 (S4/S5) | `./scripts/check_docs` + `./scripts/checar-sessao 0067` + `SESSIONS.md` atualizado no refinamento | — |

- [ ] **G1:** suíte completa verde com baseline **934/3636** preservada + novos testes (C1–C6) e lint 0 em todo green; commit obrigatório por passo; 0 regressão fora do escopo (batalha/0066/TeamBudget seguem verdes via fakes).
- [ ] **G2:** sem `db/migrations` nova / sem `UPDATE` retroativo nos existentes / sem gems novas / sem rede em testes além de stubs; `HealService`/`JourneyService`/`OpponentGenerator` sem mudança; `TeamBudget S_rest 110` intacto.
- [ ] **G3:** `SESSIONS.md` atualizado no commit do refinamento (S4) — tabela + "Próxima sessão" — e `REQUIREMENTS.md` se tocar doc; status de validação só após usuário validar (fase 3 — parar na fase 2 e aguardar).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste → `manual` explícito + evidência esperada. Baseline suíte 934/3636 de 0066.
> **Parar ao fim da fase 2 e aguardar validação do usuário (fase 3) — não marcar Done, não preencher a seção 7, não commitar conclusão.**
>
> **Nota D3 B (bypass + draw +1, sem recalcular):** `grant_levels` incrementa `level` direto (`+2` win, `+1` lose, **draw +1**) sem derivar de `ExperienceCurve.level_for_xp`; `xp` acompanha só para display (ex.: `cumulative_xp_for(new_level-1)`) — não dita progressão.

## 5. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Parar ao fim da fase 2 e aguardar validação do usuário. P=pequena (2-3 passos).

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (tabela + "Próxima sessão") | commit `Sessao 0067: refinamento concluido — progressao inicial nivel 5 + recompensa +2/+1 (D1 A, D2 A, D3 B bypass grants, fora pedras)` |
| 1 | **red→green — C1+C2 TeamRepository nível 5 xp 1000 sem migração** — `lib/team_repository.rb:217-222` `create_progress` `5,1000` + invariante `level_for_xp(1000)==5`; `test/team_repository_test.rb` `test_add_creates_progress_at_level_five` + `test/progression_repository_test.rb` `test_existing_progress_not_migrated` (sem `db/migrations`) | `./scripts/test test/team_repository_test.rb test/progression_repository_test.rb -n /add_creates_progress_at_level_five\|existing_progress_not_migrated/` + suíte + `./scripts/lint` 0; commit `Passo 1: TeamRepository#add cria progress level 5 xp 1000 sem migrar existentes` |
| 2 | **red→green — C3+C4 RewardRule levels_for + ProgressionRepository grant_levels bypass** — `lib/reward_rule.rb` `levels_for(win2/draw1/lose1)` + `money_for` preservado + `lib/progression_repository.rb` `grant_levels(user_id,id,delta)` `level+delta` direto + `xp` display; testes `test/reward_rule_test.rb` `test_levels_for_*` + `test/progression_repository_test.rb` `test_grant_levels_increments_level_directly` | `./scripts/test test/reward_rule_test.rb test/progression_repository_test.rb -n /levels_for\|grant_levels_increments/` + suíte + lint 0; commit `Passo 2: RewardRule levels_for + ProgressionRepository grant_levels bypass` |
| 3 | **red→green — C5+C6 BattleService grant_finished_xp 1× + average/banda/gen refletem 5** — `lib/battle_service.rb:235-240` `delta=levels_for(result)` + loop `grant_levels` 1× guard `finished?&&result` + `average_player_level`/`band_for_level`/`generation_for_level` já escalam de 5; testes `test/battle_service_test.rb` `test_grant_finished_xp_*` + `test_average_reflects_level_five` + `test_build_opponent_level_scales_from_average_five` | `./scripts/test test/battle_service_test.rb -n /grant_finished_xp\|average_reflects_level_five\|build_opponent_level_scales/` + suíte completa + lint 0; commit `Passo 3: BattleService grant_finished_xp bypass +2/+1 com guard 1x e oponente escala de nivel 5` |
| — | **Fase 2 concluída (3 passos)** → **Revisor (2c)**: loop Implementador↔Revisor até veredito `Aprovado` (teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar Done, não preencher a seção 7, não commitar conclusão. | — |

> **Nota:** se durante a implementação algum critério exigir isolamento, o implementador pode expandir sem mudar critérios — registrar no arquivo e manter `Passo N:` por green.

## 6. Decisões de refinamento (fechadas com o usuário em 2026-08-29)

- **D1 — Objetivo/slug A (progressão primeiro, pedras depois):** `0067-progressao-inicial-nivel5-recompensa` (kebab, P 2-3 passos) antes de pedras/modais. **A escolhida:** progressão nível 5 primeiro (P). **B preterida:** pedras+progressão juntos (M, mistura domínios). **C preterida:** pedras primeiro (inverte economia). Motivo: isola economia de XP antes de itens, escolhido pelo usuário (refinamento 2026-08-29).
- **D2 — Nível inicial A (novos nível 5 xp 1000, sem migração):** novos membros `level 5 xp 1000` (`cumulative_xp_for(4)=1000`, `level_for_xp(1000)=5`). **A escolhida:** só novos, sem `UPDATE` retroativo, sem `db/migrations`. **B preterida:** migrar existentes `1/0→5/1000` (quebra histórico). **C preterida:** nível 5 xp 0 (quebra invariante). Motivo: invariante preservada, sem reescrita, escolhido pelo usuário.
- **D3 — Recompensa B (bypass XP — grant_levels direto):** `RewardRule#levels_for(win2/lose1/draw1)` + `ProgressionRepository#grant_levels(user_id,id,delta)` incrementa `level` direto, `BattleService#grant_finished_xp` chama **1× por `:finished`** (guard). `ExperienceCurve` vira display. **A escolhida:** B bypass. **A preterida:** manter `xp_for` 50/25/20 recalculando `level_for_xp` (mantém XP mas não dá +2/+1). **C preterida:** XP + níveis híbrido. Motivo: +2/+1 direto pedido no playtest, sem recalcular curva, escolhido pelo usuário; `money_for` preservado 100/50/40; **draw +1** explícito.
- **D4 — Oferta de pedras A (fora):** preço/detalhe das pedras (ex. 80) fora desta. **A escolhida:** fora (fica p/ 0068). Motivo: D1 A.
- **D5 — Oferta por rodada A (fora):** 3 pedras/rodada fora. **A escolhida:** fora (0068). Motivo: D1 A.
- **D6 — Modais de evolução A (fora):** modais fora. **A escolhida:** fora (0068). Motivo: D1 A.
- **D7 — Contenção recomendada A (só 4 arquivos):** `lib/team_repository.rb` + `lib/progression_repository.rb` + `lib/reward_rule.rb` + `lib/battle_service.rb`. **A escolhida:** só esses 4. **B preterida:** tocar `TeamBudget`/`EvolutionRule`/views. **C preterida:** tocar `ExperienceCurve` thresholds. Motivo: menor blast radius, escolhido pelo usuário.
- **D8 — Fora de escopo M1/B5 A:** M1/B5 fora. **A escolhida:** fora. Motivo: D1 A.
- **D9 — Fora juice/dificuldade dinâmica A:** juice (0063) e dificuldade dinâmica fora; `restricted S110` intacto. **A escolhida:** fora, manter S110. Motivo: conter P, escolhido pelo usuário.

> **Grafo obrigatório (tier Scout, generation 2026-08-29T21:16:44Z, full, 5196 nodes):** `search_graph query="TeamRepository add" limit 10` → `TeamRepository.add lib/team_repository.rb:171-179` + `create_progress 217-222`; `search_graph query="ExperienceCurve level_for_xp" limit 10` → `ExperienceCurve.level_for_xp lib/experience_curve.rb:9-13`, `cumulative_xp_for:17-19`; `search_graph query="RewardRule xp_for money_for" limit 10` → `RewardRule.xp_for lib/reward_rule.rb:17`, `money_for:21`; `search_graph query="ProgressionRepository grant" limit 10` → `ProgressionRepository.grant lib/progression_repository.rb:31`, `get:14`, `progress_row:47`; `search_graph query="BattleService grant_finished_xp average_player_level" limit 10` → `BattleService.grant_finished_xp lib/battle_service.rb:235`, `average_player_level:158`, `band_for_level`, `generation_for_level:142`; `check_index_coverage` em `lib/team_repository.rb/lib/experience_curve.rb/lib/reward_rule.rb/lib/progression_repository.rb/lib/battle_service.rb` → `no_recorded_issue` `metadata_match` `indexed_at 2026-08-29T21:16:44Z`.

## 7. Validação (executada pelo usuário — S2)

> **PARAR ao fim da fase 2 e aguardar validação do usuário (fase 3) — não marcar Done, não preencher esta seção, não commitar conclusão.**

| Critério | Evidência automatizada | Evidência manual | Resultado |
| --- | --- | --- | --- |
| C1 add cria progress level 5 xp 1000 | `test/team_repository_test.rb` `test_add_creates_progress_at_level_five` | — | — |
| C2 existentes não migrados | `test/progression_repository_test.rb` `test_existing_progress_not_migrated` | — | — |
| C3 RewardRule levels_for win2/lose1/draw1 | `test/reward_rule_test.rb` `test_levels_for_*` | — | — |
| C4 grant_levels incrementa direto | `test/progression_repository_test.rb` `test_grant_levels_increments_level_directly` | — | — |
| C5 grant_finished_xp 1× guard | `test/battle_service_test.rb` `test_grant_finished_xp_*` | — | — |
| C6 average/banda/gen refletem 5 | `test/battle_service_test.rb` `test_average_reflects_level_five` + `test_build_opponent_level_scales_from_average_five` | — | — |
| G1 suíte+lint | `./scripts/test` 934/3636 + `./scripts/lint` 0 por green | — | — |
| G2 sem migração | `git diff -- db/` vazio + `grep -rn UPDATE lib/team_repository.rb` só create 5/1000 | — | — |
| G3 S4/S5 | `./scripts/check_docs` ok + `./scripts/checar-sessao 0067` ok + `SESSIONS.md` atualizado | — | — |

## 8. Observações

- **Conter P sem pedras:** D4-D6 A deixa `StoneOffer`/Mart/Modais para 0068, mantendo 0067 em 3 passos; `ExperienceCurve` vira display mas thresholds `level*100` preservados para invariante `1000→5`; `grant` legado não removido (compat).
- **Risco draw +1:** D3 B inclui **draw +1** (não só win/lose) — mesma regra de +1 de derrota; sem recalcular `level_for_xp`, `xp` é display; guard 1× por `:finished` evita duplo level em `play_round` repetido.
- **Próxima fila Onda 2 Economia:** **0068 pedras+modais** (oferta 3/rodada preço 80 + modais evolução) → **0069 resolver batalha** (batalha resolve inteira) → **0063 juice** (animações), depois Onda 3 Estabilidade; futuras **ajuste XP/dinheiro fino** e dificuldade dinâmica por desempenho seguem para sessão futura dedicada — ver `draft-auto-battler.md` § Futuras 2026-08-29.
