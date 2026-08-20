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

- Abertura: rodar `./scripts/iniciar-sessao` (digest do estado) + `./scripts/levantar-roadmap`
  (backlog/limitações abertas) e ler **na íntegra apenas o arquivo da sessão corrente**;
  consultar `REQUIREMENTS.md`/`SESSIONS.md` por **busca** (grep/índice), não ler inteiros.
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

## Regras do processo (S1–S5)

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

## Escopo grande / ideias fora de fase

- Ideias, melhorias e escopos grandes identificados durante uma sessão são
  **anotados** (em `REQUIREMENTS.md` — limitações/roadmap — ou nas observações da
  sessão), mas **não** são refinados nem viram sessão **enquanto a sessão atual não
  for concluída e validada**.
- Após a validação, a anotação pode virar **nova sessão** (refinamento → TDD → validação).
- Drafts de decisões de arquitetura/refatorações grandes vivem em arquivos `draft-*.md`,
  fora do fluxo — revisados apenas ao concluir as fases agendadas.

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

## Estrutura do arquivo de sessão

1. **Objetivo** — o incremento, em uma frase; escopo fechado pelo usuário.
2. **Critérios de aceite** — cada um aponta o teste que o prova (S1); `manual` quando
   não houver teste.
3. **Plano TDD** — passos `red → green` com a verificação (suíte baseline + lint 0).
4. **Decisões de refinamento** — decisões fechadas com o usuário.
5. **Validação** — tabela por critério (S2); suíte executada; ajustes (S3).
6. **Observações** — impedimentos, dúvidas, próximo passo sugerido.

## Verificação de consistência (S5)

`scripts/check_docs` roda **no host** (apenas grep) e confere:

1. toda sessão em `sessions/` tem linha na tabela de progresso do `SESSIONS.md`;
2. toda linha da tabela tem seu arquivo;
3. a seção "Próxima sessão" cita a sessão de maior número (a aberta no topo da fila).

Rodar ao **fechar refinamento** e ao **fechar validação**.