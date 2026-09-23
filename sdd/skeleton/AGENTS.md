# {{PROJETO}} — MANDATORY workflow rules (SDD)

## Validação é do usuário — PARE na fase de validação

- A **fase de validação** (fase 3 do ciclo de cada sessão) é executada pelo **usuário**.
- Ao concluir a fase de **implementação (TDD, fase 2)** — todos os passos red→green→commit
  feitos e suíte/lint verdes — o agente **DEVE PARAR** e **aguardar o feedback do usuário**.
- **Não** marcar fases como `Concluída`/`Done` no arquivo da sessão, **não** atualizar
  `REQUIREMENTS.md`/`SESSIONS.md` com status de validação e **não** commitar a
  conclusão da sessão até o usuário validar explicitamente.
- Ao receber o feedback, registrar a validação no arquivo da sessão e só então
  atualizar `REQUIREMENTS.md`/`SESSIONS.md` e commitar a validação.

## SDD — robustez do fluxo (regras do processo)

- **S1 — Critérios apontam os testes que os provam.** Cada critério de aceite (seções
  "Resultado"/"Garantias" do arquivo da sessão) referencia o **teste (arquivo/nome)**
  que o prova — no framework do projeto (ver `STACK.md`); critério sem teste
  automatizado registra `manual` explícito. Critério de **comportamento** no padrão
  **EARS** quando couber (`QUANDO/SE <gatilho> ENTÃO <resultado> — <qualificador>`);
  **UI puramente visual** (layout/copy/cor) é `manual` por padrão — nunca exige teste
  automatizado.
  Fecha-se isso no **refinamento (fase 1)**, antes de codar.
- **S2 — Validação é tabela por critério.** A fase 3 registra
  `critério | evidência automatizada | evidência manual | resultado (ok/nok)` — um
  resultado **por critério**, nunca um bloco único ("todos atendidos").
- **S3 — Ajuste de validação é uma alteração formal de critério.** Falha de critério na
  validação **reabre o critério**, registra a alteração com data e o usuário **reaprova**;
  nunca aplicar "ajuste" de validação sem registrar essa alteração. **Exceção UI (S3
  leve):** ajuste puramente visual (layout/copy/cor) é anotado na sessão com data e
  aplicado — sem reabrir o critério; reabre só se mudar comportamento observável.
- **S4 — `SESSIONS.md` acompanha todo refinamento.** A seção "Próxima sessão" e a
  tabela de progresso são atualizadas **no commit do refinamento (fase 1)** de **toda**
  sessão — inclusive sessões fora da fila.
- **S5 — `./scripts/check_docs` valida a consistência.** Confere `sessions/` ↔ tabela de
  progresso do `SESSIONS.md` ↔ "Próxima sessão" (+ aviso de RF sem sessão — drift).
  Rodar ao fechar refinamento e validação.
- **S6 — Memória da sessão (handoff + gotchas) ao fim da fase 2, SEM validação do
  usuário, SEM commit.** Com o TDD verde (e veredito `Aprovado` quando houver revisão —
  S7), o implementador grava **handoff** (`memory_handoff_begin` — o que foi entregue,
  perguntas em aberto, próximos passos, marcado `provisional:true`) e **gotchas**
  levantados na sessão (`memory_write_page` em `gotchas/`, marcados `provisional:true`), sempre escopados ao projeto
  corrente — sem aguardar a fase 3 e sem commitar a conclusão. A validação do usuário (fase 3)
  só confirma/enriquece a memória, nunca bloqueia o save.
- **S7 — Revisão (fase 2c) é opt-in por risco.** Por padrão a fase 2 vai direto à
  validação do usuário, com o **Converge** do Implementador (diff × cada critério,
  registrado como `> Converge: sim|nao` na sessão) como auto-verificação. A revisão
  **só dispara** quando o refinamento marca `> Revisão: exigida` (mudança em dados
  persistidos, auth, dinheiro, refatoração ampla) ou quando o usuário pedir. Havendo
  revisão, o **Revisor** devolve um **veredito fechado** (`Aprovado` | `Requer ajuste` + severidade). Se não aprovado,
  volta ao **Implementador**, que resolve os achados e re-commita; o Revisor re-revisa.
  **Teto: 3 rodadas** — sem convergir, **escalar ao usuário (S3)**. Só o Implementador edita —
  e, com `> Equipe:` (perfil `--with-especialistas`), os especialistas **nas suas lanes**;
  o Revisor nunca.

## Ideias, melhorias e escopos grandes — anotar, refinar depois

- Ideias, melhorias e escopos **grandes** identificados durante uma sessão (em qualquer
  fase) são **anotados** — no `REQUIREMENTS.md` (limitações/roadmap) ou na seção de
  observações do arquivo da sessão — mas **não** são refinados nem seguem o fluxo
  (novo arquivo de sessão + critérios de aceite + plano TDD) **enquanto a sessão atual
  não estiver concluída e validada**.
- A **regra da fase atual** continua valendo: nada de abrir novo escopo no meio de uma
  sessão; a anotação não bloqueia nem altera o fluxo corrente.
- Somente **após** a conclusão/validação da sessão corrente, a anotação pode virar uma
  **nova sessão** (refinamento → TDD → validação).

## Draft de ideias — anotar para fases futuras

- **Ideias, refatorações e decisões de mudanças grandes** (identificadas em qualquer
  fase da sessão) são **anotadas em `{{DRAFT_PATH}}`** (o draft único e
  consolidado — catálogo de feito/pendente) para serem **incluídas em fases
  futuras** — seja em uma fase específica mais adiante, seja quando todas as fases
  correntes/agendadas estiverem finalizadas.
- O draft é **fora do fluxo** (não gera critérios de aceite nem plano TDD na hora).
  Registrar uma ideia no draft **não** abre novo escopo nem atrasa a sessão em curso.
- Ao concluir as fases, o draft é **revisado**: o que entra vira sessão, o que não se
  aplica é descartado — decisão do usuário.
- Convenção de commit para anotações do tipo: `draft: <resumo do que foi anotado>`
  (tipo `draft:`, seguindo o formato de commit do projeto).

## Formato de commit (regra do projeto)

- **Formato:** `tipo[(escopo)]: descrição concisa`. O **tipo é obrigatório** e sai da
  lista abaixo; a descrição diz o **resultado**, não a atividade ("implementacao",
  "ajustes").
- **Escopo opcional** entre parênteses: o contexto do kit vira escopo — `(passo N)`,
  `(passos N-M)`, `(sessao 00NN)`.
- **Corpo opcional:** linha em branco + bullets para detalhar decisões.
- **Histórico:** a regra vale do próximo commit em diante — os commits antigos
  (`Passo N: ...`, `Sessao 0001: ...`) permanecem. `Draft:` já era um tipo: agora é
  `draft:` (minúsculo).

| Tipo | Quando usar | Exemplo |
| --- | --- | --- |
| `test(passo N):` | green do passo TDD `N` | `test(passo 1): repository#all via schema + setup` |
| `test(passos N-M):` | green de passos agrupados | `test(passos 3-4): DELETE idempotente` |
| `docs(sessao 00NN):` | refinamento (fase 1) fechado | `docs(sessao 0002): refinamento concluido — criterios e plano TDD fechados` |
| `docs(sessao 00NN):` | validação do usuário (fase 3) | `docs(sessao 0002): validacao — requisito Done, criterios verificados, prox 0003` |
| `docs(sessao 00NN):` | sessão fechada | `docs(sessao 0001): concluida — validacao integrada, proxima sessao 0002` |
| `docs(sessao 00NN):` | checkpoint de progresso | `docs(sessao 0001): progresso — passo 4 verde e validado` |
| `docs:` | mudança de convenção/regra | `docs: validacao e feita pelo usuario — parar na fase 3` |
| `chore:` | kit/tooling (install, scripts, config) | `chore: install --force preserva conteudo de autoria` |
| `draft:` | anotação de ideia/draft | `draft: performance da gateway anotada` |
| `feat:` `fix:` `refactor:` | comportamento novo / correção / refatoração | `feat: tambor aceita drop por pointer` |

> Substitua o bloco `# Projeto — índice rápido` (comandos do projeto, mapa de código,
> armadilhas) pelo seu conteúdo específico — ele **não** faz parte do protocolo.
> `./scripts/check_docs` roda no host (apenas grep); demais scripts de projeto usam o
> setup do seu repo.
