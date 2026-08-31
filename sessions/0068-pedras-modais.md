# Sessão 0068 — pedras-modais (Onda 2 Economia #5: pedras de evolução — oferta 3/rodada preço 80 + modal de evolução)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-31 (D1–D10 fechadas) |
| Implementação | **Pendente** |
| Validação | **Pendente** (executada pelo usuário) |

---

## 1. Objetivo

Entregar as **pedras de evolução** como itens compráveis no Poke Mart (catálogo de 6 pedras clássicas, oferta determinística de **3 por rodada** a **preço fixo 80**, vendáveis a 50%) e o **uso manual da pedra** via um **modal `#evolution-modal`** (overlay htmx + CSS, 3 estados) que lista as evoluções por pedra + quantidade no inventário + botão "Evoluir" por membro — com evolução automática por nível preservada (ortogonal) e bloqueio para membros `fainted?` (sem consumir).

## 2. Contexto (estado atual — diagnóstico)

- **`lib/item_catalog.rb:5-29`** — `ItemCatalog::ITEM_CATALOG` estático com **5 itens**: 3 consumíveis (`potion` 20, `super-potion` 50, `hyper-potion` 100, `category: "consumable"`) + 2 held (`choice-band` 80 Attack, `choice-scarf` 80 Speed, `category: "held"`). **Não existe `category: "stone"` nem pedras.** `Item` tem `name/display_name/category/price` (+ campos opcionais `heal_amount/stat/multiplier`).
- **`lib/mart_service.rb:14-24`** — `buy(user_id, item_name, quantity)` valida `@catalog.find` → quantidade → saldo (`@wallet.balance`) e chama `purchase_result` (debita wallet + soma inventário); `sell` (26-35) usa `SellPolicy` (50% — `test/sell_policy_test.rb:12`). **O `buy` não conhece "oferta da rodada"** — qualquer item do catálogo é comprável (D7 mudará isso para pedras).
- **`lib/gateways/poke_api_parsing.rb:166-169`** — `stage_details` captura só `{ name:, trigger:, min_level: }`; `evolution_restricted?` (94) já detecta trigger ≠ `level-up` reusando fetches cacheados; `find_current_species_next_stages` (156-164) percorre a cadeia. **Falta capturar `item`** (D4) para saber qual pedra evolui qual espécie.
- **Evolução automática (ortogonal — D8)**: `BattleServiceFinalization#try_evolve` (`lib/battle_service.rb:333-341`) → `evolution_target` (328-331, `EvolutionRule.next_stage` por nível) → `EvolutionOperations#evolve` (`lib/team_repository.rb:85-94`, UPDATE `number/name/sprite`, `PG::UniqueViolation` → `false` quando o alvo já está no time). Testes existentes: `test/battle_routes_test.rb:627` (`test_battle_finish_evolves_member_when_level_reaches_min_level`), `test/team_repository_test.rb:390/423` (evolve/evolve-blocked). **Não existe caminho manual (use-item).**
- **`server.rb:572-578`** — `evolution_chain_names` monta a cadeia para o detalhe (reuso de `settings.api.detail/find`).
- **Views**: `views/team_manage.erb` (88 linhas) tem forms hx-post de moves/item/held-item e link "Voltar", **sem botão "Evoluir"**; `views/team.erb` (63 linhas) tem link "Gerenciar time", form DELETE com `disabled + title` para `fainted?` (sessão 0064) e **sem modal**; `views/_mart.erb` (27 linhas) tem forms `hx-post /mart/buy` e `/mart/sell` apontando para `#team-view`. **Nenhum modal existe hoje** — padrão htmx é pane/swap `#team-view` (ex.: `#pokemon-detail`).
- **Rodada (D1/D2)**: tabela `battles` (migração 0026) contabiliza confrontos do usuário → `battle_count`; **não há tabela de rotação de ofertas** — a rotação será **derivada, sem banco**.
- **Fainted (D10)**: `Pokemon#fainted?`/`alive?` existem desde a 0064 (`test/team_service_test.rb:11-38`, `test/team_fainted_routes_test.rb`) — reuso para o gate de bloqueio.
- Frescor do grafo (2026-08-31T17:15:49Z): `lib/poke_api_parsing.rb` (caminho real `lib/gateways/poke_api_parsing.rb`), `views/_mart.erb`, `views/team.erb`, `views/team_manage.erb` sem registro de gap, mas `missing`/`not_tracked` — fonte conferida via read nesta sessão.

## 3. Escopo

### Produção

- `lib/item_catalog.rb` — adicionar **6 pedras** `category: "stone"`, `price: 80`, display pt-BR, nomes casando com `item.name` da PokéAPI: `fire-stone` (Pedra de Fogo), `water-stone` (Pedra de Água), `thunder-stone` (Pedra de Trovão), `leaf-stone` (Pedra de Folha), `moon-stone` (Pedra Lunar), `sun-stone` (Pedra Solar).
- Novo `lib/stone_rotation.rb` — **rotação determinística** (D2): seed = `hash(user_id) + battle_count`; `catalog.shuffle(random: seed)` tira 3 pedras distintas; sem migração.
- `lib/mart_service.rb` — `buy` de pedra **valida a oferta da rodada** (D7): pedra não ofertada → notice de erro **sem debitar**; ofertada → debita 80 + soma inventário (D3). Venda de pedras pelo fluxo atual (D9, SellPolicy 50%).
- `lib/gateways/poke_api_parsing.rb` — `stage_details` ganha **`item`** (D4); `evolution_restricted?` preservado.
- Gateway `PokeApi` (real/http + fake + cache + interface) — novo **`stone_evolutions`** (trigger `use-item`): retorna estágios por pedra; falha de rede → `[]` (modal graceful).
- `server.rb` — rotas do modal e do uso: abrir modal (lista evoluções por pedra + qtd inventário + botão "Evoluir" por membro) e `POST` de uso da pedra (evolui + consome 1; sem estágio / sem pedra / alvo no time / `fainted?` → notices **sem consumir**); injetar oferta da rodada no mart.
- `views/team_manage.erb`, `views/team.erb`, `views/_mart.erb` + CSS — botão "Evoluir" por membro e **`#evolution-modal`** overlay real (puro htmx + CSS, `role="dialog"`/aria — a11y básica), modal único em 3 estados (D6): lista evoluções por pedra + qtd + botão; resposta re-renderiza o mesmo modal; multi-ramo vira linhas distintas.

### Testes

- Novo `test/stone_rotation_test.rb` — determinismo por seed/battle_count, 3 distintas, muda ao avançar.
- Novo `test/evolution_routes_test.rb` — modal render, uso da pedra (evolui+consome), notices sem consumir (sem estágio / sem pedra / alvo no time / fainted).
- `test/item_catalog_test.rb` — 6 pedras, `category: "stone"`, price 80, display pt-BR.
- `test/mart_service_test.rb` + `test/mart_routes_test.rb` — gate de oferta (não-ofertada → erro sem debitar), compra ofertada (debita 80 + soma), venda 50%.
- `test/poke_api_http_test.rb` / `test/poke_api_fake_test.rb` / `test/poke_api_cache_test.rb` — `stone_evolutions` (use-item, captura item, rede → `[]`, delegado/cacheado via interface).
- Regressão: `test/team_repository_test.rb` (TeamEvolveTest), `test/battle_routes_test.rb` (finish evolve), `test/poke_api_http_test.rb` (`next_evolutions` level-up only).

### Fora de escopo (não abrir)

- **0069 resolver batalha**, **0063 juice** e Onda 3 Estabilidade (0070 escritas atômicas, 0071 CSRF, 0072 respiro) — fila futura.
- Pedras como **held item**/equipáveis (só consumível de evolução); preço dinâmico por pedra; novas pedras além das 6 clássicas.
- Evolução por outros triggers (troca, etc.) — **só `use-item`**; persistência da rotação (D2 sem banco); multi-evolução em lote.
- Animações/transições sofisticadas do modal (só overlay + a11y básica).

## 4. Critérios de aceite

### Resultado

- [ ] **C1 — Catálogo com 6 pedras clássicas** (`fire/water/thunder/leaf/moon/sun-stone`), `category: "stone"`, display pt-BR, **preço fixo 80**, nomes casando com `item.name` da PokéAPI — prova: `test/item_catalog_test.rb` (novo `test_stone_catalog_has_six_stones_price_80`).
- [ ] **C2 — Oferta da rodada: 3 pedras distintas, determinística** por seed `hash(user_id) + battle_count` (confrontos concluídos, tabela `battles`), e muda ao avançar — prova: `test/stone_rotation_test.rb` (novo `test_rotation_is_deterministic_three_distinct` + `test_rotation_changes_as_battle_count_grows`).
- [ ] **C3 — Compra só das 3 ofertadas (D7)**; pedra não ofertada → notice de erro **sem debitar** — prova: `test/mart_service_test.rb` (novo `test_buy_stone_not_in_rotation_is_rejected_without_debit`) + `test/mart_routes_test.rb`.
- [ ] **C4 — Compra de pedra ofertada debita 80 e soma o inventário** — prova: `test/mart_service_test.rb` (novo `test_buy_stone_debits_80_and_adds_inventory`) + `test/mart_routes_test.rb`.
- [ ] **C5 — Modal `#evolution-modal` lista evoluções por pedra + qtd no inventário + botão "Evoluir"** por membro (em `team_manage.erb` e no slot de `team.erb`) — prova: `test/evolution_routes_test.rb` (novo `test_modal_lists_stone_evolutions_and_inventory_quantity`).
- [ ] **C6 — Usar pedra evolui o membro** (número/nome/sprite atualizados, identidade preservada) e **consome 1** do inventário — prova: `test/evolution_routes_test.rb` (novo `test_use_stone_evolves_member_and_consumes_one`) + reuso `test/team_repository_test.rb` (`test_evolve_updates_number_name_sprite_keeping_identity`).
- [ ] **C7 — Sem estágio compatível → notice sem consumir** — prova: `test/evolution_routes_test.rb` (novo `test_use_stone_without_compatible_stage_notice_without_consuming`).
- [ ] **C8 — Sem pedra no inventário → notice sem consumir** — prova: `test/evolution_routes_test.rb` (novo `test_use_stone_without_inventory_notice_without_consuming`).
- [ ] **C9 — Alvo já no time → não evolui + notice** (caminho `PG::UniqueViolation` do `evolve`) — prova: `test/evolution_routes_test.rb` (novo `test_use_stone_target_already_in_team_notice`) + reuso `test/team_repository_test.rb` (`test_evolve_does_not_evolve_when_target_number_already_in_team`).
- [ ] **C10 — (D10) `fainted?` → bloqueio sem consumir** — usar pedra em membro derrotado → notice de erro, pedra **permanece** no inventário — prova: `test/evolution_routes_test.rb` (novo `test_use_stone_on_fainted_member_blocked_without_consuming`).
- [ ] **C11 — Evolução automática preservada (regressão, D8)** — `next_evolutions`/`try_evolve`/battle finish por nível intactos — prova: `test/battle_routes_test.rb` (`test_battle_finish_evolves_member_when_level_reaches_min_level`) + `test/team_repository_test.rb` (`test_evolve_*`) + `test/poke_api_http_test.rb` (`test_next_evolutions_returns_level_up_stages_only`).
- [ ] **C12 — `PokeApi#stone_evolutions` (trigger `use-item`)** — `stage_details` estendido para capturar `item`; real/http + fake + cache (delegado via interface); **falha de rede → `[]`** — prova: `test/poke_api_http_test.rb` (novo `test_stone_evolutions_returns_use_item_stages` + `test_stone_evolutions_empty_on_network_error`), `test/poke_api_fake_test.rb`, `test/poke_api_cache_test.rb`.
- [ ] **C13 — Modal overlay visual** (overlay real `#evolution-modal`, `role="dialog"`/aria, puro htmx + CSS) — prova: **`manual`** (inspeção visual via `./scripts/run` + navegador: abre por membro, overlay cobre a tela, fecha/volta, a11y básica).

### Garantias — teste que prova (S1)

| Critério | Teste que prova | Manual |
| --- | --- | --- |
| G1 (suíte+lint) | `./scripts/test` suíte completa (baseline 959/3697 + novos) + `./scripts/lint` 0 por green | — |
| G2 (sem gem/sem schema/API stub) | `git diff -- Gemfile db/` vazio (rotação derivada, D2) + `test/poke_api_http_test.rb` (fake/sem rede) | — |
| G3 (S4/S5) | `./scripts/check_docs` + `./scripts/checar-sessao 0068` + `SESSIONS.md` atualizado no refinamento | — |

> **S1:** cada critério acima aponta o teste que o prova. C13 sem teste automatizado → `manual` explícito + evidência esperada. Baseline suíte 959/3697 da 0067.

## 5. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Parar ao fim da fase 2 e aguardar validação do usuário. P=pequena (2-3 passos) — sessão M (5-7 passos).

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (tabela + "Próxima sessão") | commit `Sessao 0068: refinamento concluido — pedras de evolucao (oferta 3/rodada, preco 80, modal) + criterios e plano TDD fechados` |
| 1 | **red→green — C1 catálogo 6 pedras** — `lib/item_catalog.rb` `Item.new(name: "fire-stone", display_name: "Pedra de Fogo", category: "stone", price: 80)` ×6 (fire/water/thunder/leaf/moon/sun); `test/item_catalog_test.rb` `test_stone_catalog_has_six_stones_price_80` (+ display/category) | `./scripts/test test/item_catalog_test.rb -n /stone/` + suíte + lint 0; commit `Passo 1: ItemCatalog com 6 pedras de evolucao (category stone, preco 80, display pt-BR)` |
| 2 | **red→green — C2 rotação determinística** — novo `lib/stone_rotation.rb`: seed `hash(user_id)+battle_count`, `catalog.shuffle(random: seed)` → 3 distintas; `battle_count` via tabela `battles` (migração 0026); `test/stone_rotation_test.rb` `test_rotation_is_deterministic_three_distinct` + `test_rotation_changes_as_battle_count_grows` | `./scripts/test test/stone_rotation_test.rb` + suíte + lint 0; commit `Passo 2: StoneRotation derivada (seed hash(user_id)+battle_count) oferta 3 pedras por rodada` |
| 3 | **red→green — C3+C4 gate de compra (D7) + débito 80** — `lib/mart_service.rb` `buy` valida oferta da rodada p/ `category: "stone"` (não-ofertada → notice sem debitar); `views/_mart.erb` exibe as 3 ofertadas; `test/mart_service_test.rb` `test_buy_stone_not_in_rotation_is_rejected_without_debit` + `test_buy_stone_debits_80_and_adds_inventory`; `test/mart_routes_test.rb` | `./scripts/test test/mart_service_test.rb test/mart_routes_test.rb -n /stone|rotation/` + suíte + lint 0; commit `Passo 3: MartService#buy valida oferta da rodada (so 3 compraveis, 80, sem debito p/ nao ofertada)` |
| 4 | **red→green — C12 `stone_evolutions` na API** — `lib/gateways/poke_api_parsing.rb` `stage_details` ganha `item`; `PokeApi#stone_evolutions` (trigger `use-item`) no real/http + fake + cache (delegado via interface); rede → `[]`; `test/poke_api_http_test.rb` `test_stone_evolutions_returns_use_item_stages` + `_empty_on_network_error`, `test/poke_api_fake_test.rb`, `test/poke_api_cache_test.rb` | `./scripts/test test/poke_api_http_test.rb test/poke_api_fake_test.rb test/poke_api_cache_test.rb -n /stone_evolutions/` + suíte + lint 0; commit `Passo 4: PokeApi#stone_evolutions (trigger use-item) com item no stage_details e rede -> []` |
| 5 | **red→green — C6+C7+C8+C9+C10 rota de uso manual** — `server.rb` `POST /team/:id/evolve` (item pedra): evolui via `EvolutionOperations#evolve` + consome 1 inventário; sem estágio/sem pedra/alvo no time/`fainted?` → notices **sem consumir**; novo `test/evolution_routes_test.rb` (5 testes) | `./scripts/test test/evolution_routes_test.rb -n /stone/` + suíte + lint 0; commit `Passo 5: rota de uso da pedra (evolui e consome 1; fainted/sem estagio/sem pedra/alvo no time bloqueiam sem consumir)` |
| 6 | **red→green — C5+C13 modal `#evolution-modal`** — botão "Evoluir" por membro em `views/team_manage.erb` + slot de `views/team.erb`; overlay (3 estados: lista por pedra + qtd inventário + Evoluir; resposta re-renderiza o mesmo modal; multi-ramo em linhas); `role="dialog"`/aria + CSS; render tests em `test/evolution_routes_test.rb` (`test_modal_lists_stone_evolutions_and_inventory_quantity`) | `./scripts/test test/evolution_routes_test.rb -n /modal/` + suíte + lint 0; C13 overlay visual → `manual` na validação; commit `Passo 6: modal #evolution-modal (overlay 3 estados, htmx+CSS, a11y basica) + botao Evoluir por membro` |
| 7 | **red→green — C11 regressão evolução automática + docs** — suíte completa (baseline 959/3697 + novos) verde com `test/battle_routes_test.rb` (finish evolve) e `test/team_repository_test.rb` (TeamEvolveTest) verdes; lint 0; `REQUIREMENTS.md`/`SESSIONS.md` no escopo docs (status de validação só após usuário — S4) | `./scripts/test` completa + `./scripts/lint` 0 + `./scripts/check_docs`; commit `Passo 7: regressao da evolucao automatica preservada (ortogonal a manual) + docs` |
| — | **Fase 2 concluída (7 passos)** → **Revisor (2c)**: loop Implementador↔Revisor até veredito `Aprovado` (teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar Done, não preencher a seção 7, não commitar conclusão. | — |

## 6. Decisões de refinamento (fechadas com o usuário em 2026-08-31)

- **D1 — Rodada por confronto concluído** — oferta derivada do nº de batalhas do usuário (`battle_count`, tabela `battles` — migração 0026). Alternativa preterida: janela temporal (dia/semana).
- **D2 — Rotação derivada, sem banco** — seed = `hash(user_id) + battle_count`; `catalog.shuffle(random: seed)` tira 3 pedras. **Sem migração.** Alternativa preterida: tabela `stone_rotation` persistida.
- **D3 — Catálogo: 6 pedras clássicas** — fire/water/thunder/leaf/moon/sun-stone, `category: "stone"`, display pt-BR, **preço fixo 80**; nomes casando com `item.name` da PokéAPI.
- **D4 — Matching via PokéAPI** — estender `stage_details` (`lib/gateways/poke_api_parsing.rb:166-169`) para capturar `item`; novo `PokeApi#stone_evolutions` (trigger `use-item`); **falha de rede → `[]`** (modal graceful).
- **D5 — Modal: overlay real `#evolution-modal`** — botão "Evoluir" por membro em `team_manage.erb` e no slot de `team.erb`; puro htmx + CSS, `role="dialog"`/aria (a11y básica).
- **D6 — Fluxo do modal: modal único em 3 estados** — lista evoluções por pedra + qtd inventário + botão Evoluir; resposta re-renderiza o mesmo modal; multi-ramo vira linhas distintas.
- **D7 — Gate de compra: só as 3 ofertadas são compráveis** — `MartService#buy` valida a oferta da rodada; não-ofertada → notice de erro **sem debitar**.
- **D8 — Auto-evolução e manual ortogonais** — automática (`next_evolutions`, `try_evolve`) **intacta**; manual (`stone_evolutions`, use-item) **nova**.
- **D9 — Pedras vendáveis** pelo fluxo atual (SellPolicy 50%).
- **D10 — Fainted BLOQUEADO** — usar pedra em membro `fainted?` → notice de erro **sem consumir** a pedra. *(Fora da recomendação do refinador — decisão explícita do usuário; entra como C10.)*

## 7. Validação (executada pelo usuário — S2)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 catálogo 6 pedras price 80 stone | `test/item_catalog_test.rb` `test_stone_catalog_has_six_stones_price_80` | — | |
| C2 oferta 3 distintas determinística | `test/stone_rotation_test.rb` (`test_rotation_is_deterministic_three_distinct` + `test_rotation_changes_as_battle_count_grows`) | — | |
| C3 compra só ofertada | `test/mart_service_test.rb` `test_buy_stone_not_in_rotation_is_rejected_without_debit` | — | |
| C4 compra debita 80 e soma | `test/mart_service_test.rb` `test_buy_stone_debits_80_and_adds_inventory` | — | |
| C5 modal lista evoluções+qtd+botão | `test/evolution_routes_test.rb` `test_modal_lists_stone_evolutions_and_inventory_quantity` | — | |
| C6 usar pedra evolui+consome | `test/evolution_routes_test.rb` `test_use_stone_evolves_member_and_consumes_one` | — | |
| C7 sem estágio → notice sem consumir | `test/evolution_routes_test.rb` `test_use_stone_without_compatible_stage_notice_without_consuming` | — | |
| C8 sem pedra → notice | `test/evolution_routes_test.rb` `test_use_stone_without_inventory_notice_without_consuming` | — | |
| C9 alvo no time → não evolui | `test/evolution_routes_test.rb` `test_use_stone_target_already_in_team_notice` | — | |
| C10 fainted → bloqueio sem consumir | `test/evolution_routes_test.rb` `test_use_stone_on_fainted_member_blocked_without_consuming` | — | |
| C11 regressão automática | `test/battle_routes_test.rb` `test_battle_finish_evolves_member_when_level_reaches_min_level` | — | |
| C12 stone_evolutions (use-item, rede→[]) | `test/poke_api_http_test.rb` (`test_stone_evolutions_returns_use_item_stages` + `test_stone_evolutions_empty_on_network_error`) | — | |
| C13 modal overlay visual | — | `./scripts/run` + navegador: overlay real por membro, 3 estados, role/aria, fecha/volta | |
| G1 suíte+lint | `./scripts/test` (baseline 959/3697 + novos) + `./scripts/lint` 0 | — | |
| G2 sem gem/schema/API stub | `git diff -- Gemfile db/` vazio + fake da API | — | |
| G3 S4/S5 | `./scripts/check_docs` + `./scripts/checar-sessao 0068` + `SESSIONS.md` atualizado | — | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.

## 8. Observações

- Próxima sessão após a 0068: **0069 resolver batalha** → **0063 juice** (ordem fechada pelo usuário; ver SESSIONS.md).
- Anotações fora do fluxo (RNF-04 — não abrir escopo nesta sessão): pedras como held item/equipáveis; preço dinâmico por pedra; evolução por outros triggers (troca); persistência da rotação (hoje derivada, D2).
- `stone_evolutions` toca a interface `PokeApi` — atualizar real/http + fake + cache em paralelo no passo 4 (padrão `next_evolutions` existente: `test/poke_api_cache_test.rb:303-309` delegado/cacheado).
- Rotação derivada sem banco: instanciar `Random.new(seed)` por chamada (não reutilizar instância — estado mutável).

## 9. Gotchas / Lições (memória — S6)

- `stage_details` (`lib/gateways/poke_api_parsing.rb:166-169`) captura só `name/trigger/min_level` — estender para `item` exige tocar parsing + real/http + fake + cache na mesma passada (interface `PokeApi`).
- `EvolutionOperations#evolve` (`lib/team_repository.rb:85-94`) retorna `false` em `PG::UniqueViolation` (alvo já no time) — o caminho manual deve tratar o mesmo caso (C9) sem estourar.
- Reuso de `fainted?`/`alive?` (0064, `test/team_service_test.rb`) para o gate D10 — padrão já testado de bloqueio com notice sem efeito colateral.
- `shuffle(random:)` com `Random.new(seed)` é determinístico por seed — `hash(user_id)` é estável dentro do processo Ruby; combinar com `battle_count` para variar por rodada.

### Gotchas da implementação (fase 2, 2026-08-31)

- **`String#hash` é randomizado por processo no Ruby** — `seed = hash(user_id) + battle_count` é estável **dentro** do processo, mas **muda entre processos/reinícios**. Testes de rota que dependem da rotação real devem calcular em runtime (`StoneRotation.new("user-a", 0).stones` — mesmo processo que o servidor sob Rack::Test), **nunca** hardcodar pedras ofertadas.
- **MT19937 com seeds consecutivos colide** — `Random.new(n)` e `Random.new(n+1)` podem gerar a **mesma** rotação (ex.: bc=6 e bc=7 colidem para "user-123"). O teste "muda ao avançar" precisa de counts verificados (bc=0 vs bc=1 para "user-1" diferem; conferir antes de trocar de user).
- **`Style/Sample` (RuboCop) força `sample(3, random:)`** no lugar de `shuffle.first(3)` — ambos determinísticos por seed, mas produzem rotações diferentes; o teste não deve acoplar a ordem específica.
- **`battles` é truncada no setup de cada teste** (`TestDatabase.clear_team!` TRUNCATE inclui `battles`) — battle_count = 0 determinístico nos testes de rota do mart.
- **`./scripts/test` com pipe aborta de forma intermitente** (o consumer `tail`/`grep` fecha o pipe cedo e o `pipefail` do script reporta falha) — rodar com redirecionamento `> /tmp/x.txt` é estável.
- **Modal re-renderizado via `hx-target="#evolution-modal" hx-swap="outerHTML"`** (POST evolve e close) — o close responde `""` e o outerHTML remove o overlay; validar visualmente na fase 3 (C13).