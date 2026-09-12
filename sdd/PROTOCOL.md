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

## Ciclo de cada sessão (três fases, em ordem)

A próxima fase só começa quando a atual estiver concluída (marcada no arquivo da sessão).

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
- **Commit obrigatório após cada green** (1 passo = 1 commit `Passo N:`).
- Suíte completa verde em **todo** green — o baseline (N runs/M asserts) é preservado.
- Atualizar `REQUIREMENTS.md`/`SESSIONS.md` **no mesmo escopo** quando o comportamento
  dos requisitos mudar.
- **PARADA obrigatória ao fim da fase 2:** aguardar a validação do usuário. Não marcar
  status de validação, não atualizar docs de validação, não commitar a conclusão.
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

## Regras do processo (S1–S7)

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

## Escopo grande / ideias fora de fase

- Ideias, melhorias e escopos grandes identificados durante uma sessão são
  **anotados** (em `REQUIREMENTS.md` — limitações/roadmap — ou nas observações da
  sessão), mas **não** são refinados nem viram sessão **enquanto a sessão atual não
  for concluída e validada**.
- Após a validação, a anotação pode virar **nova sessão** (refinamento → TDD → validação).
- Drafts de decisões de arquitetura/refatorações grandes vivem no draft único e
  consolidado em `{{DRAFT_PATH}}` (padrão: `{{ROOT}}/docs/draft-backlog.md` — catálogo
  de feito/pendente), fora do fluxo — revisados apenas ao concluir as fases agendadas
  (o que entra vira sessão, o que não se aplica é descartado — decisão do usuário).
  Registrar no draft **não** abre escopo nem atrasa a sessão em curso.
- Convenção de commit para anotações do tipo: `Draft: <resumo do que foi anotado>`.

## Convenções de commit

- **Formato:** uma linha `Contexto: descrição concisa` — **sem** prefixos genéricos
  (`feat:`, `fix:`, `chore:`).
- **Idioma:** qualquer (consistente com o projeto); português/inglês.
- **Corpo opcional:** linha em branco + bullets de decisões.

| Contexto | Quando usar | Exemplo |
| --- | --- | --- |
| `Passo N:` | green do passo TDD `N` | `Passo 1: repository#all via schema + setup` |
| `Passos N-M:` | green de passos agrupados | `Passos 3-4: testes de DELETE idempotente` |
| `Sessao 00NN: refinamento concluido — ...` | refinamento (fase 1) fechado | `Sessao 0002: refinamento concluido — criterios e plano TDD fechados` |
| `Validacao sessao 00NN: ...` | validação do usuário (fase 3) | `Validacao sessao 0002: requisito Done, criterios verificados, prox sessao 0003` |
| `Sessao 00NN concluida: ...` | sessão fechada | `Sessao 0001 concluida: validacao integrada, proxima sessao 0002` |
| `Regra: ...` | mudança de convenção/regra | `Regra: validacao e feita pelo usuario — parar na fase 3` |
| `Draft: ...` | anotação de ideia/draft | `Draft: performance da gateway anotada` |
| `Atualizar progresso da sessão 00NN (...)` | checkpoint de progresso | `Atualizar progresso da sessão 0001 (passo 4 verde e validado)` |

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

## Verificação de consistência (S5)

`scripts/check_docs` roda **no host** (apenas grep) e confere:

1. toda sessão em `sessions/` tem linha na tabela de progresso do `SESSIONS.md`;
2. toda linha da tabela tem seu arquivo;
3. a seção "Próxima sessão" cita a sessão de maior número (a aberta no topo da fila).

Rodar ao **fechar refinamento** e ao **fechar validação**.