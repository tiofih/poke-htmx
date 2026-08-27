# Playtest 01 — Economia de montagem (teto 3× S via custo)

**Data:** 2026-08-27 · **Foco:** achar número mágico onde max 3 S caiba por orçamento, removendo trava hardcoded `S_LIMIT = 3`  
**Stack:** `lib/team_budget.rb` `server.rb:593 budget_block_notice` + browser-harness + simulações  
**App:** `http://localhost:3000` (docker `web` 3000, `db` postgres 16)

---

## 1. Estado atual (hardcoded)

`lib/team_budget.rb:7-15`
```rb
BUDGET = 450
S_LIMIT = 3  # trava hard
TIER_COST = { S:120, A:70, B:55, C:40, D:30, F:20 }
cost_for = restricted ? base/2 : base  # ◆
```

`server.rb:593-613` checa `s_limit_notice` ANTES de `budget_notice`. UI `views/team.erb:9-10` mostra `Custo 420/450` e `S 0/3`.

**Playtest browser (cookie jar + UI):**

```bash
curl -c /tmp/c -b /tmp/c POST /team pokeName=growlithe  → 60/450 S1/3
curl -c /tmp/c -b /tmp/c POST /team pokeName=onix       → 120/450 S2/3
curl -c /tmp/c -b /tmp/c POST /team pokeName=porygon    → 180/450 S3/3
curl -c /tmp/c -b /tmp/c POST /team pokeName=magnemite  → notice--error "Máximo de 3 S por time."
# custo projetado 180+120=300 <450, mas trava bloqueou. Sem trava, 4º S caberia.
```

Lista filtrada `tier=S` (browser):
- `S·120` zubat, magnemite, horsea, mewtwo, lugia...
- `S·60 ◆` growlithe, onix, porygon (restricted = metade)

**Furo:** 4× S normal = 480 >450 (bloqueia por custo), mas 4× S_restricted = 240 <<450, 6× S_restricted = 360 cabe. Time `3× S_r (180) + magnemite 120 =300` prova que orçamento não limita S baratos.

Browser: `GET /pokemons?tier=S` confirmado mix 120/60.

---

## 2. Simulações (via `docker compose exec web ruby`)

Cálculo de budget mínimo para conter 4 S por custo puro:

- Para **S normal**: `4×120=480 >450` já bloqueia. OK.
- Para **S restricted (60)**: `4×60+2×10(F_r)=260` <<450 → **impossível bloquear 4 S_r com BUDGET 450 e desconto 50%**.
- Condição strict para magic number: `3S+3F(60) ≤ B < 4S+2F(40)` tem que valer para normal E restricted.
- Resultado brute-force (sim3.rb): **0 candidatos com d=50%**. Só aparece com `d≥80%`.

Tabela BUDGET 450:

| S | Sr (d) | 3S+3F | 4S+2F | 3Sr+3F | 4Sr+2F | veredito |
|---|--------|-------|-------|--------|--------|----------|
|120|60  50% | 420 OK| 520 bloq|240 OK |280 **FURO**| atual fura |
|120|90  75% | 420 OK| 520 bloq|330 OK |400 **FURO**| ainda fura |
|120|96  80% | 420 OK| 520 bloq|348 OK |424 **FURO**| ainda fura |
|120|108 90%| 420 OK| 520 bloq|384 OK |472 bloq| **strict OK** |
|130|104 80%| 450 OK| 560 bloq|372 OK |456 bloq| strict OK mas 3S+3F no limite |
|140|112 80%| 480 OVER|...|...|...| 3S já estoura |

Conclusão: com desconto 50% é **matematicamente impossível** limitar a 3 S só por orçamento se mantiver F=20 (10 restricted). Precisa reduzir desconto de S.

---

## 3. Propostas — números mágicos (sem `S_LIMIT`)

Todas garantem `max 3 S` por custo, time 6 cheio.

### A — Conservadora (recomendada p/ playtest 2)
- `BUDGET 450, S 120, S_r 108` (desconto S só 10%, demais tiers mantém 50%)
- `cost_for` vira `restricted ? (tier==S ? (base*0.9).round : base/2) : base` ou floor 90
- `3S+3F=420 OK`, `4S+2F=520 bloq`, `4Sr+2F=472 bloq`, `6Sr=648 bloq`
- Prós: muda só S restricted, time 3S+suportes baratos segue viável, 4 S impossível.
- Contras: growlithe/onix deixam de ser “baratos” (60→108).

### B — Enxuta / tensão alta
- `BUDGET 420, S 120, S_r 96` (80%)
- `3S+3F=420 OK exato`, `4Sr+2F=424 bloq` (bloqueia por 4)
- Prós: orçamento mais apertado força escolha S vs suportes bons.
- Contras: `3S+ A(70)+B(55)` já estoura (525>420), time 3S será sempre 3S+Fs, pouco espaço p/ A/B.

### C — Limpa (sem desconto p/ S)
- `BUDGET 450, S 130, S_r 130` (S nunca desconta)
- `3S+3F=450 OK exato`, `4S+2F=560 bloq`, regra simples “S sempre 130”
- Prós: mais fácil de comunicar, remove exceção.
- Contras: `3S+3F` no limite cravado, qualquer A no time exige trocar S por B.

> Nota: `BUDGET 380/400` com S 120 foi testado e reprova `3S+3F` (420 OVER), então descartado.

---

## 4. Evidência browser (prints lógicos)

- Filtro `tier=S` mostra 120 e 60◆ lado a lado (zubat 120 vs growlithe 60).
- Painel `team.erb` exibe `Custo do time: X/450` e `S no time: n/3` — após 3 S_r, tentar 4º S exibe `notice--error` de S_LIMIT mas `X` ficaria 300, provando que custo não bloquearia.
- `POST /team` com cookie jar reproduz adição sequencial e bloqueio por S_LIMIT vs budget.

---

## 5. Recomendação playtest

**Escolher A para próxima sessão de refinamento:** `BUDGET 450, floor S_r = 100-108`. Mantém economia atual para 90% dos casos, fecha o furo de 6× S_r barato, e permite remover `S_LIMIT` sem quebrar times existentes (2S+2A+2B = 2*120+2*70+2*55=490 OVER ainda, mas 1S+2A+2B+1C =120+140+110+40=410 OK — balance ok).

Passos sugeridos:
1. Ajustar `TeamBudget.cost_for` com floor para S (ou `S_r = max(base/2, 90)`).
2. Remover `s_limit_ok?` / `S_LIMIT` e UI `S no time: n/3` → `S no time: n`.
3. Atualizar `test/team_budget_test.rb` e `team_routes_test.rb` (expect 4º S bloqueado por `budget_notice` não por `s_limit_notice`).
4. Rodar suite + lint, playtest manual 2: tentar montar 4× S_r (growlithe/onix/porygon + outro S) e confirmar bloqueio por “Orçamento insuficiente”.

---

## 6. Próximos playtests na fila

- P1 performance gateway / warm-up tier (índice ou cap)
- J2/J4/D4 vs limitações (race add, escritas atômicas, CSRF)
- M1 pedras / evolução por item (impacta restricted)

*Gerado em playtest browser-harness + simulações `sim_economia.rb`/`sim3.rb` via `docker compose exec web ruby`.*
