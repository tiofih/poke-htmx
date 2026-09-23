---
description: Caminho enxuto de bugfix (PROTOCOL 3c) — análise inline (atual/esperado/inalterado) → teste de regressão red→green → Converge → entrega/validação, sem refinador completo. Use para corrigir comportamento quebrado.
agent: build
---

Você está abrindo um **caminho bugfix** do `poke-htmx` (PROTOCOL §3c) — correção de
comportamento quebrado **não** é sessão de feature: mesmo ciclo, forma reduzida. Regras
base: `AGENTS.md` (S1–S7).

## 1. Análise (inline, na conversa — sem subagente `refinador`)

Registre os três pontos, sempre:
- **Comportamento atual** — o que acontece hoje (com erro/repro).
- **Comportamento esperado** — o que deveria acontecer.
- **Inalterado** — o que **não** muda com o patch (guarda contra escopo de feature escondido).

O critério é **um teste de regressão que reproduz o bug** — nada de plano TDD longo.
Se a correção pedir decisão de design ou tocar mais de um critério, **pare**: isso é
sessão normal (`/sessao`), não bugfix.

## 2. Patch em TDD (subagent `implementador-teste` ou inline)

- `red` = teste de regressão falha reproduzindo o bug → `green` = correção **mínima** →
  suíte completa + lint verdes → commit `fix: ...` (formato do projeto).
- Revisor (S7) **só** se o bug tocar risco (dados, auth, dinheiro): `> Revisão: exigida`.

## 3. Converge e entrega

- `> Converge: sim` — diff × o critério (teste de regressão) — registrado na nota/sessão.
- **Modo PR (só com `--with-pr`):** gere o corpo do arquivo da sessão (S8.2) e
  `./scripts/abrir-pr NNNN --open`, registrando `> PR: <url>`; **sem modo PR:** direto à
  validação. Se a mudança tem superfície visual, **mostre** (`browser.preview`) junto do
  pedido.
- **PARADA:** validação é do usuário — nada de `Done`, nada de commit de conclusão.

## 4. Fora do caminho

Escopo que não couber no patch (feature, refatoração, mais de um comportamento) vira
**sessão normal** (`/sessao`) — este comando não é porta de entrada de feature.
