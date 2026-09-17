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
- Fechar: **objetivo**, **escopo** ("fora de escopo" explícito), **critérios de
  aceite** e **plano TDD**.
- **Cada critério de aceite referencia o teste que o prova** (S1) — critério sem
  teste automatizado registra `manual` explícito.
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
- **PARADA obrigatória ao fim da fase 2:** aguardar a validação do usuário. Não marcar
  status de validação, não atualizar docs de validação, não commitar a conclusão.
- **Modo PR (`--with-pr`) — passo PR, ainda na fase 2:** com a implementação e os testes verdes,
  o Implementador **entrega** a sessão: (1) escreve `sessions/pr/NNNN-pr-body.md` a partir de
  `docs/pr/TEMPLATE-pr-body.md` (S8.2), roda `./scripts/checar-pr NNNN` até passar e commita
  `docs(pr 00NN): corpo do PR — <resumo>`; (2) o **Revisor** (fase 2c) revisa o diff **incluindo
  o corpo** e emite o veredito `Aprovado` (S7); (3) só então o Implementador abre o PR/MR com
  `./scripts/abrir-pr NNNN --open` (o script recusa abrir se o `checar-pr` não passar) e
  registra `> PR: <url>` no arquivo da sessão. Com o PR aberto vale a **PARADA** — a fase 3 é a
  revisão do PR.
- **Memória da sessão (S6) no Revisor APROVADO, ainda na fase 2:** com veredito
  `Aprovado` (S7), gravar **handoff** (`memory_handoff_begin` — o que foi entregue,
  perguntas em aberto, próximos passos, marcado `provisional:true`) e **gotchas**
  (`memory_write_page` em `gotchas/`, marcados `provisional:true`), escopados ao
  projeto corrente — **SEM aguardar a fase 3 e SEM commitar a conclusão**.

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
  `provisional:true` no Revisor APROVADO (fim da fase 2); a validação apenas confirma
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

## Regras do processo (S1–S8)

- **S1 — Critérios apontam os testes que os provam.** Cada critério de aceite
  referencia o teste (arquivo/nome) que o prova; sem teste → `manual` explícito.
  Fechado no refinamento, antes de codar.
- **S2 — Validação é tabela por critério.** `critério | evidência automatizada |
  evidência manual | resultado`, um resultado por critério.
- **S3 — Ajuste de validação é alteração formal de critério.** Falha de critério
  reabre o critério, registra a alteração com data e o usuário reaprova.
- **S4 — `SESSIONS.md` acompanha todo refinamento.** "Próxima sessão" + tabela são
  atualizados **no commit do refinamento** de toda sessão (inclusive fora de fila).
- **S5 — `scripts/check_docs` valida a consistência.** Confere `sessions/` ↔ tabela de
  progresso ↔ "Próxima sessão". Rodar ao fechar refinamento e validação.
- **S6 — Memória da sessão (handoff + gotchas) no Revisor APROVADO (fim da fase 2),
  SEM validação do usuário, SEM commit.** Com veredito `Aprovado` (S7), o implementador
  grava **handoff** (`memory_handoff_begin`) e **gotchas** (`memory_write_page` em
  `gotchas/`), marcados `provisional:true` e escopados ao projeto corrente — sem aguardar
  a fase 3 e sem commitar a conclusão. A validação (fase 3) só confirma/enriquece a
  memória, nunca bloqueia o save.
- **S7 — Loop Implementador↔Revisor na fase 2c.** Ao fim da fase 2 (TDD), o **Revisor**
  revisa o diff e devolve um **veredito fechado**: `Aprovado` ou `Requer ajuste` (com
  severidade Bloqueante/Ajuste). Se não aprovado, volta ao **Implementador**, que resolve
  os achados e re-commita; o Revisor então re-revisa. **Teto: 3 rodadas** (3 passos do
  Implementador) — sem convergência, **escalar ao usuário (S3)**. Só o Implementador edita;
  o Revisor nunca edita. Só ir à validação (fase 3, do usuário) com veredito `Aprovado`.
- **S8 — Modo PR (`--with-pr`): a entrega é o PR e a validação é a revisão do PR.** Só se aplica
  com o marcador `<!-- sdd-pr: ativo -->` em `AGENTS.md`; sem ele, S8 não existe.
  1. **S8.1 — A entrega da sessão é um PR/MR.** Com a fase 2 (TDD) verde, o Implementador executa
     o passo PR (corpo escrito e commitado, `checar-pr` verde) ainda **antes** do veredito; só
     depois do `Aprovado` (S7) sobre o diff **incluindo o corpo** o PR é aberto. **Um PR por
     sessão.** O agente nunca faz merge.
  2. **S8.2 — Corpo do PR para quem não trabalha no projeto, com rastreabilidade no fim.** O
     corpo (a partir de `docs/pr/TEMPLATE-pr-body.md`) diz o que muda para quem usa o produto, o
     que foi implementado, o que foi validado, o que **não** foi validado, como chegar ao estado
     inicial do teste e o roteiro manual. **Nada de `Q1`, `S3`, `CA2`, número de sessão,
     "fase 2", "Passo 3" ou sigla de requisito na narrativa** — isso vive apenas no `## Anexo`
     do fim, que preserva a rastreabilidade requisito → sessão → passos → commits.
  3. **S8.3 — Reprodução é obrigatória e declarada.** No refinamento, **todo critério** declara
     como um terceiro chega ao estado inicial, com um destes valores: `seed`, `script`, `manual`,
     `nao-aplicavel` (gravado como `> Reprodução: <valor>` no arquivo da sessão). O corpo do PR
     repete a declaração em `**Estado inicial:**` e o `./scripts/checar-pr` confere que os dois
     batem. `nao-aplicavel` exige justificativa na mesma linha — é a saída honesta, não um atalho.
     `manual` e `nao-aplicavel` são legítimos, mas **pagam preço declarado**: a seção "O que NÃO
     foi validado" do corpo diz o que ninguém conferiu, em que ambiente, com que dados, e o que
     pode quebrar por isso.
  4. **S8.4 — Peso novo de teste e e2e.** Se o projeto tem harness de ponta a ponta, os critérios
     de comportamento observável **têm** cobertura e2e. Se não tem, o critério registra `manual`
     explícito (S1) **e** o roteiro manual entra no corpo do PR — o kit não inventa harness que o
     projeto não tem, nem exige o que ele não consegue prover. Declarar `E2E: sim` **obriga** a
     **narrativa** do corpo a nomear a camada e2e — o portão aceita qualquer menção a `e2e`,
     `end-to-end`/`end to end`, `ponta a ponta`, Playwright, Cypress ou Selenium. Não nomear é
     **falha** do `./scripts/checar-pr` (não aviso): portão que aprova um corpo alegando validação
     que não existe é a falsa segurança que este kit recusa — sem evidência a citar, declare
     `E2E: nao`. Comando de teste e baseline
     (N runs/M asserts, ver `STACK.md`) vão no corpo. Recomendação (não regra): quando a
     preparação do ambiente passar de três passos, versionar um script de reprodução da sessão.
  5. **S8.5 — `./scripts/checar-pr NNNN` fecha o portão.** Roda no fim da fase 2 (antes do commit
     do corpo) e de novo dentro do `abrir-pr`, que se recusa a abrir o PR se ele falhar. Ele
     falha alto quando falta seção obrigatória, sobra placeholder, a declaração de reprodução não
     bate com a sessão ou aparece termo interno na narrativa. O que ele **não** verifica (o texto
     ser compreensível para quem é de fora, os passos realmente funcionarem, a evidência ser
     verdadeira) é julgamento do Revisor (S7) e do usuário — declarado como tal, não simulado.
  6. **S8.6 — S1–S7 continuam valendo.** S2 (tabela por critério na validação), S3 (achado reabre
     critério), S4, S5 e S7 (teto de 3 rodadas) não mudam. S6 mantém o gatilho no veredito
     `Aprovado` e o handoff passa a citar o link do PR. A revisão do PR pelo usuário **não** entra
     no teto de 3 rodadas — o teto é do loop Implementador↔Revisor.

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
> S8.3/S8.4) e registra `> PR: <url>` na seção de Validação ao abrir o PR.

## Verificação de consistência (S5)

`scripts/check_docs` roda **no host** (apenas grep) e confere:

1. toda sessão em `sessions/` tem linha na tabela de progresso do `SESSIONS.md`;
2. toda linha da tabela tem seu arquivo;
3. a seção "Próxima sessão" cita a sessão de maior número (a aberta no topo da fila).

Rodar ao **fechar refinamento** e ao **fechar validação**.

No modo PR, `./scripts/checar-pr NNNN` confere o **corpo do PR**
(`sessions/pr/NNNN-pr-body.md`) antes do commit do corpo e antes de abrir o PR (S8.5).
`./scripts/check_docs` não muda.