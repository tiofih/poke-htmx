---
name: sdd
description: Fluxo de papéis do SDD do Poke-HTMX — Refinador → Implementador/Teste → Revisor → (Playtester opcional) → validação do usuário. Use quando for abrir/refinar uma sessão, implementar TDD, revisar um diff ou decidir a próxima etapa do ciclo. Também cobre o loop Implementador↔Revisor (S7) e o gatilho de parada antes da validação.
---

# SDD — ciclo de papéis (Poke-HTMX)

## Fases e papéis (cada fase = um subagent, despachado via `task` `subagent_type`)

| Fase | Papel (subagent_type) | Entregável | Quando disparar |
|---|---|---|---|
| 1 — Refinamento (CONVERSA) | `refinador` (investigação → finalize) | **investigação**: mapa de decisões (opções A/B/C, recomendada). **finalize**: sessão `sessions/NNNN-*.md` + `SESSIONS.md` (S4) | sessão nova / refinamento pendente |
| 2 — TDD | `implementador-teste` | código + testes, commits `Passo N:`, suíte+lint verdes | refinamento aprovado |
| 2c — Revisão | `revisor` | diff revisado + `VEREDITO: Aprovado` \| `Requer ajuste` | implementação feita |
| 3 — pré-validação | `playtester` (OPCIONAL) | achados de UX/comportamento no app rodando | só se o usuário pedir / tiver valor |
| 3 — Validação | **usuário** | tabela por critério (S2) / S3 | **nunca a IA** |

## Fase 1 é conversa (não imposição)
- O `refinador` em **investigação** NÃO decide: levanta objetivo, escopo/fora-de-escopo,
  critérios→teste (S1) e decisões de design como **opções A/B/C + recomendação**, e devolve o
  **mapa de decisões** (`AGUARDANDO ESCOLHA DO USUÁRIO`).
- O orquestrador apresenta cada decisão ao usuário (via `question`) e coleta as escolhas.
- Só então re-dispare o `refinador` em **finalize** (com as escolhas) para escrever a sessão + commitar.
- **Nunca** aceitar um refinamento resolvido por um único passo automático do subagent.

## Regras que guiam o despacho

- **S1:** cada critério referencia o teste que o prova; sem teste → `manual` explícito.
- **S7 — loop Implementador↔Revisor:** se o `revisor` devolver `Requer ajuste`, re-dispare
  `implementador-teste` para resolver os achados e re-commitar, depois `revisor` de novo.
  **Teto 3 rodadas**; sem convergência, **escalar S3** (reabrir critério com o usuário).
  Só `implementador-teste` edita; `revisor` nunca edita.
- **Parada obrigatória na fase 3:** NUNCA marcar a sessão como `Done`, NUNCA commitar
  conclusão nem preencher a tabela de validação — a fase 3 é do usuário.
- **S6:** ao fechar, gravar **handoff** (`memory_handoff_begin`) e **gotchas**
  (`memory_write_page` em `gotchas/`), escopados ao projeto.
- **Contexto mínimo:** cada papel lê `./scripts/levantar-sessao NNNN`,
  `./scripts/levantar-requisito RF-XX`, `./scripts/levantar-testes`, `./scripts/levantar-roadmap`.
  NUNCA ler `REQUIREMENTS.md`/`SESSIONS.md` inteiros.
- **Comandos de projeto:** `./scripts/test`, `./scripts/lint`, `./scripts/check_docs`.
  NUNCA `rake`/`rubocop` no host.

## Economia de tokens (hábitos)
- **Digest antes de leitura integral:** prefira o resumo/digest da sessão, do requisito
  e do roadmap ao arquivo inteiro; leia na íntegra só o arquivo da sessão corrente.
- **Snippet escopado antes de busca ampla:** parta da definição/símbolo exato
  (arquivo + linhas) antes de varrer a base; amplie o escopo só se o snippet não bastar.
- **Orquestrador injeta contexto nos filhos:** o filho não redescobre — recebe no
  `prompt` os `paths`/`qualified_names`/trechos já levantados.

## Papéis SDD → fallback no harness

| Papel SDD | `subagent_type` preferido | Se indisponível |
|---|---|---|
| `refinador` | `planner` | executar a fase inline seguindo `skeleton/agents/refinador.md` |
| `implementador-teste` | `coder` | executar a fase inline seguindo `skeleton/agents/implementador-teste.md` |
| `revisor` | `reviewer` | executar a fase inline seguindo `skeleton/agents/revisor.md` |
| `playtester` (opcional) | sem fallback — pule a fase | só existe se o usuário pedir |

Sem contraparte SDD (advisory, usáveis dentro de qualquer fase, nunca donos de
transição de fase): `researcher`, `designer`, `gitter`.

## Regra de ouro para o agente
Ao receber um pedido de sessão SDD, **decida a fase pelo estado** (session file `## Status`)
e **dispache o papel certo**, em vez de fazer tudo inline. Confirme cada transição de papel
com o usuário quando envolver decisão (objetivo/escopo/critérios/ajustes).
