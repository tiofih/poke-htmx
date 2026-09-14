# UI Empty-State Survey — 2026-09-13 (READ-ONLY)

Lens: `.agents/skills/empty-state/SKILL.md` (state type → user questions → dead-chrome audit → clarity/value/CTA/chrome/tone).
No code changed. All paths below are evidence, not edits.

## Method

Surveyed `views/*.erb` + gate fragments in `server.rb:1055-1063`.
Classified each absence per skill taxonomy (first-use / no-results / cleared / permission / error-in-surface / route-level).
Scored each against Verify checklist: Clarity / Value framing / Next step (CTA) / Chrome cleanup / Tone.

## Inventory (9 surfaces)

| # | Surface | State type | Current copy / behavior | CTA today | Dead chrome |
|---|---------|------------|-------------------------|-----------|-------------|
| 1 | Team first-use — `views/team.erb:4-6` | First use / never created | `Time: 0/6` + `Monte seu time inicial de 6 Pokémon para iniciar a jornada.` | None in fragment — no anchor/button to catalog; user must discover right-hand catalog visually | `ul#roster` renders empty; header `Seu time` + readiness pill `Precisa de cura` stays (pill misleading with 0 members); Services card + filters stay visible |
| 2 | Team empty + healed-center — `views/_center.erb:5-15` | First use (degenerate) | When `@team` empty, `ul.heal-list` renders zero `li` with no message; modal shows only `Saldo / Custo total: ¥0` | Buttons enabled/disabled with zero cost — action is meaningless | Entire heal breakdown (per-member costs, avg-level math `views/_center.erb:17-18`) shown for an empty team; should collapse |
| 3 | Catalog no-results — `views/pokemon_list.erb:12-49`, hint `server.rb:282-284` | No results from search/filters | `search_hint` quirk only when `!@q.empty? && @items.empty?` (evolution/starter/base-form guidance — good). Pure filter combos (`type+generation+tier+cost`) with zero hits render **silent empty grid**: no `Nenhum encontrado` line, just `Arquivo · 0` | `Limpar filtros` link (`pokemon_list.erb:12`) always present — correct recovery, but weak visual weight (ghost sm link above empty grid) | Correct to keep filters (no-results preserves context). Pagination `Página N` + `Anterior/Próxima` still renders on zero results; count label `Arquivo · 0` is the only signal |
| 4 | History zero-battles — `views/history.erb:8-9` | First use | `Você ainda não batalhou.` (`notice--info`) | **None** — textbook skill violation (`NEVER: Leave users staring at "No items" with no next step`) | Good: ranking + recent sections fully hidden. Bad: pagehead `Sua posição / placar completo` promise stays above a one-line notice — value framing missing (what rank/recent will give you) |
| 5 | History no-wins — `views/history.erb:27-29` | Cleared/partial (zero wins but battles exist) | `Você ainda não tem vitórias.` under pos-card | None | Rest of dashboard stays — correct (context preserved) |
| 6 | Mart sell tab empty — `views/_mart.erb:34-54` | First use / cleared (inventory) | `Nenhum item no estoque para vender.` | None — no pointer to `Comprar` tab or to battling for rewards | Tabs kept (correct — needed to switch to Buy). Buy panel always populated from catalog so no symmetric empty there; out-of-rotation note `views/_mart.erb:29-32` is good context preservation |
| 7 | Battle gates — `views/battle.erb:1-13`, `server.rb:1055-1063` | First use (empty team) + error-in-surface | `empty_team_fragment`: `Forme seu time para batalhar.` / `battle_error_fragment`: `Não foi possível preparar a batalha. Tente novamente.` | Conditional `@gate_cta / @gate_action / @gate_disabled_cta` — present on some gates, absent on the generic error fragment (no Retry CTA wired in fragment; retry depends on caller) | Gate branch hides arena entirely — correct chrome removal |
| 8 | Route-level error — `views/error.erb:1` | Route-level failure (catch-all) | `<%= @message \|\| "Algo deu errado. Tente novamente." %>` | None — no Home / Search / Status / Sign-in-per-status mapping | N/A (single paragraph, no chrome to audit) — but skill demands specific recovery per status (home/search for 404, retry for transient, etc.); this is the generic catch-all the skill forbids as sole handler |
| 9 | Game-over (economic block) — `views/team.erb:8-13`, `views/battle.erb:144-151` | Permission-like / economic restriction | `Game Over — seu time está derrotado e você não tem dinheiro para curar. Venda itens no Poke Mart ou recomece a jornada.` | **Best in app**: Sell-items CTA + `Recomeçar jornada` form (both surfaces) | Correct: pill flips to `Game over` danger; battle loss branch adds `Poke Center / Novo confronto (disabled with title) / Recomeçar` — exemplary specific recovery |

## Gaps vs skill (ordered by user impact)

1. **History zero-state has no next step (P1).** Fails Clarity-lite + CTA. Skill wants: what this area is for + why useful + primary CTA + hide dead chrome. Today only the first half exists. Candidate CTA: build team / start battle; value line: rank + recent coverage.
2. **Catalog filter-zero is silent (P1).** `search_hint` covers text search only; filter-only dead-ends leave an empty `.pokemon-grid` with just `Arquivo · 0`. Needs explicit no-results block (what produced nothing + `Limpar filtros` as primary button, not ghost link) while keeping filters visible. Pagination should hide on zero pages.
3. **Team first-use has no CTA (P2).** Copy explains what/why but outsources the action to visual discovery. Needs primary CTA scrolling/targeting catalog (`#pokemon-list`) + optional starter suggestion; `ul#roster` should not render empty; readiness pill copy is wrong for size 0.
4. **Generic error fragments (P2).** `error.erb:1` + `battle_error_fragment` violate `NEVER: generic catch-all when specific recovery exists`. Map at minimum: transient→Retry, 404→Home/Search, 403→request-access, 5xx→status/support. Battle error should wire a Retry CTA in-fragment.
5. **Mart sell empty + Center empty-team (P3).** Both are one-line notices with no cross-link (sell→buy tab; heal-empty→add Pokémon). Low cost: inline link/button + collapse meaningless cost math when team is empty.

## Tone check

- First-use vs error tones are currently flat (`notice--info` everywhere except game-over/error). History zero vs Mart-sell-empty vs battle-error all read identically — skill requires distinct tones (inviting / light / plain-recovery language respectively).
- Game-over copy is the tone + CTA model to replicate; nothing else reaches that bar.

## Dead-chrome summary

- Correctly removed: history ranking/recent on zero (`history.erb:8`), arena on gate (`battle.erb:1-13`).
- Should remove/collapse: empty `ul#roster` (S1), pagination on zero results (S3), heal cost breakdown on empty team (S2), misleading `Precisa de cura` pill at 0/6 (S1).
- Correctly kept: filter controls on no-results (S3), mart tabs on sell-empty (S6).

## Suggested next slices (for TODO.md, one slice each — not implemented here)

- Slice A: history zero-state (copy + CTA + value framing).
- Slice B: catalog filter-zero block + hide pagination on zero.
- Slice C: team first-use CTA + suppress empty roster + pill copy at 0/6.
- Slice D: typed error recovery (battle fragment retry + `error.erb` status mapping).
- Slice E: mart-sell→buy cross-link + center empty-team collapse.

*Evidence paths: `views/team.erb:4-13`, `views/history.erb:8-29`, `views/pokemon_list.erb:12-49`, `views/_mart.erb:34-54`, `views/_center.erb:5-22`, `views/battle.erb:1-13,144-151`, `views/error.erb:1`, `server.rb:282-284,1055-1063`.*
