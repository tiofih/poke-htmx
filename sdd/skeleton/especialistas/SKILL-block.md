<!-- sdd-especialistas:bloco -->
## Fase 2 paralela — especialistas (`--with-especialistas`)

| Papel (`subagent_type`) | Lane | Edit | Quando disparar |
|---|---|---|---|
| `backend` | servidor/API/dados + testes da lane | sim | `> Equipe:` cita `backend` |
| `frontend` | templates/CSS/JS cliente + testes da lane | sim | `> Equipe:` cita `frontend` |
| `qa` | cobertura S1/EARS, estado da suíte | não (read-only) | `> Equipe:` cita `qa` |
| `ui-designer` | decisões visuais (propõe; `frontend` implementa) | não (read-only) | `> Equipe:` cita `ui-designer` |
| `game-designer` | mecânica/balanceamento (recomenda; decide o usuário) | não (read-only) | `> Equipe:` cita `game-designer` |
| `security-reviewer` | auth/dados/segredos/entradas de confiança (achado ranqueado; sugere `> Revisão: exigida`) | não (read-only) | `> Equipe:` cita `security-reviewer` |
| `a11y-auditor` | acessibilidade da lane UI: teclado, foco, semântica, contraste, toque, motion (tabela WCAG) | não (read-only) | `> Equipe:` cita `a11y-auditor` |

- **Portão duplo:** o agente em `.opencode/agent/<papel>.md` **E** `> Equipe: <papéis>`
  no arquivo da sessão (fechado no refinamento). Sem os dois, a fase 2 é o
  `implementador-teste` sozinho, como sempre — não existe "fase degradada".
- **Paralelo só com lanes disjuntas** (arquivos de produção não-sobrepostos):
  `backend ∥ frontend ∥ qa ∥ ui-designer ∥ game-designer` vale; dois editores na mesma
  lane, ou lane com dependência de arquivo do outro → **sequencial**. Read-only disputam
  nada e rodam com qualquer um.
- **Durante o paralelismo:** cada especialista edita **só a sua lane** e roda **apenas
  testes da lane** (filtro por arquivo). **Suíte completa + lint 0 + commits** são do
  `implementador-teste` ao **integrar** (1 commit por lane/green — especialista não
  commita, para o índice não disputar em paralelo).
- **Integração, `> Converge:` e S6** continuam com o `implementador-teste` — ele é quem
  responde pela fase 2. **S7 amendado:** "só o Implementador edita" inclui os
  especialistas **nas suas lanes**; o Revisor continua nunca editando, e revisa o diff
  consolidado.
- Sem contraparte no harness (task sem o subagente): despache inline pelo orquestrador
  injetando no prompt o papel + a lane + a regra "não commita"; integre do mesmo jeito.
<!-- fim sdd-especialistas:bloco -->
