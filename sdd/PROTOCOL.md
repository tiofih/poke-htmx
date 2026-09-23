# PROTOCOL — Spec-Driven Development (SDD)

Metodologia canônica de desenvolvimento **spec-first em sessões**: cada incremento é
**especificado antes de codar** (refinamento), implementado em **TDD estrito** e
**validado pelo dono do produto** — com rastreabilidade completa
(requisito → sessão → passos → commits) e documentação viva.

Este é **o ponto único de verdade do processo**. Os arquivos do projeto
(`REQUIREMENTS.md`, `SESSIONS.md`, `AGENTS.md`, `scripts/check_docs`) derivam dele.

## Conceitos

| Termo | Definição |
| --- | --- |
| **Sessão** | Unidade de trabalho = 1 incremento especificado (+ implementado + validado). Vive em `sessions/NNNN-slug.md`. |
| **REQUIREMENTS.md** | Fonte da verdade dos requisitos: RFs, RNFs, DoD global, limitações, roadmap. |
| **SESSIONS.md** | Registro: ciclo, tabela de progresso, "Próxima sessão", estrutura do arquivo de sessão. |
| **Validação** | Fase executada pelo **usuário/dono do produto** (nunca por quem implementa). |
| **Entrega (modo PR)** | O PR/MR da sessão, cujo corpo vive versionado em `sessions/pr/NNNN-pr-body.md`. Abrir o PR é fim da fase 2; validar é revisar o PR. |

## Ciclo de cada sessão (três fases, em ordem)

A próxima fase só começa quando a atual estiver concluída (marcada no arquivo da sessão).

> **Modo PR (`--with-pr`).** Quando o projeto instalou o perfil `--with-pr`, a **fase 3 não é
> removida nem terceirizada**: ela muda de **meio** — a entrega da sessão é um **PR/MR** e a
> **validação do usuário é a revisão desse PR** (S8). Sem o marcador `<!-- sdd-pr: ativo -->`
> em `AGENTS.md`, nada disto se aplica: vale o fluxo das três fases como está escrito acima.

### 1. Refinamento (preparação)

- Abertura (digest-first, obrigatório): rodar `./scripts/iniciar-sessao` (digest do
  estado) + `./scripts/levantar-roadmap` (backlog/limitações abertas) e ler **na íntegra
  apenas o arquivo da sessão corrente**; todo o resto via **digests** (`levantar-sessao`,
  `levantar-requisito`, `levantar-testes` — providos em `scripts/`) ou **busca**
  (grep/índice) em `REQUIREMENTS.md`/`SESSIONS.md`, nunca lendo-os inteiros.
- **Refinamento inline / modo rápido (`/sessao --rapido`):** escopo de uma tela/RF
  menor, sem decisão de arquitetura → clarificações **em cima** (2–4 perguntas no
  kickoff) e refinamento **inline na conversa principal**, gerando os artefatos de uma
  vez, sem subagente `refinador` e sem gates entre artefatos (medição: 246k in de
  média com spawn vs ~50k inline). Subagente `refinador` (investigação → finalize)
  só para escopo grande ou decisões múltiplas.
- Fechar: **objetivo**, **escopo** ("fora de escopo" explícito), **critérios de
  aceite** e **plano TDD**.
- **Cada critério de aceite referencia o teste que o prova** (S1) — critério sem
  teste automatizado registra `manual` explícito. Critério de **comportamento** é
  escrito no padrão **EARS** quando couber (`QUANDO/SE <gatilho> ENTÃO <resultado>
  — <qualificador>`): ambiguidade de critério é a maior fonte de retrabalho medido
  (36% UX); completaude do EARS é a falha conhecida — todo gatilho, resultado e
  limite no mesmo critério.
- Registrar decisões de design no arquivo da sessão.
- **Entrega:** arquivo da sessão com critérios fechados + plano TDD, commit do
  refinamento **atualizando também `SESSIONS.md`** (tabela + "Próxima sessão" — S4).
- Dúvidas em aberto → resolver antes de codar.

### 2. Implementação (TDD)

- `red` (teste falha) → `green` (implementação mínima, suíte + lint verdes) → `refactor`.
- **Commit obrigatório após cada green** (1 passo = 1 commit `test(passo N):`).
- Suíte completa verde em **todo** green — o baseline (N runs/M asserts) é preservado.
- Atualizar `REQUIREMENTS.md`/`SESSIONS.md` **no mesmo escopo** quando o comportamento
  dos requisitos mudar.
- **Converge (auto-verificação barata, fim da fase 2):** antes de declarar a fase 2
  pronta, o Implementador percorre **diff × cada critério de aceite** e registra no
  arquivo da sessão `> Converge: sim` — ou `nao` + as pendências, que viram mais um
  passo TDD ou escalação (S3). É o checkpoint que substitui a revisão padrão no fluxo
  opt-in (S7); não é revisor, é o próprio autor conferindo cobertura.
- **Especialistas (fase 2 paralela — opt-in `> Equipe:`, perfil `--with-especialistas`):**
  com `> Equipe: <papéis>` no arquivo da sessão (fechado no refinamento) e os agentes em
  `.opencode/agent/`, a fase 2 pode despachar especialistas por **lane** (`backend`,
  `frontend` editam; `qa`/`ui-designer`/`game-designer` são read-only) **em paralelo só
  com lanes disjuntas**. Cada especialista roda TDD na sua lane **sem commitar**; o
  Implementador integra, roda a suíte completa, commite por lane/green e responde pelo
  **Converge**/S6. Sem o portão duplo (agente ausente ou `> Equipe: —`), a fase 2 é o
  Implementador sozinho — fluxo padrão inalterado. Detalhe: bloco `sdd-especialistas:bloco`.
- **PARADA obrigatória ao fim da fase 2:** aguardar a validação do usuário. Não marcar
  status de validação, não atualizar docs de validação, não commitar a conclusão.
- **Mostrar antes de pedir (validação visual):** quando a mudança tem superfície
  visual, o agente exibe o resultado ao usuário (`browser.preview` ou screenshot do
  arquivo/roda) **junto do pedido de validação** — o usuário valida vendo, não
  imaginando (atitude que ataca o retrabalho UX medido).
- **Modo PR (`--with-pr`) — passo PR, ainda na fase 2:** com a implementação e os testes verdes,
  o Implementador **entrega** a sessão: (1) **gera** `sessions/pr/NNNN-pr-body.md` do próprio
  arquivo da sessão (o que muda para quem usa, o que foi implementado, o que **não** foi
  validado, roteiro manual) — rascunho **delegável ao `redator-pr`** (papel barato, instalado
  pelo `--with-pr`; bloco `sdd-redator:bloco`) e commita `docs(pr 00NN): corpo do PR — <resumo>`; (2) abre o PR/MR
  com `./scripts/abrir-pr NNNN --open` e registra `> PR: <url>` no arquivo da sessão. Sem
  `checar-pr`, sem template de narrativa: o corpo é consequência do refinamento, não tarefa
  nova. Com o PR aberto vale a **PARADA** — a fase 3 é a revisão do PR.
- **Memória da sessão (S6) ao fim da fase 2, ainda sem validação:** com o TDD verde (e
  veredito `Aprovado` quando houver revisão — S7), gravar **handoff**
  (`memory_handoff_begin` — o que foi entregue, perguntas em aberto, próximos passos,
  marcado `provisional:true`) e **gotchas** (`memory_write_page` em `gotchas/`, marcados
  `provisional:true`), escopados ao projeto corrente — **SEM aguardar a fase 3 e SEM
  commitar a conclusão**.

### 3. Validação (verificação) — executada pelo USUÁRIO

- Usuário roda a **suíte completa** e confere os **critérios de aceite** contra a
  implementação.
- Registrar a validação como **tabela por critério** (S2):
  `critério | evidência automatizada | evidência manual | resultado (ok/nok)` —
  um resultado por critério, nunca um bloco único.
- **Ajuste identificado = reabrir o critério** (S3): registrar a alteração com data e
  obter nova aprovação do usuário. Nunca aplicar "ajuste" sem esse registro.
- Só então atualizar `REQUIREMENTS.md` (status) e `SESSIONS.md` (progresso + próxima)
  e commitar a validação.
- **Memória (S6) só confirma/enriquece:** o handoff + gotchas já foram gravados como
  `provisional:true` no fim da fase 2 (com veredito `Aprovado` quando houver revisão);
  a validação apenas confirma
  ou enriquece o registro, nunca bloqueia o save.

### 3b. Modo PR — a validação é a revisão do PR (quando `--with-pr` está ativo)

- A **entrega** da sessão é o **PR/MR** aberto no passo PR (fase 2). O **usuário valida revisando
  o PR**: lê o corpo, segue o roteiro manual, roda os comandos e confere os critérios.
- O corpo do PR é escrito para **quem não trabalha no projeto**: primeiro o que muda para quem
  usa o produto, depois o que foi implementado, o que foi validado, o que **não** foi validado e
  como chegar ao estado inicial (S8.2). Identificadores internos ficam no **Anexo** do fim.
- Feedback do usuário (ou comentários na plataforma) = **S3**: o achado reabre o critério, com
  data; o Implementador corrige, **atualiza o corpo do PR** e re-empurra a branch — **sem abrir
  um segundo PR**.
- **Quem faz merge é o usuário** — nunca o agente. Só depois do merge: registrar a validação como
  tabela por critério (S2), com o link do PR como entrega, atualizar `REQUIREMENTS.md`/
  `SESSIONS.md` e commitar `docs(sessao 00NN): validacao — ...`.
- **Modo degradado (projeto sem remote ou sem CLI da plataforma):** o corpo versionado em
  `sessions/pr/NNNN-pr-body.md` passa a ser a entrega, e a validação acontece sobre ele. A
  validação continua sendo do usuário: o modo PR muda o meio, nunca o validador.

### 3c. Caminho bugfix (enxuto — sem refinador completo)

Correção de comportamento quebrado **não** é sessão de feature: mesmo ciclo, forma
reduzida.

- **Análise (inline, na conversa):** registrar no arquivo da sessão (ou nota curta se
  a sessão for trivial) **comportamento atual / esperado / inalterado** — os três,
  sempre. Sem plano TDD longo: o critério é **um teste de regressão que reproduz o
  bug**.
- **Patch em TDD:** `red` = teste de regressão falha reproduzindo o bug → `green` =
  correção mínima → suíte completa + lint verdes → commit (`fix: ...`).
- **Sem subagente `refinador`; revisor (S7) só se o bug tocar risco** (dados,
  auth, dinheiro). **Converge** (diff × critério) vale igual.
- **Entrega:** mesmo passo PR do modo PR (corpo gerado da sessão) ou, sem modo PR,
  direto à validação do usuário. `> Reprodução:`/`> E2E:` seguem o S8.3.
- Escopo que **não** couber no patch vira sessão normal (refinamento → TDD →
  validação) — o caminho bugfix não é porta de entrada de feature.

## Regras do processo (S1–S8)

- **S1 — Critérios apontam os testes que os provam.** Cada critério de aceite
  referencia o teste (arquivo/nome) que o prova; sem teste → `manual` explícito.
  Fechado no refinamento, antes de codar. **UI é `manual` por padrão:** critério
  puramente visual (layout, copy, cor, posicionamento) nunca exige teste automatizado.
  Critério de comportamento em **EARS** (`QUANDO/SE ... ENTÃO ...`) quando couber —
  completude acima de formalismo.
- **S2 — Validação é tabela por critério.** `critério | evidência automatizada |
  evidência manual | resultado`, um resultado por critério.
- **S3 — Ajuste de validação é alteração formal de critério.** Falha de critério
  reabre o critério, registra a alteração com data e o usuário reaprova.
  **Exceção UI (S3 leve):** ajuste puramente visual (layout/copy/cor) é anotado na
  sessão com data e aplicado — sem reabrir o critério nem exigir nova aprovação;
  reabre só se mudar comportamento observável.
- **S4 — `SESSIONS.md` acompanha todo refinamento.** "Próxima sessão" + tabela são
  atualizados **no commit do refinamento** de toda sessão (inclusive fora de fila).
- **S5 — `scripts/check_docs` valida a consistência.** Confere `sessions/` ↔ tabela de
  progresso ↔ "Próxima sessão". Rodar ao fechar refinamento e validação.
- **S6 — Memória da sessão (handoff + gotchas) ao fim da fase 2, SEM validação do
  usuário, SEM commit.** Com o TDD verde (e veredito `Aprovado` quando houver revisão
  — S7), o implementador
  grava **handoff** (`memory_handoff_begin`) e **gotchas** (`memory_write_page` em
  `gotchas/`), marcados `provisional:true` e escopados ao projeto corrente — sem aguardar
  a fase 3 e sem commitar a conclusão. A validação (fase 3) só confirma/enriquece a
  memória, nunca bloqueia o save.
- **S7 — Revisão (fase 2c) é opt-in por risco.** Por padrão a fase 2 vai direto à
  validação do usuário (com o **Converge** do Implementador — diff × critérios — como
  auto-verificação). A revisão **só dispara** quando o refinamento marca a sessão
  como de **risco** (`> Revisão: exigida` — mudança em dados persistidos, auth,
  dinheiro, refatoração ampla) ou quando o usuário pedir. Havendo revisão, o **Revisor** revisa o diff e devolve
  veredito fechado: `Aprovado` ou `Requer ajuste`; não aprovado → volta ao
  **Implementador** (resolve e re-commita) → re-revisa. **Teto: 3 rodadas** — sem
  convergência, **escalar ao usuário (S3)**. Só o Implementador edita — e, com
  `> Equipe:` (perfil `--with-especialistas`), os especialistas **nas suas lanes**;
  o Revisor nunca edita. Medido: taxa de apreensão de 4% (4 ajustes em 91 sessões) — por isso opt-in.
- **S8 — Modo PR (`--with-pr`): a entrega é o PR e a validação é a revisão do PR.** Só se aplica
  com o marcador `<!-- sdd-pr: ativo -->` em `AGENTS.md`; sem ele, S8 não existe.
  1. **S8.1 — Um PR por sessão; o agente nunca faz merge.** Com a fase 2 (TDD) verde, o
     Implementador gera o corpo, commita e abre o PR (`./scripts/abrir-pr NNNN --open`),
     registrando `> PR: <url>` na sessão. Vale a **PARADA** — a fase 3 é a revisão do PR.
  2. **S8.2 — Corpo gerado do arquivo da sessão.** O corpo (`sessions/pr/NNNN-pr-body.md`)
     deriva do refinamento: o que muda para quem usa o produto, o que foi implementado, o que
     foi validado, o que **não** foi validado, estado inicial e roteiro manual. Sem template
     de narrativa, sem `checar-pr` — o arquivo da sessão é a fonte, o corpo é sua projeção.
     Rastreabilidade (requisito → sessão → passos → commits) fica num `## Anexo` no fim.
  3. **S8.3 — Reprodução declarada no refinamento.** Todo critério declara
     `seed|script|manual|nao-aplicavel` (gravado como `> Reprodução: <valor>`) e `> E2E: sim|nao`;
     `nao-aplicavel` exige justificativa na mesma linha. O corpo repete em `**Estado inicial:**`
     e a seção "O que NÃO foi validado" diz o que ninguém conferiu e o que pode quebrar por isso.
  4. **S8.4 — Ajuste do usuário atualiza o PR.** Comentário no PR ou feedback reabre o critério
     (S3) com data; o Implementador corrige, atualiza o corpo e re-empurra a branch — **sem
     segundo PR**. Só o usuário faz merge; depois do merge, registra-se a validação (S2) com o
     link do PR como entrega. S1–S7 continuam valendo.

## Escopo grande / ideias fora de fase

- Ideias, melhorias e escopos grandes identificados durante uma sessão são
  **anotados** (em `REQUIREMENTS.md` — limitações/roadmap — ou nas observações da
  sessão), mas **não** são refinados nem viram sessão **enquanto a sessão atual não
  for concluída e validada**.
- Após a validação, a anotação pode virar **nova sessão** (refinamento → TDD → validação).
- Drafts de decisões de arquitetura/refatorações grandes vivem no draft único e
  consolidado em `docs/draft-backlog.md` (o `DRAFT_PATH` do install; catálogo
  de feito/pendente), fora do fluxo — revisados apenas ao concluir as fases agendadas
  (o que entra vira sessão, o que não se aplica é descartado — decisão do usuário).
  Registrar no draft **não** abre escopo nem atrasa a sessão em curso.
- Convenção de commit para anotações do tipo: `draft: <resumo do que foi anotado>`.

## Convenções de commit

- **Formato:** `tipo[(escopo)]: descrição concisa`. O **tipo é obrigatório** e sai da
  lista: `feat`, `fix`, `docs`, `test`, `chore`, `refactor`, `draft`; a descrição diz o
  **resultado**, não a atividade ("implementacao", "ajustes").
- **Escopo opcional** entre parênteses: o contexto do kit vira escopo — `(passo N)`,
  `(passos N-M)`, `(sessao 00NN)`, `(pr 00NN)`. O histórico sem tipo (`Passo N: ...`,
  `Sessao 0001: ...`) permanece; a regra vale do próximo commit em diante. `Draft:` já
  era um tipo — passa a ser `draft:`.
- **Idioma:** qualquer (consistente com o projeto); português/inglês.
- **Corpo opcional:** linha em branco + bullets de decisões.

| Tipo | Quando usar | Exemplo |
| --- | --- | --- |
| `test(passo N):` | green do passo TDD `N` | `test(passo 1): repository#all via schema + setup` |
| `test(passos N-M):` | green de passos agrupados | `test(passos 3-4): DELETE idempotente` |
| `docs(pr 00NN):` | corpo do PR commitado (modo `--with-pr`) | `docs(pr 0002): corpo do PR — recarga por arrasto (#12)` |
| `docs(sessao 00NN):` | refinamento (fase 1) fechado | `docs(sessao 0002): refinamento concluido — criterios e plano TDD fechados` |
| `docs(sessao 00NN):` | validação do usuário (fase 3) | `docs(sessao 0002): validacao — requisito Done, criterios verificados, prox 0003` |
| `docs(sessao 00NN):` | sessão fechada | `docs(sessao 0001): concluida — validacao integrada, proxima sessao 0002` |
| `docs(sessao 00NN):` | checkpoint de progresso | `docs(sessao 0001): progresso — passo 4 verde e validado` |
| `docs:` | mudança de convenção/regra | `docs: validacao e feita pelo usuario — parar na fase 3` |
| `chore:` | kit/tooling (install, scripts, config) | `chore: install --force preserva conteudo de autoria` |
| `draft:` | anotação de ideia/draft | `draft: performance da gateway anotada` |
| `feat:` `fix:` `refactor:` | comportamento novo / correção / refatoração | `feat: tambor aceita drop por pointer` |

## Estrutura do arquivo de sessão

1. **Objetivo** — o incremento, em uma frase; escopo fechado pelo usuário.
2. **Critérios de aceite** — cada um aponta o teste que o prova (S1); `manual` quando
   não houver teste.
3. **Plano TDD** — passos `red → green` com a verificação (suíte baseline + lint 0).
4. **Decisões de refinamento** — decisões fechadas com o usuário.
5. **Validação** — tabela por critério (S2); suíte executada; ajustes (S3).
6. **Observações** — impedimentos, dúvidas, próximo passo sugerido.
7. **Gotchas / Lições (memória)** — lições e armadilhas levantadas na sessão, para
   o registro de memória (S6).

> **Modo PR (`--with-pr`):** o arquivo da sessão declara, logo abaixo da tabela de `## Status`,
> `> Reprodução: seed|script|manual|nao-aplicavel` e `> E2E: sim|nao` (fechados no refinamento —
> S8.3) e registra `> PR: <url>` na seção de Validação ao abrir o PR.
> **Sessão de risco** (dispara a revisão opcional — S7) é marcada no refinamento:
> `> Revisão: exigida|dispensada` (default quando ausente: `dispensada`).
> **Equipe** (perfil `--with-especialistas`) também no refinamento:
> `> Equipe: <papéis>` — especialistas da fase 2 por lane (paralelo só com lanes
> disjuntas; default `—`/ausente = `implementador-teste` sozinho).

## Verificação de consistência (S5)

`scripts/check_docs` roda **no host** (apenas grep) e confere:

1. toda sessão em `sessions/` tem linha na tabela de progresso do `SESSIONS.md`;
2. toda linha da tabela tem seu arquivo;
3. a seção "Próxima sessão" cita a sessão de maior número (a aberta no topo da fila);
4. (aviso, não falha) todo RF da tabela de `REQUIREMENTS.md` tem ao menos uma menção
   em `sessions/` — requisito órfão = **drift spec↔código** (risco #1 do campo).

Rodar ao **fechar refinamento** e ao **fechar validação**.

No modo PR não há portão mecânico do corpo: `./scripts/checar-pr` e
`docs/pr/TEMPLATE-pr-body.md` foram removidos (medição: 2 gates por sessão para
produzir texto que já vive no arquivo da sessão). `./scripts/check_docs` não muda.