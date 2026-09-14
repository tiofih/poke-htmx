# Review retroativo — 0086 Passos 21–28 (`a93bdb3..9254ba4`) — 2026-09-14

> **Nota de persistência:** este arquivo foi **re-persistido a partir do relatório do revisor**. A escrita original (mesmo nome/timestamp) foi perdida: o arquivo não existia no working tree, em `git ls-files` nem em `git log --all`. Nesta re-persistência, **cada achado foi re-verificado contra o HEAD `230368c`** (lookups direcionados no CSS/ERB/testes/`server.rb`); desvios do relatório original estão marcados com **(corrigido)** no corpo do achado.

**Escopo:** range `a93bdb3..9254ba4`, 7 commits (`git log --oneline a93bdb3..9254ba4`):

```
9254ba4 Passo 29: cor do tipo chega ao projetil via carrier #jx-gates
5cf6c4a Passos 26-27: cor do efeito por tipo de golpe (18 tipos), contrato data-strategy/--fx-* e sync com o pacing
03abff4 Passos 24-25: projetil direcional atacante→alvo e shake no card alvo (arena fora)
5259ca8 Passo 23: move_type exposto no presenter e nos dois renders (data-move-type)
0485249 Passo 22: log__entry via swap principal — OOB do htmx descarta o <li> e achata o log
f77493d Sessao 0086: criterios reabertos (S3) — efeito atacante→alvo, shake no alvo, cor por tipo de golpe
8542a33 Passo 21: OOB do strike direto no <li> — template vazio nao insere no #battle-log
```

Foco: **Passos 21–28** (`8542a33..5cf6c4a`); `9254ba4` (Passo 29) é o limite do range e já foi revisado no round 12 (`reviews/review-2026-09-14T10-24-59.md`). Não há commit com a mensagem "Passo 28" no range — o Passo 28 (regressão) não gerou commit próprio, só a linha no §6 do doc de sessão. HEAD de verificação: `230368c`, working tree limpo. Nenhum arquivo alterado por este review.

**Evidência (verificada no HEAD, não herdada):**
- `git log --oneline a93bdb3..9254ba4` → 7 commits (acima).
- `public/style.css:925-1001` (regra de shake antiga + `--fx-shake`), `:1587`/`:1598` (travel), `:1698` (`@keyframes juice-shake`), `:1957-1960` (declaração `data-strategy`), `:1986-2003` (cor por tipo na entrada), `:2452-2471` (regra de shake efetiva + projétil).
- `test/style_responsive_test.rb:293-305` (C15), `:384-393` (C13), `:371-380` (C12), `:427-428`.
- `views/battle.erb:44` (arena toggles), `:201-202` (`--log-delay` duplicado), `views/_strike_log_entry.erb:4,10`; `views/_jx_gates.erb:1`.
- `server.rb:1138-1142` (`strike_side_delay`), `:1149` (chamada).

## Achados (worst-first)

| Severidade | file:line | problema | recomendação |
|---|---|---|---|
| **Major** | `public/style.css:2452-2456` + `test/style_responsive_test.rb:384-393` | **C13 — shake dessincronizado do impacto, sem prova de timing.** O card atingido recebe `juice-flash 0.4s` + `juice-shake 0.3s` com `animation-delay: var(--fx-shake, 0s)`; `--fx-shake` é **constante `0s`** (`public/style.css:933` e `:1959`), nunca sobrescrita em view/server. O projétil só chega ao alvo em **0,15s (delay) + 0,4s (travel) = 0,55s** (`public/style.css:2459-2461`, `animation: juice-projectile 0.4s ease-out 0.15s both`). Logo o shake (e o flash) dispara em `t=0`, **~0,55s antes** do instante do impacto. O teste `test_shake_synced_to_impact_instant` só assere a **presença** do token `animation-delay: var(--fx-shake` (`:387`) e a ausência de `var(--step-delay` — não prova valor nem sincronia alguma. | Fazer o delay ser derivado do pacing/travel (ex.: `--fx-shake: 0.55s` no instante do impacto, ou alimentar o token com o mesmo delay do projétil) e adicionar asserção que **falhe se o valor/timing regredir** (não basta o token existir). |
| **Minor** | `public/style.css:1957-1960` | **(corrigido)** O relatório dizia "C12 `--fx-*` inerte (declarada, nunca consumida)". **Isso não se sustenta como afirmado:** `--fx-color` é consumida (`.shot` `:1011`, `.fx` `:2014`), `--fx-travel` é consumido (`:1587`/`:1598`) e `--fx-shake` é lido em `:1000`/`:2456`. O defeito real: as declarações do gancho C12 `.log__entry[data-strategy="strike"] { --fx-travel: 40vw; --fx-shake: 0s; }` (`:1957-1960`) **moram no `.log__entry`**, que **não é ancestral** do `.shot` nem do `.fighter.is-hit` — esses tokens ali são inertes; quem de fato vale são as declarações do `.arena` (`:932-933`). O gancho `data-strategy` existe na view (`views/battle.erb:197`, `views/_strike_log_entry.erb:6`) mas não troca config alguma. | Mover as declarações do `data-strategy` para um ancestral comum (ou removê-las como redundantes) para o contrato C12 ser real; manter `--fx-shake` só quando passar a carregar valor real (ver Major). |
| **Minor** | `public/style.css:993-1001` (regra em `:996`) | **Regra legada que nunca casa.** `.arena[data-jx-shake="on"] .fighter.is-hit` exige `data-jx-shake="on"` **no próprio `.arena`**. O atributo só existe em `#jx-gates` (`views/_jx_gates.erb:1`, flipado pelo OOB) e no `.arena` está estaticamente `"off"` (`views/battle.erb:44`), sem nenhum JS/servidor que o acenda. A regra ativa é a `:has(> #jx-gates[…])` (`:2452`). A regra de `:996` é **código morto** (mesmo bloco duplicado). | Remover o bloco legado `:993-1001` (o `.arena` nunca recebe `data-jx-shake="on"`); a fonte única passa a ser `:2452`. |
| **Minor** | `test/style_responsive_test.rb:293-305` | **C15 não prova contenção no `@media`.** O teste pega `content.rindex(/@media (min-width: 900px)/)` e apenas assere `use_index > media_index` para `animation-name: juice-shot-ltr/rtl` — ou seja, prova ordem textual **depois da abertura** do último `@media`, não que a regra esteja **dentro** do bloco. No HEAD ela está dentro (`:2458-2470`), mas qualquer regra posta depois do bloco (fora do media) também passaria. | Delimitar o bloco (`content[/@media\s*\(min-width:\s*900px\)\s*\{(.*?)\n\}/m, 1]`) e asserir os `animation-name` / o `display: block` **dentro** dele. |
| **Minor** | `sessions/0086-battle-log-juice.md` §6 (`:97-117`), Status `:9` | **Passos 21–28 não rastreáveis no §6.** O Status afirma "Passos 1–32 verdes", mas a tabela do §6 só tem linhas para **0–4 e 23–32**: os Passos **5–22** (incl. 21 e 22, que são o foco deste review) não têm linha. A lacuna já está admitida no §8 e aberta no `TODO.md` (T3). | Enumerar 5–22 (ou uma linha remetendo a S3/commits) para o "1–32" ser verificável pelo próprio doc. |
| **Info** | `test/style_responsive_test.rb:335` | **C11 regex sem ancorage — já resolvido.** O relatório carregava o C11-regex não ancorado como info; no HEAD o teste usa `^[ \t]*\[data-move-type="…"\]` (`:335`), exatamente o fix do Passo 32. **Não reproduz** como achado aberto. | Nenhuma — mantido como histórico. |
| **Info** | `views/battle.erb:201-202`, `views/_strike_log_entry.erb:4,10` + `server.rb:1138-1142` | **Dívidas cosméticas/inertes.** (a) `--log-delay` é declarado duas vezes: no `<li class="log__entry">` e no `<span class="fx">` filho (`battle.erb:201`/`:202`; `_strike_log_entry.erb:4`/`:10`) — o do span é redundante (herda). (b) `strike_side_delay` (`server.rb:1138-1142`) sempre devolve `{0=>0.0, 1=>0.0}`: `{ 0 => 0.0, 1 => 0.0 }.merge(from => 0.0, to => 0.0)` — **no-op** (o valor já era `0.0` para os dois lados), mantido só para preservar a assinatura do caller `:1149`. | Remover o `style="--log-delay"` do span `.fx` (herança cobre); simplificar/remover `strike_side_delay` ou documentar que é provisoriamente fixo em `0.0`. |

## Checado e limpo (sem achado)

- C10: shake continua **só no card do alvo** (`:2452`), nunca na arena inteira — a asserção de refutação (`:316`, `:391`) é válida.
- C14: o bloco `@media (prefers-reduced-motion: reduce)` segue **ÚLTIMO** no arquivo (`:2472`) e cobre `.fighter.is-hit` / `.log__entry .fx`.
- C9/D2: direção por `data-side` dentro do `@media (min-width: 900px)` (`:2465-2469`) — mecanismo presente.
- `--fx-color` por tipo na entrada (`:1986-2003`) sem terceira regra sombreando: nada depois de `:2003` reescreve o token; consumos em `:1011` e `:2014`.
- G1: nenhum dos 7 commits toca `lib/battle_engine.rb`, `lib/battle_service.rb` ou `db/` (verificado por `git show --stat` dos commits do range).
- `--log-delay` em CSS (`:953`, `:2016-2032`) é consumo coerente com o C4/C5; só a duplicação na view é cosmética (Info).

## VEREDITO: **Aprovado** — 0 blocker / 1 major / 4 minor / 2 info

Nenhum blocker: nada quebra comportamento, XP, engine ou gate — os 7 commits são CSS/ERB/doc/teste. O major de **C13** é de **timing e de força de evidência**: o `ok` de C12/C13/C15 repousa em prova de **presença** (token declarado, regra presente, ordem textual), não em prova de sincronia/containment. Por isso **a validação do usuário de 2026-09-14 NÃO é reaberta** — ela foi dada em bloco, nenhum critério ficou `nok`, e os critérios permanecem `ok`; o ajuste de timing do C13 fica remetido como trabalho futuro ao `TODO.md` **T5**, as dívidas menores ao **T6** e a lacuna do §6 ao **T3**. Este arquivo apenas fecha a lacuna de **registro de processo** dos Passos 21–28 (T2): a revisão retroativa existe e está persistida.
