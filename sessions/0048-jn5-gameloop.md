# Sessão 0048 — JN-5: gameloop — circuito explícito por CTAs (fluxo guiado)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-25 |
| Implementação | **Concluída** — passos 1–2 verdes (suíte 727/2344, lint 0) |
| Validação | **Pendente** (executada pelo usuário) |

---

## 1. Objetivo

Tornar o **circuito fechado montagem de time → batalha → Poke Center/Poke Mart →
repete** explícito na navegação via **CTAs de fluxo guiado** — sem páginas nem rotas
novas. Ao terminar uma batalha, o painel de fim mostra os próximos passos do circuito
(curar no Poke Center → gastar no Poke Mart → novo confronto); no painel do time
pós-jornada, um CTA **Batalhar** fecha o circuito de volta à batalha. O `nav` continua
`Lista / Batalha / Histórico` (o Poke Center/Mart segue dentro do painel do time,
como no JN-4).

## 2. Contexto (estado atual — diagnóstico)

- **Nav livre** (`views/layout.erb:12-17`): `Lista / Batalha / Histórico` — sem indicar
  a ordem do circuito (montagem → batalha → curar/comprar → repete).
- **Poke Center/Mart não são páginas**: vivem como partials `_center.erb`/`_mart.erb`
  dentro do painel do time (`#team-view`) na Lista (`/`), renderizados só quando
  `@journey_started` e `@team` não vazio (`views/team.erb`). Não há rota `/mart` nem
  `/center` (decisão do JN-4, sessão 0047).
- **Fim de batalha** (`views/battle.erb`): quando `@engine.finished?`, mostra
  vencedor, XP/dinheiro, evolução/aprendizado e um único botão **"Novo confronto"**
  (`hx-get="/battle"` → `#battle-view`). Não indica os passos intermediários
  (curar/comprar) do circuito.
- **Painel do time** (`views/team.erb`): post-jornada mostra Center/Mart e o link
  "Gerenciar time"; **não há CTA explícito para ir batalhar**.
- `GET /battle` é **gated** até a jornada iniciar (`prepare_battle_fragment` →
  `journey_gate_fragment` em `server.rb:350`); `BattleService#prepare` gera o
  oponente/engrenagem.
- Testes atuais: fim de batalha em `test/battle_routes_test.rb`
  (`test_battle_end_shows_winner_and_reset_button`); painel do time / link manage em
  `test/team_routes_test.rb` (`test_team_fragment_manage_link_is_on_its_own_line`).

## 3. Escopo

### Produção

- `views/battle.erb` (branch `@engine.finished?`): substituir o botão único
  "Novo confronto" por um **bloco de circuito** — CTAs para **Poke Center** (curar)
  e **Poke Mart** (gastar), ambos levando à Lista (`/`, onde o painel do time mostra
  `_center.erb`/`_mart.erb`), seguidos do botão **"Novo confronto"** (mantido). Links
  navegacionais com `class="gameloop-cta"` (e `href="/"`), sem rotas novas.
- `views/team.erb` (branch `@journey_started`): acrescentar **CTA "Batalhar"**
  (`href="/battle"`, `class="gameloop-cta battle"`) acima do Center/Mart, fechando o
  circuito de volta à batalha. Sem rotas novas.
- `views/layout.erb`: **sem mudança estrutural** — nav permanece `Lista/Batalha/
  Histórico`. (Ordenação/agrupamento do nav fica **fora de escopo** — ver decisão.)
- `style.css`: classe utilitária `.gameloop-cta` (estilo leve de botão/link de fluxo)
  reutilizada nos CTAs; sem mudança de layout estrutural.

### Testes

- `test/battle_routes_test.rb` (ServerBattleTest): novos testes do bloco de fim de
  batalha — CTAs de circuito presentes quando `finished?` (links para Poke Center /
  Poke Mart com `class="gameloop-cta"` e `href="/"`) e botão "Novo confronto"
  mantido.
- `test/team_routes_test.rb` (ServerTeamTest): novo teste do painel pós-jornada —
  CTA "Batalhar" (`href="/battle"`, `class="gameloop-cta battle"`) presente quando
  `@journey_started`; ausente pré-jornada.
- Testes existentes servem de **regressão** (`test_battle_end_shows_winner_and_reset_button`,
  `test_team_fragment_manage_link_is_on_its_own_line`, gate de jornada).

### Fora de escopo (não abrir)

- **Sem rotas/páginas novas** (`GET /mart`, `/center`, `/battle/next` etc.) — coerente
  com a decisão do JN-4; CTAs são links de navegação.
- **Sem mudança no `OpponentGenerator`/`BattleService`** — "novo confronto respeitando
  a ordem rígida" fica anotado, fora desta sessão.
- **Sem reordenar/reagrupar o `nav`** (permanece `Lista/Batalha/Histórico`).
- Sem mudança de schema, sem gems novas, sem tocar `HealService`/`MartService`/
  `TeamService`.
- J2 (personalização), J4 (identidade), D4 (draft temático) e P2 (perf 1ª batalha)
  continuam **anotados**, fora desta sessão.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 — Fim de batalha mostra os CTAs do circuito (Poke Center + Poke Mart) além
      do "Novo confronto"** — prova: `test/battle_routes_test.rb`
      (`test_battle_end_shows_gameloop_ctas`) + regressão
      `test_battle_end_shows_winner_and_reset_button`.
- [ ] **C2 — CTAs do circuito levam à Lista (`/`, painel do time com Center/Mart) e o
      botão "Novo confronto" permanece** — prova: `test/battle_routes_test.rb`
      (assert de `href="/"` + `class="gameloop-cta"` + presença de "Novo confronto"
      no mesmo fragmento).
- [ ] **C3 — Painel do time pós-jornada ganha CTA "Batalhar" (`/battle`)** — prova:
      `test/team_routes_test.rb` (`test_team_panel_shows_battle_cta_after_journey`).
- [ ] **C4 — CTA "Batalhar" ausente antes da jornada (pré-jornada)** — prova:
      `test/team_routes_test.rb` (`test_team_panel_omits_battle_cta_before_journey`).
- [ ] **C5 — Nav e rotas inalterados** (Lista/Batalha/Histórico; sem `/mart`/`/center`)
      — prova: regressões `test_battle_page_renders_full_page_with_battle_view`,
      `test_team_page_is_removed_and_returns_404_without_htmx` + `manual` (navegar o
      circuito na UI: batalha → curar/comprar → novo confronto).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (724 runs/2329 asserts)** + novos
      testes e lint 0 em **todo** green; commit obrigatório por passo; 0 regressão.
- [ ] Sem gems novas / sem mudança de schema / sem rotas novas / testes sem rede / sem
      `rubocop:disable` novo.
- [ ] `REQUIREMENTS.md` + `SESSIONS.md` atualizados no passo docs; *status de
      validação* só após o usuário validar.

> **S1:** cada critério aponta o teste que o prova (novos testes nominais acima; os
> testes existentes atuam como regressão).

## 5. Decisões de refinamento (fechadas com o usuário)

- **2026-08-25 — Forma do gameloop (JN-5):** **fluxo guiado por CTAs**, sem páginas
  nem rotas novas. O circuito fica explícito por links de navegação: fim de batalha →
  CTAs Poke Center/Poke Mart (levam à Lista, onde `#team-view` mostra os partials) +
  "Novo confronto"; painel do time pós-jornada → CTA "Batalhar" (`/battle`).
  Preteridas: promover Mart/Center a páginas próprias (contradiz JN-4) e CTAs + ordem
  rígida no `OpponentGenerator` (escopo maior, toca BattleService — anotado).
- **2026-08-25 — Nav:** permanece `Lista/Batalha/Histórico`, **sem reordenação nem
  agrupamento** — fica fora de escopo; o circuito é comunicado pelos CTAs, não pelo
  nav.
- **2026-08-25 — "Novo confronto respeitando a ordem rígida"** (dar destino ao
  `OpponentGenerator`) fica **anotado**, fora desta sessão (RNF-04).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + SESSIONS.md (S4) | commit `Sessao 0048: refinamento concluido — JN-5 gameloop circuito por CTAs, criterios e plano TDD fechados` |
| 1 | Fim de batalha: testes falham (CTAs de circuito presentes quando `finished?`, com `href="/"` e `class="gameloop-cta"`; "Novo confronto" mantido) → bloco de circuito no `battle.erb` + `.gameloop-cta` no `style.css` | suíte verde + lint 0, commit `Passo 1:` |
| 2 | Painel do time: testes falham (CTA "Batalhar" presente pós-jornada / ausente pré-jornada) → CTA no `team.erb` + `.gameloop-cta.battle` no `style.css` | suíte verde + lint 0, commit `Passo 2:` |
| 3 | Docs: REQUIREMENTS (roadmap/status) + SESSIONS (tabela + "Próxima sessão") | suíte verde + lint 0, commit `Passo 3:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

> **Pendente** — a ser preenchida pelo usuário após a implementação (S2: uma linha por
> critério).

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 — Fim de batalha com CTAs do circuito | `test/battle_routes_test.rb` (`test_battle_end_shows_gameloop_ctas` + regressão `test_battle_end_shows_winner_and_reset_button`) | terminar uma batalha → painel de fim mostra Poke Center/Poke Mart + "Novo confronto" | — |
| C2 — CTAs levam à Lista e "Novo confronto" permanece | `test/battle_routes_test.rb` (assert `href="/"` + `class="gameloop-cta"` + "Novo confronto") | clicar "Poke Center" → painel do time (`/`) com `_center.erb`; "Novo confronto" segue funcionando | — |
| C3 — CTA "Batalhar" pós-jornada | `test/team_routes_test.rb` (`test_team_panel_shows_battle_cta_after_journey`) | `/` pós-jornada → painel do time mostra "Batalhar" | — |
| C4 — CTA "Batalhar" ausente pré-jornada | `test/team_routes_test.rb` (`test_team_panel_omits_battle_cta_before_journey`) | time < 6 → painel sem "Batalhar" | — |
| C5 — Nav/rotas inalterados | regressões `test_battle_page_renders_full_page_with_battle_view`, `test_team_page_is_removed_and_returns_404_without_htmx` + suíte completa (724+/2329+, lint 0) | circuito completo navegável na UI (batalha → curar/comprar → novo confronto) | — |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

- **Refinamento fechado em 2026-08-25** — JN-5 gameloop na forma "fluxo guiado por
  CTAs" (decisão do usuário); CTAs são links de navegação, sem rotas novas.
- **Anotado (fora desta sessão, RNF-04):** dar destino rígido ao `OpponentGenerator`
  ("novo confronto respeitando a ordem" do circuito) — a critério do usuário em sessão
  futura.
- **Bug anotado em 2026-08-25 (durante a validação, fora de critério — RNF-04):**
  "Novo confronto" **repete o time/oponente anterior**. Causa provável:
  `BattleService#build_opponent` (`lib/battle_service.rb:64`) usa
  `Random.new(user_id.sum)` — **seed determinístico por usuário** — então o
  `OpponentGenerator` produz o **mesmo oponente** a cada `prepare`, independente do
  time atual/nível. A banda (`band_for_level(average_player_level(...))`) varia, mas a
  escolha dentro da banda é determinística. Corrigir = nova sessão (TDD): gerar oponente
  novo a cada confronto ajustando a dificuldade ao time atual.
- **Ideias anotadas (2026-08-25, fora do fluxo — RNF-04):** (1) **Poke Center/Mart
  como janelas flutuantes** em vez de levar à tela de lista/time; (2) **gerenciar
  golpes no Poke Center e itens no Poke Mart**, reestruturando como gerenciamos golpes
  dos pokes — esboço: **4 selects para selecionar os golpes**. Ver `draft-ui-ux.md` /
  `draft-auto-battler.md` e o roadmap.
- Próximas da fila (anotadas): J2 (personalização), J4 (identidade legível), D4 (draft
  temático) e P2 (perf da 1ª batalha ~2min).
