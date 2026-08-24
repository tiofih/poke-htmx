# Sessão 0043 — Estabilidade do banco: pool de conexões (fim do "too many clients") + warnings de constante nos seeds

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída a posteriori** — correção solicitada diretamente pelo usuário em 2026-08-24 ("vamos direto para a correção do postgres"), fora da fila (RNF-04 atendido: correção de estabilidade, não novo escopo de produto) |
| Implementação | **Concluída** — passos 1–2 em 2026-08-24 (suíte 692/2193, lint 0) |
| Validação | **Done** — executada pelo usuário em 2026-08-24 (tabela da seção 7) |

---

## 1. Objetivo

Eliminar a **flakiness "too many clients"** da suíte de teste (anotada no fim da
sessão 0042) e os **warnings de redefinição de constante** nos seeds. A causa raiz
do "too many clients" é a conexão persistida por repositório
(`@connection ||= PG.connect(...)`) sem fechamento explícito: a suíte instancia
dezenas de repositórios por teste e só o GC fecha a conexão, acumulando até
estourar `max_connections` (100) — medido pico de **74 conexões** na suíte com o
container `web` ativo (6 conexões persistentes). A correção registra as conexões
em um `ConnectionRegistry` e as fecha no `after_teardown` de **cada teste**
(pico caiu para **9**), sem alterar o comportamento do app (repositórios
singleton continuam com conexão persistida).

## 2. Contexto (estado atual — diagnóstico)

- `lib/team_repository.rb:246`, `lib/battle_repository.rb:96`,
  `lib/inventory_repository.rb:61`, `lib/progression_repository.rb:58`,
  `lib/seed_team.rb:41`, `lib/user_state_repository.rb:30`,
  `lib/wallet_repository.rb:43` — todos com `def connection; @connection ||=
  PG.connect(@db_url); end` (conexão persistida por instância, sem close).
- `server.rb:530-537` — repositórios singleton configurados no boot (6 conexões
  persistentes por processo do app).
- Testes instanciam `Repository.new` no setup (32 ocorrências em arquivos de
  teste, múltiplas por teste) — cada instância abre uma conexão que só o GC
  libera, sem acompanhar o ritmo da suíte.
- Medição: `pg_stat_activity` durante `./scripts/test` subiu de 7 → **74**
  (limite 100); com o `web` ativo, a suíte estourava intermitentemente
  (`PG::ConnectionBad: FATAL: sorry, too many clients already`).
- `db/seeds/saldo_inicial.rb:7` — `INITIAL_BALANCE = 200` redefinida no `load`
  repetido (`test/seed_scripts_test.rb` carrega o seed 2–3×; Rakefile usa
  `load` em todos os seeds) → warning `already initialized constant`.

## 3. Escopo

### Produção

- `lib/connection_registry.rb` — **novo**: `ConnectionRegistry` (registro
  thread-safe das conexões por dono) com `register(owner, connection)`,
  `size` e `close_all!` (zera o `@connection` do dono e fecha a conexão).
- `lib/{team,battle,inventory,progression,user_state,wallet}_repository.rb` +
  `lib/seed_team.rb` — `connection` passa a registrar via
  `ConnectionRegistry.register(self, PG.connect(@db_url))`.
- `db/seeds/saldo_inicial.rb` — guard `unless defined?(INITIAL_BALANCE)`.

### Testes

- `test/connection_registry_test.rb` — **novo**: registra na 1ª conexão,
  `close_all!` libera e permite reuso, `close_all!` libera todas as conexões
  criadas no teste (volta ao baseline).
- `test/test_helper.rb` — `Minitest::Test#after_teardown` chama
  `ConnectionRegistry.close_all!` após cada teste.

### Fora de escopo (não abrir)

- Pool com limite/`max_connections` maior em produção (o app mantém 6 conexões
  persistentes — dentro do limite; sem mudança de comportamento).
- Fila de produto: Onda 3 (grid), JN-3, JN-4, JN-5, J2, J4, D4, P2 (perf).

## 4. Critérios de aceite

### Resultado

- [x] **C1 — Suíte não estoura o limite de conexões**: ao rodar a suíte
      completa, o pico de conexões (`pg_stat_activity`) fica bem abaixo de
      `max_connections` (antes: 74; depois: ≤ 9) — prova:
      `test/connection_registry_test.rb` (`test_close_all_releases_connections_created_during_test`)
      + medição manual do pico (manual).
- [x] **C2 — Conexões fechadas após cada teste**: `after_teardown` fecha todas
      as conexões registradas, e o repositório reconecta ao reusar — prova:
      `test/connection_registry_test.rb` (`test_close_all_releases_connections_and_allows_reuse`).
- [x] **C3 — Avisos de constante eliminados**: suíte roda sem
      `warning: already initialized constant` — prova: execução de
      `test/seed_scripts_test.rb` sem warnings (verificação manual da saída).

### Garantias (RNF)

- [x] Suíte completa verde (692 runs/2193 asserts) + lint 0; sem gems novas /
      sem mudança de schema / testes sem rede.
- [x] Comportamento do app preservado (repositórios singleton seguem com
      conexão persistida; nenhuma mudança em `server.rb`).

> **S1:** cada critério aponta o teste que o prova. C1/C3 têm componente manual
> (medição do pico e ausência de warnings na saída da suíte) — registrado.

## 5. Decisões de refinamento (fechadas com o usuário)

- **2026-08-24 — Correção direta, fora da fila** — o usuário pediu para ir direto
  à correção do Postgres ("vamos direto para a correção do postgres"), antes da
  próxima sessão de fila (Onda 3/JN-3/JN-4/JN-5/J2/J4/D4). Registrada a
  posteriori como sessão 0043 para manter a consistência do SDD.
- **2026-08-24 — Registro + fechamento determinístico** (em vez de pool com
  limite): `ConnectionRegistry` rastreia as conexões e `after_teardown` fecha
  todas após cada teste — resolve a acumulação na suíte sem mudar o app.
  Preterido: pool com checkout/checkin, `max_connections` maior, desligar o app
  durante a suíte (workaround antigo).
- **2026-08-24 — Guard em `saldo_inicial.rb`** — `unless defined?` no
  `INITIAL_BALANCE`; `team_duelo.rb` não sofre o problema (carregado 1× via
  `require_relative`; `load` 1× por processo no rake), mantido intacto.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 1 | C1 + C2 — `ConnectionRegistry` + `after_teardown` no test_helper + 7 repositórios registrando conexão | suíte verde + lint 0, commit `Passo 1:`; pico medido 74 → 9 |
| 2 | C3 — guard `unless defined?` em `saldo_inicial.rb` | suíte verde + lint 0, commit `Passo 2:`; sem warnings |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Concluída em 2026-08-24 — validada pelo usuário** *(S2: uma linha por critério).*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 suíte não estoura conexões | `test/connection_registry_test.rb` | pico de conexões na suíte completa medido em ≤ 9 (antes 74); roda com `web` ativo sem `too many clients` | ok |
| C2 conexões fechadas no teardown | `test/connection_registry_test.rb` | `./scripts/test` repetido não acumula conexões | ok |
| C3 avisos de constante eliminados | `test/seed_scripts_test.rb` | saída da suíte sem `already initialized constant` | ok |

## 8. Observações

- A correção não altera o comportamento do app: repositórios singleton seguem
  com conexão persistida por processo (6 conexões — dentro do limite). O
  `ConnectionRegistry` só importa para a suíte fechar conexões determinísticamente.
- O workaround antigo (`docker compose stop web` antes da suíte) deixou de ser
  necessário para o problema de conexões — a suíte roda limpa com o `web` ativo.
- Fila preservada após a 0043: Onda 3 (grid), JN-3, JN-4, JN-5, J2, J4, D4, P2
  (perf da 1ª batalha) — a critério do usuário.