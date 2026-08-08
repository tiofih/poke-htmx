# Draft — Ideias de fases (auto-battler)

> **Natureza deste arquivo:** rascunho de ideias, fora do fluxo de sessão (RNF-04).
> Nada aqui está refinado nem agendado. Depois elencamos o que fica, o que sai e a ordem
> (provável validação da sessão 0007 antes de abrir escopo novo).

---

## Objetivo

Este projeto vai virar um **auto-battler**. A base já existente — listar Pokémon,
ver detalhes (tipos, stats base, evoluções, RF-06), montar time (cap 6 + slots +
sem duplicados, RF-07) e equipe por usuário (RF-05) — é o alicerce. As fases abaixo
conectam essa base a um **game loop** de combate automático.

## Fases candidatas (propostas, em ordem lógica de dependência)

### A. Esquadrão (montagem)

- **A1. Reordenação de slots (manual)** — mover Pokémon entre slots 1..6 (hoje a 0007
  só reindexa na remoção; "manter lacunas" também é variante). A ordem do time vira
  input explícito do combate.
- **A2. UI: layout e estilos externo** — a antiga "0007-UI"; estender design para
  telas mais ricas (batalha não acontece em página crua).

### B. Núcleo do game loop (domínio, sem rede)

- **B1 — Modelo de batalha** — unidade de combate derivada do Pokémon: HP total/atual
  a partir do base stat HP, estados por rodada. Classes puras + testes de unidade.
- **B2 — Efetividade de tipos** — tabela dano base da PokéAPI (`damage_relations`):
  fraqueza x2, resistência x0.5, imune x0, STAB.
- **B3 — Motor de auto-batalha** — simulador 6v6 por turnos ordenados por Speed
  (consome `all(user_id)` já ordenado por slot); aplica dano, checa HP, até um lado
  zerar; retorna log + vencedor. É o game loop sem rede.
- **B4 — Oponente automático** — gera o time adversário (ex.: sorteados da lista da
  PokéAPI) para o usuário enfrentar.

### C. Batalha na web (htmx)

- **C1 — Batalha por htmx** — escolha de oponente, rodar a simulação passo a passo via
  htmx, exibir HP dos times, log de ações e resultado. 100% server-rendered (RNF-01).

### D. Opcionais / horizontes (anotados, NÃO agendar agora)

- **D1 — Golpes (moves/PP) por Pokémon** — multi-move para a simulação.
- **D2 — XP/evolução que melhora stats** — progressão do time entre batalhas.
- **D3 — Histórico/rank de batalhas** — registro de resultados por usuário.
- **D4 — Modos de draft temático** — composição de time com restrição (ex.: 1 por tipo).

---

## Notas de escopo

- B1–B3 são **domínio puro** (sem DB, sem rede) → TDD rápido, sem stub.
- B4 consome a lista da PokéAPI (já paginada/ficar cacheada, RF-01).
- C1 não muda o motor: a rota apenas stima uma partida já simulável.
- Nada aqui modifica REQUIREMENTS.md/SESSIONS.md até [0007] ser implementada e
  validada e a gente bater o martelo do que entra.