# Sessão 0089 — limpeza-user-state-e2e: remover o estado morto `user_state` (drop + código vestigial) e reparar os 4 e2e

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-09-16 (D1–D7) |
| Implementação | **Pendente** |
| Validação | **Pendente** (executada pelo usuário) |

---

## 1. Objetivo

Dívida técnica em dois blocos numa única sessão (D1): **(A)** apagar o estado morto `user_state` — tabela, repositório de leitura morta, escrita vestigial e todo o scaffolding de teste — mantendo o gate da jornada **derivado do tamanho do time**; e **(B)** reparar os **4 e2e vermelhos** de `e2e/specs/battle-log.spec.ts` trocando o helper `buildTeamOfSix` pelo `buildBudgetTeam` já existente.

## 2. Contexto (estado atual — diagnóstico)

- **A tabela nasce só na migração**: `db/migrations/0036_add_user_state.sql:4-7` (`CREATE TABLE IF NOT EXISTS user_state (user_id TEXT PRIMARY KEY, journey_started BOOLEAN NOT NULL DEFAULT false)`, idempotente, sem truncate). **Não** está em `db/schema.sql` (que só cria `team_pokemons`). Hoje há **11** migrações em `db/migrations/`.
- **Escrita viva mas vestigial**: `server.rb:599` (`add_team_success`) → `lib/journey_service.rb:23-28` (`mark_started`/`mark_started_when_full`) → `UserStateRepository#mark_started` (`lib/user_state_repository.rb:21-27`). O `server.rb` também faz `require_relative "lib/user_state_repository"` (`:24`) e `set :user_state, UserStateRepository.new` (`:1445`, injetado em `:1447`).
- **Leitura morta**: `UserStateRepository#started?` (`lib/user_state_repository.rb:15-18`) tem **zero** chamadores de produção — só `test/user_state_repository_test.rb`. Nada lê `journey_started`.
- **O gate real fica** e é derivado do time: `lib/journey_service.rb:8` (`@team.all(user_id).size >= TeamRepository::MAX_TEAM_SIZE`, isto é `team >= 6`). Decisão da sessão **0052** (`REQUIREMENTS.md:638-643`): o gate re-fecha quando o time fica < 6 e a flag deixa de liberar — **vestigial, escrita preservada**. O consumidor de UI `@journey_started` (`server.rb:1041` → `views/team.erb:4`) já usa `journey.started?` derivado: **não muda**.
- **Dependências de teste da tabela**: `test/user_state_repository_test.rb` (arquivo inteiro), `test/test_helper.rb:84-86` (`TestDatabase.clear_user_state!`), `test/journey_service_test.rb:16` (chama `clear_user_state!`), `test/server_test_helpers.rb:16` (`clear_user_state!`) e `:24-26` (helper `start_journey`, hoje **no-op funcional** — escreve um flag que nada lê). `test/journey_service_test.rb` constrói `JourneyService` com `user_state:` em **3** sites (`:19`, `:128-129`, `:179-180`).
- **4 callers de `start_journey`** em `test/team_routes_test.rb:355,471,481,593` (testes `:354` `test_team_page_is_removed_and_returns_404_without_htmx`, `:470` `test_team_member_sprite_has_alt_text`, `:480` `test_team_slot_controls_have_aria_labels`, `:592` `test_team_heal_with_empty_team_does_not_break`).
- **2 testes vacuosos da flag** a remover: `test/journey_service_test.rb:42-53` (`JourneyStartedTest#test_flag_alone_does_not_liberate_with_empty_team` e `#test_flag_alone_does_not_liberate_below_six`) e a classe inteira `JourneyMarkWhenFullTest` (`:100-119`: `#test_mark_when_full_persists_flag_at_six_members`, `#test_mark_when_full_does_not_persist_below_six`) — provam o *persistido* que está sendo apagado.
- **`test/home_view_test.rb:86` é só um comentário** sobre o gate derivado ("5 membros: time incompleto (journey nao started?)") — **manter**.
- **Migrações rodam sem ledger**: `rake db:setup` (`Rakefile:16-24`) e `TestDatabase.setup!` (`test/test_helper.rb:45-53`) re-executam **`db/schema.sql` + todas** as migrações em ordem a cada execução, sem tabela de controle. A 0037 ordena depois da 0036 e é idempotente; **não** é destrutiva como o `TRUNCATE team_pokemons CASCADE` de `db/migrations/0003:4`/`0007:4` (nenhum teste pega esse perigo — `docs/draft-backlog.md:424`).
- **Docs que afirmam o contrário do que esta sessão faz**: `GDD.md:27` (onboarding "Persiste em `user_state`"), `REQUIREMENTS.md:638-643` (decisão da 0052: "escrita preservada"), `docs/draft-backlog.md:109` (item "Flag `user_state` vestigial — remover/redefinir papel"), `docs/5F-decisoes-pendentes.md:6-31,104` (§5.F.1 "apagar ou manter?" com as duas opções e o "Para fechar" item 1).
- **Itens futuros que citam `user_state` e ficam intocados**: `docs/draft-backlog.md:133` (**J4** — "identidade legível (apelido/nome) — ranking hoje exibe UUID cru; recomendado `nickname` em `user_state`") e `:344` (onboarding `GDD.md:31-33`, "nome+avatar persistidos em `user_state`"). Ambos são roadmap, **não** refinados — passam a exigir outro lar de persistência (registrado como dúvida em §8).
- **Os 4 e2e vermelhos**: usam `buildTeamOfSix` (`e2e/specs/battle-log.spec.ts:11-19`) em `:51,77,101,112`. **Causa raiz provada — bug do helper, não regressão de produto**: `nth(i)` é aplicado à lista **que encolhe** a cada add (a carta adicionada é re-rotulada "já está no time"), então clica as cartas 1,3,5,7,9,11 = bulbasaur, squirtle, cyndaquil, treecko, mudkip, **chimchar**; chimchar → infernape = linha **S** (120) → 350+120 = **470 > 450** e o 6º add é barrado (`#nav-badge` para em `5/6`). As 6 primeiras cartas de `STARTER_SLUGS` (`server.rb:94-104`) são todas linha **A** → 420 ≤ 450: **não há bug de produto** e reparar não esconde nada. O orçamento **450 não está stale**: fonte única `lib/team_budget.rb:8` (`server.rb:1031`).
- **O reparo já existe no arquivo**: `buildBudgetTeam` (`e2e/specs/battle-log.spec.ts:157-164`) clica por **nome exato** (`CHEAP_TEAM = caterpie, weedle, rattata, spearow, ekans, nidoran-f`, `:155`) e é imune ao encolhimento; é usado pelos 5 testes da 0088 (`:237,286,332,364,425`) que já passam.
- **e2e fora do CI e sem runner próprio**: `.github/workflows/ci.yml` só tem test/lint/check_docs; não existe `scripts/e2e`; `@playwright/test 1.63.0` instalado na raiz (`package.json:7`), Chrome presente (`channel: 'chrome'`, `e2e/playwright.config.ts:16`), **sem** bloco `webServer` → o app precisa estar no ar em `:3000` (está, via `./scripts/run`). Comando usado e verificado na 0088: `cd e2e && npx playwright test specs/battle-log.spec.ts` (roda a partir de `e2e/`, resolve o `node_modules` da raiz; `retries: 0`, `workers: 1`).
- **Status no draft**: `docs/5F-decisoes-pendentes.md:104` pede a decisão do usuário (item 1 `user_state`, item 2 os 4 e2e). As duas foram tomadas em **2026-09-16** (D2/D4) — esta sessão é a execução.

## 3. Escopo

### Produção

- **`db/migrations/0037_drop_user_state.sql`** (novo) — `DROP TABLE IF EXISTS user_state;` (D3). Idempotente: 2ª execução consecutiva de `rake db:setup`/`TestDatabase.setup!` é no-op silencioso (`IF EXISTS`), sem erro e sem tocar em `team_pokemons`/`wallet`/`inventory`/`battles`.
- **`db/migrations/0036_add_user_state.sql`** (removido) — a migração de **criação** sai (D3); a 0037 fica como o único statement sobre a tabela, cobrindo bancos onde a 0036 já rodou. Sem a 0036, um banco recém-criado nunca cria `user_state` e a 0037 vira no-op.
- **`lib/user_state_repository.rb`** (removido inteiro) — só tinha leitura morta (`started?`) e a escrita vestigial (`mark_started`).
- **`lib/journey_service.rb`** — sem o kwarg `user_state:` (`:4-5`) e sem `mark_started`/`mark_started_when_full` (`:23-28`); `started?`/`battle_ready?`/`game_over?`/`affordable_heal?` **intocados** (o gate segue `team >= 6`).
- **`server.rb`** — remove `require_relative "lib/user_state_repository"` (`:24`), a chamada `settings.journey.mark_started_when_full(current_user)` (`:599`) e o `set :user_state` + o kwarg (`:1445`, `:1447`). Os `settings.journey.started?` (`:734,743,750,995`) e `@journey_started` (`:1041`) **ficam**.
- **`views/team.erb:4`** — usa `@journey_started` derivado: **não muda** (fora de escopo por não ter nada a mudar).
- **Docs no mesmo commit da remoção (D7)** — `GDD.md:27`, `REQUIREMENTS.md:638-643`, `docs/draft-backlog.md:109` e `docs/5F-decisoes-pendentes.md` (§5.F.1 + "Para fechar" itens 1 e 2): anotar que a tabela/flag foi **removida na sessão 0089** em 2026-09-16 e que o gate é derivado de `team >= 6`. **Não** tocar `docs/draft-backlog.md:133` (J4) nem `:344` (onboarding).

### Testes

- **`test/user_state_removal_test.rb`** (novo) — guarda da remoção: (a) a tabela não existe após o setup (`SELECT to_regclass('user_state') IS NULL`); (b) `JourneyService` não expõe `mark_started`/`mark_started_when_full` e o `initialize` não aceita o kwarg `user_state:`; (c) a constante `UserStateRepository` não resolve. Red antes de cada remoção, green depois.
- **`test/user_state_repository_test.rb`** (removido inteiro — provava o repositório morto).
- **`test/test_helper.rb`** — remove `TestDatabase.clear_user_state!` (`:84-86`); `clear_team!`/`clear_all!` (que já truncam as demais tabelas em bloco, `:80-82`) **ficam**.
- **`test/journey_service_test.rb`** — remove `require_relative "../lib/user_state_repository"` (`:6`), a chamada `clear_user_state!` (`:16`), o kwarg `user_state:` nos 3 sites (`:19`, `:128-129`, `:179-180`), os 2 testes vacuosos (`:42-53`) e a classe `JourneyMarkWhenFullTest` (`:100-119`). Os **4 testes que provam o gate derivado ficam** como guarda de regressão: `JourneyStartedTest#test_not_started_with_empty_team_and_no_flag` (`:32`), `#test_team_of_six_derives_started_without_flag` (`:36`), `#test_team_size_liberates_even_without_flag` (`:55`) e `JourneyGameOverTest#test_not_game_over_below_team_of_six` (`:164`).
- **`test/server_test_helpers.rb`** — remove `clear_user_state!` (`:16`) e o helper `start_journey` (`:24-26`); mantém `fill_team` (`:28-30`), que é o caminho real de abrir o gate.
- **`test/team_routes_test.rb`** — remove as **4** chamadas `start_journey("user-a")` (`:355,471,481,593`); **nada mais** muda (o helper é no-op: escrevia um flag que nada lia).
- **`test/home_view_test.rb:86`** — comentário mantido (não é dependência).
- **`e2e/specs/battle-log.spec.ts`** — os 4 call sites de `buildTeamOfSix` (`:51,77,101,112`) passam a `buildBudgetTeam`; `buildTeamOfSix` (`:11-19`) fica órfão (file-local, 4 usos) e é **removido** (~10 linhas). Sem mudança de asserção.

### Fora de escopo (não abrir)

- **J4** (`docs/draft-backlog.md:133`) e **onboarding** (`:344`, `GDD.md:31-33`): itens futuros, **não** tocados — a anotação de que `user_state` deixou de existir fica só nos docs do D7.
- **Stub de PokeAPI/VCR** (D5): apenas **anotado e dimensionado** no draft; não refinado, não implementado.
- Remover `pry`, cache TTLs, `open-design/prints/`, `_ai_context/`, flake do `ConnectionRegistryTest`, e2e no CI, regenerar cassettes grandes: itens próprios, já no draft.
- Qualquer toque no motor, na economia, no budget 450, nas rotas ou no CSS.
- Regenerar/apagar cassettes (o `git status` atual já tem cassettes **não rastreados** de outras sessões — **não** entram neste commit).

## 4. Critérios de aceite

### Resultado (S1 — cada critério aponta o teste que o prova)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| C1 a tabela `user_state` não existe após o setup (nunca criada ou dropada pela 0037) | `test/user_state_removal_test.rb` (`test_user_state_removal_test.rb#test_user_state_table_is_gone_after_setup`, consulta `to_regclass('user_state') IS NULL`) | pendente |
| C2 `lib/user_state_repository.rb` removido e zero referência de produção a `UserState`/`user_state` | `manual` — `rg -n -e UserState -e user_state lib/ server.rb Rakefile db/ test/` deve sobrar só `db/migrations/0037_drop_user_state.sql` e `test/user_state_removal_test.rb` (evidência de grep registrada no commit/§7) + guarda estrutural `test/user_state_removal_test.rb#test_user_state_repository_constant_is_gone` | pendente |
| C3 `JourneyService` sem o kwarg `user_state:` e sem `mark_started`/`mark_started_when_full` | `test/user_state_removal_test.rb#test_journey_service_has_no_persisted_start_hooks` (inspeciona `JourneyService.instance_method(:initialize).parameters` e `instance_methods`) | pendente |
| C4 o gate da jornada continua **derivado do time** (`team >= 6`), sem estado persistido | guarda de regressão (4 verdes): `test/journey_service_test.rb#test_not_started_with_empty_team_and_no_flag` (`:32`), `#test_team_of_six_derives_started_without_flag` (`:36`), `#test_team_size_liberates_even_without_flag` (`:55`) + `JourneyGameOverTest#test_not_game_over_below_team_of_six` (`:164`) | pendente |
| C5 os 4 testes vaciosos do estado persistido foram removidos e a suíte total cai no número exato | `test/journey_service_test.rb` sem `test_flag_alone_does_not_liberate_with_empty_team` (`:42`), `test_flag_alone_does_not_liberate_below_six` (`:48`), `test_mark_when_full_persists_flag_at_six_members` (`:103`), `test_mark_when_full_does_not_persist_below_six` (`:113`) e sem `test/user_state_repository_test.rb` — prova: `./scripts/test` (contagem de runs da suíte = baseline − 4 − os testes do repo) e `test/user_state_removal_test.rb` verde | pendente |
| C6 nenhum teste depende de `start_journey`/`clear_user_state!`/`UserStateRepository` | `test/user_state_removal_test.rb#test_test_help_has_no_user_state_hooks` (checa que `TestDatabase` não responde a `clear_user_state!`) + `manual` — `rg -n -e start_journey -e clear_user_state -e UserStateRepository test/` = vazio; os 4 testes de `test/team_routes_test.rb` (`:354`, `:470`, `:480`, `:592`) seguem verdes | pendente |
| C7 os 4 e2e vermelhos passam com `buildBudgetTeam` | `e2e/specs/battle-log.spec.ts` — `round headers chronological with data-round and damage/KO chips` (`:50`), `reduced-motion disables juice` (`:76`), `auto toggle chains to finish without further clicks` (`:100`), `consumption and reward copy` (`:111`) | pendente |
| C8 docs sincronizados com a remoção no mesmo commit (GDD/REQUIREMENTS/draft/5F) | `manual` — revisão de diff de `GDD.md:27`, `REQUIREMENTS.md:638-643`, `docs/draft-backlog.md:109`, `docs/5F-decisoes-pendentes.md` (§5.F.1 + itens 1 e 2 de "Para fechar"); `./scripts/check_docs` verde | pendente |

> **C7 — duas possibilidades registradas:** se a execução local for viável na fase 2 (D6 autoriza; app no ar em `:3000`), C7 é **automatizado** pelo run de `cd e2e && npx playwright test specs/battle-log.spec.ts` (9 verdes / 0 vermelhos). Se inviável no momento do green, C7 vira `manual` — evidência esperada: rodada local do mesmo comando registrada na §7 com o resultado por teste.

### Garantias (RNF)

| Critério | Teste que o prova | Estado |
| --- | --- | --- |
| G1 suíte completa verde com baseline preservado + novos testes e lint 0 em todo green; commit obrigatório por passo | `./scripts/test` + `./scripts/lint` (cada passo) | pendente |
| G2 escopo contido: sem gems novas, sem mudança de schema além da 0037, sem rede nos testes, sem tocar motor/economia/rotas/CSS/budget 450 | `git diff --stat` + revisão de diff (`manual`) | pendente |
| G3 docs + revisão: `./scripts/check_docs` e `./scripts/checar-sessao 0089` verdes, docs do D7 no mesmo commit da remoção, Revisor (2c) `Aprovado` antes da fase 3 | `./scripts/check_docs` + `./scripts/checar-sessao 0089` + revisão de diff (`manual`) | pendente |

> **S1:** cada critério acima aponta o teste que o prova (arquivo + método Minitest); critério sem teste automatizado registra `manual` explícito com a evidência esperada. As fases 2–3 e a implementação de D5 **não** acontecem aqui: esta sessão entrega só o refinamento (fase 1).

## 5. Decisões de refinamento (fechadas com o usuário — 2026-09-16)

- **D1 — uma sessão só, dois blocos.** Limpeza do `user_state` (A) e reparo dos 4 e2e (B) ficam na mesma sessão 0089; alternativa preterida: duas sessões (0078/0079-style) — rejeitada por serem ambos ~pequenos e independentes.
- **D2 — apagar tudo do `user_state`** (tabela + repositório + escrita + scaffolding). Alternativa preterida: manter documentado "à espera do J4/onboarding". Razão: a leitura é morta há várias sessões (0052, 2026-08-25), a flag é vestigial por decisão formal, e J4/onboarding são itens futuros sem data — manter agora é carregar código morto.
- **D3 — apagar a migração de criação (`0036_add_user_state.sql`) e criar `0037_drop_user_state.sql`** com `DROP TABLE IF EXISTS`. A 0037 só é significativa em bancos onde a 0036 já rodou; mantê-la é o que torna a limpeza segura com o setup "sem ledger".
- **D4 — reparar os 4 e2e** (trocar o helper), não apagá-los. Razão: é a única cobertura e2e de round-headers/chips, reduced-motion, auto-chain e reward copy; e a falha é bug do helper `buildTeamOfSix`, não regressão (as 6 primeiras cartas de `STARTER_SLUGS` cabem em 450).
- **D5 — stub de PokeAPI/VCR: anotar e dimensionar, não refinar.** Vai para `docs/draft-backlog.md` como "anotado, não refinado" (regra do projeto: ideia não abre escopo). Dimensionamento apurado nesta fase 1: `PokeApiStub` (`test/test_helper.rb:227+`) já tem ~13 helpers (`with_gateway`, `with_find`, `with_detail`, `with_all_names`, `with_base_forms`, `with_moves_for`, `with_move`, `with_available_move_names`, `with_type`, `with_next_evolutions`, `with_stone_evolutions`, `with_learnable_moves`, `with_generation`, `with_pokemon_names_by_type`, `with_type_names`) e o fake (`test/poke_api_fake.rb:5-97`) cobre `find`/`detail`/`paginate`/`move`/`moves_for`/`available_move_names`/`next_evolutions`/`stone_evolutions`/`learnable_moves`/`base_form?`/`evolution_restricted?`/`generation_for`/`pokemon_names_by_type`; o gargalo real é a **adoção** (ex.: `test/team_routes_test.rb` sozinho tem ~50 usos de helpers misturados com hits reais) sobre **76** arquivos de teste e **43** cassettes, com `record: :new_episodes` (`test/vcr_setup.rb:13,27`), cassettes somando **341 MB** e o maior em **208 MB** (`test/cassettes/ServerTeamRemoveQ5Test/test_oob_conditional_skips_starters_when_filtered_or_paginated.yml`).
- **D6 — autorizado rodar e2e localmente** nesta limpeza (a fase 2 pode executar o Playwright); se o ambiente não permitir, C7 vira `manual` (registrado no C7).
- **D7 — docs sincronizados no mesmo commit da remoção**: `GDD.md:27` (onboarding), `REQUIREMENTS.md:638-643` (decisão da 0052), `docs/draft-backlog.md:109` (item da flag vestigial, que fica obsoleto) e `docs/5F-decisoes-pendentes.md` (§5.F.1 + "Para fechar" itens 1 e 2, que registram as escolhas (b) apagar e (a) reparar). `draft-backlog:133` (J4) e `:344` (onboarding) **não** são tocados.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit `Passo N: ...`. Bloco B (Passo 6) é isolado do Bloco A. Termina em Revisor (2c, S7, teto 3 rodadas) → **PARAR** para a validação do usuário (fase 3). Nada aqui roda suíte/lint/e2e na fase 1.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados + `SESSIONS.md` (S4) + anotação do D5 no draft | commit `Sessao 0089: refinamento concluido — ...` |
| 1 | **red→green — C1/D3**: novo `test/user_state_removal_test.rb` com `test_user_state_table_is_gone_after_setup` (**red**: a 0036 ainda cria a tabela) + criar `db/migrations/0037_drop_user_state.sql` (`DROP TABLE IF EXISTS user_state;`) | `./scripts/test test/user_state_removal_test.rb` (red → green) + lint 0; commit `Passo 1:` |
| 2 | **red→green — C2/C3/C6/C8/D7**: asserts estruturais no teste de remoção (**red**) + remover `lib/user_state_repository.rb`, `test/user_state_repository_test.rb`, o kwarg/`mark_started*` de `lib/journey_service.rb`, o wire de `server.rb` (`:24,599,1445,1447`), `clear_user_state!` de `test/test_helper.rb:84-86` + seu chamador em `test/journey_service_test.rb:16` e o kwarg nos 3 sites (`:19,128-129,179-180`); **docs do D7 no mesmo commit** | `./scripts/test` + lint 0; commit `Passo 2:` |
| 3 | **red→green — C5/C6**: remover o helper `start_journey` (`test/server_test_helpers.rb:24-26`) + as 4 chamadas (`test/team_routes_test.rb:355,471,481,593`) + os 2 testes vacuosos da flag (`test/journey_service_test.rb:42-53`) + a classe `JourneyMarkWhenFullTest` (`:100-119`) | `./scripts/test test/journey_service_test.rb test/team_routes_test.rb` + lint 0; commit `Passo 3:` |
| 4 | **red→green — C1/G2**: apagar a migração de criação `db/migrations/0036_add_user_state.sql` (D3) e provar a idempotência — 2 execuções consecutivas de `rake db:setup` (ou `TestDatabase.setup!`) sem erro e com `user_state` ausente nas duas | `rake db:setup` 2× + `./scripts/test test/user_state_removal_test.rb` + `./scripts/test test/schema_test.rb` (se aplicável) + lint 0; commit `Passo 4:` |
| 5 | **green — C4/G1/G3 (verificação final do Bloco A)**: suíte completa + lint 0 + `check_docs` + grep manual do C2; confirmar os 4 testes do gate derivado verdes (C4) e o baseline de runs ajustado (C5) | `./scripts/test` + `./scripts/lint` + `./scripts/check_docs` + `rg -n -e UserState -e user_state lib/ server.rb db/ test/`; commit `Passo 5:` |
| 6 | **Bloco B, isolado — red→green — C7/D4**: os 4 call sites (`e2e/specs/battle-log.spec.ts:51,77,101,112`) passam a `buildBudgetTeam`; `buildTeamOfSix` (`:11-19`) é removido; nenhuma asserção muda | `cd e2e && npx playwright test specs/battle-log.spec.ts` (9 verdes / 0 vermelhos; se inviável → C7 `manual`) + lint 0; commit `Passo 6:` |
| — | **Fase 2 concluída** → **Revisor (2c)**: loop Implementador↔Revisor até veredito `Aprovado` (teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3). | — |

## 7. Validação (executada pelo usuário)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 | `./scripts/test test/user_state_removal_test.rb -n /table_is_gone/` | — | |
| C2 | `./scripts/test test/user_state_removal_test.rb -n /repository_constant_is_gone/` | `rg -n -e UserState -e user_state lib/ server.rb db/ test/` só com a 0037 e o teste de remoção | |
| C3 | `./scripts/test test/user_state_removal_test.rb -n /no_persisted_start_hooks/` | — | |
| C4 | `./scripts/test test/journey_service_test.rb` (4 testes do gate derivado, `:32`,`:36`,`:55`,`:164`) | abrir o gate só com 6 membros no navegador | |
| C5 | `./scripts/test` (runs do baseline − 4 − os do repo morto) | — | |
| C6 | `./scripts/test test/team_routes_test.rb` + `./scripts/test test/user_state_removal_test.rb -n /no_user_state_hooks/` | `rg -n -e start_journey -e clear_user_state -e UserStateRepository test/` = vazio | |
| C7 | `cd e2e && npx playwright test specs/battle-log.spec.ts` (4 testes, 9 verdes no arquivo) | rodar o mesmo comando se a execução automática for inviável | |
| C8 | `./scripts/check_docs` | revisar o diff de `GDD.md:27`, `REQUIREMENTS.md:638-643`, `docs/draft-backlog.md:109`, `docs/5F-decisoes-pendentes.md` | |
| G1 | `./scripts/test` + `./scripts/lint` | — | |
| G2 | `git diff --stat` | revisar diff por gems/schema/motor/economia/budget/CSS | |
| G3 | `./scripts/check_docs` + `./scripts/checar-sessao 0089` | revisão `Aprovado` na 2c | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.

## 8. Observações

- **D5 anotado, não refinado:** a anotação do stub de PokeAPI/VCR entra em `docs/draft-backlog.md` §2 (Arquitetura / Infra / Performance, junto ao item de cassettes que já vive lá) **com dimensionamento** e a marca "anotado, não refinado" — não gera critério nem passo. Correção de premissa registrada na própria anotação: o `PokeApiStub` **não** tem só `with_gateway/with_find/with_detail` — já tem ~13 helpers; o gargalo é adoção + o `:new_episodes` acumulando episódios.
- **Dúvida aberta (J4/onboarding sem lar):** `docs/draft-backlog.md:133` (J4) recomendava `nickname` **em `user_state`**, que deixa de existir; o onboarding (`:344`, `GDD.md:27`) também persistia nome+avatar lá. Ambos são itens futuros e **não** foram tocados (D7) — a próxima sessão que os refinar precisa escolher outro lar de persistência (nova tabela `profiles`/`journey_state`, ou o próprio `wallet`/`team`-adjacent). Fica registrado aqui e na anotação do draft, sem abrir escopo.
- **Riscos a vigiar — migração:** (a) o setup re-executa **todas** as migrações sem ledger (`Rakefile:16-24`, `test/test_helper.rb:45-53`), então a 0037 precisa ser idempotente (`IF EXISTS`) e ordenar depois da 0036 — se alguém rodar o setup num banco que **nunca** teve a 0036, a 0037 é no-op; se já teve, dropa. (b) A 0037 **não** é destrutiva como `0003:4`/`0007:4` (`TRUNCATE team_pokemons CASCADE`): não toca em nenhuma outra tabela. (c) Apagar a 0036 é irreversível no histórico do repo — o rollback é recriar a tabela, e nada em produção a lê.
- **Riscos a vigiar — testes que dependem da tabela:** `TRUNCATE user_state` em `clear_user_state!` **explode** depois da 0037 (tabela inexistente) → o Passo 2 precisa remover o helper e **todos** os chamadores no mesmo commit (`test/test_helper.rb:84-86`, `test/server_test_helpers.rb:16`, `test/journey_service_test.rb:16`); deixar qualquer um para trás derruba a suíte inteira com `PG::UndefinedTable`. O `clear_all!` (que trunca as outras 5 tabelas em bloco, `:80-82`) **não** menciona `user_state` e fica.
- **Riscos a vigiar — e2e dependente de budget:** o reparo **não** pode tocar em `TeamBudget::BUDGET` (`lib/team_budget.rb:8`) nem na composição de `STARTER_SLUGS` (`server.rb:94-104`) — 450 está correto e o `CHEAP_TEAM` de `buildBudgetTeam` já cabe; se o seed do orçamento das cartas mudar no futuro, esses 9 testes voltam a ser os primeiros a quebrar. `buildBudgetTeam` depende do **nome exato** da carta no botão (`Adicionar <slug> ao time`) — renomear a copy do botão quebra o helper (e a suíte inteira do arquivo).
- **Riscos a vigiar — cassettes:** `test/cassettes` soma **341 MB** e o maior cassette é **208 MB**; `record: :new_episodes` (`test/vcr_setup.rb:13,27`) faz cada run **crescer** os arquivos já versionados. Há cassettes **não rastreados** no working tree de outras sessões — **não** entram neste commit nem em nenhum passo. Nada nesta sessão toca em `test/vcr_setup.rb`.
- **Não editar nesta sessão:** `docs/draft-backlog.md:133` (J4) e `:344` (onboarding) — itens futuros; o commit do refinamento (Passo 0) só **acrescenta** a anotação do D5.
- **Não commitar:** `reviews/`, cassettes, `_ai_context/`, `open-design/prints/`.
- **Leitura exata antes de editar (Passo 1):** reler `db/migrations/0036_add_user_state.sql`, `lib/journey_service.rb`, `lib/user_state_repository.rb`, `server.rb:20-30/595-605/1440-1450`, `test/test_helper.rb:80-90`, `test/server_test_helpers.rb:10-30` e `test/journey_service_test.rb` inteiro (225 linhas) — as linhas citadas aqui foram verificadas nesta fase 1, mas o diff pode ter se deslocado.

### Bloco A — execução da fase 2 (Passos 1–5, 2026-09-16)

> **A sessão continua `Pendente`:** a validação (fase 3) é do usuário e a §7 não foi tocada. O Bloco B (Passo 6) foi executado por outro agente (`48a6774`).

| Passo | SHA | Entrega |
| --- | --- | --- |
| 1 | `d57947c` | `db/migrations/0037_drop_user_state.sql` (novo) + `test/user_state_removal_test.rb` com `test_user_state_table_is_gone_after_setup`. **RED** real: 1 run / 1 failure (`Expected "user_state" to be nil`). **GREEN** após a 0037: 1 run / 0 failures; lint 0. |
| 2 | `d6f1ff3` | **RED** (3 asserts estruturais em `user_state_removal_test.rb`): 4 runs / 3 failures. **GREEN**: remove `lib/user_state_repository.rb`, `test/user_state_repository_test.rb`, kwarg `user_state:` + `mark_started`/`mark_started_when_full` de `lib/journey_service.rb`, o wire de `server.rb` (`:24`,`:599`,`:1445-1447`), `clear_user_state!` (`test/test_helper.rb` + `test/server_test_helpers.rb:16`), o require/chamada/kwargs de `test/journey_service_test.rb`; docs do D7 no mesmo commit (`GDD.md:27`, `REQUIREMENTS.md:638-643`, `docs/draft-backlog.md:109` → obsoleto, `docs/5F-decisoes-pendentes.md` §5.F.1 + "Para fechar" 1–2). 13 arquivos, +42/−175. |
| 3 | `e7bcaf3` | Remove o helper `start_journey` (já no-op) + os 4 chamadores de `test/team_routes_test.rb`; 2 arquivos, −9 linhas. |
| 4 | `34b07b0` | Apaga `db/migrations/0036_add_user_state.sql`. **Idempotência provada:** 3 execuções consecutivas de `rake db:setup` sem erro; `to_regclass('user_state')` = NULL e 5 tabelas intactas (`team_pokemons`, `team_pokemon_progress`, `battles`, `wallet`, `inventory`) em `pokedex` **e** `pokedex_test`. |
| 5 | (este) | Verificação final do Bloco A: suíte completa **1181 runs / 6309 assertions / 0 failures / 0 errors**; lint dos 7 arquivos tocados **0 offenses**; `./scripts/check_docs` ok; `./scripts/checar-sessao 0089` ok; C2 grep = só `db/migrations/0037_drop_user_state.sql` + `test/user_state_removal_test.rb`; C4 (4 testes do gate derivado) verdes individualmente. |

**Desvios do plano (registrados, sem reabrir critério):**

- **Passo 2 absorveu parte do Passo 3.** O plano mandava remover os 2 testes vacuosos da flag, a classe `JourneyMarkWhenFullTest` e os 4 chamadores de `start_journey` no Passo 3 — mas `mark_started`/`mark_started_when_full` saem no Passo 2 e esses testes os chamam (RED no meio do caminho, violando o green por commit da G1). Os testes vaciosos e `JourneyMarkWhenFullTest` foram para o Passo 2; `start_journey` virou no-op explícito (`def start_journey(_user_id); end`) no Passo 2 e foi removido com os 4 chamadores no Passo 3 (que assim ficou sem o resto do escopo previsto). C5 continua provado (as 4 remoções + o repo morto aconteceram; só mudou o commit em que entraram).
- **Risco 1 materializou-se em forma NÃO listada no refinamento.** O grep do C2 achou **3** sites de `UserStateRepository` em `test/team_routes_test.rb` que a §3/§2 não citava: `:712` e `:735` (classe `ServerTeamJourneyMarkTest`, 706–737 — provava o persistido que foi removido) e `:1188` (um `refute UserStateRepository.new.started?` solto dentro do teste de budget da sessão C4). A classe inteira (2 testes) saiu e o `refute`+comentário saíram no Passo 2; sem isso a suíte derrubaria com `NameError`/`NoMethodError`. **Lição:** a lista "dependências de teste da tabela" do refinamento estava incompleta — o grep de `UserStateRepository` no `test/` era o inventário correto.
- **Passo 4 fez 3 setups, não 2** (um a mais para conferir as bases após a remoção da 0036) — comportamento idêntico em todas.

**Riscos vigiados — resultado:**

- **Risco 1 (`TRUNCATE user_state` explode pós-0037):** neutralizado. `clear_user_state!` saiu junto com **todos** os chamadores no Passo 2 (`test/test_helper.rb`, `test/server_test_helpers.rb:16`, `test/journey_service_test.rb:16`) — nenhum `PG::UndefinedTable` na suíte.
- **Risco 2 (apagar a 0036 é irreversível):** aceito (D3); a 0037 cobre bancos onde a 0036 rodou e é no-op em banco novo — conferido nas duas bases.
- **Risco 3 (`docs/draft-backlog.md:133` J4 e `:344` onboarding):** **não tocados**; a anotação de "novo lar de persistência" fica só no §8/5F/GDD acima (o `GDD.md:27` aponta para `:344`).
- **Risco 4 (cassettes / `reviews/`):** nada commitado; `test/cassettes/**` (untracked de outras sessões) ficou fora de todos os commits.

**Ruído do ambiente (não é do Bloco A):**

- **Agente concorrente no mesmo working tree:** o commit do Bloco B (`48a6774`, Passo 6) entrou em paralelo e, durante os Passos 2–4, `test/battle_strike_routes_test.rb` e `views/_strike_result.erb` estavam **dirty** (trabalho em voo de outro agente, +1 teste). Por isso os primeiros runs completos variaram (2 e 1 falhas em arquivos alheios). No run final (Passo 5) a suíte ficou **verde**: `1181 runs` = baseline 1186 − 4 (`UserStateStartedTest`) − 4 (vacuosos) − 2 (`ServerTeamJourneyMarkTest`) + 4 (`user_state_removal_test.rb`) **+ 1** (teste novo do agente concorrente). **A única offense de lint global** (`test/battle_strike_routes_test.rb:101`, `Style/RegexpLiteral`) é desse arquivo dirty, não do Bloco A (os 7 arquivos tocados aqui têm 0).
- **Flake pré-existente encontrado (fora de escopo):** `SeedScriptsTest#test_team_evolucao_seeds_near_evolution_thresholds` (`test/seed_scripts_test.rb:38`) falhou num run completo (seed 29866: `Expected: 15, Actual: 5`) e **passou** isolado e no run final. Causa provável: `TestDatabase.team_row(name)` (`test/test_helper.rb:124-128`) não filtra por `user_id` nem ordena → pode devolver o `charmander` de outro usuário. Ordem-dependente, pré-existente, **não** causado por esta sessão. Anotado como TODO para sessão própria (não abrir escopo aqui).


## 9. Gotchas / Lições (memória — S6)

Preenchido na validação (fase 3) — alimenta `memory_write_page` em `gotchas/`.
