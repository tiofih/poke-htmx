# UI Feel — BattleJuicePresenter (2026-09-13)

Scope: `lib/battle_juice_presenter.rb:1-90` only. Read-only, no code change.

## What exists (good hooks)
- Pure presenter: `initial_hp` replay, `damaged?/fainted?/shooting?` booleans.
- `css_classes` 1:1 with style hooks: `is-hit`, `fainted`, `is-attacking`.

## Game-feel gaps (per game-feel skill)
1. No importance tiers — footstep == KO. Add small/medium/large presets scaled to `damage_taken`.
2. Motion likely linear — route flash/pop/KO through eased tween (overshoot pop, ease-out settle).
3. No trauma shake — add decaying trauma on `damaged`, quadratic, camera/visual only, never sim.
4. No hit-stop — reserve 60-120ms freeze for KO / large hits only, input still registers.
5. Juice not transient — ensure `is-hit` flashes then returns to rest; `fainted` is end-state, not loop.
6. Single channel per event — stack 2-3: flash + shake + number pop on hit; projectile + sound on `shooting`.

## Smallest next slice
- Tier map: `damage_taken` → `juice: :small/:large/:ko` for CSS/data-attrs only.
