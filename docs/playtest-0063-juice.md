# Playtest — sessão 0063 "juice" (advisory, fase 3 pré-validação)

Data: 2026-09-08. App rodando em `localhost:3000` (`./scripts/run`). Três perfis jogaram em
sequência no navegador compartilhado: **novato** (primeira vez), **casual** (joga há um tempo,
não min-max) e **hardcore** (otimizador, foca em chegar o mais longe). Objetivo: percepção de
jogo, friction de UX e bugs de comportamento. **Isto NÃO é a validação formal** — a validação
(fase 3, tabela por critério) é do usuário. Aqui só se levantam achados para a decisão.

---

## 🔴 Achado crítico — ferimento de critério C3/C5 da 0063 (reduzir movimento)

**`prefers-reduced-motion: reduce` NÃO desliga o juice.** Confirmado independentemente por 3
agentes (via `getComputedStyle(...).animationName` sob emulação) e por leitura de fonte.

**Causa raiz (cascata CSS):** em `public/style.css`, o bloco
`@media (prefers-reduced-motion: reduce) { ... animation: none; }` está em **L301-316**, mas as
regras de juice (`.hp-bar .bar-fill { animation: juice-hp }` L328, `juice-flash` L337,
`juice-ko` L380, `juice-shake` L396, `juice-projectile` L431, `juice-toast` L467,
`juice-banner` L515, `juice-news` L520) vêm **depois**. Como os seletores têm a **mesma
especificidade**, a regra **posterior** vence → o `animation: none` é sobrescrito.

| Elemento | animationName sob reduce (esperado) | animationName real |
|---|---|---|
| `.hp-bar .bar-fill` | `none` | **`juice-hp`** ✗ |
| `.fighter--flash` | `none` | **`juice-flash`** ✗ |
| `.fighter--ko img` | `none` | **`juice-ko`** ✗ |
| `.battle-layout` (screenshake) | `none` | **`juice-shake`** ✗ |
| `.fighter--shooting .projectile` (≥900px) | `none` | **`juice-projectile`** ✗ |
| `.winner--pop` (banner) | `none` | **`juice-banner`** ✗ |
| `.battle-log__entry` (0069) | `none` | `none` ✓ (único que desliga) |

**Metodologia — erro a não repetir:** `document.getAnimations()` **não** serve para validar
reduced-motion (animações de 0.3–0.5s terminam e voltam `[]`). Usar `getComputedStyle(...).animationName`
(`none` esperado) ou `component.getAnimations({subtree:true})` imediatamente após o trigger.

**Fix provável (decisão do usuário — S3):** mover o bloco `@media (prefers-reduced-motion: reduce)`
para **o fim** de `public/style.css` (após todas as regras de juice), OU usar `!important` no
bloco, OU aumentar especificidade no bloco. Cuidado para não quebrar o `battle-log-in` (0069),
que hoje é o único que funciona porque vem antes.

---

## 🟡 UX / comportamento (sem ferir critério, mas relevantes)

1. **Toast do add de Pokémon invisível.** `#add-status` é `position: static` na `.list-column`,
   com `offsetTop ≈ 2400-2500` — fora da viewport. A animação `juice-toast-in/out` roda, mas a
   confirmação "Adicionado ao time." acontece **abaixo da dobra**, no oposto do ponto do clique.
2. **Detalhe do Pokémon abre fora da tela.** Clicar no nome de um Pokémon carrega `#pokemon-detail`
   em `offsetTop ≈ 2589px`, sem auto-scroll. Parece que o clique "não fez nada".
3. **Botões desabilitados sem razão visível.** Cards com time cheio/vazio mostram "No time ✓"
   desabilitado **sem `title`/motivo**; "Remover do time" / "Evoluir" desabilitados para Pokémon
   derrotado com motivo **só em `title`/tooltip** (inacessível por teclado/touch).
4. **"×N" do Mart = afordabilidade, não estoque.** `_mart.erb:5`: `affordable = @balance / price`.
   O contador **diminui** ao comprar/curar, mas o inventário é outro (vender). Rótulo enganoso
   (o "juice" de percepção de que "o jogo comeu seus itens").
5. **Consumo de itens em batalha opaco.** Itens auto-usados (ItemUsePolicy, ≤50% HP) são
   descontados, mas o jogador só vê o badge "já usou item" — sem "usou 1 Pocao (restam N)".
6. **Recompensa-positiva na derrota.** Após "Vencedor: Oponente", a news diz "Seu Time ganhou
   20 XP e 40 de dinheiro". Pode ser intencional (recompensa de participação), mas a mensagem lê
   como vitória.
7. **Batalha em 2 etapas (`/battle`):** "Novo confronto" (prepara) → "Batalhar" (resolve). O botão
   "Batalhar" do fragmento do time já resolve em 1 clique — redundância/atrito.
8. **Painel do time com scroll interno** (`overflow-y: auto`): `window.scrollTo` não rola a página;
   desorienta.
9. **Nav minimalista:** só `Time`/`Batalha`/`Histórico`. Mart, Center e Jornada aparecem **dentro**
   do painel do time **somente** após 6/6 — um novato que não montou o time não sabe que existem.

---

## Visão por perfil

### Novato (primeira vez)
- **Descoberta razoável, primeiro clique confuso.** A porta de entrada (listagem) não tem `<h1>`;
  o aviso "Monte seu time inicial de 6 Pokémon" guia o objetivo.
- O que **prende**: o loop central (buscar → montar com budget → batalhar animado → curar → comprar),
  o level-up mesmo perdendo, o histórico/ranking. A batalha animada dá "sensação de jogo de verdade".
- O que **faria parar**: "clique morto" (detalhe fora da tela), confirmação do add invisível,
  botões desabilitados sem motivo, contador do Mart diminuindo, scroll interno do time.

### Casual (joga há um tempo)
- **Loop coerente e juice embeleza a recompensa**, mas o ritmo atual é **de derrota** (batalha → cura
  cara → perde de novo). O "prazer de progredir" vira "gestão de recuperação".
- **Economia permissiva no papel, apertada na prática** — curar custa caro frente à recompensa.
  **Espiral de morte tangível**: sem saldo para curar, `/battle` trava no gate "time todo derrotado".
- O que **prende**: o juice, a recompensa-em-derrota, o ranking/histórico, a porta de recuperação (Center).

### Hardcore (otimizador)
- **Receita dominante:** 3 lendários S de base (mewtwo/rayquaza/mew, 120 cada) desde o nível 5 → a
  banda do oponente é capada (nível 5 → banda [D C], geração ≤2), e o jogador **não** é capado por
  banda/geração na adição → **one-shots** no começo. Front-load no slot 1 (oponente foca o 1º vivo),
  itens de cura no time da frente, Choice Band/Scarf (Attack/Speed ×1.5), cobertura de golpes
  (motor pega o de maior dano esperado), vencer rápido → curar barato → snowball.
- **Exploits/desequilíbrios:**
  - **E1 (crítico, design):** lendários desde nível 5 contra banda D/C — progressão trivial no começo.
  - **E2 (médio, confuso/não lucrativo):** farm de derrota não é sustentável (curar custa mais que
    +40); é espiral de morte.
  - **E3 (médio, armadilha):** custo por **linha** do jogador (`magikarp` base D = 70, `dratini` = 120)
    vs custo por **base** do oponente (mesmo `magikarp` = 30). Pokémon de "base fraca + linha forte"
    são noob traps.
  - **E4 (baixo):** sem cap de tier S (`team_s_count` é dead code — orçamento é o único limitador).
  - **E5 (baixo):** linha S **restrita** (◆) = 110 → permite 3 S + 1 A + 2 fracos em 450.
  - **E6 (info):** gate `base_form?` — só a 1ª evolução é adicionável.
- **Teto real:** no nível 15+ a banda sobe p/ [A S] e os fillers fracos viram liabilidade (orçamento
  450 não deixa time full-elite). É o "fim de jogo".
- **Leitura do juice sob foco:** o visual **não** mostra golpe a golpe (barra HP = sweep inicial→final;
  número de dano = total sofrido). O **log textual** é a fonte de verdade. O log revela do **último
  round para o primeiro** (`--log-delay` inverso) — um pouco estranho. Juice não atrapalha a leitura,
  mas é flair sobre o estado final.

---

## Consolidação técnica (para reabrir/formar critério — S3)

- **C3 / C5 (0063) — reduced-motion: NOK.** Confirmado (fonte + 3 medições). Decisão de reabertura
  (S3) é **do usuário**.
- O juice **em ≥900px funciona e é envolvente** (HP, projétil, flash, KO, número de dano,
  screenshake, banner, news; durações 0.3–0.5s, boa cadência, não cansativo). Em **<900px** sem
  projétil (só flash no alvo) é "ok, não decepcionante" — configura com D5 A.
- Nada de JS/polling/SSE foi feito (D2 A ok). Mecânica/economia/motor não foram tocados (G2 ok).

## Notas de processo

- Nenhum critério foi marcado ok/nok da tabela de validação (isso é do usuário na fase 3).
- Nenhum código foi editado/commitado; o estado do time no app foi modificado pelo hardcore
  (faltou registrar o time final — o agente informou 6/6: mewtwo, rayquaza, mew, wynaut, darumaka,
  rockruff, 450/450, saldo subiu). Não afeta o repo.
- Os playtesters gravaram gotchas em ai-memory (`gotchas/playtest-0063-juice.md`,
  `gotchas/juice-reduced-motion-cascade.md`, `gotchas/custo-jogador-linha-vs-oponente-base.md`)
  e registraram handoff. São achados válidos, mas escritos em momento do playtest (a regra S6 prevê
  gotchas/handoff no fechamento da validação — revisar na consolidação do usuário).
