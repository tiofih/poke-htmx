# SESSIONS — Poke-HTMX

> **Fluxo:** cada passo de implementação é uma **sessão** (arquivo próprio em `sessions/`).
> Fonte da verdade: `REQUIREMENTS.md`.

> **Sequência rígida (RNF-04):** um passo só é iniciado quando **todas as fases do passo anterior** estiverem devidamente concluídas e validadas (red → green → refactor → validação + critérios verificados).

## Ciclo de cada sessão (SDD em fases)

Cada sessão percorre **três fases** nesta ordem. A próxima fase só começa quando a fase atual estiver concluída (cada fase marcada como `Done` no arquivo da sessão):

### 1. Refinamento (preparação)

- Ler `REQUIREMENTS.md`, o arquivo da sessão atual e `SESSIONS.md`.
- Esclarecer objetivo, escopo e **critérios de aceite** do passo.
- Registrar decisões de design (schema, gems, nomes de rotas) no arquivo da sessão.
- **Entrega:** arquivo da sessão com critérios de aceite fechados e plano TDD.
- Dúvidas em aberto → resolver antes de codar.

### 2. Implementação (TDD)

- Seguir **TDD**: `red` (teste falha) → `green` (implementação mínima, suíte verde) → `refactor`.
- **Commit obrigatório após cada green.**
- Atualizar `REQUIREMENTS.md`/`SESSIONS.md` no mesmo trabalho quando o comportamento mudar.

### 3. Validação (verificação) — executada pelo USUÁRIO

- A **validação é feita pelo usuário**. Ao terminar a fase 2 (implementação TDD, suíte
  e lint verdes), o agente **para** e aguarda o feedback do usuário — não marca fases
  como concluídas, não atualiza `REQUIREMENTS.md`/`SESSIONS.md` com status de validação
  e não commita a conclusão da sessão antes disso.
- Com o feedback em mãos, o usuário roda a **suíte completa** (Minitest) e confirma
  tudo verde.
- Verificar os **critérios de aceite** da sessão contra a implementação.
- Registrar resultados e problemas no arquivo da sessão (feito junto ao usuário).
- Atualizar `REQUIREMENTS.md` (status dos requisitos) e `SESSIONS.md` (progresso +
  próxima sessão) apenas após a validação do usuário.

---

## Próxima sessão

**Sessão 0027 (Eco-1), 0028 (Eco-2 — Poke Center) e 0029 (Eco-3 — Poke Mart)
concluídas e validadas em 2026-08-14** (0029: suíte 459/1432, lint 0).

**Sessão 0030 (Eco-4-A — itens em batalha) concluída e validada em 2026-08-17**
(0030: suíte 493/1525, lint 0 — uso automático de poções em batalha).

**Sessão 0031 (Eco-4-B — item atribuído por membro) concluída e validada em
2026-08-18** (0031: suíte 524/1599, lint 0 — estratégia selecionável via
atribuição de item por membro, decisão 12 — 2ª parte).

**Sessão 0032 (Eco-4-C — seguráveis/hold items) concluída e validada em
2026-08-18** (0032: suíte 559/1696, lint 0 — 1 slot/membro, modula Attack/Speed,
decisão 13; equipa se tiver, não consome).

**Fase Eco concluída (Eco-1..4 — sessões 0027..0032).** Próxima sessão conforme
roadmap:

> Candidatos futuros (D4, D1, J1, J2, J3) — o J2 (personalização) ampliará a UI de
> equipamento.

## Progresso das sessões

| # | Sessão | Fase | Status |
| --- | --- | --- | --- |
| 0001 | Persistir equipe em PostgreSQL (RNF-02) | Concluída | Done (passos 0–5 validados) |
| 0002 | Remoção semântica (`DELETE /team`, RF-04) | Concluída | Done (passos 0–5 validados) |
| 0003 | Equipe por usuário (sessão/cookie, RF-05) | Concluída | Done (passos 0–6 + S1, validado em 2026-08-08) |
| 0004 | Página de detalhes (tipos, stats, evoluções) | Concluída | Done (passos 0–4, validado em 2026-08-08) |
| 0005 | Navegação pela sprite + Fechar/Voltar (RF-06) | Concluída | Done (passos 0–3, validado em 2026-08-08) |
| 0006 | Paginação/filtro na listagem | Concluída | Done (passos 0–6, validado em 2026-08-08) |
| 0007 | Montagem de times — cap 6 + slots + sem duplicados (RF-07) | Concluída | Done (passos 0–9, validado em 2026-08-08) |
| 0008 | Reordenação manual de slots (RF-08) | Concluída | Done (passos 0–8, validado em 2026-08-08) |
| 0009 | Modelo de batalha (RF-09, B1) — BattlePokemon puro | Concluída | Done (passos 0–5, validado em 2026-08-08) |
| 0010 | Efetividade de tipos (RF-10, B2) — lookup puro + tabela via PokéAPI | Concluída | Done (passos 0–8, validado em 2026-08-08) |
| 0011 | Motor de auto-batalha (RF-11, B3) — BattleEngine puro 6v6 | Concluída | Done (passos 0–9, validado em 2026-08-08) |
| 0012 | Oponente automático (RF-12, B4) — OpponentGenerator puro | Concluída | Done (passos 0–5, validado em 2026-08-08) |
| 0013 | Batalha na web (RF-13, C1) — BattleEngine incremental + rotas htmx | Concluída | Done (passos 0–7, validado em 2026-08-09) |
| 0014 | UI: layout e estilos externos (RF-14, A2) — layout.erb + nav + style.css | Concluída | Done (passos 0–4, validado em 2026-08-09) |
| 0015 | Golpes/moves e PP (RF-15, D1) — Move + moves_for + BattleEngine determinístico + battle.erb | Concluída | Done (passos 0–7, validado em 2026-08-09) |
| 0016 | Logs de batalha detalhados (RF-16, C1) — entry com attacker_name/target_name + battle.erb | Concluída | Done (passos 0–3, validado em 2026-08-09) |
| 0017 | Página de gerenciamento de time (RF-17, A3) — slot + golpes persistidos + team_manage.erb | Concluída | Done (passos 0–6 + ajustes de validação, 199 runs/708 asserts, validado em 2026-08-09) |
| 0018 | Tratamento de erros (RF-18, E2) — robustez da fonte + fragmentos amigáveis 200 + handler global | Concluída | Done (passos 0–5, 222 runs/778 asserts, lint 0, validado em 2026-08-09) |
| 0019 | Respiro: refatoração de testes — remoção dos `rubocop:disable` (6 arquivos, orçamentos em `test/.rubocop.yml`, `TestSupport`/`TestDatabase`/`PokeApiStub` genérico) | Concluída | Done (passos 1–6, 222 runs/778 asserts preservados, lint 0, validado em 2026-08-10) |
| 0020 | Respiro: refatoração de produção — remoção dos 7 `rubocop:disable` de `lib/**` + `server.rb` (5 arquivos, módulos por área, suíte 222/778 + lint 0 preservados) | Concluída | Done (passos 1–6, suíte 222/778, lint 0, grep `rubocop:` em lib+server → 0, validado em 2026-08-10) |
| 0021 | E1-A: gateway da PokéAPI — interface `PokeApi` + adapter real `PokeApiHttp` + adapter fake `PokeApiFake` + injeção (`settings.api`/`PokeApi.instance`); static `lib/poke_api.rb` e `PokeApiStub.stub_singleton` removidos | Concluída | Done (passos 1–6, suíte 239/821, lint 0, grep `PokeApi\.[a-z]` em lib+server → só `PokeApi.instance`, validado em 2026-08-10) |
| 0022 | E1-B: decorator de cache TTL/LRU fixos — `PokeApiCache` (TTL 600s / máx 1000) sobre a interface `PokeApi`, remove a memoização interna do `PokeApiHttp`, `PokeApi.instance` decorado no boot | Concluída | Done (passos 1–6, suíte 256/849, lint 0, validado em 2026-08-10) |
| 0023 | D2-A: progressão persistida — `team_pokemon_progress` + `ExperienceCurve` linear + `RewardRule` no `:finished` + `BattleEngine#result` + stats escalam + oponente escala | Concluída | Done (passos 1–10, suíte 292/941, lint 0, validado em 2026-08-10) |
| 0024 | D2-B: evolução por nível + aprendizado de golpes por nível (dados oficiais da species) | Concluída | Done (passos 1–7 + hotfix, suíte 328/1025, lint 0, validado em 2026-08-10) |
| 0025 | Seeds de validação — SeedTeam parametrizável + 3 cenários prontos + rake db:seed (dados hardcoded) | Concluída | Done (passos 1–3 + ajustes de validação, suíte 337/1086, lint 0, validado em 2026-08-10) |
| 0026 | D3: histórico/rank de batalhas — `battles` + `BattleRepository` + persistência no `:finished` + `GET /history` (rank local/global) + seed `batalhas_historico` | Concluída | Done (passos 1–7, suíte 367/1172, lint 0, validado em 2026-08-13) |
| 0027 | Eco-1: moeda pós-batalha — `wallet` + `RewardRule#money_for` + `WalletRepository` + grant no hook `:finished` + aviso no `battle.erb` | Concluída | Done (passos 1–5, suíte 386/1216, lint 0, validado em 2026-08-14) |
| 0028 | Eco-2: Poke Center — HP persistente por membro + `HealCostPolicy` proporcional ao HP faltante + `WalletRepository#spend` + `HealService` + `POST /team/heal` + carryover de HP p/ a próxima batalha | Concluída | Done (passos 1–8, suíte 428/1333, lint 0, validado em 2026-08-14) |
| 0029 | Eco-3: Poke Mart — `Item` + catálogo estático + `InventoryRepository` + `MartService` + `POST /mart/buy` + bloco Poke Mart no `team.erb` + seed `saldo_inicial` | Concluída | Done (passos 1–5, suíte 459/1432, lint 0, validado em 2026-08-14) |
| 0030 | Eco-4-A: itens em batalha — `Item#heal_amount` + `BattlePokemon#heal` + `ItemUsePolicy` automática (decisão 12) + `BattleEngine` ação `:item` (half-FSM) + `InventoryRepository#use` + `POST /battle/play` debitando + `battle.erb` (branch `:item` + estoque) | Concluída | Done (passos 0–7, suíte 493/1525, lint 0, validado em 2026-08-17) |
| 0031 | Eco-4-B: item atribuído por membro — `assigned_item` persistido (0031_add_assigned_item) + `TeamRepository#assign_item` + `BattlePokemon#assigned_item` + `ItemUsePolicy` prefere o atribuído (decisão 12 — 2ª parte) + `BattleEngine` usa o atribuído + `POST /team/:id/item` + select no `team_manage.erb` + `battle.erb` (`carrega:`) | Concluída | Done (passos 0–6, suíte 524/1599, lint 0, validado em 2026-08-18) |
| 0032 | Eco-4-C: seguráveis/hold items — `Item` `stat`/`multiplier` + `ItemCatalog.can_hold` (choice-band/scarf, decisão 13) + coluna `held_item` (0032_add_held_item) + `TeamRepository#assign_held_item` + `BattlePokemon#held_item` + modulação de `stat` (motor sem mudança) + `POST /team/:id/held-item` + select "Segurável:" no `team_manage.erb` + `battle.erb` (`segura:`) + seed `team_duelo` | Concluída | Done (passos 0–6 + seed, suíte 559/1696, lint 0, validado em 2026-08-18) |

## Estrutura do arquivo de sessão

Todo arquivo em `sessions/` contém as seções:

1. **Objetivo**
2. **Critérios de aceite**
3. **Plano TDD** (passos + testes)
4. **Decisões de refinamento**
5. **Validação** (resultados da fase, suíte executada, checagem dos critérios)
6. **Observações** (impedimentos, dúvidas, próximo passo sugerido)