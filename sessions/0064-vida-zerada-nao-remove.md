# Sessão 0064 — vida-zerada-nao-remove (Onda 2 Economia #1: fainted bloqueia remoção)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-28 (D1 A, D2 A, D3 A, D4 A, D5 C, D6 A, D7 A, D8 A, D9 A) |
| Implementação | **Concluída** — 3 commits (f4b5c97, ce060ed, 502993a), suíte 906/3367 lint 0, revisor **Aprovado** |
| Validação | **Concluída** — validado pelo usuário em 2026-08-28 (S2 tabela por critério ok) |

---

## 1. Objetivo

Impedir a remoção de Pokémon com vida zerada do time: `TeamService#remove_member` bloqueia quando `fainted?` (`hp_max>0 && hp_current==0`), `views/team.erb` desabilita o botão "Remover do time" com tooltip, `DELETE /team` devolve `false+notice` de erro, e `TeamService#reset` (`POST /journey/restart`) ignora a regra e limpa mesmo com todos fainted.

## 2. Contexto (estado atual — diagnóstico)

- **Baseline pós-0062:** suíte 889/3279 lint 0, `SESSIONS.md`/`check_docs` ok. 0062 entregou RESP-1 P2 maximal (aspas+nav 44px+body 8px+calc+badge `Time n/6` via `before+OOB nav-badge`, reindex transacional). Roadmap Onda 2 Economia (0064 vida zerada → 0065 death spiral → 0066 pool oponente → 0067 pedras+modais → 0068 resolver batalha → 0063 juice), Onda 3 Estabilidade (0069→0072). `SESSIONS.md:371` "Depois da 0062: Onda 2 Economia (0064 vida zerada → 0065 death spiral → ...)" — a critério do usuário.
- **Regra pedida (playtest):** remover vida zerada hoje é permitido (`TeamService#remove_member` em `lib/team_service.rb:66-72` só verifica `member` existindo, depois `restore_items` + `@team.remove`, sem checar HP; `views/team.erb:50-61` botão "Remover do time" sempre habilitado; `server.rb:614` `remove_team_member` chama `settings.team_strategy.remove_member` sem ler retorno). Economia pede travar a remoção para evitar contornar custo/cura — fainted deve ser curado antes de sair (Poke Center), exceto no `reset` de jornada.
- **HP hoje:** `lib/pokemon.rb:22-24` tem `usable_hp? = hp_max<=0 || hp_current>0` (nunca lutou → `hp_max==0` é usable); não há `fainted?`/`alive?` em `Pokemon` — só em `lib/battle_pokemon.rb:88-90` (`alive? = hp_current.positive?`, `fainted? = !alive?`). `lib/journey_service.rb` usa `usable_hp?` em `battle_ready?`/`game_over?` (via `any?(&:usable_hp?)`); `lib/team_repository.rb:225` hidrata `hp_max`/`hp_current` do DB. Fainted precisa ser extraído em `Pokemon` alinhado a `BattlePokemon`.
- **O que muda:** bloquear no **service** (único ponto), extrair `fainted?`+`alive?` em `Pokemon`, view desabilita com `title`, rota lê `false` e seta `@notice/@notice_kind=:error`, `reset` já usa `@team.clear` direto e ignora a regra.
- **Arquivos atuais:** `lib/pokemon.rb` (`usable_hp?`), `lib/team_service.rb:66-72` (`remove_member`) + `74-77` (`reset` via `@team.clear`), `views/team.erb:50-61` form `hx-delete`, `server.rb:614-618` `remove_team_member` + `704-718` `restart_journey`/`render_restart_fragment`, `lib/battle_pokemon.rb:85-90` (`alive?`/`fainted?`).
- **Preservar:** `TeamRepository` burro (sem regra), `usable_hp?` existente, `game_over?`/`battle_ready?`, `oob_pokemon_list` condicional 0059, `oob_nav_badge`, `TeamBudget`/`poke-cost`, paginação 36, `ConnectionRegistry.release_current_thread!`, suíte/lint verdes.

## 3. Escopo

### Produção

- `lib/pokemon.rb` — extrair `Pokemon#fainted?` e `Pokemon#alive?` alinhados a `BattlePokemon#fainted?` (`lib/battle_pokemon.rb:88`). Definição fechada: `fainted? = hp_max.to_i>0 && hp_current.to_i==0 ; alive? = !fainted?` (inclui `hp_max==0` como `alive?`, coerente com `usable_hp?` — nunca lutou nunca é fainted). Documentar no método.
- `lib/team_service.rb:66-72` — `remove_member` passa a **bloquear fainted**: `return false` (ou `false + notice` via retorno composto — ver D8) quando `member.fainted?`; sem tocar `TeamRepository` (burro) nem `reset` (`74-77` já faz `@team.all.each restore + @team.clear` direto, ignora guarda).
- `views/team.erb:50-61` — botão "Remover do time" quando `poke.fainted?` fica `disabled` + `title="Pokémon derrotado — cure antes de remover"` (D6 A). Sem mudar `hx-delete`/`hx-target`/`hx-include`/`hx-params`/`hx-sync`/`hx-indicator`/`hx-disabled-elt`.
- `server.rb:614-618` — `remove_team_member` lê retorno de `settings.team_strategy.remove_member`; quando `false` seta `@notice = "Pokémon derrotado — cure antes de remover"` + `@notice_kind = :error` e devolve `render_team_fragment_with_notice + oob_pokemon_list + oob_nav_badge` sem remover (D8 A). Quando `true`/truthy, segue fluxo atual (`invalidate` + `render_team_fragment_with_notice + oob`s). `restart_journey` (`704-718`) intocado — `reset` ignora bloqueio (D7 A).
- Sem tocar `lib/team_repository.rb` (fora do escopo — burro), `db/schema.sql`/`db/migrations/*`, `Gemfile*`, `lib/battle_pokemon.rb` (só referência), `lib/journey_service.rb`/`lib/heal_service.rb`/`lib/mart_service.rb`.

### Testes

- `test/team_service_test.rb` **novo/estendido** — `FaintedRemoveTest`:
  - **C1** `test_remove_fainted_returns_false` — `remove_member` com `hp_current==0 && hp_max>0` não remove e devolve `false` + aviso (sem `restore_items` extra quando bloqueado, time intacto).
  - **C2** adaptado — `remove_member` com `hp_current>0` ou `hp_max==0` remove normal + devolve itens (`assigned_item`/`held_item` ao estoque) — reaproveita existentes adaptados.
- `test/team_routes_test.rb` **estendido** — `DELETE /team` via htmx (`HX-Request: true` + `.list-state`) com poke fainted não remove, time permanece, resposta traz `@notice` erro + OOBs (`#team-view` + `#pokemon-list` condicional + `nav-badge`):
  - **C3** `test_delete_fainted_blocked` — time `6→6` (não `6→5`), `assert_includes body, "Pokémon derrotado"` + `notice--error`.
  - **C4** `assert body` — botão Remover fica `disabled` + `title="Pokémon derrotado — cure antes de remover"` quando `fainted?` (file-read ou `GET /` fragmento).
  - **C5** `test_restart_clears_fainted_team` — `POST /journey/restart` com todos `fainted?` limpa `6→0` + devolve `assigned_item`/`held_item` ao estoque + `WalletRepository#set` → saldo 200 + `redirect "/"` ou fragmento `hx` com `oob_pokemon_list` + `oob_nav_badge` + notice `info`.
- `test/journey_service_test.rb` + `test/battle_routes_test.rb` — **C6** `game_over?` + gate de batalha validado: `game_over` com time todo `fainted?` + sem saldo bloqueia `GET /battle`/`POST /battle/new` (mensagem game over), mas `restart` libera (`battle_ready?` após `reset` com time vazio → `started? false`, mas novo time `6` libera). Manual opcional para CDP.
- **C7** sem regressão — reaproveita `test/team_routes_test.rb` Q5 suite (OOB condicional `starters_visible?` + `reindex` transacional): `DELETE` fainted não quebra OOB (`#pokemon-list` só quando `starters_visible?`) nem reindex (slots `1..5` intactos quando bloqueado, `1..6` quando permitido).

### Fora de escopo (não abrir)

- **Death spiral / heal trap** (curar com saldo 0) — fica para **0065** (Onda 2 #2), ver D9 A.
- **Venda/cura de fainted, batalha, `held_item` em batalha** — não tocar `lib/battle_engine.rb`/`lib/heal_service.rb`/`lib/mart_service.rb` além do `reset` já existente.
- **Migração de schema** — sem `ADD COLUMN`/nova coluna (HP já persistido em `team_pokemon_progress`/`team` via `hp_max`/`hp_current`); D5 C é só método em `Pokemon`.
- **`TeamRepository` com regra** — preterido: repo burro (D4 A), guarda só no `TeamService#remove_member`.
- **Const nova para BUDGET/custo/S_limit** — não tocar `lib/team_budget.rb`/`WalletRepository`/`TeamRepository::MAX_TEAM_SIZE`.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 remove fainted bloqueado (service):** `TeamService#remove_member` com `hp_current==0 && hp_max>0` **não remove** e devolve `false` + aviso "Pokémon derrotado — cure antes de remover" (time `6→6`, sem `restore_items` duplicado quando bloqueado). — prova: `test/team_service_test.rb` `FaintedRemoveTest#test_remove_fainted_returns_false` (stub `TeamRepository` + `InventoryRepository` + `@team.all` com `Pokemon.new(hp_max: 10, hp_current: 0)`).
- [ ] **C2 remove normal preservado:** `remove_member` com `hp_current>0` ou `hp_max==0` (nunca lutou) **remove** normal (`6→5`) + devolve `assigned_item`/`held_item` ao estoque via `restore_items` + `@team.remove` truthy. — prova: `test/team_service_test.rb` existentes adaptados (`test_remove_member_restores_items` / `test_remove_member_with_usable_hp_succeeds`).
- [ ] **C3 DELETE htmx bloqueado:** `DELETE /team` via htmx (`HX-Request: true` + `id` + `.list-state`) com poke fainted **não remove**, time permanece `6→6`, resposta traz fragmentos `#team-view` + `oob_pokemon_list` (condicional `starters_visible?`) + `oob_nav_badge` + `@notice` erro `notice--error` com texto "Pokémon derrotado — cure antes de remover". — prova: `test/team_routes_test.rb` `test_delete_fainted_blocked` (`Rack::Test` com `header "HX-Request" => "true"`, `current_user` stubado, `TeamRepository` com `hp_max:10 hp_current:0`).
- [ ] **C4 botão disabled+tooltip (view):** `views/team.erb` renderiza botão "Remover do time" com `disabled` + `title="Pokémon derrotado — cure antes de remover"` quando `poke.fainted?`, e habilitado sem `disabled`/`title` quando `!fainted?`. — prova: `test/team_routes_test.rb` `assert_match /disabled/` + `assert_match /title="Pokémon derrotado — cure antes de remover"/` no body do `GET /` ou fragmento `#team-view` (file-read `views/team.erb` também contém `fainted?` + `disabled` + `title`).
- [ ] **C5 reset limpa mesmo fainted (bypass):** `POST /journey/restart` (`TeamService#reset` via `settings.team_strategy.reset` + `WalletRepository#set` 200) **limpa mesmo com todos fainted** (`6→0`) + devolve `assigned_item`/`held_item` ao estoque + saldo 200 + resposta com `oob_pokemon_list` (quando `list_state_present?`) + `oob_nav_badge` + notice `info` "Jornada recomeçada. Monte seu time inicial de 6 Pokémon." — prova: `test/team_routes_test.rb` `test_restart_clears_fainted_team` (`post "/journey/restart", {}, { "HTTP_HX_REQUEST" => "true" }` com `hp_current:0` + `hp_max>0` em todos).
- [ ] **C6 game_over/recomeço validado:** `game_over?` (`JourneyService` via `!battle_ready?` + `!affordable_heal?`) com time todo `fainted?` + saldo < custo cura bloqueia `GET /battle`/`POST /battle/new` (gate `game_over_fragment`), mas `POST /journey/restart` libera (time vazio + saldo 200 permite nova montagem `6` → `started?`/`battle_ready?`). — prova: `test/journey_service_test.rb` `game_over?` + `test/battle_routes_test.rb` gate (`manual` opcional para CDP de tela cheia).
- [ ] **C7 sem regressão OOB/reindex:** OOB `#pokemon-list` condicional `starters_visible?` (`q.empty? && offset.zero? && !filter_active? && !sort_active?`) preservado após `DELETE` fainted (só com OOB quando visível, sem varrer starters quando filtrado) e reindex transacional de `TeamRepository#remove` preservado (`1..5` quando permitido, `1..6` intacto quando bloqueado). — prova: reaproveita `test/team_routes_test.rb` Q5 suite (0059 — `test_oob_conditional_skips_starters_when_filtered_or_paginated` + `test_oob_includes_starters_when_visible` + `test_remove_first_slot_reindexes_to_one`).

### Garantias — teste que prova (S1)

| Critério | Teste que prova | Manual |
| --- | --- | --- |
| C1 (remove fainted bloqueado) | `test/team_service_test.rb` `FaintedRemoveTest#test_remove_fainted_returns_false` (`hp_max>0 && hp_current==0` → `false`, time `6→6`) | — |
| C2 (remove normal preservado) | `test/team_service_test.rb` existentes adaptados (`hp_current>0` ou `hp_max==0` → remove `6→5` + `restore_items`) | — |
| C3 (DELETE htmx bloqueado) | `test/team_routes_test.rb` `test_delete_fainted_blocked` (`DELETE /team` htmx fainted → `6→6` + `@notice` erro + OOBs) | — |
| C4 (botão disabled+title) | `test/team_routes_test.rb` (`GET /` body contém `disabled` + `title="Pokémon derrotado — cure antes de remover"` quando `fainted?`) | — |
| C5 (reset limpa fainted) | `test/team_routes_test.rb` `test_restart_clears_fainted_team` (`POST /journey/restart` htmx + fainted `6→0` + saldo 200 + OOBs) | — |
| C6 (game_over/recomeço) | `test/journey_service_test.rb` `game_over?` + `test/battle_routes_test.rb` gate (bloqueia batalha quando todo fainted + sem saldo) | `manual` opcional CDP 375/768/1024: tela de fim + gate + restart |
| C7 (OOB/reindex sem regressão) | `test/team_routes_test.rb` Q5 suite (`oob_conditional_*` + `test_remove_first_slot_reindexes_to_one`) | — |
| G1 (suíte+lint) | `./scripts/test` suíte completa + `./scripts/lint` 0 em todo green; commits por passo | — |
| G2 (sem migração/TRepository) | `git diff -- db/` vazio + `grep -rn "fainted" lib/team_repository.rb` vazio + `TeamRepository` sem regra | — |
| G3 (S4/S5) | `./scripts/check_docs` + `./scripts/checar-sessao 0064` + `SESSIONS.md` atualizado no refinamento | — |

- [ ] **G1:** suíte completa verde com baseline **889/3279** preservado + novos testes (C1–C5) e lint 0 em todo green; commit obrigatório por passo; 0 regressão fora do escopo (adds/batalha/UX-2b/M2b seguem verdes via fakes).
- [ ] **G2:** sem `db/migrations` nova / sem `TeamRepository` com regra / sem gems novas / sem rede em testes além de `PokeApiStub` quando necessário; `fainted?`/`alive?` só em `lib/pokemon.rb` + uso em `lib/team_service.rb` + `views/team.erb`.
- [ ] **G3:** `SESSIONS.md` atualizado no commit do refinamento (S4) — tabela + "Próxima sessão" — e `REQUIREMENTS.md` se tocar doc; status de validação só após usuário validar (fase 3 — parar na fase 2 e aguardar).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste → `manual` explícito + evidência esperada (ver C6). Baseline suíte 889/3279 de 0062. **Parar ao fim da fase 2 e aguardar validação do usuário (fase 3) — não marcar Done, não preencher a seção 7, não commitar conclusão.**

## 5. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Parar ao fim da fase 2 e aguardar validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (tabela + "Próxima sessão") | commit `Sessao 0064: refinamento concluido — vida-zerada-nao-remove (regra fainted bloqueia remocao)` |
| 1 | **red→green — C1+C2 helper `fainted?`+`alive?` + service guarda** — `lib/pokemon.rb` `fainted? = hp_max.to_i>0 && hp_current.to_i==0` + `alive? = !fainted?` (doc inclui `hp_max==0→alive`) + `lib/team_service.rb#remove_member` bloqueia `fainted?` (`return false` + notice via retorno ou `@notice` — D8 A `false+notice error` na rota) + `test/team_service_test.rb` (`FaintedRemoveTest#test_remove_fainted_returns_false` + adaptados `hp_max==0`/`hp_current>0` removem) | `./scripts/test test/team_service_test.rb -n /FaintedRemoveTest|test_remove_fainted_returns_false/` + suíte + `./scripts/lint` 0; commit `Passo 1: Pokemon#fainted?+alive? e TeamService#remove_member bloqueia fainted` |
| 2 | **red→green — C4 view disabled+title** — `views/team.erb` botão "Remover do time" com `disabled` + `title="Pokémon derrotado — cure antes de remover"` quando `poke.fainted?` + `test/team_routes_test.rb` assert body (`disabled` + `title`) | `./scripts/test test/team_routes_test.rb -n /test_delete_fainted_blocked|disabled|title/` + suíte + lint 0; commit `Passo 2: team.erb desabilita Remover quando fainted (disabled+title)` |
| 3 | **red→green — C3 rota DELETE notice error** — `server.rb:614-618` `remove_team_member` lê `false` de `settings.team_strategy.remove_member` → `@notice="Pokémon derrotado — cure antes de remover"` + `@notice_kind=:error` + `render_team_fragment_with_notice + oob_pokemon_list + oob_nav_badge` sem `invalidate` quando bloqueado (ou com `invalidate` idempotente) + `test/team_routes_test.rb` `test_delete_fainted_blocked` (`6→6` + `notice--error`) | `./scripts/test test/team_routes_test.rb -n /test_delete_fainted_blocked/` + suíte + lint 0; commit `Passo 3: DELETE /team bloqueia fainted com notice error` |
| 4 | **red→green — C5 reset bypass** — `lib/team_service.rb#reset` já `@team.clear` direto (D7 A ignora regra) + `server.rb:704-718` `restart_journey`/`render_restart_fragment` preservados + `test/team_routes_test.rb` `test_restart_clears_fainted_team` (`POST /journey/restart` htmx `6 fainted →0` + saldo 200 + OOBs) | `./scripts/test test/team_routes_test.rb -n /test_restart_clears_fainted_team/` + suíte + lint 0; commit `Passo 4: POST /journey/restart limpa mesmo com todos fainted` |
| 5 | **red→green — C6 game_over/recomeço + C7 OOB/reindex sem regressão** — validar `JourneyService#game_over?` (`battle_ready?` via `usable_hp?` + `affordable_heal?`) + gate `GET /battle`/`POST /battle/new` (`game_over_fragment`/`defeated_gate_fragment`) bloqueia batalha quando todo fainted + sem saldo, mas `restart` libera; reaproveitar Q5 suite OOB condicional (`starters_visible?`) + reindex transacional (`lib/team_repository.rb:188` já `transaction`) quando bloqueado vs permitido | `./scripts/test test/journey_service_test.rb test/battle_routes_test.rb test/team_routes_test.rb -n /game_over|battle_ready|defeated_gate|oob_conditional|reindexes_to_one/` + suíte completa + lint 0; commit `Passo 5: game_over/recomeco validado e OOB/reindex sem regressao` |
| — | **Fase 2 concluída** → **Revisor (2c)**: loop Implementador↔Revisor até veredito `Aprovado` (teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar Done, não preencher a seção 7, não commitar conclusão. | — |

## 6. Decisões de refinamento (fechadas com o usuário em 2026-08-28)

- **D1 — Objetivo/slug A (vida-zerada-nao-remove):** nome da sessão derivado da regra "vida zerada não remove". **A escolhida:** `vida-zerada-nao-remove` (kebab, curto, estável — `sessions/0064-vida-zerada-nao-remove.md`). **B/C preteridas:** slugs com `fainted`/`bloqueio-remocao` — preteridos por serem anglicismo/técnico vs pt-BR do jogo. Motivo: slug reflete o objetivo em 1 frase (bloquear remoção de fainted) e alinha com Onda 2 Economia #1.
- **D2 — Escopo A (Service+view+rota):** produção = `TeamService#remove_member` bloqueia fainted + `TeamService#reset` ignora bloqueio (`@team.clear` direto) + `views/team.erb` `disabled+title` + rota `DELETE /team` com `@notice/@notice_kind=:error`; fora = death spiral, venda/cura, batalha, migração, `TeamRepository`. **A escolhida:** Service+view+rota (P, 6 passos). **B preterida:** Service só (sem view/rota — deixa UX sem feedback). **C preterida:** Service+repo+migração (repo burro quebrado). Motivo: guarda no service já cobre `DELETE` htmx + view desabilita; `reset` já bypassa; sem migração.
- **D3 — Critérios S1 A (Manter os 7):** C1 fainted bloqueado service, C2 remove normal, C3 DELETE htmx bloqueado, C4 botão `disabled+title`, C5 `reset` limpa fainted, C6 `game_over`+recomeço, C7 OOB/reindex sem regressão. **A escolhida:** manter os 7 (cobertura `fainted` de ponta a ponta sem abrir death spiral). **B preterida:** reduzir para 4 (perde `reset`+`game_over`+OOB). Motivo: 7 cabem em P sem abrir 0065; C6/C7 são garantias de Onda 2 já existentes.
- **D4 — Onde bloquear A (Só service):** `TeamService#remove_member` é o único guarda; `TeamRepository` burro (só `DELETE`/`UPDATE slot-1`); rota lê retorno `false`. **A escolhida:** só service. **B preterida:** repo também bloqueia (duplica regra, quebra `TeamRepository` burro e `reset` via `@team.clear` teria que contornar). Motivo: `TeamRepository` já é burro e `remove_member` é o único caller via `server.rb:614` (`settings.team_strategy.remove_member`).
- **D5 — Detectar fainted C (fainted?+alive?):** extrair ambos em `Pokemon` (`Pokemon#fainted?` e `Pokemon#alive?`), alinhado a `BattlePokemon#fainted?` (`lib/battle_pokemon.rb:88` `fainted? = !alive?` / `alive? = hp_current.positive?`). Definição: `fainted? = hp_max.to_i>0 && hp_current.to_i==0 ; alive? = !fainted?` (inclui `hp_max==0` como `alive?`, coerente com `usable_hp?` `hp_max<=0 || hp_current>0` — nunca lutou nunca é fainted). **A preterida:** só `fainted?`. **B preterida:** usar `usable_hp?` direto (inverte semântica). **C escolhida:** ambos + doc. Motivo: `Pokemon` espelha `BattlePokemon` e `alive?` é útil para view/gate sem negar `fainted?` toda vez.
- **D6 — UI A (disabled+title):** botão "Remover do time" com `disabled` + `title="Pokémon derrotado — cure antes de remover"` quando `fainted?`. **A escolhida:** `disabled+title` (sem `hx-disabled-elt` extra — `disabled` nativo já bloqueia htmx). **B preterida:** esconder botão (perde affordance). **C preterida:** `hx-confirm` (confirma mas ainda permite remover). Motivo: barato, acessível, reversível (cura reabilita).
- **D7 — Reset bypass A (Ignora regra):** `TeamService#reset` (`lib/team_service.rb:74-77`) já faz `@team.all.each restore + @team.clear(user_id)` direto, sem passar por `remove_member` — ignora guarda. **A escolhida:** ignora regra (já existe). **B preterida:** `reset` também bloqueia fainted (inviabiliza recomeço quando todo fainted + sem saldo). Motivo: `POST /journey/restart` é o escape de game over (0065 death spiral fica p/ 0065).
- **D8 — Mensagem A (false+notice error):** `TeamService#remove_member` retorna `false` quando bloqueia (+ `notice` via rota); `server.rb#remove_team_member` seta `@notice="Pokémon derrotado — cure antes de remover"` + `@notice_kind=:error` e devolve fragmento sem remover. **A escolhida:** `false+notice error` na rota. **B preterida:** `raise`/`throw` (exceção para controle de fluxo). Motivo: `remove_member` já retorna `false` quando `member` não existe (`lib/team_service.rb:68` `return false unless member`); reaproveita contrato.
- **D9 — Contenção A (Sim, conter):** P, 6 passos, death spiral/venda/cura/batalha/migração ficam para **0065** (Onda 2 #2). **A escolhida:** conter. **B preterida:** incluir death spiral agora (vira M/P grande, mistura 0064+0065). Motivo: 0064 é só "não remove fainted"; 0065 é "heal trap/death spiral" (cura com saldo 0).

> **Grafo obrigatório (tier Scout):** `search_graph query="TeamService Pokemon" limit 10` → `TeamService.remove_member lib/team_service.rb:66-72` + `TeamService.reset 74-77`; `search_graph query="Pokemon class hp_current fainted"` → `BattlePokemon.fainted? lib/battle_pokemon.rb:88-90` + `Pokemon.usable_hp? lib/pokemon.rb:22-24`; `get_code_snippet` de `TeamService.remove_member`/`TeamService.reset`/`BattlePokemon.fainted?`/`Pokemon.usable_hp?`; `check_index_coverage` em `lib/pokemon.rb`/`lib/team_service.rb`/`lib/battle_pokemon.rb`/`views/team.erb`/`server.rb` → `no_recorded_issue` (best-effort, sem `parse_partial`).

## 7. Validação (executada pelo usuário — S2)

> Validado pelo usuário em 2026-08-28. Suíte 906/3367 lint 0, revisor Aprovado sem S3.

| Critério | Evidência automatizada | Evidência manual | Resultado |
| --- | --- | --- | --- |
| C1 (remove fainted bloqueado) | `test/team_service_test.rb` `FaintedRemoveTest#test_remove_fainted_returns_false` — `hp_max 10 hp_current 0 → false`, time 6→6, sem restore | — | ok |
| C2 (remove normal preservado) | `test/team_service_test.rb` `test_remove_with_usable_hp_succeeds` + `test_remove_never_fought_hp_max_zero_succeeds` — remove 6→5 + restore | — | ok |
| C3 (DELETE htmx bloqueado) | `test/team_fainted_routes_test.rb` `test_delete_fainted_blocked` — DELETE htmx 6→6 + `notice--error` "Pokémon derrotado" + OOBs | — | ok |
| C4 (botão disabled+title) | `test/team_fainted_routes_test.rb` `test_team_view_disables_remove_when_fainted` — body contém `disabled` + `title="Pokémon derrotado — cure antes de remover"` | — | ok |
| C5 (reset limpa fainted) | `test/team_fainted_routes_test.rb` `test_restart_clears_fainted_team` + `test/team_service_test.rb` `test_reset_clears_even_when_all_fainted` — 6→0 + saldo 200 + OOBs | — | ok |
| C6 (game_over/recomeço) | `test/journey_service_test.rb` `game_over?` + `test/battle_routes_test.rb` gate (todo fainted + sem saldo bloqueia battle) | `manual` opcional CDP 375/768/1024 conferido | ok |
| C7 (OOB/reindex sem regressão) | `test/team_fainted_routes_test.rb` `test_delete_fainted_blocked_does_not_break_oob_when_filtered` + `test_remove_fainted_does_not_reindex_slots` + Q5 suite `oob_conditional_*`/`reindexes_to_one` verde | — | ok |
| G1 (suíte+lint) | `./scripts/test` 906/3367 0F + `./scripts/lint` 0 em 117 files | — | ok |
| G2 (sem migração/TRepository) | `git diff -- db/` vazio + `grep fainted lib/team_repository.rb` vazio | — | ok |
| G3 (S4/S5) | `./scripts/check_docs` ok + `./scripts/checar-sessao 0064` ok + `SESSIONS.md` atualizado | — | ok |

> **S2:** um resultado por critério, nunca bloco único "todos atendidos". **S3:** sem ajuste — nenhum critério reaberto; se houver, registrar alteração com data e reaprovar.

## 8. Observações

- **Próxima após 0064:** Onda 2 Economia **0065 death spiral+game over** (heal trap), depois **0066 pool oponente → 0067 pedras+modais → 0068 resolver batalha → 0063 juice** a critério do usuário; Onda 3 Estabilidade (0069 race add → 0070 escritas atômicas → 0071 CSRF → 0072 respiro) permanece fila. Ver `SESSIONS.md:371` e `sessions/0062-resp1-quick-wins.md:153`.
- **Risco `fainted?` vs `usable_hp?`:** `Pokemon#alive? = !fainted?` inclui `hp_max==0` como alive (nunca lutou). `JourneyService#battle_ready?` usa `usable_hp?` (`hp_max<=0 || hp_current>0`) — coerente: nunca lutou é battle-ready. Se `fainted?` fosse `!usable_hp?` daria no mesmo, mas `fainted?` explícito (`hp_max>0 && hp_current==0`) é mais legível para view.
- **Risco `reset` bypass:** `TeamService#reset` faz `@team.all.each restore + @team.clear` em 2 chamadas — não transacional. Se `clear` falhar após `restore`, itens já devolvidos mas time não limpo. Aceito nesta P (fora de T2 escritas atômicas 0070).
- **Dependência 0062:** `oob_nav_badge` + `prepare_team_fragment_data @team_size` + `POST /journey/restart` OOBs já existem (0062 S3); 0064 só condiciona `DELETE` fainted sem quebrar OOBs quando permitido.

## 9. Gotchas / Lições (memória — S6)

- **Fainted vs usable_hp (0064):** `Pokemon#usable_hp?` (`hp_max<=0 || hp_current>0`) já trata `hp_max==0` como usable (nunca lutou). `fainted?` deve ser `hp_max>0 && hp_current==0` — não `!usable_hp?` invertido sem parens (embora equivalente, `fainted?` explícito evita `to_i` esquecido e `nil` em `hp_current`). `alive? = !fainted?` mantém `hp_max==0` como alive. Lição: extrair ambos em `Pokemon` espelhando `BattlePokemon` evita divergência view/service.

