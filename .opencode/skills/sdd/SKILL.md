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
- **Grafo obrigatório (antes de qualquer read/grep):** quando `graphify-out/` existe (índice `Users-tiofih-workspace-poke-htmx` 5196 nodes), **NUNCA** usar `read`/`grep`/`glob` para explorar — use `codebase-memory-mcp` (`search_graph limit10` → `get_code_snippet` → `trace_path` → `check_index_coverage`) ou `graphify query/explain/path`. `read` é só para **editar** (precisa do byte exato p/ `edit` casar). `grep` só para literais/mensagens de erro/configs ou quando MCP retorna insuficiente (e então cite o gap).
- **Delegação com grafo (orquestrador → subagent):** antes de `task(subagent_type)`, o orquestrador **deve** rodar `search_graph + get_code_snippet + trace_path + check_index_coverage` no parent e injetar no `prompt` do filho: `tier` (Verify por padrão), `project`, `qualified_name`, `paths`, `coverage` (`no_recorded_issue` vs `parse_partial` com ranges), `scopes` e perguntas em aberto. O filho **não** herda MCP automaticamente — sem esse contexto ele volta ao `read`.
- **Comandos de projeto:** `./scripts/test`, `./scripts/lint`, `./scripts/check_docs` (+ `scripts/medir-uso-grafo` para taxa read:mcp).
  NUNCA `rake`/`rubocop` no host.

## Regra de ouro para o agente
Ao receber um pedido de sessão SDD, **decida a fase pelo estado** (session file `## Status`)
e **dispache o papel certo**, em vez de fazer tudo inline. Confirme cada transição de papel
com o usuário quando envolver decisão (objetivo/escopo/critérios/ajustes).
