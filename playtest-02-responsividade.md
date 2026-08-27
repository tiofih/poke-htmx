# Playtest 02 — Responsividade e adaptabilidade (levantamento)

**Data:** 2026-08-27 · **Foco:** onde quebrar em tamanhos de tela (sem implementar)
**Rotas:** `/` (lista+time), `/battle`, `/history`, `/team/manage` · **CSS:** `public/style.css:11-384` + sakura CDN + `views/layout.erb`
**Método:** browser-harness CDP `Emulation.setDeviceMetricsOverride` + `getComputedStyle` + injeção de `viewport` para simular fix

---

## 1. Blocker crítico — sem `<meta viewport>`

`views/layout.erb:5-8` não tem `viewport`:
```html
<meta charset="UTF-8">
<title>Poké-HTMX</title>
<!-- falta: <meta name="viewport" content="width=device-width,initial-scale=1"> -->
```
Medido sem fix (CDP `w 375`):
- `window.innerWidth = 980` (iPhone simula 980 desktop), `body 980`, `scroll 980`
- `.pokemon-grid` = 6 colunas `77px` cada, `.list-team-grid` = `531px 396px` (2 colunas) — **mobile renderiza desktop zoomed-out**, media-queries `max-width 720/480` nunca disparam.
- Resultado: usuário em celular vê lista minúscula e precisa pinch-zoom. Fix é adicionar a tag.

Com fix injetado (`meta viewport`):
- `375×812` → `innerW 375`, grid `346px` (1 col), team `349px` (1 col) ✅ media dispara.
- `768×1024` → `innerW 768`, grid `42px ×6` (ainda 6 col) ❌
- `1024×768` → `85px ×6` **muito estreito** para 6 cards.

**Ação requerida:** adicionar `viewport` em `layout.erb` (P0).

---

## 2. Grid da listagem — breakpoint muito baixo

`public/style.css:18-35` + `102-114`:
```css
.pokemon-grid { grid-template-columns: repeat(6,1fr); }
@media (max-width:720px){ .pokemon-grid { repeat(3,1fr) } }
@media (max-width:480px){ .pokemon-grid { 1fr } }
```
Medições com viewport:

| Largura | Colunas reais | Largura por card | Veredito |
|---------|---------------|------------------|----------|
| 375 (mobile) | 1 | 346px | ok mas desperdiça — 2 col `~170px` seria melhor para browse |
| 320 (SE) | 1 | 291px | card enorme, filter 165px de altura (4 linhas) domina viewport |
| 768 (tablet) | 6 | 42px | **inutilizável** — imagem 96px espremida, texto quebra, botão fora |
| 820 | 6 | 51px | igual |
| 1024 | 6 | 85px | estreito — nome + `S·120` + botão espremidos |
| 1440 | 6 | 154px | ok |

Causa: breakpoint `720` só pega celular; tablet `768-1024` fica com 6 colunas em coluna estreita `319px` (`list-team-grid 319px 396px`). `list-column` tem `minmax(0,1fr)` mas com `gap 12px` + `6` colunas, card < 90px.

Proposta (anotar em draft-ui-ux):
- Trocar para `auto-fill` ou breakpoints graduais: `>1100:6`, `900:4`, `720:3`, `520:2`, `360:1` — ou `repeat(auto-fill,minmax(140px,1fr))` que já resolve 768 (auto vira 2-3).
- Revisar `list-team-grid` breakpoint: hoje `720` → colapsa para `1fr`; tablet `768` ainda é 2 colunas `319+396` com lista espremida. Sugerir `960` ou `900` (ex: `list-team-grid 1fr` em `<960`).

---

## 3. Barra de filtros — 7 controles em flex wrap

`views/_filter_controls.erb` 6 selects + input + link = 7 filhos, `filter-controls: flex wrap gap .5em`, `select/input { flex:1 1 8em; min-width:8em }`

| Largura | Altura medida | Layout |
|---------|---------------|--------|
| 375 | 117px (~3 linhas) | `q` ocupa linha 1, `type+generation` linha 2, `tier+cost` linha3, `sort+Limpar` linha4 — wrap caótico, selects 106px min |
| 320 | 165px (4 linhas) | pior, link `Limpar` quebra sozinho |
| 768 | 179px | mesmo com 768, 6 selects * 128px = 768 exato, ainda 2-3 linhas |
| 1024 | 91px (2 linhas) | ok |

Toque: selects com altura nativa ~32px (< 44px recomendado), sem `min-height`.

Proposta:
- `<600px`: filtros em **2 colunas grid** ou **drawer “Filtros”** (colapsável), input `q` full-width no topo.
- Aumentar `min-height 44px` p/ alvo de toque.
- `gap .75em`, `min-width` maior, ou agrupar `type+generation` e `tier+cost+sort`.

---

## 4. Layout Lista+Time — duas colunas com scroll aninhado

`public/style.css:260-310`:
```css
.list-team-grid { grid-template-columns: 1fr 22em; }
.list-column { max-height:78vh; overflow-y:auto; min-height:420px }
.team-column { max-height:78vh; overflow-y:auto; min-height:420px; border }
@media (max-width:720px){ grid:1fr; max-height:none; overflow:visible }
```

- Desktop `1024`: `575px 396px` ok, mas `list-column 78vh` cria **scroll interno** + scroll da página — duplo scroll confunde, wheel preso na coluna.
- Tablet `768`: `319px 396px` — lista 319px muito estreita para grid 6 col (ver §2).
- Mobile `375`: colapsa para `1fr`, `max-height none` (correct) — colunas empilham, mas `team-column` ainda tem `min-height 420px` mesmo vazio (espaço branco grande antes de montar time).

Proposta:
- Subir breakpoint para `960`.
- Remover `max-height 78vh` em `<960` já feito, mas em desktop considerar `max-height: calc(100vh - header)` ou remover scroll interno e deixar página rolar.
- `team-column` `min-height` condicional (só quando tem conteúdo) ou `400px` → `auto` em mobile.

---

## 5. Batalha — 3 colunas sem breakpoint

`public/style.css:170-176`:
```css
.battle-layout { display:grid; grid-template-columns: repeat(3,1fr); }
```
Sem `@media` para batalha.

Gate atual `/battle` sem time mostra só notice, mas com batalha ativa (mockado) em `375`:
- 3 colunas `~115px` cada — `battle-pane` com `fighter img + Nível + HP 120px` estoura.
- `.hp-bar 120px` + `.pp-bar 80px` são **fixos**, não fluidos — em 375, `fighter` quebra linha e barra vaza.
- Central `.battle-controls` e `.battle-log` espremidos.

Proposta:
- `@media (max-width:900px){ .battle-layout { grid-template-columns:1fr; } }` — empilhar: Seu Time → Controles/Log → Oponente, ou `1fr` com `order`.
- Barras `width: 100%; max-width:120px` ou `flex:1`.

---

## 6. Outros achados

- **Nav:** `header nav` `nowrap` sem wrap; em `320` ainda cabe (3 links curtos), mas `strong Poké-HTMX` + 3 links em 320 pode quebrar em 2 linhas (não medido com wrap). Aumentar `gap` e `padding` para alvo 44px.
- **Sakura base:** body `max-width 38em` sobrescrito por `page-list/page-battle/page-history none` ok, mas `padding 13px` fixo em mobile reduz área útil (13*2=26 → 349px efetivo).
- **Imagens:** sprite `96px` via PokeAPI, `.list-item img display:block` ok, mas sem `max-width 100%` — em card 42px a imagem vaza (medido 42px card vs 96px img).
- **Manage (`/team/manage`):** `manage-member` lista vertical com dezenas de `form.move-row` + selects — sem grid, em mobile lista interminável. Não medido neste playtest, mas draft-ui-ux §2.5 já anota.
- **Histórico:** sem grid, só `<p>` + `<ul>` — ok em mobile, mas ranking com `UUID` cru (draft-ui-ux §2.7) quebra linha em 375 (UUID 36 chars > 375).
- **Tipografia/sakura:** `font-size` base 1.8rem sakura, sem escala fluida — ok mas em 320 texto grande.

---

## 7. Prioridade sugerida (para draft)

**P0 (bloqueia mobile):**
- [ ] `layout.erb` adicionar `<meta name="viewport" content="width=device-width,initial-scale=1">`
- [ ] `pokemon-grid` usar `auto-fill minmax(140px,1fr)` ou subir breakpoint 6→3 para `960`, 3→2 para `600`, 2→1 para `400`
- [ ] `list-team-grid` colapsar em `960` não `720`

**P1 (tablet e filtros):**
- [ ] `filter-controls` layout mobile (grid 2 col ou drawer), `min-height 44px`
- [ ] `battle-layout` empilhar em `900`

**P2 (polimento):**
- [ ] `hp-bar/pp-bar` fluidos, `img max-width 100%`, `team-column min-height auto` em mobile, `list-column` sem `78vh` duplo scroll
- [ ] `nav` wrap + gap, `body padding` responsivo

---

## 8. Evidências brutas (CDP)

```
SEM viewport (atual prod): 375→ innerW 980, grid 6×77px, team 531+396 (mobile = desktop)
COM viewport injetado:
  375: grid 1×346px, team 349px, fcH 117px
  320: grid 1×291px, fcH 165px
  768: grid 6×42px (!), team 319+396, fcH 179px
  1024: grid 6×85px, team 575+396
battle gate 375: sem battle-layout (precisa time de 6 p/ medir 3 col)
```

Próximo: anotar em `draft-ui-ux.md` ou `draft-design-system.md` como `RESP-1` e abrir sessão SDD de responsividade após fechar M2b.
