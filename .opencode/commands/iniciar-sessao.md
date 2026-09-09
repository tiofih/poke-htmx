---
description: Inicia/continua a sessão seguindo a sequência rígida — refina, implementa (TDD) ou aguarda validação, de acordo com o estado real do projeto.
---

Você está iniciando uma **sessão de trabalho do Poke-HTMX**. Sua primeira tarefa é
identificar o estado real do projeto e executar **exatamente a próxima etapa válida**
(regra RNF-04 / sequência rígida de `AGENTS.md` e `SESSIONS.md`).

## 1. Levantamento (antes de decidir)

Leia, nesta ordem:

1. `AGENTS.md` — regras obrigatórias de fluxo e formato de commit.
2. `SESSIONS.md` — seção "Próxima sessão" e tabela "Progresso das sessões".
3. `REQUIREMENTS.md` — roadmap e requisitos.
4. O arquivo da sessão alvo em `sessions/NNNN-*.md` (a mais recente pendente).

Fique atento a `AGENTS.md` / `REQUIREMENTS.md`: a sessão corrente **não pode ser
trocada** no meio; itens grandes (ideias, draft) são apenas anotados — nunca abrir
novo escopo.

## 2. Decisão — qual fase executar

Localize a **sessão mais recente que ainda não está totalmente resolvida** (olhe
a tabela `## Status` do arquivo da sessão: `Refinamento`, `Implementação`, `Validação`).
A decisão segue nesta ordem:

| Estado da sessão | Ação |
| --- | --- |
| `Refinamento` não `Concluída`/`Done` | **Refinar** a sessão (fase 1) conforme `SESSIONS.md` — fechar objetivo, escopo, critérios de aceite e plano TDD no arquivo da sessão. |
| `Refinamento` feito e `Implementação` pendente | **Implementar (TDD)** (fase 2) conforme `SESSIONS.md` — red → green → commit por green, atualizar docs no escopo. |
| `Refinamento` e `Implementação` feitos, `Validação` pendente | **Parar** — a fase 3 é executada pelo usuário. Avisar que o passo anterior concluiu a implementação (suíte/lint verdes) e aguardar o feedback antes de marcar `Done`/commitar conclusão. |
| Todas as sessões fechadas | Propor a **próxima sessão** a partir de `SESSIONS.md` ("Próxima sessão") / `REQUIREMENTS.md` (roadmap) / `docs/draft-backlog.md`, apresentar ao usuário e **aguardar confirmação** antes de criar arquivo novo. |

Se o usuário passou argumentos, eles podem **sobrescrever** a decisão automática
(formato livre, ex.: `refinar 0012`, `implementar 0011`). Caso contrário, decida
somente pelo estado do projeto.

## 3. Execute a fase determinada

Siga o ciclo definido em `SESSIONS.md` para a fase escolhida e as regras de
`AGENTS.md` (parada obrigatória antes da validação; formato de commit em português
sem prefixos genéricos; `./scripts/test` e `./scripts/lint` para verificar).

Antes de terminar, diga explicitamente qual etapa você executou e em qual sessão,
e qual é o próximo passo do fluxo.