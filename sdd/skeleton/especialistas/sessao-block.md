<!-- sdd-especialistas:bloco -->
## Fase 2 com especialistas (só com `--with-especialistas` e `> Equipe:`)

Com `> Equipe: <papéis>` preenchido no refinamento (default `—` = sem especialistas) e os
agentes em `.opencode/agent/`, a fase 2 muda **só a montagem**, não o ciclo:

1. Despache **em paralelo** (chamadas `task` na mesma rodada) um especialista por papel
   citado, cada um com: o caminho do arquivo da sessão, a **lane** dele e as regras do
   papel (TDD na lane, testes só da lane, **não commita**).
2. Integre: dispare o `implementador-teste` com o resumo das lanes — suíte **completa**
   + lint 0, **commit por lane/green**, `> Converge:` e S6 dele.
3. `> Revisão: exigida` (S7): o Revisor revisa o **diff consolidado** — nunca uma lane isolada.

Sem o portão duplo (agente ausente ou `> Equipe: —`), despache o `implementador-teste`
direto, como sempre. Read-only (`qa`, `ui-designer`, `game-designer`, `security-reviewer`, `a11y-auditor`)
podem rodar **antes ou durante** — não disputam arquivos.
<!-- fim sdd-especialistas:bloco -->
