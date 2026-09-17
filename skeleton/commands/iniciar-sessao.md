---
description: Mostra o estado corrente do SDD sem ler os docs inteiros (digest de abertura). Use ao iniciar o trabalho antes de refinar/implementar.
agent: build
---

Você está abrindo uma **sessão SDD do {{PROJETO}}** em modo **somente-leitura**
(digest de abertura). Regras base: `AGENTS.md` (S1–S7), `SESSIONS.md`,
`REQUIREMENTS.md`. **Não** refine nem implemente aqui — só levante o estado.

## 0. Argumentos do usuário (opcional)
`$ARGUMENTS` pode indicar a sessão (ex.: "0055"). Se não vier, use a
"Próxima sessão" do digest.

## 1. Levante o estado — contexto mínimo
- Rode `./scripts/iniciar-sessao` (histórico + próxima sessão + checklist fase 1;
  já inclui o digest do roadmap). Se precisar só do backlog, rode também
  `./scripts/levantar-roadmap`.
- **Não** leia `REQUIREMENTS.md`/`SESSIONS.md` inteiros.

## 2. Leia na íntegra só o necessário
- Leia na íntegra **apenas** o arquivo da sessão corrente em `sessions/`
  (crie a partir de `sessions/template.md` se for nova).
- Todo o resto via digests (`./scripts/levantar-sessao NNNN`,
  `./scripts/levantar-requisito <ID>`, `./scripts/levantar-testes [kw]`)
  ou busca (`grep`/índice) — nunca o arquivo inteiro.

## 3. Responda com o digest + próximo passo
- Reporte: última validação, próxima sessão, backlog/limitações abertas e o
  checklist da fase 1 (objetivo/escopo/critérios→teste S1; `SESSIONS.md` no
  commit do refinamento S4; `check_docs` S5).
- Indique a próxima etapa (ex.: "refinar via `/sessao`" ou "implementar via
  `/sessao`") e **pare** — o trabalho continua no `/sessao`.
