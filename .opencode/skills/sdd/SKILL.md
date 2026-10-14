---
name: sdd
description: Fluxo de papéis do SDD do Poke-HTMX — Refinador → Implementador/Teste → Revisor → (Playtester opcional) → validação do usuário. Use quando for abrir/refinar uma sessão, implementar TDD, revisar um diff ou decidir a próxima etapa do ciclo. Também cobre o loop Implementador↔Revisor (S7) e o gatilho de parada antes da validação.
---

# SDD — ciclo de papéis (Poke-HTMX)

## Fases e papéis (cada fase = um subagent, despachado via `task` `subagent_type`)

| Fase | Papel (subagent_type) | Entregável | Quando disparar |
|---|---|---|---|
| 1 — Refinamento (CONVERSA) | `refinador` (investigação → finalize) | **investigação**: mapa de decisões (opções A/B/C, recomendada). **finalize**: sessão `sessions/NNNN-*.md` + `SESSIONS.md` (S4) | sessão nova / refinamento pendente |
| 1b — Desenho técnico | `arquiteto` (read-only) | fatias (frontend/backend/devops), contratos, riscos de acoplamento | refinamento aprovado, antes de implementar |
| 2 — TDD | `implementador-teste` (+ `frontend`/`backend` como fatias) | código + testes, commits `Passo N:`, suíte+lint verdes | desenho pronto (ou refinamento, se trivial) |
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
- **Economia por papel (ponytail + caveman):** `implementador-teste` = ponytail ULTRA + caveman full na prosa (testes/S1 intocáveis); `revisor` = lente ponytail FULL (item 5 de over-engineering) + caveman full nos achados; `refinador` = ponytail LITE + caveman lite/off no mapa (nuance p/ o usuário); `playtester` = ambos OFF.
- **Especialistas por área (fase 2):** o `implementador-teste` pode delegar fatias a `frontend` / `backend` (genéricos, especializam via `STACK.md` do repo); só o `implementador-teste` commita.
- **Roteamento coder/frontend/backend por escopo:** só views+public→frontend; só lib+server.rb+db+config→backend; ambos ou desconhecido→coder (triage); teste segue o código que trava; scripts/docker/CI→devops; visual→design-review; números→game-design; QA→qa-e2e.
- **Comandos de projeto:** `./scripts/test`, `./scripts/lint`, `./scripts/check_docs` (+ `scripts/medir-uso-grafo` para taxa read:mcp).
  NUNCA `rake`/`rubocop` no host.

## Regra de ouro para o agente
Ao receber um pedido de sessão SDD, **decida a fase pelo estado** (session file `## Status`)
e **dispache o papel certo**, em vez de fazer tudo inline. Confirme cada transição de papel
com o usuário quando envolver decisão (objetivo/escopo/critérios/ajustes).

<!-- sdd-especialistas:bloco -->
## Fase 2 paralela — especialistas (`--with-especialistas`)

| Papel (`subagent_type`) | Lane | Edit | Quando disparar |
|---|---|---|---|
| `backend` | servidor/API/dados + testes da lane | sim | `> Equipe:` cita `backend` |
| `frontend` | templates/CSS/JS cliente + testes da lane | sim | `> Equipe:` cita `frontend` |
| `qa` | cobertura S1/EARS, estado da suíte | não (read-only) | `> Equipe:` cita `qa` |
| `ui-designer` | decisões visuais (propõe; `frontend` implementa) | não (read-only) | `> Equipe:` cita `ui-designer` |
| `game-designer` | mecânica/balanceamento (recomenda; decide o usuário) | não (read-only) | `> Equipe:` cita `game-designer` |
| `security-reviewer` | auth/dados/segredos/entradas de confiança (achado ranqueado; sugere `> Revisão: exigida`) | não (read-only) | `> Equipe:` cita `security-reviewer` |
| `a11y-auditor` | acessibilidade da lane UI: teclado, foco, semântica, contraste, toque, motion (tabela WCAG) | não (read-only) | `> Equipe:` cita `a11y-auditor` |

- **Portão duplo:** o agente em `.opencode/agent/<papel>.md` **E** `> Equipe: <papéis>`
  no arquivo da sessão (fechado no refinamento — o refinador **decide** a escala:
  produção → lane; editores só com ≥2 lanes disjuntas; read-only por risco; `—` = sozinho).
  Sem os dois, a fase 2 é o
  `implementador-teste` sozinho, como sempre — não existe "fase degradada".
- **Paralelo só com lanes disjuntas** (arquivos de produção não-sobrepostos):
  `backend ∥ frontend ∥ qa ∥ ui-designer ∥ game-designer` vale; dois editores na mesma
  lane, ou lane com dependência de arquivo do outro → **sequencial**. Read-only disputam
  nada e rodam com qualquer um.
- **Durante o paralelismo:** cada especialista edita **só a sua lane** e roda **apenas
  testes da lane** (filtro por arquivo). **Suíte completa + lint 0 + commits** são do
  `implementador-teste` ao **integrar** (1 commit por lane/green — especialista não
  commita, para o índice não disputar em paralelo).
- **Integração, `> Converge:` e S6** continuam com o `implementador-teste` — ele é quem
  responde pela fase 2. **S7 amendado:** "só o Implementador edita" inclui os
  especialistas **nas suas lanes**; o Revisor continua nunca editando, e revisa o diff
  consolidado.
- Sem contraparte no harness (task sem o subagente): despache inline pelo orquestrador
  injetando no prompt o papel + a lane + a regra "não commita"; integre do mesmo jeito.
<!-- fim sdd-especialistas:bloco -->

<!-- sdd-redator:bloco -->
## Corpo do PR com `redator-pr` (papel barato — só com `--with-pr`)

- **Portão:** só se `.opencode/agent/redator-pr.md` existir. Sem ele, o
  `implementador-teste` escreve o corpo no passo PR — fluxo padrão, inalterado.
- Com ele, na fase 2: no spawn do `implementador-teste` acrescente ao prompt *"o corpo do
  PR será gerado por outro papel — faça TDD + Converge e **pare antes** de escrever
  `sessions/pr/NNNN-pr-body.md`"*.
- Depois do Converge: dispare `redator-pr` (modelo barato — proza derivada da sessão) →
  confira a coerência com o arquivo da sessão → commite
  (`docs(pr 00NN): corpo do PR — <resumo>`) → `./scripts/abrir-pr NNNN --open` →
  registre `> PR: <url>` na sessão.
- `> Revisão: exigida` (S7): o corpo entra na revisão **antes** do abrir-pr.
- S8 vale inteiro: um PR por sessão, nunca merge, feedback = S3 atualizando o corpo.
<!-- fim sdd-redator:bloco -->

<!-- sdd-debate:bloco -->
## Debate entre modelos (`debatedor`, só com o perfil `--with-debate`)

- **Portão:** só se `.opencode/agent/debatedor.md` existir **e** o usuário pedir, ou o
  `refinador` travar num A/B com tradeoff real que nenhum critério decide. Sem isso, o
  debate **não existe** — refinamento normal, sem custo extra.
- **Brief (orquestrador escreve, 1×):** contexto + A/B com prós/contras + pergunta +
  "o que viraria o voto". Sem brief, não há spawn.
- **Round 1 — 3 votos independentes, em paralelo**, cada spawn com `model:` de uma
  **família distinta** (nunca o mesmo id nos 3):

  | Voto | `model:` sugerido | Família |
  |---|---|---|
  | 1 | `omniroute/auto/smart` | raciocínio |
  | 2 | `omniroute/auto/gemini` | Google |
  | 3 | `omniroute/oc/mimo-v2.5-free` | OpenCode free |

  Alternativas livres: `omniroute/auto/cheap`, `omniroute/auto/llama`, `omniroute/auto/glm`.
- **Checagem de diversidade (obrigatória):** cada voto declara o backend real (`routed:`).
  `auto/*` varia por chamada — se dois votos caírem no mesmo backend, re-dispare o
  terceiro com outra família antes do round 2. Debate com 1 backend só é 1 opinião
  repetida, não debate.
- **Round 2 — réplica cruzada:** cada debatedor recebe os outros dois votos e devolve
  advogado-do-diabo + `VEREDITO FINAL:`. **Teto: 2 rounds** — sem terceiro round, sem
  desempate por voto extra; empate vira "sem consenso" e o usuário decide.
- **Síntese (orquestrador + `refinador`, nunca o debatedor):** vencedor entra no mapa de
  decisões como recomendação; cada **condição de flip vira check explícito** (teste,
  leitura de código ou critério) antes de fechar. Debatedor não marca critério (S1),
  não reabre decisão (S3) e não grava memória (S6).
- **Custo:** free-tier do gateway + resposta curta (cortar em ~400 tokens). Debate é o
  papel mais barato do ciclo depois do `redator-pr`.
- **Gotchas (medidos em 2026-09-29):** `oc/*` só responde via subagent (origem OpenCode;
  curl direto dá `403 free tier can only be used from within OpenCode`) — nunca rode o
  debate por script/shell. Sem provider `omniroute` no `opencode.json`, rode 1× inline
  com o modelo default e declare `diversidade: nenhuma`.
- No harness sem override de modelo por spawn: reduza a 1 debatedor inline (recomendação
  única + condição de flip) em vez de fingir debate.
<!-- fim sdd-debate:bloco -->
