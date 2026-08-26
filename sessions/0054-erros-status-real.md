# Sessão 0054 — Limitação técnica: erros com status real (handler global devolve 500 em não-AJAX)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-08-26 |
| Implementação | Pendente (plano TDD fechado — ver seção 6) |
| Validação | Pendente (validação é do usuário — fase 3) |

---

## 1. Objetivo

Fechar a limitação técnica **"erros sem status real"**: o handler global de erro
(`error 500 do`) passa a devolver o **status HTTP real** — **500** — nas requisições
**não-htmx** (monitoria/healthcheck/navegação direta), mantendo o **fragmento amigável + 200**
nos swaps **htmx** (padrão do projeto desde a 0018). Resultado: a falha deixa de ficar
invisível para monitoria/healthcheck sem quebrar a UX htmx.

## 2. Contexto (estado atual — diagnóstico)

- `module ErrorHandling` (`server.rb:686-695`): `app.error 500 do` registra o erro
  (`env["sinatra.error"]`), seta `@message = "Algo deu errado. Tente novamente."`,
  `status 200` e renderiza `erb :error, layout: false`. **Sempre 200, sem distinguir o
  tipo de request** — é exatamente o ponto anotado na limitação.
- Helper **já existente** `htmx_request?` (`server.rb:482-484`):
  `request.env["HTTP_HX_REQUEST"] == "true"`. É a chave para separar os dois ramos sem
  JS novo. Várias rotas já o usam (`render_team`, `render_history`, etc.).
- `views/error.erb` (fragmento, `layout: false`): `<p class="notice notice--error"><%=
  @message || "Algo deu errado. Tente novamente." %></p>`. Mantido.
- **Teste que hoje fixa o comportamento contrário** — `test/team_routes_test.rb:412`
  `test_unexpected_error_renders_friendly_fragment_without_stack`: faz `get "/team/manage"`
  **sem** `HX-Request` e afirma `last_response.ok?` (200) + corpo "Algo deu errado" + sem
  `<html`. É esse o teste que muda de contrato no plano (vira o ramo htmx) e o contraponto
  (o novo teste de 500).
- `test/server_test_helpers.rb:53` já expõe `htmx_session(user_id)` (injeta
  `HTTP_HX_REQUEST: true`) — usar nos testes para distinguir os ramos.
- **Fora do problema:** `halt 404` (`server.rb:226`) **já** devolve 404 real
  (`render_team`/`render_history` sem `HX-Request`). Os "fragmentos amigáveis 200" **por
  rota** (PokeAPI `detail`/`moves` nil, busca vazia, etc. — decisão da 0018) são
  degradação esperada de rota, **não** o handler global; não entram nesta sessão.

## 3. Escopo

### Produção
- `server.rb` — `module ErrorHandling` (`error 500 do`): ramificar pela presença do header
  htmx (helper `htmx_request?` já existente):
  - `htmx_request?` → `status 200` + `erb :error, layout: false` (swap preservado; comportamento atual).
  - senão → `status 500` + `erb :error, layout: false` (status real para monitoria/healthcheck).
  - Log do erro original (`env["sinatra.error"]`) e `@message` **preservados** em ambos os ramos.
- `views/error.erb`: **inalterado** (fragmento já serve os dois ramos).

### Testes
- `test/team_routes_test.rb`:
  - **Atualizar** `test_unexpected_error_renders_friendly_fragment_without_stack` para usar
    `htmx_session("user-a")` e seguir afirmando `ok?` (200) + fragmento + sem `<html` — fixa o
    ramo htmx (swap preservado).
  - **Novo** `test_unexpected_error_returns_500_status_for_full_page_request`: `get
    "/team/manage", {}, user_session("user-a")` (sem `HX-Request`) → `assert_equal 500,
    last_response.status` + corpo "Algo deu errado" + `refute_includes last_response.body,
    "<html"` — fixa o ramo não-AJAX (status real).

### Fora de escopo (não abrir)
- **`halt 404` / `not_found`** — já devolve 404 real; não mexer.
- **Fragmentos amigáveis 200 por rota** (PokeAPI `detail`/`moves` nil, busca/lista vazia, etc.,
  decisão da 0018) — são degradação esperada de rota; **não** mudar o status deles.
- **Página de erro full-page estilizada** (com layout) para navegação direta — fora; mantém
  `error.erb` como fragmento (`layout: false`), mudando **apenas** o status.
- **Configurar htmx para swap em 5xx** (`htmx.config.responseHandling`/`beforeSwap`) — preterida
  (ver D1); exigiria JS no layout e tornaria a prova do swap manual.
- **Outras limitações técnicas anotadas** (escritas não atômicas, race no add, identidade/CSRF,
  estado transiente, `pry`, CI) — anotadas no `REQUIREMENTS.md`, não refinadas aqui.

## 4. Critérios de aceite

### Resultado
- [ ] **C1 (status real p/ não-AJAX):** uma requisição a rota que lança erro inesperado, **sem**
      header `HX-Request`, devolve **HTTP 500** + fragmento amigável ("Algo deu errado. Tente
      novamente.") e **sem `<html`** (corpo não vaza stack). — prova:
      `test/team_routes_test.rb` (`test_unexpected_error_returns_500_status_for_full_page_request`).
- [ ] **C2 (swap htmx preservado):** uma requisição a rota que lança erro inesperado **com**
      `HX-Request: true` devolve **HTTP 200** + fragmento amigável e **sem `<html`** — o htmx
      continua achando o conteúdo trocável. — prova: `test/team_routes_test.rb`
      (`test_unexpected_error_renders_friendly_fragment_without_stack`).
- [ ] **C3 (erro interno não vaza):** nenhum ramo expõe stack/erro no corpo (mensagem amigável
      em ambos) e o erro original continua logado (`env["sinatra.error"]`). — prova: cobertura
      das C1/C2 (`refute_includes last_response.body, "<html"` e stack ausente) + verificação
      do log no passo de implementação.

### Garantias (RNF)
- [ ] **G1:** suíte completa verde após os 2 passos + lint 0 em **todo** green; commit
      obrigatório por passo; 0 regressão fora do escopo.
- [ ] **G2:** sem gems novas / sem mudança de schema / testes sem rede; manter o padrão local de
      RuboCop em testes (se necessário, `# rubocop:disable` no escopo mínimo, sem reestruturar).
- [ ] **G3:** `SESSIONS.md` atualizado no commit do refinamento (S4); status de validação só após
      o usuário validar (fase 3 — parar na fase 2 e aguardar feedback).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste automatizado → escrever
> `manual` explícito + a evidência manual esperada.

## 5. Decisões de refinamento (fechadas com o usuário)

- **D1 (estratégia do status, 2026-08-26 — confirmada com o usuário):** status real **só** para
  requisições **não-htmx** (500); requisição **htmx** mantém **200** + fragmento (swap preservado).
  **Alternativa preterida:** devolver 500 sempre + configurar htmx (`htmx.config.responseHandling`/
  `beforeSwap`) para trocar mesmo em 5xx — mais "correto" para ambos, porém exigia JS novo no
  layout, a prova do swap viraria `manual` (enfraquece S1) e tocava o padrão deliberado da 0018.
- **D2 (contenção, 2026-08-26):** escopo **restrito ao handler global** `error 500 do`. Os
  fragmentos amigáveis 200 **por rota** (decisão da 0018) não mudam de status — são degradação
  esperada de rota, não erro global. **Alternativa preterida:** elevar todo 200 de erro para status
  real (quebraria a UX htmx deliberada e ampliaria demais o escopo desta sessão).
- **D3 (body, 2026-08-26):** manter `views/error.erb` como fragmento (`layout: false`, sem `<html>`)
  para **ambos** os ramos; mudar **apenas** o status. Uma página de erro full-page estilizada
  (com layout/nav) para navegação direta fica como refinamento futuro (fora de escopo).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados + `SESSIONS.md` (tabela + "Próxima sessão") | commit `Sessao 0054: refinamento concluido — erro com status real no handler global, criterios e plano TDD fechados` |
| 1 | **red** — `test/team_routes_test.rb`: adicionar `test_unexpected_error_returns_500_status_for_full_page_request` (plain `get`, espera 500 — hoje 200 → **vermelho**); converter `test_unexpected_error_renders_friendly_fragment_without_stack` para `htmx_session` (ramo htmx, continua 200) | suíte: 1 falha (novo 500) + demais verdes; `./scripts/test test/team_routes_test.rb -n /unexpected_error/` |
| 2 | **green** — `server.rb` `error 500 do`: `if htmx_request?` → 200 + `erb :error`; senão → `status 500` + `erb :error`; log e `@message` preservados | suíte completa verde + `./scripts/lint` 0; commit `Passo 1: handler global devolve status 500 em requisicao nao-htmx e preserva fragmento 200 no swap htmx` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

*(A preencher na fase 3 — o implementador para ao terminar a fase 2.)*

## 8. Observações

- **htmx não faz swap em resposta não-2xx por padrão** — por isso o ramo htmx deve continuar em
  200, senão o fragmento de erro não aparece na página (swap abortado). Se um dia se quiser 500 +
  swap, é preciso `htmx.config.responseHandling`/`beforeSwap` (JS) + verificação manual, o que
  foi preterido em D1.
- O teste do handler global precisa de um **stub que lance exceção dentro de uma rota real**
  (padrão da `test/team_routes_test.rb:415` — `raising_api` cujo `learnable_moves` faz `raise`).
  Sem isso a rota não cai no `error 500`.
- `htmx_session` (`test/server_test_helpers.rb:53`) já injeta `HTTP_HX_REQUEST: true` — usar para
  distinguir os ramos nos testes (não montar o header à mão).
- O log do erro original (`env["sinatra.error"]`) deve ser **preservado** — o problema era só o
  status, não o log.
- Após 0054, restam as outras limitações técnicas anotadas (escritas não atômicas, race no add,
  identidade/CSRF, estado transiente, `pry`, CI) e a fila J2/J4/D4/M2 — a critério do usuário.
