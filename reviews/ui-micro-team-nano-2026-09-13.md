# Team Add Button — Micro-interaction Nano
- Target: team add button only (`views/team.erb:10-11` restart/add path).
- Press: `scale: 0.96`, 100–150ms, transform-only, no layout anim.
- Enter: ease-out `cubic-bezier(0.16,1,0.3,1)` ~200ms; exit faster ease-in.
- Success: opacity fade for `#team-view` innerHTML swap continuity.
- Roster add: subtle scale-in new `.member`, avoid width/height anim.
- Disabled/journey states: opacity-only change, no movement.
- Reduced motion: keep opacity, drop scale/translate entirely.
- Htmx hook: CSS only; no JS lib needed for this single button.
- Out of scope: rest of team view, toasts, modals, list reorder.
