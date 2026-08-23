# Sessão 0039 — JN-1: telas próprias (fim do empilhamento)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisão do usuário em 2026-08-22 (prioridade urgente; modelo A — páginas próprias por tela) |
| Implementação | **Concluída** — passos 1–6 em 2026-08-22 (suíte 626/2017, lint 0) |
| Validação | **Done** — executada pelo usuário em 2026-08-22 (tabela da seção 7) |

---

## 1. Objetivo

Cada área vira uma **tela própria com rota e página dedicadas** — Lista (`GET /`),
Time (`GET /team`), Batalha (`GET /battle`), Histórico (`GET /history`) — navegada
por links reais no nav (com estado ativo), eliminando os 5 painéis empilhados do
`index.erb`. htmx fica restrito às interações dentro de cada tela. Zero mudança de
regra de negócio/domínio.

## 2. Contexto (estado atual — diagnóstico)

- `views/index.erb`: 5 `<div>` empilhados — `#pokemon-list`, `#pokemon`, `#team`
  (auto-load `hx-trigger="load, teamRefresh from:body"`), `#battle`, `#history`.
- `views/layout.erb`: nav com âncoras `hx-get` para alvos diferentes + hack
  `<span hx-trigger="click from:#nav-lista">` limpando só `#history`.
- Todas as rotas de conteúdo renderizam fragmento com `layout: false`; existem
  rotas de limpeza `/pokemon/close`, `/battle/close`, `/history/close`.
- `POST /battle/play` devolve o fragmento para `#battle`; ações do time retornam
  `team.erb` para `#team`; `HX-Trigger: teamRefresh` emitido ao fim de batalha com
  evolução (server.rb).
- `POST /team` retorna o fragmento inteiro do time — sem sentido com telas
  separadas.
- Testes fixam o modelo atual: alvos `#team`/`#pokemon`/`#battle`,
  `refute_includes "<html"` nas rotas que virarão páginas, asserts do span hack e
  das rotas `_close`.

## 3. Escopo

### Produção

- `views/layout.erb` — nav com links reais (`/`, `/team`, `/battle`, `/history`)
  e classe `active` conforme `request.path`; span hack removido.
- Páginas com layout: `GET /team` → `team_page.erb`; `GET /battle` →
  `battle_page.erb`; `GET /history` → `history_page.erb` (embutem os fragmentos
  atuais). `GET /` reescrito como página exclusiva da Lista (busca, paginação,
  Iniciais, pool, detalhe interno em `#pokemon-detail`).
- Alvos locais: time → `#team-view` (heal/buy/manage/move/remove), batalha →
  `#battle-view` (play), lista → `#pokemon-detail` + `#add-status`.
- `POST /team` passa a retornar mini-fragmento de status (`team_add_result.erb`)
  usando notice/kind já existentes.
- Remoções: span hack, `GET /battle/close`, `GET /history/close`, evento
  `teamRefresh`. `/pokemon/close` permanece (interação interna da Lista).

### Testes

- Adaptar alvos (`#team-view`, `#battle-view`, `#pokemon-detail`, `#add-status`);
  páginas completas passam a assertar layout/nav; testes do SPA único (span hack,
  `_close` battle/history, auto-load do time) são removidos ou viram 404; testes
  de negócio existentes seguem verdes com alvos renomeados.

### Fora de escopo (não abrir)

- Ondas 1–3 restantes (contador n/6, barras HP/PP, partial/presenter de batalha,
  grid responsivo), J3/JN-4/J4/D4, domínio/services/repos, identidade.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 — Nav real com estado ativo por rota** (sem `hx-get`; classe `active`
      no link corrente) — prova: `test/pokemon_routes_test.rb` (layout via `GET /`)
      + teste de página por rota em `test/team_routes_test.rb`,
      `test/battle_routes_test.rb`, `test/history_routes_test.rb`.
- [ ] **C2 — Páginas próprias completas**: `GET /team`, `GET /battle`,
      `GET /history` renderizam com layout o conteúdo da área — prova: mesmos
      testes de página de C1.
- [ ] **C3 — `GET /` mostra somente a Lista** (sem `id="team"`/`"battle"`/
      `"history"` empilhados; detalhe interno preservado) — prova:
      `test/pokemon_routes_test.rb`.
- [ ] **C4 — Interações intra-tela funcionam**: heal/buy/manage/move/remove →
      `#team-view`; play → `#battle-view`; add → status local em `#add-status`
      — prova: testes existentes dos fluxos adaptados.
- [ ] **C5 — Mecanismos do SPA único removidos**: `GET /battle/close` e
      `GET /history/close` retornam 404; sem span hack nem `teamRefresh` —
      prova: novos asserts de 404 nos arquivos de rota correspondentes.

### Garantias (RNF)

- [ ] Suíte completa verde com baseline preservado (624 runs / 2006 asserts ±
      ajustes desta sessão) e lint 0 em todo green; commit por passo; 0 regressão
      de negócio.
- [ ] Sem gems novas / sem schema / sem rede em testes / sem `rubocop:disable`.
- [ ] Docs no passo docs; status de validação só após o usuário validar (S4/S2).

> **S1:** cada critério aponta o teste que o prova; sem teste → `manual` explícito.

## 5. Decisões de refinamento (fechadas com o usuário)

- **2026-08-22 — JN-1 urgente** (usuário): entra no lugar de J3/ondas; fila volta
  depois.
- **2026-08-22 — Modelo A (páginas próprias)** sobre B (SPA com troca total):
  mata o empilhamento pela estrutura; estado ativo nativo no nav (antecipa item
  da onda 3); htmx restrito ao intra-tela.
- **2026-08-22 — Add na lista retorna mini-status local** (`#add-status`);
  alternativa preterida: redirecionar para a tela Time.
- **2026-08-22 — Limpezas mortas removidas**: span hack, `battle/close`,
  `history/close`, `teamRefresh`; `/pokemon/close` permanece.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (S4) | commit `Sessao 0039: refinamento concluido — ...` |
| 1 | C1 — nav real + estado ativo (layout.erb + helper de path) | suíte verde + lint 0, commit `Passo 1:` |
| 2 | C2/C4(Time) — `GET /team` página própria; alvos internos `#team-view` | suíte verde + lint 0, commit `Passo 2:` |
| 3 | C3/C4(Lista) — index só Lista; add → status local; detalhe `#pokemon-detail` | suíte verde + lint 0, commit `Passo 3:` |
| 4 | C2/C4(Batalha) — `GET /battle` página; play → `#battle-view`; fim do `teamRefresh` | suíte verde + lint 0, commit `Passo 4:` |
| 5 | C2(Histórico)/C5 — `GET /history` página; remoção `_close`/span hack (404s) | suíte verde + lint 0, commit `Passo 5:` |
| 6 | **Docs:** REQUIREMENTS.md, SESSIONS.md, draft-auto-battler.md | suíte verde + lint 0, commit `Passo 6:` |
| — | **Fase 2 concluída** → **PARAR** para validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Concluída em 2026-08-22 — validada pelo usuário** *(S2: uma linha por critério).*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 nav ativo | `./scripts/test -n /nav|active/` | link da tela corrente destacado ao navegar | ok |
| C2 páginas próprias | `./scripts/test -n /page/` | cada âncora do nav abre sua tela, sem acúmulo | ok |
| C3 lista pura | `./scripts/test -n /index/` | `GET /` não mostra time/batalha/histórico | ok |
| C4 interações locais | `./scripts/test -n /heal|buy|play|moves|add/` | fluxos funcionam dentro de cada tela | ok |
| C5 limpezas removidas | `./scripts/test -n /404|not_found/` | navegar não deixa painéis residuais | ok |

> **S3:** ajuste = reabrir o critério, registrar alteração e obter nova aprovação.

## 8. Observações

- Sessão fora da fila (urgência do usuário, 2026-08-22); após validação, fila
  retoma em **J3** → **JN-1 restantes? (esta sessão esgota JN-1)** → ondas 1–3 de
  UX a critério → organizar o resto.
- Maior churn esperado em `test/pokemon_routes_test.rb` e
  `test/team_routes_test.rb` (asserts de alvo/layout).
