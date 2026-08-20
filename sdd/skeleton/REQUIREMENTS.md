# Requisitos — {{PROJETO}}

## Visão Geral

{{PROJETO}} segue **Spec-Driven Development (SDD)**: cada incremento é uma **sessão**
(refinamento → TDD → validação). Este arquivo é a **fonte da verdade** dos requisitos;
o registro das sessões vive em `SESSIONS.md`.

## Definition of Done (Global)

Para que um requisito seja considerado **completo**, todos os itens abaixo devem ser verdadeiros:

- [ ] Todos os **critérios de aceite** do requisito implementados e verificados.
- [ ] Testes cobrindo o comportamento implementado, todos **verdes**.
- [ ] Nenhuma regressão na suíte existente (baseline N runs/M asserts preservado).
- [ ] `REQUIREMENTS.md` e `SESSIONS.md` **atualizados** no mesmo commit.
- [ ] Commit realizado após cada `green` (TDD).
- [ ] Commit realizado ao concluir e validar cada fase de **refinamento** (critérios de aceite e plano TDD fechados).
- [ ] Um **passo** só é considerado concluído após a **validação** (suíte verde + critérios verificados) — o passo seguinte só é iniciado quando todas as fases do passo anterior estiverem devidamente concluídas e validadas.

## Stack

| Item | Tecnologia |
| --- | --- |
| Linguagem | — |
| Framework | — |
| Persistência | — |
| Testes | — |
| Infra | — |

## Requisitos Funcionais

| RF | Descrição | Status |
| --- | --- | --- |

## Requisitos Não-Funcionais

### RNF/TDD — desenvolvimento — `Approved`

- Toda implementação **começa por um teste que falha** (red), depois implementação mínima (green) e depois refatoração.
- **Commit obrigatório após cada green.**
- **Commit obrigatório após cada fase de refinamento concluída e validada**.
- `REQUIREMENTS.md` e `SESSIONS.md` sempre atualizados no mesmo escopo.
- **Sequenciamento:** um passo só é iniciado quando todas as fases do passo anterior estiverem concluídas e validadas.
- **SDD robustecido (S1/S2/S3):** critérios de aceite referenciam os **testes que os
  provam** (sem teste automatizado = `manual` explícito); a validação é registrada como
  **tabela por critério** e todo **ajuste de validação** é **alteração formal de
  critério** (reaberto + reaprovado pelo usuário).
- **Consistência dos docs (S4/S5):** `SESSIONS.md` (tabela + "Próxima sessão") é
  atualizado **no commit do refinamento** de toda sessão (inclusive fora de fila);
  `./scripts/check_docs` valida sessões ↔ `SESSIONS.md` ↔ "Próxima sessão".
- **Ideias/escopos grandes fora da fase:** são **anotados** (limitações/roadmap ou
  observações da sessão), mas só seguem o fluxo (refinamento → TDD → validação) **após
  a sessão corrente ser concluída e validada**.

## Limitações Conhecidas / Pontos de Refinamento

- [ ] *(anote aqui itens de robustez/melhoria identificados — viram sessão após a corrente validar)*

## Roadmap (executado em `SESSIONS.md`)

| # | Sessão | Status |
| --- | --- | --- |