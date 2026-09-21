# Sessão 0091 — T3+T4 rodada 3 da 0089

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — sem decisões abertas (aceites literais do `TODO.md`) em 2026-09-21 |
| Implementação | **Pendente** |
| Validação | **Pendente** (revisão do PR — modo PR ativo) |

> Reprodução: manual
> E2E: sim
>
> Detalhe: harness Playwright existe e cobre o fragmento (`e2e/battle-log.spec.ts`, 9 cenários); roteiro manual no corpo do PR.

---

## 1. Objetivo

Fechar os dois achados `low` da rodada 3 da 0089: indentação do `<p class="rewards">` (T3) + assert exato da copy de XP (T4).

## 2. Contexto (estado atual — diagnóstico)

- `views/battle.erb:126-128` e `views/_strike_result.erb:23-25`: `<p class="rewards">` com 4 espaços a mais que o `if` que o envolve.
- `test/battle_routes_test.rb:785-795` (`test_battle_finish_shows_money_gained_message`): assert OR (`||`) aceita copy de vitória ou derrota — trocar derrota por vitória (ou vice-versa) não falha.
- Baseline 2026-09-21: suíte 1192/6389, lint 0 (pós-0090+S3).

## 3. Escopo

### Produção

- Reindentar o `<p class="rewards">` nos dois arquivos para o nível do `if` (só whitespace).

### Testes

- `test_battle_finish_shows_money_gained_message`: assert exato da copy de vitória **e** da copy de derrota (duas asserções, sem OR).

### Fora de escopo (não abrir)

- T1/T2 do `TODO.md`; qualquer mudança visual/comportamental; e2e novo.

## 4. Critérios de aceite

### Resultado

- [ ] **C1** — `<p class="rewards">` no nível do `if` nos dois arquivos — prova: `e2e/battle-log.spec.ts` (9 passed, renderiza o fragmento) + diff só-whitespace.
- [ ] **C2** — trocar vitória por derrota no teste passa a falhar — prova: `test/battle_routes_test.rb` (`test_battle_finish_shows_money_gained_message` com asserções exatas).

### Garantias (RNF)

- [ ] Suíte completa verde + lint 0 em **todo** green; commit por passo; 0 regressão.
- [ ] Sem dependência nova / sem schema / sem rede / sem supressão de lint.
- [ ] `SESSIONS.md` atualizado; validação só após o usuário revisar o PR (S4).

> **S1:** cada critério acima aponta o teste que o prova. Roteiro manual vai ao corpo do PR junto do e2e.

## 5. Decisões de refinamento (fechadas em 2026-09-21)

- Sem decisões abertas: aceites literais do `TODO.md` (T3/T4). Uma sessão só porque são mesma área e mesmo porte.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte + lint 0) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `Sessao 0091: refinamento concluido — ...` |
| 1 | T3 (reindent) + T4 (assert exato) | suíte verde + lint 0 + e2e battle-log 9 passed, commits `Passo 1:` e `Passo 2:` (ou agrupado) |
| 2 | Corpo do PR + revisor + abrir-pr | `checar-pr` verde, commit `docs(pr 0091):` |
| — | **Fase 2 concluída** → **Revisor (2c)** até `Aprovado` + `CORPO DO PR: publicável` (teto 3 rodadas, senão S3) → `abrir-pr 0091` → **loop segue** (validação em lote no fim). | `> PR: <url>` na §7 |

## 7. Validação (revisão do PR pelo usuário)

**Pendente.**

Roteiro manual (vai ao corpo do PR): ver o fonte da página de fim de batalha (indentação do `<p class="rewards">` alinhada ao `if`); ler o teste e confirmar as duas copies exatas.

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 | `e2e/battle-log.spec.ts` (9 passed) | fonte da página | |
| C2 | `test/battle_routes_test.rb` | leitura do teste | |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.

## 8. Observações

- Na sequência: `T1`/`T2` (flake do `SeedScriptsTest`, `db:setup` destrutivo).

## 9. Gotchas / Lições (memória — S6)

- *(a preencher na fase 2.)*

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
