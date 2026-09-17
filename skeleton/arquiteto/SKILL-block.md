<!-- sdd-arquiteto:bloco -->
## Fase 1b — Desenho técnico (`arquiteto`, só com o perfil `--with-arquiteto`)

| Fase | Papel (`subagent_type`) | Entregável | Quando disparar |
|---|---|---|---|
| 1b — Desenho técnico | `arquiteto` (read-only) | fatias, **uma por área do `STACK.md`**; contratos entre fatias; riscos de acoplamento (com como o `revisor` verifica); dívida nomeada | refinamento fechado **e** a sessão cruzar áreas |

- **Só dispare se `.opencode/agent/arquiteto.md` existir.** Sem o perfil, a fase 1b **não existe** e
  o refinamento fechado vai direto para a fase 2 — isso é o fluxo padrão, não um modo degradado.
- Sessão de **área única** ou trivial: o `arquiteto` responde `Desenho: nao-aplicavel — <motivo>` em
  uma linha e a fase 2 começa igual. Fase 1b vazia é resultado legítimo.
- O desenho é **advisory e read-only**: não escreve arquivo, não commita, não marca critério, não
  reabre decisão do usuário (S3) e não cria segundo loop de revisão. Precisando de decisão nova, ele
  **devolve a pergunta** ao orquestrador.
- No harness: `arquiteto` → `planner`; **sem contraparte, pule a fase 1b** (não execute o desenho
  inline).
- O que ele faz sem cada dependência: bloco `## Dependências` em `.opencode/agent/arquiteto.md`.
<!-- fim sdd-arquiteto:bloco -->
