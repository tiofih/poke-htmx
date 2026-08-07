# SESSIONS — Poke-HTMX

> **Fluxo:** cada passo de implementação é uma **sessão** (arquivo próprio em `sessions/`).
> Fonte da verdade: `REQUIREMENTS.md`.

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

### 3. Validação (verificação)

- Rodar a **suíte completa** (Minitest) e confirmar tudo verde.
- Verificar os **critérios de aceite** da sessão contra a implementação.
- Registrar resultados e problemas no arquivo da sessão.
- Atualizar `REQUIREMENTS.md` (status dos requisitos) e `SESSIONS.md` (progresso + próxima sessão).

---

## Próxima sessão

**Sessão 0001** — Persistir equipe em PostgreSQL (RNF-02).
Refinamento concluído e validado; implementação TDD em andamento — passos 0–1 verdes (infra de testes + `TeamRepository#all`). Próximo: passo 2 (`#add`).
Detalhes em `sessions/0001-persist-postgres.md`. Atualizar este arquivo conforme o progresso.

## Progresso das sessões

| # | Sessão | Fase | Status |
| --- | --- | --- | --- |
| 0001 | Persistir equipe em PostgreSQL (RNF-02) | Implementação | Em andamento (passos 0–1) |
| 0002 | Remoção semântica (`DELETE /team/:key`) | — | Backlog |
| 0003 | Equipe por usuário (sessão/cookie) | — | Backlog |
| 0004 | Página de detalhes (tipos, stats, evoluções) | — | Backlog |
| 0005 | Paginação/filtro na listagem | — | Backlog |
| 0006 | UI: layout e estilos externo | — | Backlog |

## Estrutura do arquivo de sessão

Todo arquivo em `sessions/` contém as seções:

1. **Objetivo**
2. **Critérios de aceite**
3. **Plano TDD** (passos + testes)
4. **Decisões de refinamento**
5. **Validação** (resultados da fase, suíte executada, checagem dos critérios)
6. **Observações** (impedimentos, dúvidas, próximo passo sugerido)