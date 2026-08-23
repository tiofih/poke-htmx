# Sessão 0037 — JN-2: gerenciamento de golpes em lista (fim dos checkboxes)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-22 (padrão lista clicável htmx; toggle na própria rota com rascunho; rascunho inicia nos golpes salvos) |
| Implementação | **Concluída** — passos 1–4 em 2026-08-22 (suíte 614/1952, lint 0) |
| Validação | **Done** — executada pelo usuário em 2026-08-22 (tabela da seção 7) |

---

## 1. Objetivo

Substituir os checkboxes de golpes do `team_manage.erb` por uma **lista clicável com
marcação** (round-trip htmx, sem JS custom), mantendo o limite de 4 golpes e a
validação/persistência da rota `POST /team/:id/moves` intocadas.

## 2. Contexto (estado atual — diagnóstico)

- `views/team_manage.erb:12-26` — por membro, um `<form hx-post="/team/<%= poke.id %>/moves">`
  com um **checkbox** `name="moves"` por golpe disponível (`@available_moves[poke.id]`,
  marcado quando `poke.moves.include?(move[:name])`) + botão "Salvar golpes".
- `server.rb` (`ServerTeamMovesActions#save_team_moves`) — recebe `Array(params[:moves])`,
  chama `settings.team_strategy.save_moves(current_user, member, selected, @available_moves)`
  e re-renderiza `team_manage.erb`.
- `lib/team_service.rb#save_moves` → `move_choice_error`: cap `MAX_MOVES_PER_POKEMON` (4)
  e disponibilidade contra `available_moves[member.id]`; persiste via
  `TeamRepository#set_moves`.
- `lib/team_service.rb#gated_moves` — alimenta `available_moves`: learnable filtrado por
  nível do membro + golpes salvos fora do gated (legados visíveis/removíveis).
- Testes que afirmam markup de checkbox hoje (`test/team_routes_test.rb`):
  `test_team_manage_renders_move_checkboxes_for_each_member`,
  `test_team_manage_checks_currently_selected_moves`,
  `test_team_manage_gates_available_moves_by_member_level`,
  `test_team_manage_higher_level_member_sees_more_learnable_moves`,
  `test_team_manage_renders_learn_level_label_in_move_checkbox`,
  `test_team_manage_keeps_saved_move_outside_learnable_visible_and_checked`,
  `test_team_manage_keeps_saved_move_above_level_visible_with_level_and_checked`.
- Testes do fluxo de salvar (cap/indisponível/persistência) em `test/team_routes_test.rb`
  (~linhas 420–511) — **não** devem mudar.

## 3. Escopo

### Produção

- `views/team_manage.erb` — bloco do formulário de golpes vira **lista clicável**:
  - cada golpe é uma linha/botão com marcação visual quando selecionado;
  - cada linha é um mini-form `hx-post="/team/<id>/moves"` com `draft=1`, o golpe
    clicado (`toggle`) e hidden inputs carregando a seleção corrente (`moves[]`);
  - form "Salvar golpes" separado, com hidden inputs da seleção final (`moves[]`),
    postando sem `draft` (caminho atual).
- `server.rb` (`ServerTeamMovesActions`) — branch para `draft=1`: computa o toggle e
  re-renderiza o manage com a seleção atualizada, **sem persistir**.
- `lib/team_service.rb` — método puro de preview/toggle (aplica toggle com cap 4 +
  disponibilidade, retorna seleção e aviso); `save_moves` inalterado.

### Testes

- `test/team_routes_test.rb` — adaptar os testes de markup listados no contexto
  (checkbox → linha clicável marcada); adicionar: toggle atualiza marcação sem
  persistir; toggle respeita o cap de 4. Stubs existentes
  (`PokeApiStub.with_learnable_moves`) continuam suficientes.

### Fora de escopo (não abrir)

- JN-1 (telas próprias), ondas de layout/UI do draft, ordenação/filtro/busca da lista
  de golpes, mudança na validação ou contrato de save, mobile-first além do mínimo,
  J3/JN-3/JN-4/JN-5/J2/J4/D4.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 — Manage renderiza lista clicável de golpes sem checkboxes**
      (linhas com marcação visual, `hx-post` da rota existente) — prova:
      `test/team_routes_test.rb` (`test_team_manage_renders_clickable_move_list_without_checkboxes`).
- [ ] **C2 — Golpes salvos do membro aparecem marcados na carga inicial**, incluindo
      legado fora do learnable e rótulo "— Nível N" quando houver — prova:
      `test/team_routes_test.rb` (`test_team_manage_marks_current_moves_in_clickable_list`,
      `test_team_manage_keeps_saved_move_outside_learnable_marked`,
      `test_team_manage_renders_learn_level_label_in_move_list`).
- [ ] **C3 — Clicar numa linha alterna a marcação via round-trip htmx sem persistir**
      (só "Salvar golpes" grava) — prova: `test/team_routes_test.rb`
      (`test_move_toggle_updates_marking_without_persisting`).
- [ ] **C4 — Toggle respeita o limite de 4** (5º clique não marca; aviso ao usuário)
      — prova: `test/team_routes_test.rb` (`test_move_toggle_respects_cap_of_four`).
- [ ] **C5 — Fluxo de salvar inalterado**: validação (cap 4, golpe indisponível) e
      persistência pela rota `POST /team/:id/moves` existente — prova: testes atuais
      de save em `test/team_routes_test.rb` verdes **sem alteração**.

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (hoje 611 runs / 1936 asserts) +
      novos testes** e lint 0 em todo green; commit obrigatório por passo; 0 regressão.
- [ ] Sem gems novas / sem mudança de schema / testes sem rede / sem `rubocop:disable`.
- [ ] `REQUIREMENTS.md` + `SESSIONS.md` + `draft-auto-battler.md` atualizados no passo
      docs; status de validação só após o usuário validar (S4/S2).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste automatizado →
> escrever `manual` explícito + a evidência manual esperada.

## 5. Decisões de refinamento (fechadas com o usuário)

- **2026-08-22 — Padrão da UI: B — lista clicável com marcação via htmx.** Alternativas
  preteridas: A (`<select multiple>` nativo — UX fraca em mobile) e C (checkboxes
  estilizados — não muda a semântica criticada pelo draft). Consistente com o padrão
  da lista clicável da J1 (sessão 0036); sem JS custom.
- **2026-08-22 — Toggle reutiliza `POST /team/:id/moves` com rascunho (`draft=1`).**
  Alternativa preterida: rota nova só para toggle — manteria dois pontos de validação.
  Rascunho não persiste; cap 4 + disponibilidade aplicados no preview.
- **2026-08-22 — Rascunho inicial = golpes salvos do membro** na carga do manage.
- Herdado de D1 (sessão 0034): rótulo "— Nível N" preservado; legados fora do
  learnable permanecem visíveis/selecionáveis.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados + `SESSIONS.md` (tabela + "Próxima sessão", S4) | commit `Sessao 0037: refinamento concluido — ...`; `./scripts/checar-sessao 0037` + `./scripts/check_docs` |
| 1 | C1/C2 — adaptar testes de renderização p/ lista clicável marcada (sem checkbox; salvos marcados; legado+rótulo) → view reescrita (rascunho inicial = salvos) | suíte verde + lint 0, commit `Passo 1:` |
| 2 | C3 — toggle sem persistir (draft=1: marcação atualiza, `set_moves` não chamado, save posterior intacto) → branch draft + preview no service | suíte verde + lint 0, commit `Passo 2:` |
| 3 | C4 — cap 4 no toggle (5º clique não marca + aviso) → enforce no preview | suíte verde + lint 0, commit `Passo 3:` |
| 4 | **Docs:** `REQUIREMENTS.md` (roadmap itens 24/25 — JN-2 executado, status `Planejada` até validação), `SESSIONS.md`, `draft-auto-battler.md` (JN-2 executado) | suíte verde + lint 0, commit `Passo 4:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Concluída em 2026-08-22 — validada pelo usuário** *(S2: uma linha por critério).*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 lista clicável sem checkbox | `./scripts/test -n /clickable_move_list/` | linhas clicáveis estilizadas em `GET /team/manage` | ok |
| C2 salvos marcados (+legado/nível) | `./scripts/test -n /marks_current_moves|outside_learnable_marked|learn_level_label_in_move_list/` | golpes já salvos aparecem marcados ao abrir o manage | ok |
| C3 toggle sem persistir | `./scripts/test -n /toggle_updates_marking_without_persisting/` | clicar alterna marcação; recarregar sem Salvar mantém os salvos | ok |
| C4 cap 4 no toggle | `./scripts/test -n /toggle_respects_cap_of_four/` | 5º clique não marca e mostra aviso | ok |
| C5 salvar inalterado | `./scripts/test -n /moves/` (testes de save atuais) | "Salvar golpes" grava; >4 ou golpe inválido mostra aviso | ok |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

- Sem bloqueios. Próxima da fila após esta sessão: **J3 (ranking S–F)** → **JN-1
  (telas próprias)** → organizar o resto (JN-3, JN-4, JN-5, J2, J4, D4).
- A lista clicável de golpes é base visual para JN-1 (telas próprias) — manter markup
  simples/reusável facilitará a extração.
