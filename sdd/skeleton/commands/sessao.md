---
description: Abre/continua uma sessão SDD RODANDO OS PAPÉIS como subagents (Refinador → Implementador/Teste → Revisor opt-in por risco → Playtester opcional), parando na validação do usuário. Use para trabalhar uma sessão no fluxo de papéis. `--rapido` = refinamento inline sem refinador (sessão pequena).
agent: build
---

Você está iniciando/continuando uma **sessão SDD do {{PROJETO}}** usando os **papéis de subagent**
(chame o skill `sdd` se precisar do guia). Regras base: `AGENTS.md` (S1–S7), `SESSIONS.md`,
`REQUIREMENTS.md`. **Ressalto:** a execução é feita pelos **subagents**, não por você inline.

## 0. Argumentos do usuário (opcional)
`$ARGUMENTS` pode indicar a sessão/fase (ex.: "refinar 0055", "implementar 0054") ou a
flag `--rapido` (refinamento **inline**: clarificações em cima, artefatos de uma vez,
sem subagente `refinador` — sessão pequena, sem decisão de arquitetura). Se não vier
nenhum, decida pelo estado do projeto.

## 1. Kickoff (levante o estado — contexto mínimo)
- Rode `./scripts/iniciar-sessao` e `./scripts/levantar-roadmap` (digests) para saber a
  próxima sessão/estado. **Não** leia `REQUIREMENTS.md`/`SESSIONS.md` inteiros.

## 2. Decida a fase (sessão mais recente pendente)

| Estado da sessão | Papel a disparar |
| --- | --- |
| Refinamento pendente | **fase 1 (conversa)** → subagent `refinador` **em modo investigação** (ou, com `--rapido`/sessão pequena, refinamento **inline** aqui: clarificações em cima e artefatos de uma vez — PROTOCOL §1): ele devolve um **mapa de decisões** (opções A/B/C + recomendação). Apresente as decisões ao usuário uma a uma (via `question`) e **deixe-o escolher**. Só então re-dispare `refinador` em **modo finalize** (com as escolhas) para escrever `sessions/NNNN-*.md` + `SESSIONS.md` (S4) e commitar. NUNCA deixe o refinador decidir sozinho. |
| Refinamento feito, Implementação pendente | **fase 2** → subagent `implementador-teste` (TDD, suíte+lint verdes, commits `test(passo N):`, `> Converge: sim` diff × critérios). |
| Implementação feita | **fase 2c (só se risco)** → se a sessão marcar `> Revisão: exigida` ou o usuário pedir, subagent `revisor`; se `VEREDITO: Requer ajuste`, re-dispare `implementador-teste` e depois `revisor` de novo (**loop S7, teto 3 rodadas**, senão escalar S3) até `Aprovado`. Sem marcação → **pule direto para a validação** (Converge é a auto-verificação). |
| Pronto para validar | **fase 3** → **PARE** (é do usuário). NÃO marcar Done, NÃO validar, NÃO commitar conclusão. Se a mudança tem superfície visual, **mostre antes** (`browser.preview`/screenshot) junto do pedido de validação. |
| Implementação feita (modo PR ativo) | **passo PR** → subagent `implementador-teste` gera o corpo (`sessions/pr/NNNN-pr-body.md`) **do arquivo da sessão** (sem template, sem `checar-pr`), confere `> Converge: sim`, commita `docs(pr 00NN):` e roda `./scripts/abrir-pr NNNN --open`; registra `> PR: <url>`; (Revisor (2c) só se `> Revisão: exigida`, aí com o corpo no escopo dela); → **PARE** — a validação é a revisão do PR, nunca o merge pelo agente. Só vale com o marcador `<!-- sdd-pr: ativo -->` em `AGENTS.md`; **um PR por sessão**. |
| Bugfix (caminho enxuto) | **PROTOCOL 3c** → sem `refinador`: análise inline (atual/esperado/inalterado) + teste de regressão red→green via `implementador-teste` (ou inline), Converge, entrega/validação. Revisor só se tocar risco. Escopo maior vira sessão normal. |
| Playtester | só dispare se o usuário pedir / tiver valor (advisory, não substitui a S2). |

## 2b. Refinamento = conversa (regra de ouro)
Na fase 1, o Refinador investiga e **levanta opções**; **você** (orquestrador) apresenta cada
decisão ao usuário e coleta a escolha. Só escreve o arquivo da sessão **depois** de todas as
escolhas. Aplicar ao objetivo, escopo/fora-de-escopo, critérios→teste (S1) e decisões de design.
**Não** aceitar um refinamento que o subagent resolveu sozinho em um único passo.

## 3. Como disparar cada papel
- Sempre via **`task`** com `subagent_type`: `refinador` · `implementador-teste` · `revisor` · `playtester`.
- Passe ao subagent o contexto necessário (arquivo da sessão `sessions/NNNN-*.md`, o
  commit/papel anterior, e o handoff `memory_handoff_accept` se houver).
- Cada subagent segue as regras do seu próprio prompt (verificado no kit/AGENTS.md).

## 4. Ao encerrar cada papel
- Reporte o estado (commit/SHA, suíte+lint, `> Converge`/veredito) e a **próxima etapa**.
- **Nunca** salte a validação do usuário; **nunca** marque a sessão como `Done` antes dela.
- **Modo PR (só com `--with-pr`):** registre `> PR: <url>` na seção de Validação do arquivo da sessão
  assim que o `./scripts/abrir-pr` devolver a URL (o script não edita a sessão — quem registra é o
  `implementador-teste`, antes de parar). No modo PR a fase "Pronto para validar" é o **PR aberto**.
