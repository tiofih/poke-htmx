# --- SDD/PR (--with-pr) ---

<!-- sdd-pr: ativo -->

> Bloco anexado pelo instalador (`install.sh --with-pr`). O marcador `sdd-pr: ativo` acima é a
> **única fonte de verdade** do modo PR: sem ele, nada abaixo se aplica e vale o fluxo padrão de
> três fases. Este bloco é **autossuficiente** — vale mesmo em projeto que já tinha o kit
> instalado antes e não recebeu os arquivos de papel atualizados.

## A entrega da sessão é um PR/MR; a validação é a revisão do PR

- Fechada a fase 2 (TDD) com **Converge verde** (`> Converge: sim`; e veredito `Aprovado`
  quando houver revisão por risco — S7), o Implementador **entrega a sessão
  como PR/MR**: a fase 3 deixa de ser "usuário valida na máquina" e passa a ser "usuário valida
  revisando o PR".
- **Um PR por sessão.** **Quem faz merge é o usuário** — o agente nunca faz merge, nunca aprova e
  nunca responde comentário de revisão automaticamente.
- O validador não muda: continua sendo o usuário. O modo muda o **meio** (PR em vez de máquina
  local) e a **barra de evidência**.

## Ordem fina do passo PR (fim da fase 2)

1. escrever `sessions/pr/NNNN-pr-body.md` **gerado do próprio arquivo da sessão** (o que
   muda para quem usa, o que foi implementado, o que **não** foi validado, estado inicial,
   roteiro manual — sem template, sem `checar-pr`);
2. conferir o **Converge** (`> Converge: sim` — diff × critérios);
3. commitar `docs(pr 00NN): corpo do PR — <resumo>`;
4. **Revisor (2c) só se `> Revisão: exigida`** — aí o corpo entra no escopo dela;
5. `./scripts/abrir-pr NNNN --open`;
6. registrar `> PR: <url>` na seção de Validação do arquivo da sessão;
7. handoff (S6) citando o link do PR → **PARADA**. A fase 3 é a revisão do PR.

## O corpo do PR é escrito para quem NÃO trabalha no projeto

- Gerado do **arquivo da sessão** — o refinamento é a fonte, o corpo é sua projeção.
  Primeiro **o que muda para quem usa o produto** (linguagem de produto), depois o que foi
  implementado, o que foi validado, o que **não** foi validado, como chegar ao estado inicial do
  teste e o roteiro manual (ação → o que deve acontecer).
- **Nenhuma sigla interna, número de sessão, número de fase/passo ou ID de requisito na
  narrativa** — nada disso acima do `## Anexo`. Toda a rastreabilidade (requisito → sessão →
  passos → commits) vive no Anexo do fim; o Anexo é trilha, não o lugar de guardar a explicação.
- Quem revisa precisa conseguir **entender, preparar o ambiente, executar e observar** sem
  perguntar nada a ninguém. Sem `checar-pr`: essa sobra é julgamento do Revisor (quando
  houver) e do usuário — declarado, não simulado por um gate de grep.

## Reprodução e evidência — o peso novo de teste/e2e

- No **refinamento**, todo critério declara como um terceiro chega ao estado inicial. O arquivo
  da sessão grava, abaixo da tabela de Status: `> Reprodução: seed|script|manual|nao-aplicavel` e
  `> E2E: sim|nao`. `nao-aplicavel` exige justificativa na mesma linha — é a saída honesta, não
  um atalho.
- O corpo do PR repete a declaração em `**Estado inicial:**` — quem lê confere contra o
  arquivo da sessão (não há portão mecânico).
- Havendo script de seed/fixture no projeto, usá-lo é obrigatório (não invente caminho paralelo).
  Não havendo, passos manuais numerados e copiáveis, capazes de deixar o app **no ponto exato em
  que o teste começa**.
- Havendo harness de ponta a ponta, critérios de comportamento observável **têm** cobertura e2e.
  Não havendo, o critério registra `manual` explícito (S1) **e** o roteiro manual entra no corpo
  do PR — o kit não inventa harness que o projeto não tem.
- Comando de teste e baseline do projeto vão no corpo do PR; sem eles a evidência não é
  auditável por terceiros.
- Recomendação (não regra): preparação de ambiente passando de três passos → versione um script
  de reprodução da sessão.

## Sem portão mecânico de texto

- `checar-pr` e `TEMPLATE-pr-body.md` foram **removidos**: o corpo deriva do arquivo da
  sessão e o custo de 2 gates por sessão não pagava o que produziam (texto já existente
  no refinamento). O que nenhum gate captura (compreensão, passos funcionando, evidência
  verdadeira) é julgamento do Revisor (quando houver) e do usuário — declarado como tal.

## Ferramenta de abertura (`PR_CMD`)

- **Ferramenta (`PR_CMD`):** `gh pr create --base <base> --title "<titulo>" --body-file <corpo>`
  (GitLab: `glab mr create --yes --target-branch <base> --title "<titulo>" --description "$(cat <corpo>)"`).
  `./scripts/abrir-pr` substitui `<titulo>`, `<corpo>` e `<base>`; **sem `PR_CMD` ele usa o
  padrão `gh` acima**. Ajuste esta linha ao seu host — o kit não detecta plataforma.
- Sem CLI no `PATH` ou sem remote configurado, `abrir-pr` cai no **modo degradado honesto**:
  imprime o comando exato e o corpo versionado em `sessions/pr/NNNN-pr-body.md` passa a ser a
  entrega, validada pelo usuário do mesmo jeito. Ele nunca finge sucesso.

## Ajuste do usuário = S3, sem segundo PR

- Feedback do usuário (ou comentários na plataforma) **reabre o critério** (S3), com data. O Implementador
  corrige, **atualiza o corpo do PR** e re-empurra a branch — **sem abrir um segundo PR**.
- A revisão do PR pelo usuário **não** entra no teto de 3 rodadas (o teto é do loop
  Implementador↔Revisor, quando a revisão estiver ativa por risco — S7).
- S1–S7 continuam valendo sem alteração; a validação registrada (S2) só é preenchida **depois do
  merge**, com o link do PR como entrega.

# --- fim SDD/PR rules ---
