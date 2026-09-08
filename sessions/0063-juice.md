# Sessão 0063 — juice (Onda 2 Economia #6: HP animado / projéteis / flash / KO / screenshake / toast / banner / news)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | **Concluída** — decisões do usuário em 2026-09-02 (D1–D8 fechadas) |
| Implementação | **Concluída** — 5 passos (be8b08e, 6aa4f6e, 62d9c7c, 938d145, 2ccc277), suíte 995/3938 lint 0, revisor **Aprovado** |
| Validação | **Concluída** — validado pelo usuário em 2026-09-08 (S2 tabela por critério ok, C5 manual ok) |

---

## 1. Objetivo

Juice de batalha CSS-only — HP animado (dano/cura), projéteis C2 (só ≥900px), flash de dano, KO fade/grayscale, número de dano flutuante e screenshake leve — mais juice fora da batalha (toast do add + hover/active em botões) e banner de vitória/derrota + news de evolução/XP animadas; origem calculada no servidor (replay do log), reusa `--log-delay`/stagger da 0069 e `prefers-reduced-motion` desliga tudo, sem JS/polling/SSE (C2 de `draft-auto-battler.md:710-716`; §juice de `draft-ui-ux.md:138-145`).

## 2. Contexto (estado atual — diagnóstico)

- **Baseline pós-0069:** suíte **985/3831**, lint 0 (0069 validada 2026-09-02). Roadmap: **0063 juice** → Onda 3 Estabilidade (race add, escritas atômicas, CSRF, respiro — numeração desliza).
- **`public/style.css`** — `@keyframes battle-log-in` (:290) + `--log-delay` stagger (0069) + `@media (prefers-reduced-motion: reduce)` (:301-305, hoje só desliga `.battle-log__entry`); `.hp-bar`/`.bar-fill` (:243-276) com `hp-bar--high/medium/low`; `.gameloop-cta:hover` (:467) já existe parcial — hover/active genérico de botões ainda não.
- **`views/battle.erb`** — log completo com `--log-delay` escalonado (:80-91); painéis via `_fighter_panel` (:20/:95); banner `winner` + XP + `evolution-news`/`learned-news` (:34-53); game over (:54-61).
- **`views/_fighter_panel.erb`** — barras HP com `hp_percent`/`hp_label`/`hp_tier` (:7-11); sprite/nome/nível; barras PP.
- **`lib/battle_log_presenter.rb`** — `entries` (:13-15), `entries_all` (:17-19), `format_entry` (:31-37) devolve **só** `round/side/text` — sem origem/alvo explícitos (o `entry` bruto do log tem `attacker`/`target` indexes — gotcha da 0069: entradas de item também têm `attacker_index`).
- **`server.rb`** — `advance_battle` (:924-930) → `settings.battle.resolve` (:925); `add_team_member` (:494) → `render_team_fragment_with_notice` (:905) → `#team-view` + notice em `#add-status` (**texto**, sem toast); `views/index.erb:11` `#add-status`; `pokemon_list_item.erb:14`/`pokemon.erb:3`/`pokemon_detail.erb:25` `hx-target="#add-status"`.
- **C1 (texto do log)** já atendido ("X usou Y em Z, N de dano" + KO) desde 0016/0069 — **a 0063 trata só C2 (projéteis) + painéis/HP + itens D1 C e D4 C**; nada mais de C1.
- Frescor do grafo 2026-09-03T02:13Z: `lib/battle_log_presenter.rb`, `lib/battle_service.rb`, `server.rb`, `public/style.css`, testes sem gap registrado; `views/*.erb` `not_tracked` (fonte conferida via read).

## 3. Escopo

### Produção

- `lib/battle_log_presenter.rb` — `entries`/`entries_all` passam a incluir **`from_side`/`to_side` (0/1)** por entrada **mantendo `round/side/text`** (backwards-compat — D6 A).
- `lib/battle_juice_presenter.rb` (**novo**) — helper puro: **HP inicial por lutador via replay** (`hp_final + Σdano − Σcura`) e derivação origem/alvo por entrada quando ausente; sem tocar engine/backend.
- `views/battle.erb` / `views/_fighter_panel.erb` — marcação de juice: log com `data-round` + `data-from-side`/`data-to-side`; painéis com `data-hp-initial`/`data-hp-percent` e classes de flash de dano / KO / projétil; banner vitória/derrota animado; news (evolução/XP) com classes de animação (D4 C).
- `public/style.css` — keyframes: **HP dano/cura**, **projétil** (só `min-width: 900px` — D5 A; <900px só flash no alvo), **flash de dano**, **KO fade/grayscale**, **número de dano flutuante**, **screenshake leve**, **toast do add** (entrada/saída), **hover/active em botões**, **banner vitória/derrota**, **news** — reusando `--log-delay`/stagger da 0069 e `prefers-reduced-motion` **desligando tudo** (D2 A, D3 B ~0.3–0.5s).
- `views/index.erb`/`pokemon_list_item.erb` (mínimo, se necessário) — classe/marcação do **toast** no `#add-status` (sprite + nome, kinds de notice; §juice `draft-ui-ux.md:138-141`).

### Testes

- `test/battle_log_presenter_test.rb` — novos `test_entries_include_from_to_side` + `test_entries_all_include_from_to_side`; **existentes preservados** (`test_returns_only_last_three_rounds`/`test_default_limit_is_three` — backwards-compat).
- `test/battle_juice_presenter_test.rb` (**novo**) — HP inicial por replay (`test_initial_hp_derived_from_final_plus_damage_minus_heal`); origem/alvo derivados.
- `test/battle_routes_test.rb` — novo `test_battle_fragment_marks_juice_targets` (fragmento `#battle-view` com `data-*`/classes de juice; sem rede).
- `test/style_responsive_test.rb` — novos `test_juice_keyframes_present` + `test_juice_reduced_motion_disables` + `test_projectile_only_above_900px` (leitura de `public/style.css`, padrão da 0060-0062).

### Fora de escopo (não abrir)

- **C1 (texto do log)** — já atendido; nada mais de C1.
- **JS/polling/SSE** — CSS-only (D2 A).
- **Mecânica/economia/motor** — `BattleEngine#battle`, `BattleService#resolve`/`finish_effects`, `BattleLogPresenter::DEFAULT_LIMIT` intocados.
- **Projétil em viewport <900px** — só flash no alvo (D5 A).
- **Mudanças de produto/schema/gems** — G2.
- → Ideias já anotadas (RNF-04): `draft-auto-battler.md` C2 (:710-716) e `draft-ui-ux.md` §juice (:138-145); demais itens (persistência do log, ajuste XP/dinheiro, dificuldade dinâmica) seguem para sessões futuras.

## 4. Critérios de aceite

### Resultado

- [ ] **C1 — Presenter juice backwards-compat:** `BattleLogPresenter#entries`/`entries_all` incluem `from_side`/`to_side` (0/1) por entrada **mantendo `round/side/text`** (sem quebrar `DEFAULT_LIMIT`/histórico/ranking); `BattleJuicePresenter` puro deriva **HP inicial por lutador** via replay (`hp_final + dano − cura`) e origem/alvo quando ausentes. — prova: `test/battle_log_presenter_test.rb` (novos `test_entries_include_from_to_side` + `test_entries_all_include_from_to_side`; existentes `test_returns_only_last_three_rounds`/`test_default_limit_is_three` preservados) + `test/battle_juice_presenter_test.rb` (novo, `test_initial_hp_derived_from_final_plus_damage_minus_heal`).
- [ ] **C2 — Marcação juice na UI:** `views/battle.erb`/`views/_fighter_panel.erb` marcam o log (`data-round` + `data-from-side`/`data-to-side`), os painéis (`data-hp-initial` + classes flash/KO/projétil) e o banner vitória/derrota + news (evolução/XP) com classes de animação (D4 C). — prova: `test/battle_routes_test.rb` (novo `test_battle_fragment_marks_juice_targets` — asserts nos atributos `data-*`/classes no fragmento `#battle-view`, sem rede).
- [ ] **C3 — CSS juice + a11y:** `public/style.css` contém keyframes de **HP dano/cura, projétil, flash de dano, KO fade/grayscale, número de dano flutuante, screenshake leve, toast do add, hover/active em botões, banner vitória/derrota e news**; projétil **só em `min-width: 900px`** (D5 A); `prefers-reduced-motion` **desliga todos** os novos keyframes (D2 A). — prova: `test/style_responsive_test.rb` (novos `test_juice_keyframes_present` + `test_juice_reduced_motion_disables` + `test_projectile_only_above_900px`).
- [ ] **C4 — Regressão (suíte+lint+docs):** suíte completa verde (baseline **985/3831** + novos) e lint 0 em todo green; sem gem/schema/rede; docs consistentes. — prova: garantias G1/G2/G3.
- [ ] **C5 — Visual manual no navegador:** HP anima dano/cura; projétil visível **≥900px** e ausente (só flash) **<900px**; flash de dano; KO fade/grayscale; número de dano flutuante; screenshake leve; toast do add (entrada/saída); hover/active em botões; banner vitória/derrota e news animados; `prefers-reduced-motion` ativo desliga tudo. — prova: **`manual`** (`./scripts/run` + navegador; viewport ≥900 e <900; devtools `prefers-reduced-motion: reduce`).

### Garantias — teste que prova (S1)

| Critério | Teste que prova | Manual |
| --- | --- | --- |
| G1 (suíte+lint) | `./scripts/test` suíte completa (baseline 985/3831 + novos) + `./scripts/lint` 0 por green | — |
| G2 (sem gem/schema/API stub) | `git diff -- Gemfile db/` vazio; testes sem rede (fragmento via `Rack::Test`; style lê arquivo) | — |
| G3 (S4/S5) | `./scripts/check_docs` + `./scripts/checar-sessao 0063` + `SESSIONS.md` atualizado no refinamento | — |

> **S1:** cada critério aponta o teste que o prova. C5 sem teste automatizado → `manual` explícito + evidência esperada. Baseline suíte 985/3831 da 0069.

## 5. Decisões de refinamento (fechadas com o usuário em 2026-09-02)

- **D1 — Escopo (C escolhido):** B — HP animado dano/cura + projéteis C2 + flash de dano + KO fade/grayscale + número de dano flutuante — **+ screenshake leve + juice fora da batalha** (toast do add + hover/active em botões, §juice `draft-ui-ux.md:138-145`).
- **C1 confirmado:** texto do log já atende C1 ("X usou Y em Z"); a 0063 trata **só C2 (projéteis) + painéis/HP + itens D1 C e D4 C**; nada mais de C1.
- **D2 — Técnica (A escolhida):** CSS-only; origem calculada no servidor (replay do log); reusa `--log-delay`/stagger da 0069; `prefers-reduced-motion` desliga tudo; zero JS/polling/SSE. Alternativas preteridas: B — JS/htmx por rodada (contradiz CSS-only do projeto); C — SSE/polling (complexidade sem ganho).
- **D3 — Intensidade (B escolhida):** média — flash de dano + número de dano flutuante + KO fade; ~0.3–0.5s. Alternativas preteridas: A — sutil (só fade, pouco feedback); C — alta (telas tremendo, cansa e conflita com a11y).
- **D4 — Juice de fim de batalha (C escolhido):** B (dano + KO + projétil + cura) **+ banner de vitória/derrota animado + news de evolução/XP animadas**.
- **D5 — Projétil por viewport (A escolhida):** projétil só **≥900px** (battle 3 colunas); **<900px** (empilhado) só flash no alvo. Motivo: painel oponente fica abaixo do jogador em viewport estreito — projétil ficaria ilegível.
- **D6 — Presenter (A escolhida):** backwards-compatible — `BattleLogPresenter#entries_all`/`entries` incluem `from_side`/`to_side` (0/1) por entrada mantendo `round/side/text`; helper puro de HP inicial por lutador (replay: HP final + dano − cura) em presenter dedicado (`BattleJuicePresenter`). TDD Ruby puro, sem tocar engine/backend.
- **D7 — Critérios (A escolhido, ampliado):** 5 critérios — 4 automatizados + 1 manual (C1 presenter → teste; C2 marcação → teste de rota; C3 CSS keyframes+reduced-motion → teste de style; C4 regressão suíte+lint; C5 visual manual). Com o escopo D1 C + D4 C, screenshake, toast do add, hover/active, banner vitória/derrota e news animadas são cobertos em **C3 (style)** + **C5 (manual)** — S1 sem célula vazia.
- **D8 — Plano TDD (A escolhido, ajustado ao escopo maior):** 4 passos — passo 1 presenter/log; passo 2 marcação `battle.erb`/`_fighter_panel.erb` + banner/news; passo 3 CSS keyframes (HP/projétil/flash/KO/screenshake/toast/hover/banner/news) + reduced-motion; passo 4 docs/manual. Cada passo red→green→commit `Passo N:` com suíte+lint verdes.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (suíte completa + lint 0) → commit. Parar ao fim da fase 2 e aguardar validação do usuário. P=pequena (2-3 passos) — sessão M (5-7 passos); esta é M (4 passos).

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo + `SESSIONS.md` (tabela + "Próxima sessão") | commit `Sessao 0063: refinamento concluido — juice (HP/projeteis/flash/KO/screenshake/toast/banner/news), criterios e plano TDD fechados` |
| 1 | **red→green — C1 presenter juice** — `lib/battle_log_presenter.rb` `entries`/`entries_all` com `from_side`/`to_side` (0/1) mantendo `round/side/text`; `lib/battle_juice_presenter.rb` novo (HP inicial por replay: `hp_final + dano − cura`; origem/alvo derivados); `test/battle_log_presenter_test.rb` novos `test_entries_include_from_to_side` + `test_entries_all_include_from_to_side` (+ existentes preservados); `test/battle_juice_presenter_test.rb` novo `test_initial_hp_derived_from_final_plus_damage_minus_heal` | `./scripts/test test/battle_log_presenter_test.rb test/battle_juice_presenter_test.rb` + suíte + lint 0; commit `Passo 1: presenter juice backwards-compat (from_side/to_side + BattleJuicePresenter HP inicial por replay)` |
| 2 | **red→green — C2 marcação juice** — `views/battle.erb`/`views/_fighter_panel.erb`: log com `data-round` + `data-from-side`/`data-to-side`, painéis com `data-hp-initial` + classes flash/KO/projétil, banner vitória/derrota e news com classes de animação; `test/battle_routes_test.rb` novo `test_battle_fragment_marks_juice_targets` (asserts nos `data-*`/classes do fragmento, sem rede) | `./scripts/test test/battle_routes_test.rb -n /juice/` + suíte + lint 0; commit `Passo 2: marcacao juice no fragmento (data-from/to-side, data-hp-initial, classes de banner/news)` |
| 3 | **red→green — C3 CSS juice + a11y** — `public/style.css` keyframes de HP dano/cura, projétil (só `min-width: 900px`), flash, KO fade/grayscale, número de dano flutuante, screenshake leve, toast do add, hover/active em botões, banner vitória/derrota, news — reusando `--log-delay`/stagger e `prefers-reduced-motion` desligando **todos**; marcação mínima do toast no `#add-status` (classe + sprite, se necessário); `test/style_responsive_test.rb` novos `test_juice_keyframes_present` + `test_juice_reduced_motion_disables` + `test_projectile_only_above_900px` | `./scripts/test test/style_responsive_test.rb -n /juice|projectile|reduced/` + suíte + lint 0; commit `Passo 3: keyframes de juice (HP/projetil/flash/KO/dano/screenshake/toast/hover/banner/news) + reduced-motion total` |
| 4 | **red→green — C4 regressão + docs** — suíte completa (baseline 985/3831 + novos) verde; lint 0; `REQUIREMENTS.md`/`SESSIONS.md` no escopo docs (status de validação só após usuário — S4) | `./scripts/test` completa + `./scripts/lint` 0 + `./scripts/check_docs`; commit `Passo 4: regressao suíte/lint preservada (juice nao toca motor nem economia) + docs` |
| — | **Fase 2 concluída (4 passos)** → **Revisor (2c)**: loop Implementador↔Revisor até veredito `Aprovado` (teto 3 rodadas, senão S3) → **PARAR** e aguardar a validação do usuário (fase 3, C5 `manual`). Não marcar Done, não preencher a seção 7, não commitar conclusão. | — |

## 7. Validação (executada pelo usuário — S2 — 2026-09-08)

> Validada pelo usuário em 2026-09-08 — S2 por critério ok, C5 `manual` ok (HP anima dano/cura, projétil ≥900 / flash <900, flash de dano, KO fade/grayscale, número de dano flutuante, screenshake leve, toast do add, hover/active em botões, banner vitória/derrota e news animadas, `prefers-reduced-motion` desliga tudo — via navegador), sem S3. Fase 3 concluída.

| Critério | Evidência automatizada | Evidência manual | Resultado (ok/nok) |
| --- | --- | --- | --- |
| C1 presenter juice | `test/battle_log_presenter_test.rb` `test_entries_include_from_to_side`/`test_entries_all_include_from_to_side` + `test/battle_juice_presenter_test.rb` `test_initial_hp_derived_from_final_plus_damage_minus_heal` | — | ok |
| C2 marcação juice | `test/battle_routes_test.rb` `test_battle_fragment_marks_juice_targets` | — | ok |
| C3 CSS juice + a11y | `test/style_responsive_test.rb` `test_juice_keyframes_present`/`test_juice_reduced_motion_disables`/`test_projectile_only_above_900px` | — | ok |
| C4 regressão | suíte completa + `./scripts/lint` 0 + `./scripts/check_docs` | — | ok |
| C5 visual manual | — | `./scripts/run` + navegador: HP anima; projétil ≥900 (flash <900); flash; KO fade/grayscale; número de dano; screenshake; toast do add; hover/active; banner + news; reduced-motion desliga tudo | ok |
| G1 suíte+lint | `./scripts/test` (baseline 985/3831 + novos, suíte final 995/3938) + `./scripts/lint` 0 | — | ok |
| G2 sem gem/schema/rede | `git diff -- Gemfile db/` vazio + testes sem rede | — | ok |
| G3 S4/S5 | `./scripts/check_docs` + `./scripts/checar-sessao 0063` | — | ok |

> **S3:** ajuste identificado aqui = reabrir o critério, registrar a alteração com data e obter nova aprovação do usuário.

## 8. Observações

- **Fase 2 (TDD) executada em 2026-09-02/08:** commits `be8b08e` (Passo 1 — presenter juice), `6aa4f6e` (Passo 2 — marcação no fragmento), `62d9c7c` (Passo 3 — CSS juice + reduced-motion), `938d145` (Passo 4 — regressão/docs) e `2ccc277` (Passo 5 — reduced-motion desliga todos os keyframes); suíte **995/3938** lint 0; `./scripts/check_docs` e `./scripts/checar-sessao 0063` ok. Revisor **Aprovado** (S7, 1ª rodada — achados baixo não-bloqueantes anotados em `gotchas/`).
- **Validação (fase 3) em 2026-09-08:** usuário validou — S2 por critério ok, C5 `manual` ok via navegador; sem S3. **Fase 3 concluída.**
- **Fila após 0063:** **Onda 3 Estabilidade** (race add, escritas atômicas, CSRF, respiro — numeração desliza) — a critério do usuário.
- **Reuso da 0069:** o `--log-delay`/stagger (`views/battle.erb:86`, `public/style.css:285-305`) é a base do escalonamento do juice; `prefers-reduced-motion` precisa **estender a lista** (hoje só cobre `.battle-log__entry` — C3).
- **HP inicial sem persistência extra:** derivar por replay (`hp_final + dano − cura`) evita migração/estado novo; `BattleJuicePresenter` puro e testável (D6 A).
- **Gotchas da 0069 aplicáveis:** `./scripts/test -n` não aceita `|` no regex (usar token único); `./scripts/test` com pipe aborta (redirecionar para arquivo); entradas de log de item têm `attacker_index` (fakes precisam incluir).
- **Views `not_tracked` no grafo** — conferir fonte de `views/*.erb` via read/grep (feito no refinamento).
- **Regra de parada:** ao concluir a fase 2 (TDD) com veredito do Revisor `Aprovado`, **PARAR** e aguardar a validação do usuário (fase 3); não marcar Done, não atualizar status de validação em `REQUIREMENTS.md`/`SESSIONS.md`, não commitar a conclusão (AGENTS.md).

## 9. Gotchas / Lições (memória — S6)

- **`BattleLogPresenter#format_entry` devolve só `round/side/text`** — `from_side`/`to_side` (0/1) devem ser derivados do `entry` bruto (`attacker`/`target` indexes) e **adicionados** sem quebrar `DEFAULT_LIMIT = 3` (`test_default_limit_is_three`/`test_returns_only_last_three_rounds` existem; histórico/ranking dependem do contrato atual).
- **HP inicial por replay** (`hp_final + Σdano − Σcura`) — sem persistir estado extra; `BattleJuicePresenter` precisa de entradas com `damage`/`healed`/`ko` (formato atual do `format_attack`/`format_item`).
- **`prefers-reduced-motion` cobre todos os keyframes novos** — hoje o media query só lista `.battle-log__entry`; esquecer um keyframe (ex.: toast, screenshake) viola C3.
- **Projétil é responsivo** — em viewport <900px (battle empilhado) o alvo está fora da linha visual; gate `min-width: 900px` + flash no alvo (D5 A) evita animação sem sentido.
- **Toast do add é CSS no `#add-status`** (`views/index.erb:11`, `hx-target="#add-status"` em 3 formulários) — o notice atual é texto; virar toast exige classe + sprite reutilizando os kinds de notice existentes (`draft-ui-ux.md:138-141`), sem mexer na rota `add_team_member` (`server.rb:494`).

### Da implementação (fase 2 — 2026-09-02)

- **Lib nova não autoload — require explícito no `server.rb`:** `BattleJuicePresenter` não é autocarregado (o app usa `require_relative` por arquivo); sem `require_relative "lib/battle_juice_presenter"` o fragmento de batalha quebra com 500 (NameError). Toda lib nova precisa do require no `server.rb`.
- **Somas do juice por nome, não por índice:** o log bruto não registra índice do alvo — `BattleJuicePresenter` casa por `target_name`/`attacker_name` (nomes únicos por time na prática; o time do jogador não duplica). `attacker_index` existe só em entradas de item (gotcha 0069).
- **Toast preserva `notice--<kind>`:** testes assertam `notice--success`/`notice--error`/`notice--info` na resposta do add — o `team_add_result.erb` virou `.add-toast` mantendo `notice notice--<kind>` (backwards-compat com os kinds).
- **Número de dano flutuante = total sofrido** (via `data-damage`): CSS-only não anima um número por golpe com valores distintos; aproximação por total aceita — C5 (manual) valida o visual.
- **HP animado via custom property herdada:** `--hp-initial-percent` definida no `.hp-bar` (style attr) e lida no `.bar-fill` filho — custom properties herdam, então `var()` funciona; keyframe só com `from` anima até o `width` inline.
- **Projétil direcional via `--fly` + `data-side`:** `transform: translateX(calc(var(--fly, 1) * (100% + 18em)))`; sem `data-side="0|1"` nas `.battle-column` o projétil voa na direção errada (lado 1 precisa `--fly: -1`).