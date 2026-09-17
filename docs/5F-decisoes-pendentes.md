# §5.F — Digest para decisão (leitura only, nada foi rodado/alterado)

Escopo: `docs/draft-backlog.md:427-432`. O §5.F tem 4 itens; o **item 4 (cassette 197 MB)** está fora
por já ter outro dono. Investigado sem rodar suíte/e2e/docker.

## 5.F.1 — `user_state`: apagar ou manter?

**O que é.** Tabela `user_state(user_id TEXT PK, journey_started BOOLEAN)`, criada só por
`db/migrations/0036_add_user_state.sql:4-7` (**arquivo removido na sessão 0089**) (não está em `db/schema.sql`, que só cria `team_pokemons`
— `db/schema.sql:4`). Repositório `lib/user_state_repository.rb` (upsert `mark_started`, SELECT `started?`).

**Estado hoje: escrita viva mas inútil; leitura morta.**
- Escrita: `server.rb:599` (`add_team_success`) → `lib/journey_service.rb:23-28` → `user_state_repository.rb:21-27`.
  Roda a cada add bem-sucedido; grava `TRUE` para um usuário que já tem 6 — e ninguém lê.
- Leitura: `UserStateRepository#started?` (`lib/user_state_repository.rb:15-20`) tem **zero chamadores de
  produção** — só `test/user_state_repository_test.rb`. O gate real é
  `lib/journey_service.rb:8` (`@team.all.size >= MAX_TEAM_SIZE`), sem tocar em `user_state`.
- Dependências vivas da tabela: `test/user_state_repository_test.rb` (arquivo inteiro),
  `test/test_helper.rb:84-86` (`clear_user_state!`), `test/server_test_helpers.rb:16,24`
  (`clear_user_state!` + `start_journey`), 4 chamadas de `start_journey` em `test/team_routes_test.rb`
  (`:355,471,481,593`), `test/journey_service_test.rb:7,16,20`.
- Reuso só *planejado*: `docs/draft-backlog.md:133` (J4 apelido) e `:344` (onboarding nome+avatar) —
  nenhuma sessão aberta.

**Opções.**
- **(a) Manter** — custo 0 linhas / 0 migração / 0 risco. Convive com ~15 linhas write-only e uma
  tabela que já foi declarada vestigial.
- **(b) Apagar** — diff ~9 arquivos, ~70 linhas: migração `0037_drop_user_state.sql` (DROP idempotente,
  seguro no `rake db:setup` sem ledger — `Rakefile:16-24`), `rm lib/user_state_repository.rb`, tirar
  `require`/`set` (`server.rb:24,1445`), tirar o kwarg `user_state:`/`mark_started*`
  (`lib/journey_service.rb:4-5,23-28`), `rm test/user_state_repository_test.rb`, e ajustar os 5 arquivos
  de teste listados. Risco de regressão: baixo (nenhum caminho de produção lê a tabela); custo de
  retorno se J4 chegar: ~30 linhas + migração de volta.

**Recomendação:** (b) apagar — hoje é write-only e o gate ignora o valor.
**Do usuário:** J4 (apelido no ranking) e onboarding entram no próximo ciclo? Se sim → (a) e a tabela é
o alvo de J4; se não → (b) com a migração de drop.

**FECHADO (2026-09-16, D2/D3):** (b) apagar — **executado na sessão 0089** (Passo 1/2: `0037_drop_user_state.sql`
+ deleção de `lib/user_state_repository.rb` e da escrita vestigial; a criação `0036` saiu). O gate da
jornada segue derivado de `team >= 6`. As linhas acima ficam como registro do digest; J4/onboarding
precisam de novo lar de persistência (registrado em `docs/draft-backlog.md:133,344` e na §8 da 0089).

## 5.F.2 — Os 4 e2e vermelhos de `e2e/specs/battle-log.spec.ts`

**O que é.** 12 testes no arquivo, 5 já usam `buildBudgetTeam` (`:157-164`, `CHEAP_TEAM`), e **4 ainda
usam `buildTeamOfSix`** (`:11`, que clica nos 6 primeiros `li.pcard` do catálogo): `:51` round
headers/chips, `:77` reduced-motion, `:101` auto-chain, `:112` reward copy. `buildBudgetTeam` chegou em
2026-09-15 (`git log -S` → 222d918) exatamente como contorno do orçamento.

**Premissa que envelheceu:** "os 6 primeiros cards do catálogo caibam no orçamento". O próprio arquivo
admite em `:153-154`: *"o helper de 6 starters do topo estoura o orcamento neste seed e nao abre a
arena"*. Com o add barrado pelo gate (`server.rb:587-606`; `TeamBudget.fits?` → `lib/team_budget.rb:32`),
o badge `n/6` estaciona e o `expect(#nav-badge)` morre no meio do helper.
- **O 450 NÃO envelheceu:** `lib/team_budget.rb:8` `BUDGET = 450` é fonte única — `server.rb:1031`
  expõe `TeamBudget::BUDGET`, e `rg '450'` não acha literal em `lib/`/`views/`/`server.rb`. Histórico:
  teto de 3 S (2026-08-26) → `S_rest 110` + 450 como limitador único (2026-08-27).
- **Não verificado:** a lista nominal dos 4 vem da premissa + comentário (`buildTeamOfSix` × 4 é o
  candidato exato); `test-results/.last-run.json` diz `{"status":"passed"}` da última execução, mas foi
  subset — não é contraprova. Comando que fecha: `npx playwright test e2e/specs/battle-log.spec.ts`
  (1 arquivo, não a suíte).

**Opções.**
- **(a) Reparar** — trocar os 4 `await buildTeamOfSix(page)` por `await buildBudgetTeam(page)` (~4
  linhas; ~10 se remover o helper órfão). Sem produção, sem migração. Risco baixo, mas condicionado:
  rodar o arquivo isolado antes, porque se `buildBudgetTeam` também não abrir a arena o vermelho persiste.
- **(b) Apagar os 4** — diff ~-40 linhas, risco 0. Perde a **única** cobertura e2e de
  reduced-motion/auto-chain/chips/round-headers (C1/C2/C15 da 0086); keyframes e `cqi` não são cobertos
  por teste de unidade (o próprio arquivo explica: só a página viva prova `cqi`).

**Recomendação:** (a) reparar.
**Do usuário:** autoriza a sessão de reparo (rodar o arquivo → trocar o helper → verde)? Senão, (b) com
a perda acima registrada.

## 5.F.3 — `open-design/prints/` e `_ai_context/`

São duas coisas de naturezas opostas; a decisão precisa ser separada.

**`open-design/prints/` — 3,7 MB, untracked + gitignored (`.gitignore:39 open-design/`; `git ls-files
open-design` = 0).** Conteúdo: 4 renders (`01-home-team.png` 756K, `02-battle.png` 528K,
`03-history.png` 440K, `04-manage-team.png` 924K) + `backup-2026-09-10/` (1,1 MB). Nada no código
referencia `prints/` (`rg` só acha o draft-backlog). `sessions/0080:21` declara os prints obsoletos e
elege `tmp/proto-{home,battle,history}.png` como referência visual — e esses 3 existem (2026-09-10).
- **Correção ao §5.A (`docs/draft-backlog.md:392`):** "duplicata exata" é falso — `diff -rq` mostra que
  os 4 PNGs do backup **diferem** dos atuais. Dá para liberar 1,1 MB sem perder o render atual.
- Opções: **(a)** apagar `prints/` inteiro → -3,7 MB, irreversível (nunca esteve no git; os protótipos
  HTML de origem ficam, os PNGs não); **(b)** apagar só `backup-2026-09-10/` → -1,1 MB, mantém os 4
  renders; **(c)** preservar tudo → custo zero, só espaço local.

**`_ai_context/` — 472 KB, untracked + gitignored (`.gitignore:74`), mas é o subsistema ai-context EM
USO, não lixo.** Citado por `AGENTS.md:408,416-417` (`ai-symptom-router.sh`, `knowledge.manifest.yaml`,
`_gotchas.md`), `.cursor/rules/ai-context.mdc:5`, `.claude/skills/ai-doctor/SKILL.md:20,50` e ~8 hooks
de `.claude/settings.json` (inclui `cat _ai_context/_SESSION.md` sem guarda em `:36`). `_temp_notes.md`
tem mtime de hoje (2026-09-16 18:50) — escrita por hook de post-commit. O "0 citações" do §5.A
provavelmente não varreu `.claude/`/`.cursor/` (dirs ocultos); o junk real dentro do dir é
`legacy/README.md` (590 B) e, no limite, `_temp_notes.md` — exatamente os dois que o §5.A já isola.
- Opções: **(a)** apagar o dir → -472 KB mas quebra as citações acima (hooks degradam em silêncio e
  `AGENTS.md:405-417` fica mentindo); **(b)** apagar só `legacy/README.md` + `_temp_notes.md` → ~2,5 KB,
  sem tocar no sistema; **(c)** preservar tudo.

**Recomendação:** prints → (b) apagar só o `backup-2026-09-10/`, ou (a) se o usuário confirmar que o
substituto `tmp/proto-*.png` basta; `_ai_context/` → (c), com a limpeza fina (b) se quiser fechar o §5.A.
**Do usuário:** (i) `prints/`: apagar tudo ou só o backup? (ii) `_ai_context/`: o ai-context continua em
uso (os hooks dizem que sim)? Se estiver abandonado, descartar é uma limpeza grande — remover hooks de
`.claude/settings.json`, a regra de `.cursor/rules/` e as seções de `AGENTS.md` —, não um `rm` de 472 KB.

## Para fechar (marque 1 por item)

1. ~~`user_state` → (a) manter (J4 próximo) · (b) apagar agora~~ → **(b) apagar agora — decidido em 2026-09-16 e executado na sessão 0089 (Bloco A)**
2. ~~4 e2e `battle-log` → (a) reparar (`buildBudgetTeam`) · (b) apagar os 4~~ → **(a) reparar — decidido em 2026-09-16; execução no Bloco B (Passo 6) da sessão 0089**
3. `prints/` → (a) tudo · (b) só backup · (c) preservar ‖ `_ai_context/` → (b) limpeza fina · (c) tudo
