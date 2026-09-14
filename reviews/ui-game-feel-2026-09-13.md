# UI Game-Feel Survey — 2026-09-13 (READ-ONLY)

Skill: `game-feel` (+ `references/feedback-recipes.md`). App: Poke-HTMX (Sinatra + HTMX, no own JS, CSS-only juice).
Scope: survey only — no code changed. Sources: `PRODUCT.md`, `DESIGN.md`, `STACK.md`, `views/_fighter_panel.erb:8-14`,
`views/_jx_gates.erb:1`, `views/team_add_result.erb:2-6`, `public/style.css:918-1064,1566-1734,2404-2471`.

## Event hooks (skill step 1) — present

- Server computes per-fighter juice (`juice.fighter_juice(side, name)` → `is-hit` / `is-attacking` / `fainted`,
  `data-damage`, `--hp-initial-percent`, `--step-delay`) in `_fighter_panel.erb:1-14`.
- Aspect gates via OOB `#jx-gates` (`data-jx-hit/dmg/ko/hp/shake/shot/log`) in `_jx_gates.erb:1`; CSS aggregates
  on `.arena[data-jx-*="on"]` (`style.css:951-1001`) plus `:has(> #jx-gates…)` mirror (`2404-2443`). Default OFF per aspect.
- OOB swaps re-render fighters + gates per strike (`_strike_fighters.erb:1`, `_strike_log_entry.erb`, `_strike_result.erb:1`).

## Feedback-channel inventory (skill step 2)

| Channel (skill menu) | Status in app | Evidence |
|---|---|---|
| Sound (tick/hit/boom) | Absent (by constraint) | No-JS rule (`PRODUCT.md:12-13`); no `<audio>`, no SFX hooks |
| Particles (burst, pooled) | Minimal — single dot projectile only | `.shot` 10px radial dot (`1004-1014`); directional `juice-shot-ltr/rtl` with `--fx-travel:40vw` (`1581-1601,932`) |
| Screen shake (trauma², camera offset) | Deliberately card-local, tiny | `juice-shake` ±1px translate, 0.3s (`1698-1712`), composed with flash on `.fighter.is-hit` (`996-1001`); arena itself never shakes (comment C10/Passo 25, `993-995`). No trauma model, no decay — one-shot keyframe |
| Hit-stop / freeze frame | Absent (CSS-only cannot retime) | No `time-scale` equivalent; stagger via `--log-delay`/`--step-delay` only |
| Flash | Present, legible | `juice-flash` red inset wash 0.4s (`1664-1671`), gated by `data-jx-hit` (`965-967`) |
| Knockback | Absent | No displacement toward/away from hit normal; shake is in-place jitter |
| Tween / squash & stretch pop | Weak — settle-only, no overshoot | All juice `ease-out`/`ease-in` (`0.3-0.5s` per `DESIGN.md:36-37`); `juice-banner` scales 0.9→1.0 with plain `ease-out` (`1714-1723`) — no `BACK`/overshoot equivalent; no volume-conserving squash |
| Damage number pop | Present, single style | `::after` with `attr(data-damage)`, rise + fade 0.5s (`970-979,1673-1685`); always `var(--danger)`, no crit/large variant, no horizontal fan-out |
| HP bar settle | Present | `juice-hp` from `--hp-initial-percent` 0.5s (`958-960,1658-1662`) |
| KO / death | Present, correct resting-state change | Grayscale + 0.6 opacity 0.5s (`982-987,1687-1696`); `.fainted` resting opacity 0.75 (`989-991`) — intentional non-return, reads as state not juice |
| Log stagger / anticipation | Present | `battle-log-in` 0.35s + `--log-delay` (`951-954,1647-1656`) |
| Toast / banner / rewards | Present | `juice-toast-in` 0.35s + `juice-toast-out` 0.35s @3s (`1613-1642`); `juice-banner`/`juice-news` (`1034-1041,1714-1734`) |
| Button micro-juice | Present | `.btn:hover -1px`, `:active scale .98`; `.pcard:hover -2px` (DESIGN.md:23-25) |

## Easing (skill step 3) — all linear-settle, no pop curve

- Every keyframe uses `ease-out` (or `ease-in` for toast-out); no overshoot/bounce keyframe anywhere in `1566-1734`.
- Closest to "pop" is `juice-banner` but it lacks the overshoot past 1.0 that `TRANS_BACK` would give.
- Projectile is a constant-velocity translate + shrink (`1566-1575`); no anticipation wind-up, no ease-in then snap.

## Importance tiers (skill step 6) — binary gates, not scaled presets

- Recipes want small/medium/large (trauma 0.15→0.8, hit-stop 0→0.15s, particles 0→40). App has per-aspect ON/OFF gates,
  no intensity dimension: a chip hit and a KO flash/shake identically; damage number has one size/color.
- `DESIGN.md:36` fixes durations 0.3–0.5s globally — consistent, but proportional scaling (crit = bigger) is unobserved.
- Recommendation (not applied — survey only): tier `data-damage` magnitude → modifier class (`is-crit`) driving
  larger shake/number scale; keep routine adds/toasts at current small tier.

## Restraint checks (skill steps 4-5, pitfalls)

- ✅ Juice off simulation: shake/flash live on card visual only; HP width is server-rendered data, animated via keyframe from var — no collision/aim surface to desync (no canvas/physics).
- ✅ Returns to rest: flash/shake/banner/toast all end at neutral (toast-out ends at opacity 0 = dismissed, correct);
  only KO persists, which is state.
- ✅ Never on routine actions: projectile gated `min-width:900px` (`1016`), flash-only below — good mobile restraint;
  filters/pagination have no shake (correct).
- ✅ Non-blocking: pure CSS animations, no input lock; `prefers-reduced-motion` kills all juice incl. toast (`1049-1064,2446-2471`)
  plus `:has(.log-skip-input:checked)` kill-switch (`1901-1905`) — exceeds the skill's accessibility ask (no separate
  shake/flash sliders, but full-off + skip covers the constraint).
- ⚠️ Shake implementation uses fixed 4-step translate keyframe, not noise/sine-decay; at ±1px/0.3s it avoids buzz, but it
  also barely reads as impact — more "tick" than "punch". Acceptable under no-JS, but call it what it is: a nudge, not trauma shake.
- ⚠️ `box-shadow: inset 0 0 0 9999px` flash (`1666`) is the most expensive channel here; short duration keeps it fine.

## Biggest gaps vs. skill (ordered by feel payoff, CSS-only feasible)

1. No overshoot pop anywhere (banner, toast-in, damage number) — cheapest win: `cubic-bezier` overshoot on banner/toast.
2. No tier scaling — crit/KO vs chip look identical except KO fade.
3. No anticipation/follow-through (wind-up on attacker before `.shot` fires; settle on target after flash).
4. No sound layer by architecture decision — stacking therefore caps at ~4 channels (flash+shake+number+HP) vs. skill's 5–8.
5. Hit-stop and camera trauma shake are architecturally out of reach without JS — document as accepted, not missing.

## Verdict

Mechanically hooked and disciplined (gated, restorable, reduced-motion-safe), but feel sits at "legible settle" rather than
"punchy": flash + 1px nudge + number + HP drain with uniform ease-out. Matches PRODUCT/DESIGN constraints; the pop/tier
layer from the skill is the unclaimed upside.
