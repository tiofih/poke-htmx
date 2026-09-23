<!-- sdd-redator:bloco -->
## Corpo do PR com `redator-pr` (papel barato — só com `--with-pr`)

- **Portão:** só se `.opencode/agent/redator-pr.md` existir. Sem ele, o
  `implementador-teste` escreve o corpo no passo PR — fluxo padrão, inalterado.
- Com ele, na fase 2: no spawn do `implementador-teste` acrescente ao prompt *"o corpo do
  PR será gerado por outro papel — faça TDD + Converge e **pare antes** de escrever
  `sessions/pr/NNNN-pr-body.md`"*.
- Depois do Converge: dispare `redator-pr` (modelo barato — proza derivada da sessão) →
  confira a coerência com o arquivo da sessão → commite
  (`docs(pr 00NN): corpo do PR — <resumo>`) → `./scripts/abrir-pr NNNN --open` →
  registre `> PR: <url>` na sessão.
- `> Revisão: exigida` (S7): o corpo entra na revisão **antes** do abrir-pr.
- S8 vale inteiro: um PR por sessão, nunca merge, feedback = S3 atualizando o corpo.
<!-- fim sdd-redator:bloco -->
