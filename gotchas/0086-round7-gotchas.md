# Gotchas — 0086 round 7 per-aspect modules (provisional)

> Provisional: derived from reviews/review-2026-09-11T18-15-00.md (Aprovado, 0/0/2low + 3 info), no commit.

## S1 names don't match real tests (Low)
`sessions/0086-battle-log-juice.md:46-52` names `test_entries_grouped_by_round_chronological`, `test_log_tiered_pacing_delays`/`data-log-index`, `test_effect_sync_step_delay`, `test_per_aspect_modules_with_toggles` / `test_aggregates_off_per_aspect_timed` / e2e `per-aspect toggles` — none exist. Real proofs: `battle_view_test.rb:86` + e2e chronological, `test_battle_log_pacing_uses_tiered_step` + `..._cumulative_per_entry`, `test_juice_effects_sync_per_line`, `test_battle_arena_carries_jx_toggles_per_aspect` + `test_juice_aspects_modular_with_off_defaults`. Align rows at S2 validation — doc-only.

## `--jx-*` vars written but never read (Low)
`public/style.css:927-942, 2370-2378` — defaults + reduce zeroing exist, but gating is purely `[data-jx-...="on"]` attribute-selector; no `var(--jx-*)` read anywhere. Reduce's `--jx-*:0` is a no-op (the `animation:none !important` in the same block does the work). Either consume via `var()` or drop var writes — cosmetic, future pass.

## Toggle off = no base style (Info)
`views/battle.erb:44` — with any toggle `off` the aspect has no base style (e.g. `data-jx-modal="off"` leaves `.res-overlay` unstyled = immediately visible). Intended toggle semantics (off = no juice), but off also removes reveal delay, not just animation. Document as intended; no action.

## Shake uncapped vs modal capped (Info)
`public/style.css:989-991` — `.arena[data-jx-shake="on"]` uses uncapped full `acc` via `--step-delay` while modal `--log-total` caps at 3s; on long logs shake fires behind revealed modal. Muted by default (`shake=off` ships). Cap only if shake ever defaults ON.

## Modal label without keyboard semantics (Info)
`views/battle.erb:84` carried — close `<label>` no keyboard semantics, focus never moved into `role="dialog"`. Out of narrow scope, CSS-only constraint. Future a11y pass.
