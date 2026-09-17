<!--
Modelo do corpo do PR (modo `--with-pr`). Copie para `sessions/pr/NNNN-pr-body.md`,
preencha TODOS os `{{...}}` e rode `./scripts/checar-pr NNNN` antes de commitar.

Regra desta narrativa: escreva para alguém que NÃO trabalha no projeto. Nada de sigla
interna, número de sessão, "fase", "passo" ou ID de requisito aqui — isso vive só no
`## Anexo` do fim. Quem lê precisa conseguir entender, preparar o ambiente, executar e
observar o resultado sem perguntar nada a ninguém.

Checklist rápido antes de commitar:
- [ ] Todo `{{...}}` foi substituído (é o que o `checar-pr` cobra).
- [ ] Um estranho entende o que muda para quem usa o produto só lendo a primeira seção.
- [ ] O bloco de comandos sobe o app E deixa o estado inicial do teste — copiável, na ordem.
- [ ] Cada linha do roteiro diz o que DEVE ACONTECER, não só o que fazer.
- [ ] "O que NÃO foi validado" tem pelo menos um limite nomeado (ambiente, volume, dado).
- [ ] Nada de rastreabilidade interna acima do `## Anexo` — e o Anexo é trilha, não o lugar
      de guardar a explicação: quem é de fora lê só o que está acima dele.

Sem script de seed no projeto? Escreva os passos manuais numerados: o revisor não pode
montar o cenário de cabeça, e "rode aí do jeito que você costuma" não conta como passo.
-->

# {{TITULO}}

> **Projeto:** poke-htmx · **Entrega:** {{DATA}} · **Alteração proposta em:** {{PR_URL}}

## O que muda para quem usa o produto

{{De 2 a 5 linhas em linguagem de produto: o que a pessoa passa a conseguir fazer, o que
muda na tela/fluxo e em que momento isso aparece. Sem nome de arquivo, de função ou de
requisito. Se nada mudar para quem usa, diga isso explicitamente.}}

**Antes:** {{o comportamento de hoje, em uma frase}}
**Depois:** {{o comportamento novo, em uma frase}}

## O que foi implementado

{{Lista do que passou a existir e por quê, compreensível fora do time: telas, dados
salvos, regras de negócio, integrações externas, mudanças de configuração.}}

## O que foi validado

{{O que foi efetivamente conferido, como, e o resultado observado.}}

- **Testes automatizados:** {{o que cobrem}} — para rodar: `{{COMANDO_TESTE}}`
- **Verificado à mão durante a implementação:** {{o que foi aberto/clicado e o que se observou}}
- **Só provável à mão:** {{o que não tem teste automatizado, e por quê}}

## O que NÃO foi validado (limites conhecidos)

{{Obrigatório. O que ninguém conferiu ainda, em que ambiente, com que dados, e o que pode
quebrar por isso. Exemplos: "só testado em um navegador, com dados de exemplo", "não
testado com duas pessoas ao mesmo tempo", "não testado com volume real".}}

## Como rodar e chegar ao estado inicial do teste

{{O caminho mais curto para deixar o app exatamente no ponto em que o teste começa. Use o
que o projeto realmente tem: script de seed/fixture, dados de exemplo versionados, ou
passos manuais numerados. Existindo script de seed, use o script.}}

```bash
{{COMANDOS_PARA_SUBIR_O_AMBIENTE_E_SEMEAR}}
```

**Estado inicial:** `{{seed|script|manual|nao-aplicavel}}` — {{como o estado é obtido, em uma linha}}

## Roteiro de teste manual (o que fazer e o que observar)

{{Sequência curta, na ordem de execução. Cada linha: a ação e o resultado esperado — o que
aparece, o que muda e o que NÃO deve acontecer.}}

| # | O que fazer | O que deve acontecer |
| --- | --- | --- |
| 1 | {{ação}} | {{resultado esperado}} |
| 2 | {{ação}} | {{resultado esperado}} |

## Comandos do projeto

```bash
{{COMANDO_TESTE}}   # testes
{{COMANDO_LINT}}    # lint
{{COMANDO_BUILD}}   # subir o app (se houver)
```

## Anexo — rastreabilidade interna (equipe)

<!-- Tudo abaixo é para quem trabalha no projeto. O texto acima é para quem não trabalha.
     O Anexo existe para a trilha requisito → sessão → passos → commits; ele NÃO é o lugar
     de guardar a explicação — o que explica está acima. -->

- Arquivo da sessão: `sessions/{{NNNN}}-{{slug}}.md`
- Critérios e o teste que prova cada um: {{critério → arquivo/nome do teste, ou `manual`}}
- Rastreabilidade de requisitos: {{IDs de requisito afetados}}
- Commits desta entrega: {{SHAs}}
