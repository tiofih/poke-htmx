---
name: sdd
description: Fluxo de papéis do SDD do {{PROJETO}} — Refinador (ou modo rápido inline) → Implementador/Teste → Revisor (opt-in por risco) → (Playtester opcional) → validação do usuário. Use quando for abrir/refinar uma sessão, implementar TDD, revisar um diff ou decidir a próxima etapa do ciclo. Também cobre o Converge (auto-verificação fim da fase 2), o loop Implementador↔Revisor (S7, só em sessão de risco), o caminho bugfix e o gatilho de parada antes da validação.
---

# SDD — ciclo de papéis ({{PROJETO}})

## Fases e papéis (cada fase = um subagent, despachado via `task` `subagent_type`)

| Fase | Papel (subagent_type) | Entregável | Quando disparar |
|---|---|---|---|
| 1 — Refinamento (CONVERSA) | `refinador` (investigação → finalize) — ou **inline** com `--rapido` (clarificações em cima, artefatos de uma vez) | **investigação**: mapa de decisões (opções A/B/C, recomendada). **finalize**: sessão `sessions/NNNN-*.md` + `SESSIONS.md` (S4) | sessão nova / refinamento pendente |
| 2 — TDD | `implementador-teste` | código + testes, commits `test(passo N):`, suíte+lint verdes, `> Converge: sim` (diff × critérios) | refinamento aprovado |
| 2c — Revisão | `revisor` | diff revisado + `VEREDITO: Aprovado` \| `Requer ajuste` | **só** com `> Revisão: exigida` (risco) ou pedido do usuário (S7) |
| 2d — Entrega (modo PR) | `implementador-teste` (corpo gerado da sessão + commit → `abrir-pr`) | corpo do PR em `sessions/pr/NNNN-pr-body.md` + PR/MR aberto e registrado na sessão | só com o marcador `<!-- sdd-pr: ativo -->` em `AGENTS.md` |
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
  Critério de comportamento em **EARS** (`QUANDO/SE ... ENTÃO ...`) quando couber; UI
  puramente visual é `manual` por padrão.
- **Converge (fim da fase 2):** antes de sinalizar pronto, o `implementador-teste` percorre
  **diff × cada critério** e registra `> Converge: sim` (ou `nao` + pendências) na sessão.
- **S7 — revisão opt-in por risco:** por padrão a fase 2 vai direto à validação (com o
  Converge). Dispare o `revisor` **só** se a sessão marcar `> Revisão: exigida` (dados
  persistidos, auth, dinheiro, refatoração ampla) ou se o usuário pedir. Havendo revisão: se
  ele devolver `Requer ajuste`, re-dispare `implementador-teste` e depois `revisor` de novo
  (**teto 3 rodadas**; sem convergência, **escalar S3**). Só `implementador-teste` edita.
- **Caminho bugfix (PROTOCOL 3c):** correção de bug não roda refinador — análise inline
  (atual/esperado/inalterado) → teste de regressão red→green → Converge → entrega. Revisor
  só se o bug tocar risco. Escopo maior vira sessão normal.
- **S8 — modo PR (só com `--with-pr`, marcador `<!-- sdd-pr: ativo -->` em `AGENTS.md`):** a entrega
  da sessão é **um PR/MR** — um PR por sessão, corpo escrito pelo `implementador-teste` para quem
  **não** trabalha no projeto (rastreabilidade no `## Anexo` do fim) — e a validação do usuário é a
  **revisão desse PR**. Todo critério declara a reprodução (`seed`/`script`/`manual`/`nao-aplicavel`)
  e o e2e onde houver harness; **sem `checar-pr`** — o corpo é gerado do arquivo da sessão e a
  sobra (compreensão, passos, veracidade da evidência) é julgamento do `revisor` (quando houver)
  e do usuário; o teto de 3 rodadas do loop Implementador↔Revisor **não muda**;
  **merge é do usuário, nunca do agente**.
- **Parada obrigatória na fase 3:** NUNCA marcar a sessão como `Done`, NUNCA commitar
  conclusão nem preencher a tabela de validação — a fase 3 é do usuário.
- **S6:** ao fechar a fase 2 (TDD verde; com `Aprovado` quando houver revisão), gravar
  **handoff** (`memory_handoff_begin`) e **gotchas** (`memory_write_page` em `gotchas/`),
  escopados ao projeto.
- **Contexto mínimo:** cada papel lê `./scripts/levantar-sessao NNNN`,
  `./scripts/levantar-requisito RF-XX`, `./scripts/levantar-testes`, `./scripts/levantar-roadmap`.
  NUNCA ler `REQUIREMENTS.md`/`SESSIONS.md` inteiros.
- **Comandos de projeto:** teste e lint conforme o `STACK.md` do projeto, mais
  `./scripts/check_docs` (do kit). NUNCA rode teste/lint fora do ambiente do projeto.

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
