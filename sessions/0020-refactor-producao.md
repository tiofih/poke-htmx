# Sessão 0020 — Refatoração de produção (respiro: remover `rubocop:disable` de `lib/**` + `server.rb`)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída — critérios e plano fechados com o usuário em 2026-08-10 (respiro) |
| Implementação | Pendente |
| Validação | Pendente (executada pelo usuário) |

---

## 1. Objetivo

**Respiro de refatoração de produção** (item "Refatoração dos arquivos de produção"
do `draft-auto-battler.md`, anotado 2026-08-10): aplicar aos arquivos **não-teste**
o mesmo tratamento que a sessão 0019 aplicou aos testes — remover os
`# rubocop:disable` de **`lib/**` + `server.rb`** e voltar às **métricas padrão**
do RuboCop do root (`.rubocop.yml`: `Metrics/AbcSize` 17, `Metrics/MethodLength` 10,
`Metrics/ClassLength` 100, `Metrics/ParameterLists` 5, `Naming/MethodParameterName` 3)
por **extração de métodos/módulos e divisão por área** — **sem mudança de comportamento**.

Escopo confirmado pelo usuário (2026-08-10, decidido como **sessão 0020**, 1 fase —
após E1/D2/D3/Eco na sequência): `server.rb`, `lib/battle_engine.rb`,
`lib/battle_pokemon.rb`, `lib/team_repository.rb`, `lib/poke_api.rb` — **5 arquivos,
7 disables**.

## 2. Contexto (estado atual — diagnóstico)

| Arquivo | Linhas | Disables | Cops envolvidos |
| --- | --- | --- | --- |
| `server.rb` | 200 | 1 (`:12`) | `Metrics/ClassLength` — classe `Server` (~185 linhas de corpo > 100) |
| `lib/battle_engine.rb` | 176 | 1 (`:16`) | `Metrics/AbcSize`+`ClassLength`+`MethodLength`+`ParameterLists` — `act` (~21 linhas), `action_entry` (8 params > 5), classe ~176 > 100 |
| `lib/battle_pokemon.rb` | 60 | 1 (`:19`) | `Metrics/MethodLength` — `self.from` (13 linhas > 10) |
| `lib/team_repository.rb` | 170 | 2 (`:6` e `:19`) | `Metrics/ClassLength` (classe ~170 > 100) + `Metrics/MethodLength` (`all`, 15 linhas > 10) |
| `lib/poke_api.rb` | 183 | 2 (`:6` e `:55`) | `Metrics/ClassLength` (classe ~183 > 100) + `Metrics/AbcSize`/`MethodLength` (`detail`, 15 linhas; também `available_move_names`) |

**Causas-raiz** (inspecionadas):

- **Classes grandes:** `Server` (~185 linhas de corpo), `BattleEngine` (176),
  `TeamRepository` (170), `PokeApi` (183) — todas acima do `ClassLength` default 100
  → exigem **extração de módulos/áreas** (o disable de `ClassLength` do arquivo segue
  valendo até o `# rubocop:enable`, mascarando também `AbcSize`/`MethodLength` em
  todo o corpo do arquivo).
- **Métodos longos mascarados pelos disables de arquivo:** `BattleEngine#act`
  (choque entre caminho legado e com moves: escolha de alvo, golpe, dano e log num
  único método), `PokeApi.detail` (5 passos de parsing num método), `PokeApi.moves_for`/
  `available_move_names` (~7 linhas cada) e `TeamRepository#all`/`#shift_slots`.
- **`Metrics/ParameterLists` no `action_entry`:** assinatura com 8 params
  (`round, attacker_team_index, move_type, damage, damaged, attacker_name,
  target_name, move_name = nil`) > default 5 — resolver com hash/objeto de entrada.
- **`server.rb`:** rotas de Lista/Time/Batalha + handler `error 500` + helper
  `battle_moves_for` tudo no corpo da classe — o meio de derrubar o `ClassLength`
  sem mudar contrato é **extrair as rotas por área em módulos registrados**
  (`Sinatra::Base.register` com `self.registered(app)`, padrão nativo do Sinatra),
  mantendo `configure`/`before`/`battle_moves_for` no `Server`.

**Sem mudança de comportamento:** nenhuma rota, assinatura pública, schema ou
comportamento de negócio muda (suíte completa 222 runs/778 asserts preservada).
`lib/battle_registry.rb`, `lib/opponent_generator.rb`, `lib/move.rb`,
`lib/pokemon.rb`, `lib/type_effectiveness.rb` **não** têm disables — ficam intocados.

## 3. Critérios de aceite

### Resultado

- [ ] **Nenhum `# rubocop:disable`/`enable` restante** em `lib/**` + `server.rb`
      (`grep 'rubocop:' lib server.rb` → 0 ocorrências).
- [ ] `./scripts/lint` → **0 offenses** com as **métricas padrão do root**
      (`.rubocop.yml`; sem orçamentos de produção, que continuam só para `test/`).
- [ ] `./scripts/test` → **suíte completa verde com o mesmo tamanho de cobertura**
      (baseline **222 runs/778 asserts**): nenhum teste removido; asserts preservados.
- [ ] 0 regressão de comportamento — rotas/domínio intactos (a suíte existente é a
      rede de segurança; nada de novo a escrever nesta sessão).

### Estrutura

- [ ] `server.rb`: rotas extraídas por área em módulos registrados no `Server`
      (`register` + `self.registered(app)`), rotas Planas (Lista/Detalhe/Time/Batalha)
      e `error 500` fora do corpo da classe; `configure`/`before`/helper
      `battle_moves_for` permanecem disponíveis; contrato de rotas **idêntico**
      (mesmos paths, layout: false, fragmentos, alvos htmx).
- [ ] `lib/battle_engine.rb`: `act` fatiado (resolver golpe/ação, dano e log em
      métodos menores); `action_entry` com ≤ 5 params (hash/objeto); dano ("legado",
      "com moves" e multiplicador) extraído para módulo; `ClassLength` do `BattleEngine`
      derrubado com extrações para módulos incluídos (mesmos métodos privados,
      distribuídos em módulos) — **sem mudar** `move_damage_for`/`damage_for`/
      `move_type_for` em resultado.
- [ ] `lib/battle_pokemon.rb`: `self.from` fatiado (HP inicial extraído; defaults de
      `moves` arrumados) — resultado idêntico para qualquer `Pokemon`.
- [ ] `lib/team_repository.rb`: `all` fatiado (`row_to_pokemon` extraído) e
      re-índex de slots (`park/shift/assign/increment/decrement`) extraído para
      módulo/métodos menores; `ClassLength` derrubado — SQL e ordem de slots intactos.
- [ ] `lib/poke_api.rb`: parsing de `detail` (stats/tipos/evolução) e helpers de
      movimentos (`move`/`moves_for`/`available_move_names`/`fetch_move_json`) e
      tipos (`type_relations`/`fetch_type_json`/`extract_*`) extraídos para módulos;
      `ClassLength` derrubado — URLs, caches e robustez (nil/[]) intactos.

### Garantias (RNF)

- [ ] Commit obrigatório a cada passo verde (lint 0 + suíte completa verde); suíte
      sem rede (mas válida em `lib/` — E1 cache é sessão futura).
- [ ] `draft-auto-battler.md` (status da anotação "Refatoração dos arquivos de
      produção" → marcado como feito/sessão 0020) e `SESSIONS.md` (0020 registrada +
      próxima sessão **E1**) atualizados no mesmo escopo; `REQUIREMENTS.md` roadmap
      (item 19) sem N par: sessão registrada como concluída só após validação.
- [ ] Sem novas gems, sem mudança de schema/rotas/contrato público; `lib/**` continuam
      nas métricas estritas do root (nenhum orçamento novo de produção).

## 4. Decisões de refinamento

- **Tipo de sessão:** respiro de refatoração de **produção** (não gera RF novo em
  `REQUIREMENTS.md`; comportamento continua sendo o dos RF-01..RF-18, 0 regressão).
- **Definição de `red` nessa sessão:** remover um `# rubocop:disable` de um arquivo
  e ver o lint acusar offense(s) reais (métrica) — esse é o "teste que falha".
  **`green`:** refatorar a região (método/módulo/área) até **lint 0 + suíte completa
  verde** → **commit**. Não há teste novo a escrever: a suíte existente é a rede de
  segurança (mesma mecânica da 0019).
- **`red` pode revelar offenses adicionais:** como os disables de arquivo mascaravam
  as métricas em todo o corpo, ao removê-los o lint pode acusar **outros** métodos
  acima do limite (ex.: `TeamRepository#shift_slots`, `PokeApi.moves_for`) além dos
  conhecidos — eles fazem parte do `red` do passo e devem ser resolvidos no mesmo
  `green` (lint 0 obrigatório).
- **Estratégia para `ClassLength`:** extrair métodos/módulos para **fora do corpo da
  classe** (módulos com `include`, padrão local ao `BattlePokemon#from`→helpers,
  `PokeApi`→módulos temáticos por responsabilidade). Para `server.rb`, usar o padrão
  **nativo do Sinatra**: módulos de rotas com `self.registered(app)` + `register`
  (mesmo mecanismo do `Sinatra::Reloader`), definidos no próprio `server.rb` antes da
  classe — dev-reload preservado, sem novos requires/routes.
- **Estratégia para `ParameterLists` (`action_entry`):** reduzir a assinatura
  agrupando dados correlatos num hash/objeto de entrada (ex.: `nomes:` ou um
  `attacker`/`target` que carreguem `name`); os valores **existentes** das entries
  (`:round/:attacker/:move_type/:damage/:ko/:move/:attacker_name/:target_name`) são
  preservados (contrato da RF-16).
- **Ordem sugerida (cada passo termina com lint 0 + suíte verde + commit):**
  `battle_pokemon` (mais simples) → `team_repository` → `poke_api` → `battle_engine`
  → `server.rb` (mais estrutural, por último) → docs.
- **Contrato público intocado:** assinaturas públicas (`PokeApi.detail/find/move/...`,
  `TeamRepository#all/add/remove/move/set_moves`, `BattleEngine#play_round/finished?/
  winner/rounds/log/teams/battle`, rotas Sinatra) não mudam — se no meio de um passo
  algum arquivo exigir mudança de contrato público ou refactor estrutural grosso, a
  parte afetada **vira sessão própria** (critério do draft para "1 fase ou mais") e
  o passo corrente para no estado verde.

## 5. Plano TDD (passos)

> Cada passo = "red" (remover disable → lint acusa) → "green" (extrair método/módulo/
> área → lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo de sessão com critérios e plano fechados | commit `Sessao 0020: refinamento concluido ...` |
| 1 | **`lib/battle_pokemon.rb`:** fatiar `self.from` (extratores de HP/defaults) e remover o disable `Metrics/MethodLength` (`:19`) | lint 0 (0 disables nesse arquivo) + suíte verde (222/778) |
| 2 | **`lib/team_repository.rb`:** fatiar `all` (`row_to_pokemon`) e re-índex de slots para métodos/módulo menores; remover os 2 disables (`ClassLength` `:6`, `MethodLength` `:19`) | lint 0 + suíte verde |
| 3 | **`lib/poke_api.rb`:** extrair módulos temáticos de parsing (stats/tipos/evolução/robustez e movimentos); remover os 2 disables (`ClassLength` `:6`, `AbcSize`+`MethodLength` `:55`) | lint 0 + suíte verde |
| 4 | **`lib/battle_engine.rb`:** fatiar `act` (ação/golpe/dano/log), reduzir `action_entry` para ≤ 5 params (hash/objeto) e extrair dano/lógica p/ módulos; remover o disable composto (`:16`) | lint 0 + suíte verde |
| 5 | **`server.rb`:** extrair rotas por área (Lista/Detalhe/Time/Batalha) + `error 500` em módulos `self.registered(app)` com `register` no `Server`; remover o disable `Metrics/ClassLength` (`:12`) | lint 0 + suíte verde (rotas idênticas) |
| 6 | **Verificação final + docs:** `grep 'rubocop:' lib server.rb` → 0; suíte completa + lint 0; atualizar `REQUIREMENTS.md` (roadmap item 19 sem N par), `SESSIONS.md` (0020 + próxima sessão E1) e `draft-auto-battler.md` (anotação marcada como feito) | suíte verde + lint 0 + docs |

## 6. Validação (executada pelo usuário)

**Status: pendente — aguardando o usuário** (fase 3 do ciclo; ao concluir a fase 2,
o agente para e não marca fases como concluídas nem commita a conclusão).

- [ ] Suíte completa verde: **222 runs/778 asserts, 0 failures/errors** (baseline preservado).
- [ ] Lint RuboCop: **0 offenses** (métricas padrão do root: `.rubocop.yml`).
- [ ] `grep 'rubocop:' lib server.rb` → **0 ocorrências** (nenhum disable/enable de produção).
- [ ] Nenhum comportamento alterado: rotas/domínio/schema/suíte de testes intactos;
      0 mudanças em `test/**` nesta sessão.
- [ ] `server.rb` funcionando em dev (`./scripts/run` + navegação Lista/Time/Batalha).

**Resultado:** a preencher após validação do usuário.

## 7. Observações

- Sessão de **respiro de produção** (decisão do usuário em 2026-08-10), em sequência
  rígida após a 0019; não abre escopo novo no meio (RNF-04). Após a 0020, a próxima
  sessão é **E1 (cache de detalhes da PokéAPI)** — já fechado na sequência
  E1 → D2 → D3 → Eco → candidatos.
- Implícito (não é entregável): `server.rb` pode totalizar menos linhas de classe,
  mas o contrato de rotas (paths, fragmentos, alvos, `layout: false`) é preservado —
  `GET /` continua servindo o layout, fragmentos htmx intactos (RF-14/18).
- Atenção à suíte: nenhuma edição em `test/**`; apenas `lib/**` + `server.rb`.
- **Contraste com a 0019:** lá os orçamentos em `test/.rubocop.yml` eram o bônus
  aceito; aqui **nenhum orçamento novo** — revisar `Metrics/MethodLength`/`AbcSize`
  mascarados em cada `red` (o lint é o crítico objetivo, não a leitura manual).