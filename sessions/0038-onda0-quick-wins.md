# Sessão 0038 — Onda 0 UX: quick wins de acessibilidade, feedback e copy

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisão do usuário em 2026-08-22 (priorizar UX; Onda 0 do `draft-ui-ux.md` §5 no lugar de J3) |
| Implementação | **Pendente** |
| Validação | **Pendente** (executada pelo usuário) |

---

## 1. Objetivo

Entregar a **Onda 0 de quick wins de UI/UX**: acessibilidade mínima nos sprites/botões,
lazy loading das imagens da listagem, evoluções do detalhe viram links, copy unificada
em pt-BR com hierarquia visual de notices e indicador global de carregamento htmx —
só view/CSS/handlers leves, sem regra de negócio nova.

## 2. Contexto (estado atual — diagnóstico)

- Sprites **sem `alt`**: `pokemon_detail.erb:1` (principal) e `:15` (evoluções),
  `team.erb:35`, `team_manage.erb:9`, `pokemon.erb:10`. Com `alt`: `battle.erb`
  e `pokemon_list_item.erb`.
- Botões ▲▼ sem `aria-label`: `team.erb:45,52` e `team_manage.erb:79,86`.
- Nenhuma imagem com `loading="lazy"` (27 iniciais + pool paginado + detalhes).
- Evoluções do detalhe são texto+sprite **sem link** (`pokemon_detail.erb`,
  bloco `.evolutions`) — `Pokemon` tem `number`, e `GET /pokemon/:poke_id` existe
  (mesmo alvo `#pokemon` dos itens da lista).
- Copy EN: "Filter by name" (`index.erb` placeholder), "Add to Team"
  (`pokemon_detail.erb`, `pokemon.erb`, `pokemon_list_item.erb`), "Remove from Team"
  (`team.erb`) — 3 testes fixam essa string (`test/pokemon_routes_test.rb:290`,
  `test/team_routes_test.rb:168,249`).
- Notices: `<p class="notice">` único estilo (vermelho) para tudo — avisos neutros
  parecem falha (`views/history.erb:4`, `error.erb:1`, `battle.erb:2`, `team.erb:2,30`,
  `pokemon_list.erb:2`, `team_manage.erb:2`). CSS em `public/style.css` (servido em
  `/style.css` pelo layout).
- Sem indicador de carregamento em nenhum request htmx (`layout.erb` não tem
  `hx-indicator` nem CSS de progresso).
- Fixture de cadeia de evolução já existe em `test/pokemon_routes_test.rb` (~linha 92);
  `GET /` renderiza o layout (caminho para testar markup global).

## 3. Escopo

### Produção

- `views/` — `alt="<nome>"` nos sprites sem alt; `aria-label` nos ▲▼;
  `loading="lazy"` nas imagens de lista/evoluções/time (não no herói do detalhe);
  evoluções viram `<a hx-get="/pokemon/<number>" hx-target="#pokemon">`;
  copy pt-BR ("Adicionar ao time", "Remover do time", "Filtrar por nome");
  notices ganham variante `notice--info|notice--success|notice--error`
  (default info; `error.erb` → erro; gate pré-jornada/vazios → info).
- `server.rb` — handlers marcam `@notice_kind = :error|:success` onde a severidade é
  inequívoca (validações de golpes/time cheio/duplicado/saldo → erro; cura/compra
  bem-sucedida → sucesso); demais seguem default info.
- `public/style.css` — estilos das variantes de notice + barra global de progresso.
- `views/layout.erb` — elemento fixo de progresso + listener mínimo dos eventos htmx
  (`htmx:beforeRequest/afterRequest`) alternando a barra (script de 3 linhas).

### Testes

- `test/pokemon_routes_test.rb`, `test/team_routes_test.rb`,
  `test/team_manage_test.rb` — asserts novos/atualizados (alt/lazy/aria/links de
  evolução/copy/classes de notice); 3 asserts de "Remove from Team" migram para
  "Remover do time"; teste de layout via `GET /`.

### Fora de escopo (não abrir)

- Ondas 1–3 do draft (contador n/6, barras HP/PP, partial de batalha, nav ativo/grid),
  JN-1/JN-4/J3/J4, mudança de rotas/contratos, design system além das variantes de
  notice + barra de progresso, responsividade/grid.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 — Todos os sprites têm `alt` descritivo e os botões ▲▼ têm `aria-label`;
      imagens repetidas usam `loading="lazy"`** — prova: `test/pokemon_routes_test.rb`
      (alt no detalhe), `test/team_routes_test.rb` + `test/team_manage_test.rb`
      (alt/aria no time e manage), assert de `loading="lazy"` na listagem.
- [ ] **C2 — Evoluções do detalhe são links** para `GET /pokemon/:number`
      (alvo `#pokemon`, mesmo padrão da listagem) — prova: `test/pokemon_routes_test.rb`
      (detalhe com cadeia fixture renderiza `hx-get="/pokemon/<number>"` por evolução).
- [ ] **C3 — Copy unificada em pt-BR** ("Adicionar ao time", "Remover do time",
      "Filtrar por nome") — prova: asserts atualizados em
      `test/team_routes_test.rb`/`test/pokemon_routes_test.rb` +
      novo assert do placeholder em `test/pokemon_routes_test.rb`.
- [ ] **C4 — Hierarquia de notices**: variantes `info/success/error` visíveis
      (classe correta no error page, no gate pré-jornada e num fluxo de sucesso)
      — prova: `test/pokemon_routes_test.rb` ou `test/team_routes_test.rb`
      (classes `notice--error`, `notice--info`, `notice--success` nos renders correspondentes).
- [ ] **C5 — Indicador global de carregamento presente no layout** (elemento fixo +
      CSS + gatilho pelos eventos htmx) — prova: `test/smoke_test.rb` ou
      `test/pokemon_routes_test.rb` via `GET /` (markup/CSS class no body do layout).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (614 runs / 1952 asserts) +
      novos testes** e lint 0 em todo green; commit obrigatório por passo; 0 regressão.
- [ ] Sem gems novas / sem mudança de schema / testes sem rede / sem `rubocop:disable`.
- [ ] `REQUIREMENTS.md` + `SESSIONS.md` + `draft-ui-ux.md` atualizados no passo docs;
      status de validação só após o usuário validar (S4/S2).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste automatizado →
> escrever `manual` explícito + a evidência manual esperada.

## 5. Decisões de refinamento (fechadas com o usuário)

- **2026-08-22 — Priorizar UX antes de J3/JN-1** (usuário): a nota do draft
  ("ondas depois da fila fechada") é superssedada; fila volta depois com J3 → JN-1.
- **2026-08-22 — Onda 0 inteira numa única sessão** (itens §5 do draft-ui-ux).
- **2026-08-22 — Indicador global via eventos htmx** (barra fixa + script mínimo no
  layout); alternativa rejeitada: `hx-indicator` por elemento (invasivo nos fragmentos).
- **2026-08-22 — Severidade de notices por `@notice_kind` nos handlers** onde
  inequívoca; default `info` (alternativa rejeitada: inferir severidade por regex na
  mensagem — frágil).
- **2026-08-22 — pt-BR:** "Adicionar ao time", "Remover do time", "Filtrar por nome".

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (S4) | commit `Sessao 0038: refinamento concluido — ...`; `./scripts/checar-sessao 0038` + `./scripts/check_docs` |
| 1 | C1 — alt/aria-label/lazy (red: asserts novos → green nas views) | suíte verde + lint 0, commit `Passo 1:` |
| 2 | C2 — evoluções linkadas no detalhe | suíte verde + lint 0, commit `Passo 2:` |
| 3 | C3+C4 — copy pt-BR + variantes de notice (views/style.css/@notice_kind) | suíte verde + lint 0, commit `Passo 3:` |
| 4 | C5 — indicador global (layout + CSS) | suíte verde + lint 0, commit `Passo 4:` |
| 5 | **Docs:** `REQUIREMENTS.md` (roadmap — onda 0 executada), `SESSIONS.md`, `draft-ui-ux.md` (itens da onda 0 marcados) | suíte verde + lint 0, commit `Passo 5:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 alt/aria/lazy | `./scripts/test -n /alt|aria_label|lazy/` | sprites com texto alternativo; ▲▼ anunciados por leitor de tela; lista carrega sob demanda | |
| C2 evoluções linkadas | `./scripts/test -n /evolution.*link|evolutions_linked/` | clicar numa evolução abre o detalhe dela | |
| C3 copy pt-BR | `./scripts/test -n /remover_do_time|adicionar_ao_time|filtrar/` | nenhum botão/placeholders em EN | |
| C4 notices hierárquicos | `./scripts/test -n /notice--(error|info|success)/` | aviso neutro não aparece mais como vermelho de erro | |
| C5 indicador global | `./scripts/test -n /loading|indicator/` | barra de progresso aparece durante requests htmx | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

- Sessão fora da fila anterior (decisão do usuário em 2026-08-22); após validação,
  voltar à fila: **J3 → JN-1** (ondas 1–3 de UX podem ser encaixadas a critério).
- Tokens visuais necessários anotados em `draft-design-system.md` (usar só o mínimo
  para notices/barra).
