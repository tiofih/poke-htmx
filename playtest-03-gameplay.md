# Playtest 03 — Rodada completa de gameplay (game design, UI/UX, bugs)

**Data:** 2026-08-27 · **Método:** browser-harness + `curl -c /tmp/full` sessão única + `docker compose exec db psql`  
**Fluxo:** montar 6 (starters A 70) → `GET /battle` → `POST /battle/play`×6 → heal/mart/history/manage/remove → reinício  
**Base:** `6022665`? `server.rb:471-809`, `battle_service.rb`, `heal_service.rb`, `mart_service.rb`, `reward_rule.rb`, `experience_curve.rb`

---

## 1. Loop jogado (evidência)

```bash
POST /team bulbasaur…totodile (6×70) → 420/450 S0/3
GET /battle → “Jogar”
POST /battle/play ×6 → Rodada 6 “Vencedor: Oponente” + “40 XP + 40 dinheiro” → HP 0/45…0/50 todos zumbis
GET /team → Custo total heal 131, Saldo 40 → “Dinheiro insuficiente” + Game Over
POST /mart/buy potion 20 → Saldo 20 ; sell → 30 (ainda <131)
HISTORY → Posição 3, 0V 1D
Manage → “Gerenciar time” ok, remove id 128052 → 350/450, Time 5/6
```

DB `team_pokemon_progress: level 1 xp 0` (nenhum level up), `wallet 30`, `battles` game_over state.

---

## 2. Game Design

### 2.1 Economia — death spiral em derrota precoce (P0 design)

- `RewardRule: win 100 / lose 40` (`lib/reward_rule.rb:5`), `HealCostPolicy 0.5/HP` (`lib/heal_cost_policy.rb:5`). Time 6 full wiped ≈ 260 HP faltante → `131` heal. Saldo inicial `200` (`db/seeds/saldo_inicial.rb`), mas após 1ª derrota saldo `40` (200+40-? gastos?) — `heal 131 > 40` trava.
- Jogador sem estoque não consegue vender para curar (potion 20 → +10 venda = net -10). Loop: perder → sem dinheiro → sem heal → Game Over → única saída `POST /journey/restart` perde time.
- **Efeito:** punição muito dura para primeira derrota com time inicial fraco (6× starters A). Win rate baixo (oponente band `B→A` em nível 1 aleatório) torna spiral provável. Oponente do teste venceu 6×A com 6 rounds.
- **Sugestão:** `lose_money` 60-70 ou heal `0.3/HP` ou 1ª cura grátis / “revive” barato; ou cap heal ≤ `lose_money`. Testar `lose 60, heal 0.3` → heal 78 vs 60 ainda perde mas recuperável com venda.

### 2.2 Progressão XP — grind lento mas ok

- `ExperienceCurve: xp_needed = level*100, cumulative level*(level+1)/2*100` (`lib/experience_curve.rb`). Win 50, lose 40, draw 25.
- Nível 1→2 precisa `100` (2 vitórias), 2→3 `200` cumulativo (4 vitórias). Com lose 40, 3 derrotas = 120 XP → nível 2 igual. Ritmo 2-3 batalhas/level early — aceitável, mas sem “catch up” para time derrotado (XP de derrota quase igual a vitória).
- Evolução `EvolutionRule nxt_stage min_level ≤ level` (`lib/evolution_rule.rb`) — só level-up, sem item/pedra (correto). Starters evoluem em 16? Teste não chegou a evoluir.

### 2.3 Balance de montagem vs batalha

- Starters `A 70` fixos dão `420/450` → time homogêneo barato. Oponente `OpponentGenerator band B→A` em média nível 1 misturado, mas rating inclui S (ex: 6× S possível?). Banda `band_for_level: 1→F/D` (§ `pokemon_rating.rb:45`) deveria dar F/D, mas teste usou band média `average_level 1` → `F/D` — por que perdemos com A vs F/D? Damage formula ` (Atk-Def)*power/50*multiplier` (`battle_engine.rb:45`) favorece speed? Ou oponente tinha 6× “tank”?
- Sem preview de força do oponente (sem tier/custo do inimigo) — jogador não sabe se enfrenta spike.
- Itens `choice-band/scarf 80` caros vs saldo 40 — inacessíveis early.

### 2.4 Loop e gating

- `JourneyService.started? = team.size>=6` (`lib/journey_service.rb:8`) — simples, mas `battle_ready?` exige `usable_hp?` (algum HP>0). GameOver = `started && !battle_ready && !affordable_heal` — correto.
- Porém `remove` após Game Over reduz para 5/6 → `started? false` → mostra “Monte time 5/6” e libera heal/mart? No teste remove liberou e tirou Game Over, mas não restaurou HP — exploit para escapar heal caro removendo 1 poke (350/450, 5/6). Design deve decidir: remover em Game Over deve ser bloqueado ou heal persiste.

---

## 3. UI/UX

### 3.1 Lista + Time unificados (Onda 1B) — bom, mas atritos

- 2 colunas `1fr 22em` funcionais em desktop, mas `78vh` scroll interno (§ playtest 02) confunde. Filtros 117px em 375 ocupam 15% viewport.
- `poke-cost` colorido S roxo, A vermelho etc — legível. `S·60 ◆` indica restricted mas sem tooltip (“por quê metade?”).
- Botão “Adicionar ao time” disabled sem explicação quando já está no time ou time cheio — falta estado “No time ✓ / Time cheio”.
- Paginação “Anterior/Próxima” pequena, sem número total.

### 3.2 Batalha

- 3 colunas `Seu Time | Controles/Log | Oponente` sem breakpoint (§02) — mobile espremido. Log mostra todas as rodadas (6) ok, mas sem scroll, texto denso.
- “Jogar” auto-resolve até fim (B5) — bom, mas sem animação. HP `0/45` + barra `0%` clara, PP `40→33` mostra gasto.
- Pós-batalha CTAs “Poke Center / Poke Mart / Novo confronto” levam à `/` (lista) — perde contexto da batalha. WIP: janelas flutuantes anotadas em `draft-ui-ux §6`.
- `battle-loading` “Carregando…” aparece só com `hx-indicator` — rápido, quase imperceptível.

### 3.3 Poke Center / Mart

- Center mostra `HP 0/45` lista + `Custo total 131` + botão “Curar” disabled quando sem saldo — correto, mas estado `disabled` sem explicar “por quê 131”.
- Mart `Saldo: 40` + botões `Pocao 20 ×2` (affordables = saldo/price) — bom. Venda mostra `Pocao ×1` + Vender — ok. Porém compra e venda são 1 por clique, sem quantidade, e consomem `hx-target #team-view` que re-renderiza tudo (pisca).
- Itens held `Choice Band/Scarf` sem descrição do buff (só nome).

### 3.4 Gerenciar, Histórico, Navegação

- Manage lista todos os golpes com `toggle` + “Salvar golpes” — lista longa (dezenas) sem busca, em 375 vira scroll infinito.
- Histórico exibe `UUID` cru (`user_id`) — ilegível, quebra linha em mobile.
- Nav `Lista/Batalha/Histórico` com `active` underline ok, mas sem badge `n/6`.

---

## 4. Bugs e fragilidades

**P0 — funcional/game over:**
- [ ] **Heal trap:** `lose_money 40 < heal 131` — softlock 1ª derrota sem estoque. Reproduzido 100%.
- [ ] **Remove escapa Game Over:** `DELETE /team` em Game Over reduz para 5/6 e limpa gate, sem curar. Jogador evita `restart` perdendo só 1 poke.
- [ ] **HP persiste após derrota:** `post-battle` zera HP mas não auto-cura nem dá revive — design intencional mas UX punitiva sem tutorial.

**P1 — UI/UX e contratos:**
- [ ] **`views/pokemon.erb:8` falta aspas:** `<input value=<%= @pokemon.name %>>` quebra se nome com `"` e é XSS vetorial (embora slug). Deve ser `value="<%= … %>"`.
- [ ] **Sem `meta viewport`** (playtest 02) — todos os breakpoints quebrados em mobile real.
- [ ] **Grid 6 col em tablet** (playtest 02) e **battle 3 col** sem media — já anotado `RESP-1`.
- [ ] **Manage sem paginação/busca** — O(n) forms por poke (6× ~30 golpes = 180 forms) — lento em mobile.
- [ ] **Histórico UUID** — deve mostrar apelido/`?as=` (J4).

**P2 — técnicas / edge:**
- [ ] **Race add:** `TeamRepository.add` checa `team_size` e `duplicate?` sem lock transacional forte — 2 `POST /team` paralelos podem estourar `MAX_TEAM_SIZE` (limitação já em `draft-auto-battler` “race no add”).
- [ ] **BattleService `build_opponent` banda:** usa `average_level 1` → band F/D, mas oponente pode ter S se pool não filtrado por `base_form?` (OPP-1/2 no draft).
- [ ] **PP `Struggle` infinito:** `choose_move` cai em `power 10 pp 100` quando sem PP — correto mas sem UI de “sem PP”.
- [ ] **Cassettes pendentes:** `test/cassettes/ServerBattleTest/...` não limpos.

---

## 5. Próximos passos sugeridos

- Balance: testar `lose_money 60` + `heal 0.4` ou 1ª cura grátis; validar com 3 vitórias simuladas.
- UI: abrir `RESP-1` (viewport+grid) + `M2b` (S_r 110) antes de nova mecânica; depois janelas flutuantes Center/Mart.
- Bugs P0: decidir regra `remove` em Game Over (bloquear ou curar parcial) e ajustar economia heal/lose.

