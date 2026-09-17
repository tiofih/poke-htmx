# Sessão {{NNNN}} — {{NOME}}

> Copie este modelo para `sessions/{{NNNN}}-{{slug}}.md` e preencha. `NNNN` = próximo
> número da tabela do `SESSIONS.md`. Cada seção é obrigatória (S1/S2/S4).

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em {{DATA}} |
| Implementação | **Pendente** |
| Validação | **Pendente** (executada pelo usuário) |

---

## 1. Objetivo

{{Uma frase: o incremento que esta sessão entrega. Escopo fechado pelo usuário.}}

## 2. Contexto (estado atual — diagnóstico)

{{O que já existe (arquivos/linhas), o que falta, o que será preservado. Sem
descrição do resultado futuro — estado ANTES do code.)

## 3. Escopo

### Produção

{{Arquivos/componentes a mudar e como.}}

### Testes

{{Testes novos e stubs/fakes a migrar.}}

### Fora de escopo (não abrir)

{{O que fica de fora nesta sessão — explicitamente.}}

## 4. Critérios de aceite

### Resultado

- [ ] **{{Critério 1}}** — prova: `{{arquivo de teste}}` ({{nome do teste}}).
- [ ] **{{Critério 2}}** — prova: `{{arquivo de teste}}` ({{nome do teste}}).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (N runs/M asserts)** + novos testes e
      lint 0 em **todo** green; commit obrigatório por passo; 0 regressão.
- [ ] Sem dependência nova / sem mudança de schema / testes sem rede / sem supressão de lint injustificada
      *(ajuste ao projeto).*
- [ ] `REQUIREMENTS.md` + `SESSIONS.md` atualizados no mesmo escopo do passo docs;
      *status de validação* só após o usuário validar (S4).

> **S1:** cada critério acima aponta o teste que o prova. Sem teste automatizado →
> escrever `manual` explícito + a evidência manual esperada.

## 5. Decisões de refinamento (fechadas com o usuário)

{{Decisões tomadas na fase 1, com data e alternativa preterida.}}

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `docs(sessao {{NNNN}}): refinamento concluido — ...` |
| 1 | {{teste que falha → implementação mínima}} | suíte verde + lint 0, commit `test(passo 1):` |
| 2 | {{...}} | suíte verde + lint 0, commit `test(passo 2):` |
| — | **Fase 2 concluída** → **Revisor (2c)**: loop Implementador↔Revisor até veredito `Aprovado` (teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| {{Critério 1}} | `{{comando de teste do projeto}}` | {{o que observar}} | |
| {{Critério 2}} | `{{comando de teste do projeto}}` | {{o que observar}} | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

{{Impedimentos, dúvidas, próximo passo sugerido.}}

## 9. Gotchas / Lições (memória — S6)

{{Armadilhas, lições e erros levantados na sessão (ex.: comportamento de lib, migração
de schema, bug de concorrência). Alimentam o `memory_write_page` em `gotchas/` ao fechar
a validação.}}

<!-- sdd-pr:bloco -->
> **Modo PR ativo (`--with-pr`).** Bloco anexado pelo instalador. Para desligar o modo, remova
> este bloco junto com o bloco `SDD/PR` do `AGENTS.md` e os scripts `checar-pr`/`abrir-pr`.

## Declarações do modo PR (fechadas no refinamento)

Logo **abaixo** da tabela de `## Status`, escreva as duas linhas — e feche-as na fase 1, não
depois:

> Reprodução: seed|script|manual|nao-aplicavel
> E2E: sim|nao

- `Reprodução` responde: *como um terceiro chega ao estado inicial do teste?* Havendo script de
  seed/fixture no projeto, use `seed` ou `script` e cite o comando. Sem caminho automatizado,
  `manual`; sem cenário de estado a montar, `nao-aplicavel` **com a justificativa na mesma
  linha**.
- `E2E` responde: *o comportamento observável desta sessão tem teste de ponta a ponta?* Havendo
  harness, `sim`. Não havendo, `nao` — e então cada critério observável registra `manual` (S1) e
  o roteiro manual vai para o corpo do PR.

O `./scripts/checar-pr` confere que o `**Estado inicial:**` do corpo do PR bate com o valor
declarado aqui.

## A linha `Validação` do Status

No modo PR ela se refere à **revisão do PR**, não a uma execução local do usuário. Continua
`Pendente` até o usuário validar revisando o PR.

## Onde entra o link do PR (seção 7)

Ao abrir o PR (fim da fase 2, após o veredito `Aprovado`), registre na seção `## 7. Validação`:

> PR: <url>

A tabela por critério (S2) só é preenchida **depois do merge**. Um PR por sessão; o merge é do
usuário. Ajuste pedido na revisão reabre o critério (S3) e **atualiza o PR** — não abre um
segundo.
<!-- /sdd-pr:bloco -->
