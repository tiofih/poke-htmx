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

- [ ] **{{Critério 1}}** — prova: `test/{{arquivo}}` ({{nome do teste}}).
- [ ] **{{Critério 2}}** — prova: `test/{{arquivo}}` ({{nome do teste}}).

### Garantias (RNF)

- [ ] Suíte completa verde com **baseline preservado (N runs/M asserts)** + novos testes e
      lint 0 em **todo** green; commit obrigatório por passo; 0 regressão.
- [ ] Sem gems novas / sem mudança de schema / testes sem rede / sem `rubocop:disable`
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
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `Sessao {{NNNN}}: refinamento concluido — ...` |
| 1 | {{teste que falha → implementação mínima}} | suíte verde + lint 0, commit `Passo 1:` |
| 2 | {{...}} | suíte verde + lint 0, commit `Passo 2:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar a validação do usuário (fase 3). |

## 7. Validação (executada pelo usuário)

**Pendente.** *(Ao validar — S2: uma linha por critério, nunca bloco único.)*

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| {{Critério 1}} | `./scripts/test -n /.../` | {{o que observar}} | |
| {{Critério 2}} | `./scripts/test -n /.../` | {{o que observar}} | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data
> e obter nova aprovação do usuário.

## 8. Observações

{{Impedimentos, dúvidas, próximo passo sugerido.}}