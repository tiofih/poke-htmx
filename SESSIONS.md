# SESSIONS — Poke-HTMX

> **Fluxo:** cada passo de implementação é uma **sessão** (arquivo próprio em `sessions/`).
> Fonte da verdade: `REQUIREMENTS.md`.

> **Sequência rígida (RNF-04):** um passo só é iniciado quando **todas as fases do passo anterior** estiverem devidamente concluídas e validadas (red → green → refactor → validação + critérios verificados).

## Ciclo de cada sessão (SDD em fases)

Cada sessão percorre **três fases** nesta ordem. A próxima fase só começa quando a fase atual estiver concluída (cada fase marcada como `Done` no arquivo da sessão):

### 1. Refinamento (preparação)

- Ler `REQUIREMENTS.md`, o arquivo da sessão atual e `SESSIONS.md`.
- Esclarecer objetivo, escopo e **critérios de aceite** do passo.
- Registrar decisões de design (schema, gems, nomes de rotas) no arquivo da sessão.
- **Entrega:** arquivo da sessão com critérios de aceite fechados e plano TDD.
- Dúvidas em aberto → resolver antes de codar.

### 2. Implementação (TDD)

- Seguir **TDD**: `red` (teste falha) → `green` (implementação mínima, suíte verde) → `refactor`.
- **Commit obrigatório após cada green.**
- Atualizar `REQUIREMENTS.md`/`SESSIONS.md` no mesmo trabalho quando o comportamento mudar.

### 3. Validação (verificação) — executada pelo USUÁRIO

- A **validação é feita pelo usuário**. Ao terminar a fase 2 (implementação TDD, suíte
  e lint verdes), o agente **para** e aguarda o feedback do usuário — não marca fases
  como concluídas, não atualiza `REQUIREMENTS.md`/`SESSIONS.md` com status de validação
  e não commita a conclusão da sessão antes disso.
- Com o feedback em mãos, o usuário roda a **suíte completa** (Minitest) e confirma
  tudo verde.
- Verificar os **critérios de aceite** da sessão contra a implementação.
- Registrar resultados e problemas no arquivo da sessão (feito junto ao usuário).
- Atualizar `REQUIREMENTS.md` (status dos requisitos) e `SESSIONS.md` (progresso +
  próxima sessão) apenas após a validação do usuário.

---

## Próxima sessão

**Sessão 0013** — a definir: **C1 — Batalha na web (htmx)** consumindo `BattleEngine`
(team do jogador × `OpponentGenerator`) e/ou **A2 — UI: layout e estilos externos**
(roadmap item 13). RF-12 (B4) está `Done` (validado em 2026-08-08). Aguardando decisão do usuário.

## Progresso das sessões

| # | Sessão | Fase | Status |
| --- | --- | --- | --- |
| 0001 | Persistir equipe em PostgreSQL (RNF-02) | Concluída | Done (passos 0–5 validados) |
| 0002 | Remoção semântica (`DELETE /team`, RF-04) | Concluída | Done (passos 0–5 validados) |
| 0003 | Equipe por usuário (sessão/cookie, RF-05) | Concluída | Done (passos 0–6 + S1, validado em 2026-08-08) |
| 0004 | Página de detalhes (tipos, stats, evoluções) | Concluída | Done (passos 0–4, validado em 2026-08-08) |
| 0005 | Navegação pela sprite + Fechar/Voltar (RF-06) | Concluída | Done (passos 0–3, validado em 2026-08-08) |
| 0006 | Paginação/filtro na listagem | Concluída | Done (passos 0–6, validado em 2026-08-08) |
| 0007 | Montagem de times — cap 6 + slots + sem duplicados (RF-07) | Concluída | Done (passos 0–9, validado em 2026-08-08) |
| 0008 | Reordenação manual de slots (RF-08) | Concluída | Done (passos 0–8, validado em 2026-08-08) |
| 0009 | Modelo de batalha (RF-09, B1) — BattlePokemon puro | Concluída | Done (passos 0–5, validado em 2026-08-08) |
| 0010 | Efetividade de tipos (RF-10, B2) — lookup puro + tabela via PokéAPI | Concluída | Done (passos 0–8, validado em 2026-08-08) |
| 0011 | Motor de auto-batalha (RF-11, B3) — BattleEngine puro 6v6 | Concluída | Done (passos 0–9, validado em 2026-08-08) |
| 0012 | Oponente automático (RF-12, B4) — OpponentGenerator puro | Concluída | Done (passos 0–5, validado em 2026-08-08) |

## Estrutura do arquivo de sessão

Todo arquivo em `sessions/` contém as seções:

1. **Objetivo**
2. **Critérios de aceite**
3. **Plano TDD** (passos + testes)
4. **Decisões de refinamento**
5. **Validação** (resultados da fase, suíte executada, checagem dos critérios)
6. **Observações** (impedimentos, dúvidas, próximo passo sugerido)