# Sessão {{NNNN}} — {{NOME}}

> Copie este modelo para `sessions/{{NNNN}}-{{slug}}.md` e preencha. `NNNN` = próximo
> número da tabela do `SESSIONS.md`. Cada seção é obrigatória (S1/S2/S4).

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em {{DATA}} |
| Implementação | **Pendente** |
| Validação | **Pendente** (executada pelo usuário) |

> Revisão: dispensada
> Converge: — (fim da fase 2: `sim` | `nao` + pendências)
> Equipe: — (fase 2: especialistas por lane, ex. `backend, frontend, qa` — paralelo só
> com lanes disjuntas; `—`/ausente = implementador-teste sozinho)

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
> escrever `manual` explícito + a evidência manual esperada. Critério de comportamento
> em **EARS** (`QUANDO/SE <gatilho> ENTÃO <resultado> — <qualificador>`) quando couber;
> UI puramente visual nasce `manual`.

## 5. Decisões de refinamento (fechadas com o usuário)

{{Decisões tomadas na fase 1, com data e alternativa preterida.}}

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `docs(sessao {{NNNN}}): refinamento concluido — ...` |
| 1 | {{teste que falha → implementação mínima}} | suíte verde + lint 0, commit `test(passo 1):` |
| 2 | {{...}} | suíte verde + lint 0, commit `test(passo 2):` |
| — | **Fase 2 concluída** → **Converge** (`> Converge: sim` — diff × critérios); **Revisor (2c) só se `> Revisão: exigida`** (loop teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3). |

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
