---
description: Abre/continua uma sessão SDD RODANDO OS PAPÉIS como subagents (Refinador → Implementador/Teste → Revisor → Playtester opcional), parando na validação do usuário. Use para trabalhar uma sessão no fluxo de papéis.
agent: build
---

Você está iniciando/continuando uma **sessão SDD do Poke-HTMX** usando os **papéis de subagent**
(chame o skill `sdd` se precisar do guia). Regras base: `AGENTS.md` (S1–S7), `SESSIONS.md`,
`REQUIREMENTS.md`. **Ressalto:** a execução é feita pelos **subagents**, não por você inline.

## 0. Argumentos do usuário (opcional)
`$ARGUMENTS` pode indicar a sessão/fase (ex.: "refinar 0055", "implementar 0054"). Se não vier,
decida pelo estado do projeto.

## 1. Kickoff (levante o estado — contexto mínimo)
- Rode `./scripts/iniciar-sessao` e `./scripts/levantar-roadmap` (digests) para saber a
  próxima sessão/estado. **Não** leia `REQUIREMENTS.md`/`SESSIONS.md` inteiros.

## 2. Decida a fase (sessão mais recente pendente)

| Estado da sessão | Papel a disparar |
| --- | --- |
| Refinamento pendente | **fase 1** → subagent `refinador` (fecha objetivo/escopo/critérios S1/plano TDD). Apresente ao usuário e **aguarde aprovação**. |
| Refinamento feito, Implementação pendente | **fase 2** → subagent `implementador-teste` (TDD, suíte+lint verdes, commits `Passo N:`). |
| Implementação feita | **fase 2c** → subagent `revisor`; se `VEREDITO: Requer ajuste`, re-dispare `implementador-teste` e depois `revisor` de novo (**loop S7, teto 3 rodadas**, senão escalar S3) até `Aprovado`. |
| Pronto para validar | **fase 3** → **PARE** (é do usuário). NÃO marcar Done, NÃO validar, NÃO commitar conclusão. |
| Playtester | só dispare se o usuário pedir / tiver valor (advisory, não substitui a S2). |

## 3. Como disparar cada papel
- Sempre via **`task`** com `subagent_type`: `refinador` · `implementador-teste` · `revisor` · `playtester`.
- Passe ao subagent o contexto necessário (arquivo da sessão `sessions/NNNN-*.md`, o
  commit/papel anterior, e o handoff `memory_handoff_accept` se houver).
- Cada subagent segue as regras do seu próprio prompt (verificado no kit/AGENTS.md).

## 4. Ao encerrar cada papel
- Reporte o estado (commit/SHA, suíte+lint, veredito) e a **próxima etapa**.
- **Nunca** salte a validação do usuário; **nunca** marque a sessão como `Done` antes dela.
