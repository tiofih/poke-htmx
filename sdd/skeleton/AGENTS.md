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
  "Resultado"/"Garantias" do arquivo da sessão) referencia o **teste (arquivo/nome
  Minitest)** que o prova; critério sem teste automatizado registra `manual` explícito.
  Fecha-se isso no **refinamento (fase 1)**, antes de codar.
- **S2 — Validação é tabela por critério.** A fase 3 registra
  `critério | evidência automatizada | evidência manual | resultado (ok/nok)` — um
  resultado **por critério**, nunca um bloco único ("todos atendidos").
- **S3 — Ajuste de validação é uma alteração formal de critério.** Falha de critério na
  validação **reabre o critério**, registra a alteração com data e o usuário **reaprova**;
  nunca aplicar "ajuste" de validação sem registrar essa alteração.
- **S4 — `SESSIONS.md` acompanha todo refinamento.** A seção "Próxima sessão" e a
  tabela de progresso são atualizadas **no commit do refinamento (fase 1)** de **toda**
  sessão — inclusive sessões fora da fila.
- **S5 — `./scripts/check_docs` valida a consistência.** Confere `sessions/` ↔ tabela de
  progresso do `SESSIONS.md` ↔ "Próxima sessão". Rodar ao fechar refinamento e validação.
- **S6 — Memória da sessão (handoff + gotchas) na validação.** Ao fechar a fase 3, o
  implementador grava **handoff** (`memory_handoff_begin` — o que foi entregue, perguntas
  em aberto, próximos passos) e **gotchas** levantados na sessão (`memory_write_page` em
  `gotchas/`), sempre escopados ao projeto corrente — para o próximo agente partir com
  contexto e as lições virarem conhecimento duradouro.
- **S7 — Loop Implementador↔Revisor na fase 2c.** Ao fim da fase 2 (TDD), o **Revisor**
  devolve um **veredito fechado** (`Aprovado` | `Requer ajuste` + severidade). Se não aprovado,
  volta ao **Implementador**, que resolve os achados e re-commita; o Revisor re-revisa.
  **Teto: 3 rodadas** — sem convergir, **escalar ao usuário (S3)**. Só o Implementador edita;
  o Revisor nunca. Vai à validação (fase 3) apenas com veredito `Aprovado`.

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
  fase da sessão) são **anotadas em `draft-*.md`** para serem **incluídas em fases
  futuras** — seja em uma fase específica mais adiante, seja quando todas as fases
  correntes/agendadas estiverem finalizadas.
- O draft é **fora do fluxo** (não gera critérios de aceite nem plano TDD na hora).
  Registrar uma ideia no draft **não** abre novo escopo nem atrasa a sessão em curso.
- Ao concluir as fases, o draft é **revisado**: o que entra vira sessão, o que não se
  aplica é descartado — decisão do usuário.
- Convenção de commit para anotações do tipo: `Draft: <resumo do que foi anotado>`.

## Formato de commit (regra do projeto)

- **Formato:** uma linha `Contexto: descrição concisa`. **Sem** prefixos genéricos
  (`feat:`, `fix:`, `chore:`). Descrever o que mudou e por quê (resultado), não
  "teste"/"implementação".
- **Corpo opcional:** linha em branco + bullets para detalhar decisões.

| Contexto | Quando usar | Exemplo |
| --- | --- | --- |
| `Passo N:` | green do passo TDD `N` | `Passo 1: repository#all via schema + setup` |
| `Passos N-M:` | green de passos agrupados | `Passos 3-4: testes de DELETE idempotente` |
| `Sessao 00NN: refinamento concluido — ...` | refinamento (fase 1) fechado | `Sessao 0002: refinamento concluido — criterios e plano TDD fechados` |
| `Validacao sessao 00NN: ...` | validação do usuário (fase 3) | `Validacao sessao 0002: requisito Done, criterios verificados, prox sessao 0003` |
| `Sessao 00NN concluida: ...` | sessão fechada | `Sessao 0001 concluida: validacao integrada, proxima sessao 0002` |
| `Regra: ...` | mudança de convenção/regra | `Regra: validacao e feita pelo usuario — parar na fase 3` |
| `Draft: ...` | anotação de ideia/draft | `Draft: performance da gateway anotada` |

> Substitua o bloco `# Projeto — índice rápido` (comandos do projeto, mapa de código,
> armadilhas) pelo seu conteúdo específico — ele **não** faz parte do protocolo.
> `./scripts/check_docs` roda no host (apenas grep); demais scripts de projeto usam o
> setup do seu repo.