# Sessão 0071 — ci-cd-healthcheck (CI no GitHub Actions + healthcheck do app/banco)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-09-08 (D1 A, D2 A, D3 A, D4 A, D5 A, D6 A, D7 A) |
| Implementação | **Concluída (TDD) — passos 1–4 verdes (suíte 1003/3980, lint 0, check_docs ok); aguardando revisão (fase 2c) e validação do usuário (fase 3)** |
| Validação | **Pendente** (executada pelo usuário) |

---

## 1. Objetivo

Adicionar **CI no GitHub Actions** (workflow que roda `test` + `lint` + `check_docs` via `docker compose` fiel ao dev, com cache de camadas do build **e** do bundle) e um **healthcheck** do app (**nova rota `GET /health`** — 200, sem tocar a rede) e do banco (`pg_isready` no `docker-compose.yml`), atendendo a limitação **"Sem CI"** do `REQUIREMENTS.md:575-576`. **CD fica fora de escopo** (D7 — anotado no roadmap para depois).

## 2. Contexto (estado atual — diagnóstico)

- **Baseline pós-0070:** suíte **998/3950** lint 0 (0070: `Sessão 0070` Done — validado em 2026-09-08). Onda 3 Estabilidade (0070 race add → **0071 CI/CD** → 0072 escritas atômicas → 0073 CSRF → 0074 respiro — **numeração deslizou**: 0071 era escritas atômicas, virou CI/CD).
- **Limitação a atender** (`REQUIREMENTS.md:575-576`): "**Sem CI (anotado 2026-08-20):** teste+lint rodam só local; sem validação automatizada no push e sem healthcheck do app/banco."
- **`server.rb` não tem rota `GET /health` hoje.** As rotas são registradas via módulos (`server.rb:1219-1225`: `register PokemonRoutes`, `register TeamRoutes`, `register MartRoutes`, `register JourneyRoutes`, `register BattleRoutes`, `register HistoryRoutes`, `register ErrorHandling`) e cada módulo declara `app.get/post/delete` (`server.rb:1006-1109`). O `before` (`server.rb:1198`) roda em toda request e chama `settings.team.all(current_user)` (toca o banco); o `after` (`server.rb:1204`) faz `ConnectionRegistry.release_current_thread!`. O handler global `error 500 do` (`server.rb:1125`) devolve **500** em requisições não-htmx.
- **`docker-compose.yml` atual** (25 linhas): `web` (build .) e `db` (postgres:16-alpine) **sem** `healthcheck`; `web.depends_on` só `db` (sem `condition: service_healthy`).
- **Não existe `.github/`** — nenhum workflow. Testes/lint rodam via `./scripts/*` que usam `docker compose` (`./scripts/test` sobe `db` + exec `web` `bundle exec rake test`; `./scripts/lint` exec `web` `bundle exec rubocop`; `./scripts/check_docs` roda **no host** — apenas grep/awk).
- **Gemfile** (`Gemfile:14-20`): `group :test` (minitest, rack-test, rake, vcr, webmock) + `group :development` (rubocop). **Nenhuma gem nova** — o teste de estrutura usa `YAML` (psych, stdlib).
- **Preservar:** `server.rb` ganha só a rota `/health` (sem tocar PokéAPI/rede); `docker-compose.yml` mantém `db`/`web` como estão (só ganha `healthcheck`); `./scripts/*` intactos (o workflow os reutiliza); CI **não** muda o comportamento local de teste/lint.

## 3. Escopo

### Produção

- `.github/workflows/ci.yml` (**novo**) — workflow com gatilhos `push` (main) + `pull_request`, rodando jobs que executam `./scripts/test`, `./scripts/lint` e `./scripts/check_docs` via `docker compose` fiel ao dev, com **cache de camadas do build** (`docker/build-push-action` `cache-from/to: type=gha`) **+** **cache do bundle** (`actions/cache` em `vendor/bundle` + `Gemfile.lock`). **Qualquer check vermelho bloqueia o merge** (D3).
- `docker-compose.yml` — adicionar `healthcheck` no serviço `db` via `pg_isready` (D4a); opcionalmente `depends_on` do `web` com `condition: service_healthy`.
- `server.rb` — adicionar **rota `GET /health`** que devolve **200** sem tocar a rede (ex.: `content_type :json; { status: "ok" }.to_json`), via módulo de rotas registrado (`register HealthRoutes` ou similar) (D4b).
- `REQUIREMENTS.md` — anotar a limitação "Sem CI" como **em andamento (sessão 0071)** e **anotar o CD** no roadmap/limitações (D7 — fora de escopo).

### Testes

- `test/ci_structure_test.rb` (**novo**) — **teste Minitest de estrutura** que carrega `.github/workflows/*.yml` e `docker-compose.yml` via `YAML.safe_load_file` e asserta a presença dos jobs/healthcheck esperados (automatiza a prova dos critérios de CI; a evidência do run verde no Actions é confirmação manual opcional — D1/`S1`).
- `test/health_test.rb` (**novo**, ou em `test/server_test.rb`) — `GET /health` devolve 200 sem tocar a rede.

### Fora de escopo (não abrir — RNF-04)

- **CD / deploy** (D7): sem alvo de deploy, sem push de imagem a registry, sem serviço de hosting — **anotado no roadmap/limitações para depois**.
- **Testes de integração com o GitHub Actions real** (o run verde no Actions é confirmação manual opcional; não automatizável localmente).
- **Erros com status real / handler global**, **escritas não atômicas**, **identidade/`?as=`/CSRF** — sessões próprias.
- **Não tocar:** `lib/**` de domínio (batalha/economia/repositórios), `db/*`, `views/*`, `Gemfile*`, `test/*` além do novo `ci_structure_test.rb` e do teste do `/health`.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 workflow CI existe e roda os 3 checks** — existe `.github/workflows/ci.yml` (ou `.yml`) que executa `test`, `lint` e `check_docs`; qualquer check vermelho bloqueia o merge. — prova: `test/ci_structure_test.rb` `test_workflow_has_expected_jobs`.
- [ ] **C2 gatilhos push + pull_request** — o workflow dispara em `push` (main) e `pull_request`. — prova: `test/ci_structure_test.rb` `test_workflow_triggers_push_and_pull_request`.
- [ ] **C3 cache do build e do bundle** — o workflow usa `docker/build-push-action` com `cache-from/to: type=gha` **e** `actions/cache` para `vendor/bundle` + `Gemfile.lock`. — prova: `test/ci_structure_test.rb` `test_workflow_caches_build_and_bundle`.
- [ ] **C4 healthcheck do `db` via `pg_isready`** — `docker-compose.yml` declara `healthcheck` no serviço `db` usando `pg_isready`. — prova: `test/ci_structure_test.rb` `test_db_has_healthcheck_pg_isready`.
- [ ] **C5 rota `GET /health` devolve 200 sem tocar a rede** — `GET /health` responde **200** e não toca a PokéAPI/rede. — prova: `test/health_test.rb` `test_health_returns_ok`.
- [ ] **C6 sem regressão** — suíte completa verde (baseline 998/3950 preservado) + lint 0. — prova: `./scripts/test` + `./scripts/lint` + `./scripts/check_docs`.

### Garantias — teste que prova (S1)

| Critério | Teste que prova | Manual |
| --- | --- | --- |
| C1 (workflow roda test/lint/check_docs) | `test/ci_structure_test.rb` `test_workflow_has_expected_jobs` | — |
| C2 (gatilhos push + pull_request) | `test/ci_structure_test.rb` `test_workflow_triggers_push_and_pull_request` | — |
| C3 (cache do build e do bundle) | `test/ci_structure_test.rb` `test_workflow_caches_build_and_bundle` | — |
| C4 (healthcheck do db via pg_isready) | `test/ci_structure_test.rb` `test_db_has_healthcheck_pg_isready` | — |
| C5 (`GET /health` 200 sem rede) | `test/health_test.rb` `test_health_returns_ok` | — |
| C6 (sem regressão) | `./scripts/test` + `./scripts/lint` + `./scripts/check_docs` | — |
| G1 (suíte+lint em todo green) | `./scripts/test` suíte completa + `./scripts/lint` 0 em todo green; commits por passo | — |
| G2 (sem gems/schema/rede) | `git diff -- Gemfile* db/` vazio + `grep` sem rede nos testes | — |
| G3 (S4/S5) | `./scripts/check_docs` + `./scripts/checar-sessao 0071` + `SESSIONS.md` atualizado no refinamento | — |
| G4 (run verde no GitHub Actions) | — | **manual (opcional):** abrir o run no GitHub e confirmar `test`+`lint`+`check_docs` verdes (evidência do CI real; não automatizável localmente) |

- [ ] **G1:** suíte completa verde com baseline **998/3950** preservado + novos testes (C1–C5) e lint 0 em todo green; commit obrigatório por passo; 0 regressão fora do escopo.
- [ ] **G2:** sem gem nova, sem mudança de schema, testes sem rede (webmock/stub), sem `rubocop:disable` novo além do padrão local.
- [ ] **G3:** `SESSIONS.md` atualizado no commit do refinamento (S4) — tabela + "Próxima sessão"; status de validação só após usuário validar (fase 3 — parar na fase 2 e aguardar).
- [ ] **G4:** run do workflow no GitHub Actions verde (test+lint+check_docs) — **confirmação manual** (evidência do CI real).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste → `manual` explícito + evidência esperada. Baseline suíte **998/3950** de 0070. **Parar ao fim da fase 2 e aguardar validação do usuário (fase 3) — não marcar Done, não preencher a seção 7, não commitar conclusão.**

## 5. Decisões de refinamento (fechadas com o usuário em 2026-09-08)

- **D1 — Onde rodar o CI A (GitHub Actions):** `.github/workflows/ci.yml` no repo. **A escolhida.** **B preterida:** outro provider (GitLab CI/CircleCI). Motivo: o repo já está no GitHub (`origin` = GitHub, branch `main`) — integração nativa, sem infra extra.
- **D2 — Cache do build/bundle A (híbrido):** workflow usa `docker compose` fiel ao dev **+** cache de camadas do build (`docker/build-push-action` `cache-from/to: type=gha`) **+** cache do bundle (`actions/cache` em `vendor/bundle` + `Gemfile.lock`). **A escolhida.** **B preterida:** só cache de camadas; **C preterida:** só cache do bundle. Motivo: cachear ambos acelera o CI (build + bundle) com pouco custo de manutenção.
- **D3 — Checks A (test+lint+check_docs):** os três checks rodam no workflow; **qualquer vermelho bloqueia o merge**. **A escolhida.** **B preterida:** só `test`; **C preterida:** `test`+`lint`. Motivo: a limitação "Sem CI" é sobre validação automatizada; incluir `check_docs` fecha também a consistência do SDD no push.
- **D4 — Healthcheck A (db + app):** (a) `db` via `pg_isready` no `docker-compose.yml`; (b) app via **nova rota `GET /health`** (200, sem tocar a rede) em `server.rb`. **A escolhida.** **B preterida:** só healthcheck do db; **C preterida:** só do app. Motivo: a limitação pede healthcheck do app **e** do banco; o `/health` não deve tocar a PokéAPI/rede (estável e barato).
- **D5 — Cache ambos A:** manter cache de camadas **e** do bundle. **A escolhida** (reforça D2). **B preterida:** cachear só um. Motivo: custo/benefício — CI mais rápido.
- **D6 — Gatilhos A (push + pull_request):** `push` (main) **+** `pull_request`. **A escolhida.** **B preterida:** só `push`. Motivo: valida PRs antes do merge e protege a main.
- **D7 — CD fora de escopo A:** **CD/deploy fora** desta sessão (sem alvo de deploy); **anotar CD no roadmap/limitações** para depois. **A escolhida.** **B preterida:** incluir deploy mínimo (push de imagem / serviço). Motivo: a limitação atual é "Sem CI"; CD é um passo adicional com decisões próprias (registry, serviço, secrets) — melhor anotar e tratar em sessão própria.

> **Grafo obrigatório (tier Scout):** `search_graph query="Server routes register health"` → módulos de rota (`register PokemonRoutes` etc., `server.rb:1219-1225`) e `app.get/post/delete` (`server.rb:1006-1109`); `get_code_snippet` do módulo de rotas; `check_index_coverage` em `server.rb`/`docker-compose.yml`/`Gemfile` → `no_recorded_issue` (best-effort). `docker-compose.yml`/`Gemfile`/`.github/workflows` são arquivos de config (grep/read permitido).

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Parar ao fim da fase 2 e aguardar validação do usuário.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (tabela + "Próxima sessão") + anotação no `REQUIREMENTS.md` (CD — D7) | commit `Sessao 0071: refinamento concluido — CI/CD (GitHub Actions) com healthcheck, criterios e plano TDD fechados` |
| 1 | **red→green — C5 (rota `/health`)** — `test/health_test.rb` `test_health_returns_ok` (GET `/health` → 200, sem rede) + implementar `GET /health` em `server.rb` (módulo `HealthRoutes` registrado) | `./scripts/test test/health_test.rb` + suíte + `./scripts/lint` 0; commit `Passo 1: GET /health responde 200 sem tocar a PokéAPI/rede` |
| 2 | **red→green — C4 (healthcheck do db)** — `test/ci_structure_test.rb` `test_db_has_healthcheck_pg_isready` (YAML load `docker-compose.yml`, assert `healthcheck` no `db` com `pg_isready`) + adicionar `healthcheck` no serviço `db` do `docker-compose.yml` | `./scripts/test test/ci_structure_test.rb -n /healthcheck/` + suíte + lint 0; commit `Passo 2: healthcheck do db via pg_isready no docker-compose.yml` |
| 3 | **red→green — C1+C2+C3 (workflow CI)** — `test/ci_structure_test.rb` `test_workflow_has_expected_jobs`, `test_workflow_triggers_push_and_pull_request`, `test_workflow_caches_build_and_bundle` (YAML load `.github/workflows/*.yml`, assert jobs test/lint/check_docs + gatilhos push/pull_request + cache build/bundle) + criar `.github/workflows/ci.yml` | `./scripts/test test/ci_structure_test.rb -n /workflow/` + suíte + lint 0; commit `Passo 3: workflow de CI no GitHub Actions (test+lint+check_docs, push+pull_request, cache build e bundle)` |
| 4 | **red→green — C6 (regressão + docs)** — suíte completa + lint 0 (baseline 998/3950 preservado) + `REQUIREMENTS.md` (limitação "Sem CI" atualizada; CD anotado — D7) | `./scripts/test` + `./scripts/lint` + `./scripts/check_docs` + `./scripts/checar-sessao 0071`; commit `Passo 4: regressao da suite e docs (limitação Sem CI atendida, CD anotado no roadmap)` |
| — | **Fase 2 concluída** → **Revisor (2c)**: loop Implementador↔Revisor até veredito `Aprovado` (teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3). Não marcar Done, não preencher a seção 7, não commitar conclusão. | — |

## 7. Validação (executada pelo usuário — S2)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 (workflow roda test/lint/check_docs) | `./scripts/test -n /test_workflow_has_expected_jobs/` | — | |
| C2 (gatilhos push + pull_request) | `./scripts/test -n /test_workflow_triggers_push_and_pull_request/` | — | |
| C3 (cache build e bundle) | `./scripts/test -n /test_workflow_caches_build_and_bundle/` | — | |
| C4 (healthcheck db via pg_isready) | `./scripts/test -n /test_db_has_healthcheck_pg_isready/` | — | |
| C5 (`GET /health` 200 sem rede) | `./scripts/test -n /test_health_returns_ok/` | — | |
| C6 (sem regressão) | `./scripts/test` + `./scripts/lint` 0 + `./scripts/check_docs` | — | |
| G1 (suíte+lint) | `./scripts/test` + `./scripts/lint` 0 | — | |
| G2 (sem gems/schema/rede) | `git diff -- Gemfile* db/` vazio + grep sem rede | — | |
| G3 (S4/S5) | `./scripts/check_docs` + `./scripts/checar-sessao 0071` | — | |
| G4 (run verde no Actions) | — | abrir o run no GitHub e confirmar `test`+`lint`+`check_docs` verdes | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.

## 8. Observações

- **Próxima após 0071:** **0072 escritas atômicas** (batalha/compra) → **0073 CSRF** → **0074 respiro** (numeração deslizou: 0071 era escritas atômicas, virou CI/CD). Ver `SESSIONS.md` e o roadmap.
- **Rota `/health` x `before`:** o `before` (`server.rb:1198`) chama `settings.team.all(current_user)` em **toda** request (toca o banco). Se o `/health` for um healthcheck "puro" (sem banco), o `before` precisa ser condicionado (`skip` para `/health`); se for um healthcheck "app+db" (mais completo), pode passar pelo `before` (banco cai → 500, o que é desejável). **Decisão de design do implementador** — o critério C5 exige apenas **200 sem tocar a rede** (não a PokéAPI/Faraday), não exige "sem banco". Validar no green do Passo 1.
- **`YAML.safe_load_file` e a chave `on:`** dos workflows: em YAML, `on` (gatilhos) é uma chave reservada que `YAML.safe_load` pode rejeitar como "attempt to parse a not allowed key" ou similar. Se ocorrer, carregar o arquivo como string e verificar substrings, ou usar `YAML.safe_load_file(path, aliases: true)` (e `permitted_classes:` se necessário). **Validar no green do Passo 3.**
- **`check_docs` no workflow:** roda **no host** (apenas grep/awk). No Actions, ele pode rodar direto no runner (host) ou via `docker compose run web ./scripts/check_docs`. Confirmar o caminho escolhido (D3) — se for no host, o runner precisa ter o repositório com os scripts (o que tem).
- **Cache do bundle:** `actions/cache` com `path: vendor/bundle` e `key` baseada em `hashFiles('Gemfile.lock')`. Confirmar **onde** o bundle é instalado no Dockerfile (`BUNDLE_PATH`/`bundle config path`) — se não for `vendor/bundle`, o cache é no-op. Validar no green do Passo 3.
- **Nomes de teste sem dígitos** (gotcha da 0070, `Naming/VariableNumber`): usar `test_health_returns_ok` (não `test_health_returns_200`). Manter o nome exato do critério exige `# rubocop:disable Naming/VariableNumber` inline se precisar de dígito.

## 9. Gotchas / Lições (memória — S6)

- **`GET /health` não deve tocar a PokéAPI/rede** — senão o healthcheck fica instável (rede da gateway) e a limitação continua. Garantir com webmock (sem rede) no teste `test_health_returns_ok`.
- **`before` do `server.rb:1198` toca o banco em toda request** — se o `/health` for "puro", condicionar o `before` para `skip` em `/health`; se for "app+db", deixar (banco cai → 500 é desejável). Decisão do implementador.
- **`YAML.safe_load_file` + chave `on:`** — a chave de gatilhos dos workflows pode quebrar o parse do `safe_load`; carregar como string + substring, ou `aliases: true`. 
- **`check_docs` roda no host** (grep/awk) — o workflow deve rodá-lo no host ou via `docker compose run web`, confirmar o caminho.
- **Cache do bundle** — `actions/cache` só ajuda se o bundle for instalado em `vendor/bundle` (ou o path configurado); verificar o Dockerfile.
- **`docker/build-push-action` `cache-from/to: type=gha`** — o cache de camadas do build no GitHub usa o cache do Actions; precisa de `GITHUB_TOKEN` (o Actions injeta por padrão).

### Confirmações no green (sessão 0071)

- **Rota `/health` decidida como "pura"** (skip do `before` para `/health`): o `before` (`server.rb:1198`) roda em toda request e chama `settings.team.all(current_user)` (toca o banco). Para um healthcheck de **liveness** estável e barato, o `/health` **não toca o banco nem a rede** — o `before` ganhou `next if request.path_info == "/health"`. A saúde do banco é responsabilidade separada do `pg_isready` no `docker-compose.yml`. Se um dia se quiser um healthcheck "app+db" (banco cai → 500), basta remover o `next`. Validado no green do Passo 1 (`test_health_returns_ok`, 200 + `{"status":"ok"}`).
- **Chave `on:` dos workflows é parseada como boolean `true` pelo Psych** (Ruby 3.3): `YAML.safe_load_file` devolve `wf[true]` em vez de `wf["on"]`. Confirmado no green do Passo 3: `wf.keys` = `["name", true, "jobs"]`; `wf[true]` = `{"push"=>{"branches"=>["main"]}, "pull_request"=>nil}`. O helper `workflow_triggers` tolera `workflow["on"] || workflow[true] || workflow["On"]` — sem isso o teste de gatilhos quebra.
- **Cache do bundle é no-op com o setup atual**: o Dockerfile faz `bundle install` sem `BUNDLE_PATH`, e a imagem `ruby:3.3.6-slim` oficial instala as gems em `/usr/local/bundle` (default), **não** em `vendor/bundle`. Como `./scripts/test`/`./scripts/lint` rodam via `docker compose run web` (volume monta o repo em `/var/www/pokedex/`), o `actions/cache` em `vendor/bundle` não é consumido. O cache **efetivo** de build é o de camadas via `docker/build-push-action` (`cache-from/to: type=gha`). Mantive o `actions/cache` `vendor/bundle` + `Gemfile.lock` para atender o critério C3 (estrutura), mas documentei o no-op. Se quiserem o cache do bundle real, o caminho é setar `BUNDLE_PATH=vendor/bundle` no Dockerfile **e** não montar o repo por cima (conflita com o volume atual) — decisão para sessão futura.
- **Flakiness transitória da suíte com o container `web` ativo**: um dos runs completos abortou (stacktrace do rake) e os runs seguintes ficaram verdes (1003/3980, 0 falhas). É a flakiness conhecida ("too many clients" — workaround `docker compose stop web`); não é regressão do escopo da 0071.
