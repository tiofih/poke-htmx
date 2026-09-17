<!-- Exemplo ilustrativo do corpo de PR no modo `--with-pr`. Não corresponde a um PR real. -->

# Exportar o relatório do mês em CSV

> **Projeto:** Controle de Gastos · **Entrega:** 2026-08-14 · **Alteração proposta em:** https://github.com/exemplo/controle-de-gastos/pull/12

## O que muda para quem usa o produto

Na tela de Relatórios agora existe um botão **Exportar CSV**. Ao clicar, o navegador baixa um
arquivo com todas as despesas do mês que está aberto na tela, uma linha por despesa, pronto para
abrir no Excel ou no Google Sheets. Antes disso só era possível ler o relatório dentro do app e
digitar os números à mão.

**Antes:** o relatório do mês só existia dentro do app, sem forma de levar os dados para fora.
**Depois:** um clique gera um arquivo com as despesas do mês aberto, incluindo categoria e data.

## O que foi implementado

- Botão **Exportar CSV** na tela de Relatórios, desabilitado enquanto o relatório está carregando.
- Geração do arquivo no navegador, com colunas `Data`, `Descrição`, `Categoria`, `Valor` e
  separador ponto e vírgula, para abrir corretamente em planilhas configuradas em português.
- O arquivo respeita o mês que está aberto na tela e o filtro de categoria ativo; nenhum dado de
  outro mês entra no arquivo.
- Valores em reais, escritos com vírgula decimal e sem símbolo de moeda.

## O que foi validado

- **Testes automatizados:** 6 testes novos cobrem o formato da linha, o respeito ao mês aberto,
  o filtro por categoria, o caso de mês vazio (cabeçalho e nenhuma linha), a ordem das colunas e
  o escape de descrição contendo ponto e vírgula. Todos os testes do projeto continuam passando
  (nenhuma regressão) — para rodar: `npm test`
- **Verificado à mão durante a implementação:** cliquei em Exportar CSV em um mês com 47
  despesas e abri o arquivo no Google Sheets; conferi a soma das colunas contra o total mostrado
  na tela, que bateu.
- **Só provável à mão:** o comportamento de download do arquivo em si (o teste automatizado
  verifica o conteúdo gerado, não o download que o navegador dispara).

## O que NÃO foi validado (limites conhecidos)

- Testado apenas no Chrome, em um computador com macOS. Não foi testado no Safari, no Firefox nem
  no celular.
- Não foi testado com mais de 2.000 despesas em um mês; acima do volume de exemplo a geração
  pode ficar lenta e travar a tela por alguns segundos.
- Descrições com acentos e emojis foram testadas; descrições com aspas duplas não foram.
- Não foi conferido como o Excel do Windows abre o arquivo com separador ponto e vírgula —
  verificamos no Google Sheets e no LibreOffice.

## Como rodar e chegar ao estado inicial do teste

```bash
npm install
npm run seed:dev          # cria o banco local e as 47 despesas de agosto/2026
npm run dev               # sobe o app em http://localhost:3000
```

Entre com o usuário de exemplo `demo@exemplo.com` / senha `demo1234` e abra a aba **Relatórios**.

**Estado inicial:** `seed` — o comando `npm run seed:dev` deixa o banco exatamente com as despesas
de agosto/2026 e o total já conferido nas telas.

## Roteiro de teste manual (o que fazer e o que observar)

| # | O que fazer | O que deve acontecer |
| --- | --- | --- |
| 1 | Abrir a aba Relatórios com agosto/2026 selecionado | Aparece o botão **Exportar CSV** acima da lista; o total do mês é R$ 3.482,90 |
| 2 | Clicar em **Exportar CSV** | O navegador baixa um arquivo `relatorio-2026-08.csv`; nenhum aviso de erro aparece |
| 3 | Abrir o arquivo numa planilha | Primeira linha é `Data;Descrição;Categoria;Valor`; 47 linhas de dados; a soma da coluna Valor é R$ 3.482,90 |
| 4 | Voltar ao app, selecionar julho/2026 e exportar | O arquivo passa a ter os dados de julho; nenhuma despesa de agosto aparece nele |
| 5 | Filtrar por categoria "Mercado" e exportar | O arquivo contém apenas as despesas de Mercado do mês selecionado |
| 6 | Selecionar um mês sem despesas e exportar | O arquivo baixa só com a linha de cabeçalho |

## Comandos do projeto

```bash
npm test        # testes automatizados
npm run lint    # lint
npm run dev     # sobe o app em http://localhost:3000
```

## Anexo — rastreabilidade interna (equipe)

- Arquivo da sessão: `sessions/0012-exportar-relatorio-csv.md`
- Critérios e o teste que prova cada um: CA1 e CA2 → `test/reports/export.spec.ts`
  (`formats csv header and rows`, `respects selected month`); CA3 → `manual` (download real)
- Rastreabilidade de requisitos: RF-14 (exportação de relatórios), RNF-3 (sem dependência nova)
- Commits desta entrega: `4f1c9a2`, `b7d0e11`, `9ac3f04`
