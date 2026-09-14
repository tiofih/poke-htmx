# Gotchas — 0080 convergência visual (provisional)

> Provisional: derived from reviews/review-2026-09-10T17-35-00.md Low findings, no commit.

## roster-grid hook without CSS rule (Low)
`views/team.erb:21` class `roster-grid` has no rule in committed CSS at 0080 state (only uncommitted 0077 defines `.roster-grid`). Dead hook today; `.roster` applies the grid. 0081/0077 own the hook, or remove the class if 0077 does not use it.

## result-card unclosed pre-existing for 0078 (Low)
`views/battle.erb:86-143` `.result-card` opened at :86 has no own `</div>` — :142 closes `.result`, :143 closes `section`; div imbalance +1 pre-exists 0080 (parent of step 4: 22 open/21 close). Out of 0080 scope (RNF-04); 0078 battle-1a1 to close the tag.
