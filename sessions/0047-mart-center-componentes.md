# Sessão 0047 — JN-4: componentes de Poke Mart e Poke Center

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-24 |
| Implementação | **Concluída** — passos 1–3 verdes (suíte 724/2329, lint 0) |
| Validação | **Concluída** — validada pelo usuário em 2026-08-24 |

---

## 1. Objetivo

Extrair os blocos de **Poke Center** e **Poke Mart** de `views/team.erb` em **partials
reutilizáveis** (`_center.erb`, `_mart.erb`) renderizados no painel do time
(`#team-view`), completando visualmente a cura (**HP atual/máx + custo total
antecipado**, botão Curar desabilitado quando já curado ou saldo insuficiente) e a
compra (**preço × quantidade comprável = saldo/preço**, botão desabilitado quando
saldo < preço). Sem rotas/páginas novas.

## 2. Contexto (estado atual — diagnóstico)

- `views/team.erb:11-36` embute **inline** os dois blocos: Poke Center (`team_hp.erb`
  + botão `hx-post="/team/heal"`) e Poke Mart (saldo + catálogo com botões
  `hx-post="/mart/buy"` + inventário). Ambos só aparecem quando `@journey_started`
  e `@team` não vazio.
- `server.rb`: `mart_data` (linha ~200) carrega `@catalog`/`@inventory`/`@balance`;
  `prepare_team_fragment_data` (linha ~365) chama `mart_data`; `heal_team` e
  `buy_from_mart` retornam `render_result_notice` → `render_team_fragment_with_notice`
  (re-renderiza o fragmento inteiro `#team-view`).
- **Custo da cura só aparece depois de clicar** — `HealService#heal` calcula
  `missing_hp`/`cost` internamente via `HealCostPolicy` (0.5/HP, `missing_hp` clamp,
  `cost` arredonda) e o valor só sai no notice.
- **Compra mostra preço, mas não a quantidade comprável** — `ItemCatalog` (5 itens:
  potion 20, super-potion 50, hyper-potion 100, choice-band 80, choice-scarf 80);
  `MartService#buy` valida saldo e debita; `@balance` já está no fragmento.
- Testes atuais: heal em `test/team_routes_test.rb` (ServerTeamTest —
  `test_team_heal_cures_team_and_charges_wallet`, `...insufficient_balance...`,
  `...already_cured...`, `test_team_fragment_shows_poke_center_with_hp_and_heal_button`,
  `test_team_fragment_omits_heal_button_for_empty_team`); mart em
  `test/mart_routes_test.rb` (ServerMartTest — `test_mart_fragment_shows_catalog_inventory_and_balance`,
  `test_mart_buy_debits_wallet_and_adds_to_inventory`).

## 3. Escopo

### Produção

- `views/_center.erb` (novo partial): lista HP atual/máx por membro (absorve
  `team_hp.erb`, que é removido) + **custo total da cura antecipado** + botão Curar
  (`hx-post="/team/heal"`) com `disabled` quando `custo.zero?` (já curado) ou
  `saldo < custo`.
- `views/_mart.erb` (novo partial): saldo + por item **preço × quantidade comprável**
  (`@balance / item.price`, ex. "×5") + botão `hx-post="/mart/buy"` com `disabled`
  quando `saldo < preço`; inventário com quantidades preservado.
- `views/team.erb`: substituir os blocos inline pelos partials `_center.erb`/`_mart.erb`
  (guardas `@journey_started`/`@team.empty?` preservadas).
- `lib/heal_service.rb`: adicionar `preview_cost(user_id)` (público) que calcula o
  custo total sem mutar — reusa `missing_hp`/`cost` do `HealCostPolicy`.
- `server.rb`: `center_data` carrega `@heal_cost` (`settings.heal.preview_cost`) e
  `@balance`; `prepare_team_fragment_data` passa a chamar `center_data` + `mart_data`.

### Testes

- `test/team_routes_test.rb` (ServerTeamTest): novos testes do fragmento Center —
  custo antecipado exibido; botão Curar desabilitado quando já curado; desabilitado
  quando saldo insuficiente.
- `test/mart_routes_test.rb` (ServerMartTest): novos testes do fragmento Mart —
  quantidade comprável exibida; botão comprar desabilitado quando saldo insuficiente.
- Testes existentes de heal/mart/buy servem de **regressão** (strings `"Poke Center"`,
  `"HP 100/200"`, `hx-post`, notices preservadas).

### Fora de escopo (não abrir)

- **Sem rotas/páginas novas** (`GET /mart`, `GET /center`) — preterido telas próprias
  no padrão JN-1 e fragmentos com rotas próprias.
- Sem mudança de contrato de `MartService`; sem alterar a lógica de `HealService#heal`
  (débito, notices, gateway de jornada).
- Sem mudança de schema, sem gems novas.
- JN-5 (gameloop), J2 (personalização), D4 (draft temático) e P2 (perf da 1ª batalha)
  continuam **anotados**, fora desta sessão.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 — Poke Center virou partial `_center.erb` reutilizável no painel do time
      com HP atual/máx por membro + custo total da cura antecipado** — prova:
      `test/team_routes_test.rb` (`test_center_fragment_shows_heal_cost_upfront`) +
      regressão `test_team_fragment_shows_poke_center_with_hp_and_heal_button`.
- [ ] **C2 — Botão Curar desabilitado quando o time já está curado (custo 0) ou o saldo
      é insuficiente** — prova: `test/team_routes_test.rb`
      (`test_center_fragment_disables_heal_when_cured`,
      `test_center_fragment_disables_heal_when_insufficient_balance`).
- [ ] **C3 — Poke Mart virou partial `_mart.erb` reutilizável no painel do time com
      preço × quantidade comprável (saldo/preço) por item** — prova:
      `test/mart_routes_test.rb` (`test_mart_fragment_shows_affordable_quantity`) +
      regressão `test_mart_fragment_shows_catalog_inventory_and_balance`.
- [ ] **C4 — Botão comprar desabilitado quando saldo < preço** — prova:
      `test/mart_routes_test.rb` (`test_mart_fragment_disables_buy_when_insufficient_balance`).
- [ ] **C5 — Heal e buy inalterados** (rotas, notices, débito/reposição, gate de
      jornada) — prova: regressão `test/team_routes_test.rb`
      (`test_team_heal_cures_team_and_charges_wallet`) e `test/mart_routes_test.rb`
      (`test_mart_buy_debits_wallet_and_adds_to_inventory`) + `manual` (navegar e
      comprar/curar na UI).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (718 runs/2294 asserts)** + novos
      testes e lint 0 em **todo** green; commit obrigatório por passo; 0 regressão.
- [ ] Sem gems novas / sem mudança de schema / testes sem rede / sem `rubocop:disable`
      novo.
- [ ] `REQUIREMENTS.md` + `SESSIONS.md` atualizados no passo docs; *status de
      validação* só após o usuário validar.

> **S1:** cada critério aponta o teste que o prova (novos testes nominais acima; os
> testes existentes atuam como regressão).

## 5. Decisões de refinamento (fechadas com o usuário)

- **2026-08-24 — Forma dos componentes:** partials `_mart.erb`/`_center.erb`
  reutilizáveis renderizados dentro do painel do time (`#team-view`), **sem rotas nem
  páginas novas**. Preteridas: telas próprias `GET /mart`/`GET /center` no padrão JN-1
  e fragmentos com rotas próprias (escopo maior, ganho de "componente" já atendido
  pelos partials).
- **2026-08-24 — Cura (HP × custo):** fragmento do Center mostra HP atual/máx por
  membro + **custo total antecipado** via `HealService#preview_cost` (expõe o
  `HealCostPolicy` 0.5/HP sem mutar); botão Curar `disabled` quando custo 0 (já
  curado) ou saldo < custo.
- **2026-08-24 — Compra (stock × saldo):** fragmento do Mart mostra por item **preço +
  quantidade comprável** (`saldo/preço`, inteiro, ex. "×5"); botão `disabled` quando
  saldo < preço; inventário com quantidades preservado.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + SESSIONS.md (S4) | commit `Sessao 0047: refinamento concluido — JN-4 componentes de Mart/Center, criterios e plano TDD fechados` |
| 1 | Center: testes falham (custo antecipado + botão desabilitado quando curado/insuficiente) → `HealService#preview_cost` + `center_data` em `server.rb` + `views/_center.erb` (absorve `team_hp.erb`, removido) + `team.erb` renderiza o partial | suíte verde + lint 0, commit `Passo 1:` |
| 2 | Mart: testes falham (qtd comprável + botão desabilitado quando saldo < preço) → `views/_mart.erb` + `team.erb` renderiza o partial | suíte verde + lint 0, commit `Passo 2:` |
| 3 | Docs: REQUIREMENTS (roadmap/status) + SESSIONS (tabela + "Próxima sessão") | suíte verde + lint 0, commit `Passo 3:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Concluída em 2026-08-24 — validada pelo usuário** *(S2: uma linha por critério).*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 — Center em partial com custo antecipado | `test/team_routes_test.rb` (`test_center_fragment_shows_heal_cost_upfront` + regressão `test_team_fragment_shows_poke_center_with_hp_and_heal_button`) | `/`: com jornada + poke de HP baixo, painel do time mostra HP atual/máx + custo total antes de curar | **ok** |
| C2 — Curar desabilitado quando curado/insuficiente | `test/team_routes_test.rb` (`test_center_fragment_disables_heal_when_cured`, `test_center_fragment_disables_heal_when_insufficient_balance`) | `/`: time curado ou saldo baixo → botão Curar desabilitado | **ok** |
| C3 — Mart em partial com qtd comprável | `test/mart_routes_test.rb` (`test_mart_fragment_shows_affordable_quantity` + regressão `test_mart_fragment_shows_catalog_inventory_and_balance`) | `/` com saldo: item mostra preço × qtd comprável (ex. "Pocao — 20 ×5") | **ok** |
| C4 — Comprar desabilitado quando saldo < preço | `test/mart_routes_test.rb` (`test_mart_fragment_disables_buy_when_insufficient_balance`) | `/` com saldo < 20: botão de compra desabilitado | **ok** |
| C5 — Heal/buy inalterados | `test/team_routes_test.rb` (`test_team_heal_cures_team_and_charges_wallet`) + `test/mart_routes_test.rb` (`test_mart_buy_debits_wallet_and_adds_to_inventory`) + suíte completa (724/2329, lint 0) | curar e comprar funcionam; notices e saldo corretos | **ok** |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

- **Validada pelo usuário em 2026-08-24 (C1–C5 ok, sem ajustes S3).**
- `test_team_fragment_omits_heal_button_for_empty_team` e o gate de jornada
  (`test_heal_blocked_before_journey`, `test_mart_buy_blocked_before_journey`)
  seguem válidos como regressão — as guardas `@journey_started`/`@team.empty?` no
  `team.erb` são preservadas.
- `HealService#preview_cost` é aditivo (attr público), sem alterar `heal`.
- Próximas da fila (anotadas): JN-5 (gameloop), J2 (personalização), J4 (a definir),
  D4 (draft temático) e P2 (perf da 1ª batalha ~2min).