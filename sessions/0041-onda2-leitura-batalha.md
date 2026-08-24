# Sessão 0041 — Onda 2 UX: leitura da batalha

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-23 |
| Implementação | **Concluída** — passos 1–5 em 2026-08-23 (suíte 680/2132, lint 0) |
| Validação | **Pendente** (executada pelo usuário) |

---

## 1. Objetivo

Entregar a **Onda 2 de leitura da batalha** (`draft-ui-ux.md` §5, alvo em
`docs/screens/battle.md`): fim da duplicação dos painéis Seu Time/Oponente via
**partial único** + **presenters puros** (`FighterPresenter`/`BattleLogPresenter`),
**barras visuais de HP e PP** por lutador/golpe, **log com as últimas 3 rodadas**
(mais recente no topo) e **indicador de carregamento local no botão Jogar**.
Só view/presenter/CSS + um atributo de domínio mínimo (`Move#pp_max`) — nenhuma
regra de negócio nova, nenhum contrato de rota alterado.

## 2. Contexto (estado atual — diagnóstico)

- `views/battle.erb:7-47` **duplica o painel de lutador** — o bloco "Seu Time"
  (`@engine.teams[0]`) e "Oponente" (`@engine.teams[1]`) são o mesmo loop/markup
  copiado; só diferem em dados (o do jogador acrescenta itens atribuído/segurável
  e o bloco de estoque `@engine.items`).
- HP e PP são **apenas texto** (`"HP 150/200"`, `"PP 30"`) — sem barra visual;
  tokens das barras já anotados em `draft-design-system.md` §3 (alta ≥50% verde
  `#2e7d32`, média 20–49% âmbar `#b26a00`, baixa <20% vermelho `#b00`; trilha
  `#eee`, raio 4px, altura 8px HP / 6px PP).
- O **log mostra só a rodada corrente** (`battle.erb:49` filtra
  `entry[:round] == @engine.rounds`) — o histórico completo existe em `@engine.log`
  (por `round`, `attacker`, `move`/`move_type`, `damage`, `ko`, `attacker_name`,
  `target_name`; ações `:item` com `item`/`healed`) e se perde na UI.
- `Move` (Dry::Struct) guarda apenas `pp` (atual); **não há `pp_max`** para a barra
  de PP. `BattlePokemon#use_move` decrementa via `move.new(pp: ...)`, que preserva
  os demais atributos automaticamente.
- Botão Jogar é `hx-post="/battle/play"` sem indicador próprio; a barra global
  (`#global-loading`, Onda 0) já cobre todos os requests htmx.
- Nenhum presenter existe hoje em `lib/`; o draft de padrões prevê
  `BattleLogPresenter`/`FighterPresenter` (`draft-arquitetura-design-patterns.md`,
  seção Presenter). Testes de batalha em `test/battle_routes_test.rb`
  (649 runs/2063 asserts, lint 0 — baseline verde).

## 3. Escopo

### Produção

- `lib/fighter_presenter.rb` (novo) — PORO **puro** (sem rede/PG): formata a linha
  do lutador a partir de um `BattlePokemon` (nome, nível, sprite com `alt`, HP
  corrente/máx + percent + tier alta/média/baixa, moves com PP corrente/máx +
  percent + tier, itens atribuído/segurável com display name via `ItemCatalog`).
- `lib/battle_log_presenter.rb` (novo) — PORO **puro**: a partir de `engine.log`
  devolve as últimas **N=3** rodadas, **mais recente no topo**, com linhas
  formatadas (lado "Seu Time"/"Oponente", atacante, golpe/item, dano/cura, KO).
- `lib/move.rb` — atributo `pp_max` (Coercible::Integer, **default = pp** quando
  ausente), preservado em `use_move` (Dry::Struct `.new` mantém atributos).
- `views/_fighter_panel.erb` (novo) — **partial único** de painel de lutador,
  consumido para Seu Time e Oponente; renderiza `FighterPresenter` por membro com
  barras `hp-bar`/`pp-bar`.
- `views/battle.erb` — usa o partial nos dois painéis (fim da duplicação; estoque
  `@engine.items` e itens atribuído/segurável continuam no painel do jogador);
  log via `BattleLogPresenter` (últimas 3 rodadas, mais recente no topo); botão
  Jogar ganha `hx-indicator` local.
- `public/style.css` — estilos das barras (`bar-hp`/`bar-pp`, trilha, tiers) e do
  indicador local do botão.
- Textos de contrato preservados: "Seu Time"/"Oponente", "Rodada N", "HP x/y",
  "Nível N", "PP N", "Itens:", "×N", "usou X em", "+N HP", "Vencedor:",
  `hx-post="/battle/play"`, `hx-target="#battle-view"`.

### Testes

- `test/fighter_presenter_test.rb` (novo) — formatação da linha, percent/tier de
  HP e PP, itens.
- `test/battle_log_presenter_test.rb` (novo) — últimas N=3 rodadas, ordem
  (mais recente no topo), formatação de ataque e de item.
- `test/move_test.rb` — asserts de `pp_max` (default = pp; preservado no
  `use_move`).
- `test/battle_routes_test.rb` — asserts de markup: barras `hp-bar`/`pp-bar` com
  `style="width: N%"` e tier nos **dois** painéis; log com rodadas anteriores após
  vários plays; `hx-indicator` no botão Jogar; textos de contrato preservados.

### Fora de escopo (não abrir)

- Ondas 1 (contador n/6, strip de sprites) e 3 (grid responsivo) do
  `draft-ui-ux.md`; JN-3/JN-4/JN-5/J2/J4/D4; P2 (perf da 1ª batalha ~2min).
- Mudança de rotas/contratos de `BattleEngine`/`BattleService`/gateway.
- Agrupamento de recompensas do fim de batalha (XP+dinheiro já saem na mesma
  linha em `battle.erb:68`); evolução/aprendizado continuam como listas próprias.
- Histórico de log além de 3 rodadas; persistir/derivar `pp_max` na gateway
  (o default `pp` no `Move` cobre sem tocar `PokeApiMoves`).

## 4. Critérios de aceite

### Resultado

- [ ] **C1 — `FighterPresenter` (lib/, puro) formata a linha do lutador**: nome,
      nível, sprite com `alt`, HP (`hp_current`/`hp_max` + `hp_percent` +
      `hp_tier` alta/média/baixa), moves (`name`, PP corrente/máx + `pp_percent` +
      `pp_tier`), itens atribuído/segurável com display name — prova:
      `test/fighter_presenter_test.rb`.
- [ ] **C2 — `Move#pp_max`** com default = `pp` quando ausente, preservado em
      `use_move` — prova: `test/move_test.rb`.
- [ ] **C3 — Painéis Seu Time/Oponente usam o partial único `_fighter_panel.erb`**:
      ambos renderizam a linha de lutador compartilhada com barras visuais
      `hp-bar`/`pp-bar` (width percentual + tier class) — prova:
      `test/battle_routes_test.rb` (barras com `style="width: N%"` e tier nos dois
      painéis; textos de contrato preservados). *Ajuste S3 (2026-08-23): layout em
      3 colunas em tela cheia — Seu Time à esquerda, controles centralizados + log
      ao centro, Oponente à direita.*
- [ ] **C4 — Log exibe as últimas 3 rodadas, mais recente no topo** — prova:
      `test/battle_log_presenter_test.rb` (ordem/limite/formatação) +
      `test/battle_routes_test.rb` (após vários plays, o fragmento contém entradas
      de rodadas anteriores à corrente).
- [ ] **C5 — Botão Jogar com `hx-indicator` local** (indicador de carregamento
      próprio, além da barra global) — prova: `test/battle_routes_test.rb`.

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (649 runs/2063 asserts)** +
      novos testes e lint 0 em **todo** green; commit obrigatório por passo; 0 regressão.
- [ ] Sem gems novas / sem mudança de schema / testes sem rede / sem `rubocop:disable`.
- [ ] `REQUIREMENTS.md` + `SESSIONS.md` + `draft-ui-ux.md` (Onda 2 marcada) +
      `draft-design-system.md` (barras usadas) atualizados no passo docs; status de
      validação só após o usuário validar (S4).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste automatizado →
> escrever `manual` explícito + a evidência manual esperada.

## 5. Decisões de refinamento (fechadas com o usuário)

- **2026-08-23 — Próxima sessão = Onda 2 UX (leitura da batalha)** — preteridos:
  Onda 1 (jornada visível), Onda 3 (grid), JN-4, P2 (perf), JN-5.
- **2026-08-23 — Presenters puros em `lib/`** (`FighterPresenter` +
  `BattleLogPresenter`, PORO sem rede, testáveis direto — S1) — preterido: só
  partial + helpers inline no ERB.
- **2026-08-23 — Log das últimas 3 rodadas (N=3), mais recente no topo** —
  preterido: log completo ilimitado.
- **2026-08-23 — Barras de HP (por membro) e PP (por golpe)**, seguindo os tokens
  do `draft-design-system.md` §3 (alta/média/baixa; trilha #eee) — preterido: só HP.
- **2026-08-23 — `hx-indicator` local no botão Jogar** além da barra global —
  preterido: manter só a barra global.
- **2026-08-23 — `Move#pp_max` com default = pp** (necessário p/ a barra de PP);
  preservado no `use_move` via Dry::Struct — sem tocar `PokeApiMoves`/gateway.
- **2026-08-23 — Ajuste S3 na validação (layout da batalha):** reabre o **C3** —
  os painéis passam de empilhados (Seu Time acima, Oponente abaixo, botão embaixo)
  para **3 colunas** em tela cheia: **Seu Time à esquerda** (+ estoque Itens:),
  **controles centralizados (Jogar/Novo confronto) + log ao centro** e **Oponente à
  direita**. Alteração registrada com data; reaprovação do usuário pendente após o
  ajuste. *(2ª revisão: Seu Time na esquerda em vez da direita; botão Jogar
  centralizado.)*

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (S4) | commit `Sessao 0041: refinamento concluido — ...`; `./scripts/checar-sessao 0041` + `./scripts/check_docs` |
| 1 | C2 — `Move#pp_max` (default = pp; preservado no `use_move`) | suíte verde + lint 0, commit `Passo 1:` |
| 2 | C1 — `FighterPresenter` (linha do lutador: HP/PP percent+tier, itens) | suíte verde + lint 0, commit `Passo 2:` |
| 3 | C4 (parte 1) — `BattleLogPresenter` (últimas 3 rodadas, mais recente no topo, formatação ataque/item) | suíte verde + lint 0, commit `Passo 3:` |
| 4 | C3 — `_fighter_panel.erb` + `battle.erb` usando o partial nos dois painéis + barras `hp-bar`/`pp-bar` + `style.css` | suíte verde + lint 0, commit `Passo 4:` |
| 5 | C4 (parte 2) + C5 — `battle.erb` log via `BattleLogPresenter` (3 rodadas) + `hx-indicator` no botão Jogar | suíte verde + lint 0, commit `Passo 5:` |
| 6 | **Docs:** `REQUIREMENTS.md` (roadmap — Onda 2 executada), `SESSIONS.md`, `draft-ui-ux.md` (Onda 2 marcada), `draft-design-system.md` | suíte verde + lint 0, commit `Passo 6:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 FighterPresenter | `./scripts/test test/fighter_presenter_test.rb` | — (domínio puro) | |
| C2 Move#pp_max | `./scripts/test -n /pp_max/` | — (domínio puro) | |
| C3 partial único + barras | `./scripts/test test/battle_routes_test.rb` | abrir `/battle`: Seu Time e Oponente com barras de HP/PP; código sem loop duplicado | |
| C4 log últimas 3 rodadas | `./scripts/test test/battle_log_presenter_test.rb` | jogar 3+ rodadas: log mostra as 3 mais recentes, atual no topo | |
| C5 hx-indicator no Jogar | `./scripts/test -n /hx_indicator/` | botão Jogar mostra carregamento próprio durante o round | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

- Fila: após a 0041, restam Onda 1, Onda 3 (grid), JN-3, JN-4, JN-5, J2, J4, D4 e a
  perf da 1ª batalha (P2) como candidatas — a critério do usuário.
- Barras seguem os tokens já anotados (`draft-design-system.md` §3); thresholds de
  tier (≥50 / 20–49 / <20) são heurística do draft — ajuste reabre critério via S3.
- `Move#pp_max` é adição mínima de domínio; a gateway (`PokeApiMoves`) não muda
  (default cobre).