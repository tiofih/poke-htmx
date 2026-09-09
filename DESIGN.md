# DESIGN.md — sistema visual canônico (Poke-HTMX)

Extraído de `public/style.css` (`:root` + blocos ODS 0072–0076). **Toda UI nova
reusa estes tokens e componentes; nada de hex hardcoded nem componente paralelo.**
Skills: `impeccable audit/critique`, `stark`, `normalize`, `extract`.

## Tokens

```css
/* base dark esverdeada (oklch, hue ~165) */
--bg / --surface / --fg / --muted / --border / --ink
--accent (ações) / --ok / --warn / --danger
--accent-soft / --fg-soft (color-mix, fundos discretos)
/* 18 tipos: --t-fire ... --t-steel (badge = bg tipo + color --ink) */
--font-display (Avenir Next Rounded) / --font-body (sistema) / --font-mono (números: .num, .meta, .rank-*)
--radius: 12px; --radius-lg: 18px; --gutter: 32px; --container: 1180px
--fs-h1: clamp(28px,3vw,40px) / h2 / h3:18px / lead:17px / body:15px / meta:12.5px
--gap-xs 8 / sm 12 / md 20 / lg 32 / xl 56 / 2xl 96 (px)
```

## Componentes (reusar, não duplicar)

`.topnav`+`.nav-badge` / `.btn`+`-primary/-secondary/-ghost/-lg/-sm` (hover -1px,
active scale .98, `:disabled` op .45) / `.card` / `.pcard` (hover -2px + borda
accent) / `.member`+`.sprite-tile` / `.bar/.bar-fill` (tiers ok/mid/low) /
`.pill`(.warn/.danger) / `.meter`(.over/.danger=.near/.warn) / `.arena` 3col→1
(≤980px) / `.fighter(.engaged)`+`.moves/.move` / `.podium` sticky / `.result` /
`.battle-log` (stagger via `--log-delay`, max-height 380px) / `.overlay:target`
+ `.modal[role=dialog]` (sem JS) / `.pos-card/.stat-chip/.rank-row/.history-row`
(win/loss/draw) / `.add-toast` / `.filter-grid` (inputs min-height 44px).

## Regras

1. Novo estado visual = classe nova sobre token existente; tier HP/XP segue
   `ok/mid/low`, resultado `win/loss/draw` — sempre com texto junto.
2. Juice (keyframes `juice-*`, 0.3–0.5s) só via classes `is-hit/is-attacking/
   fainted` + `data-damage`; projétil só ≥900px; tudo coberto pelo bloco
   `@media (prefers-reduced-motion: reduce)` no fim do ODS.
3. Breakpoints: 920 (grids→1col), 700/600/480/375 (listas empilham).
4. Auditoria: `/impeccable audit` ou skill `audit` antes de validar qualquer
   sessão com UI; `normalize` quando surgir drift.
