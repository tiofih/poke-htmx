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
