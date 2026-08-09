# Sessão 0014 — UI: layout e estilos externos (A2)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluída — decisões fechadas com o usuário em 2026-08-09 |
| Implementação | Concluída — passos 0–4 TDD, suíte 139 runs/535 asserts e lint 0 verdes (aguardando validação) |
| Validação | (a preencher pelo usuário) |

---

## 1. Objetivo

Extrair **layout/navbar/estilos compartilhados** (A2 do draft, roadmap item 14): criar
`views/layout.erb` único (html + head + nav) usado por `GET /`, transformar o
`index.erb` em **parcial** (sem `<html>` próprio) e entregar **CSS externo**
estilizando as classes usadas pelos fragmentos — com **sakura (CDN) como base** +
`public/style.css` sobreposto. Navegação **consistente** na página única
(Lista / Time / Batalha), 100% htmx/âncoras (RNF-01), e **0 regressão** nas rotas e
fragmentos atuais — o contrato htmx (alvos, swaps, forms) permanece intacto.

## 2. Contexto (estado atual)

- `index.erb` é o **único** HTML completo (htmx + sakura CDN no `<head>`); as demais
  views são fragmentos htmx renderizados diretamente pelas rotas (sem `<html>` próprio).
- `public/style.css` existe (classes antigas `.main`/`.list`/`.ryu`/`.validation-error`)
  mas **não é referenciado** — órfão, provavelmente sobra de um protótipo.
- Classes usadas pelos fragmentos hoje: `.notice`, `.slot`, `.btn`, `.type`, `.stats`,
  `.evolutions`, `.pagination`, `.battle-pane`, `.fighter`, `.battle-log`, `.winner`,
  `.round`.
- Ao criar `views/layout.erb`, o Sinatra passa a envolvê-lo em **todas** as renderizações
  `erb` por padrão → os fragmentos precisam de `layout: false` explícito (ex.:
  `/pokemon/close` é vazio e o teste exige resposta vazia).
- `index.erb` embute `erb :pokemon_list` (linha 22) — a chamada aninhada também precisa
  de `layout: false` para não gerar `<html>` aninhado.
- Garantia de 0 regressão: suíte existente (135 runs/481 asserts, sem rede, com
  `PokeApiStub`) e lint RuboCop — padrão das sessões anteriores.

## 3. Critérios de aceite

### Layout único e navegação (UI)

- [ ] `views/layout.erb`: `<html>` único (charset, título, script htmx 2.0.3, sakura CDN
      + link `/style.css`) + `<nav>` com título da app e links **Lista / Time / Batalha**
      + `yield` para o conteúdo da página.
- [ ] `GET /` responde o layout único; `index.erb` vira **parcial** (sem `<html>/<head>`);
      conteúdo preservado (filtro, `#pokemon-list`, `#pokemon`, `#team`, `#battle`) e a
      resposta contém **exatamente um** `<html>`.
- [ ] Navegação consistente na página única: Lista → `#pokemon-list`; Time → `#team`;
      Batalha → `hx-get="/battle"` no alvo `#battle` (mantém o comportamento atual),
      100% htmx/âncoras, sem JS custom (RNF-01).
- [ ] Ao sair da aba Batalha (Lista/Time), `#battle` é limpo (`GET /battle/close`,
      fragmento vazio) — a mensagem "Forme seu time para batalhar." não permanece
      na tela ao trocar de aba.

### Fragmentos htmx continuam parciais

- [ ] Rotas de fragmento com `layout: false`: `/pokemons`, `/pokemon`, `/pokemon/:poke_id`,
      `/pokemon/close`, `GET /team`, `POST /team`, `DELETE /team`, `POST /team/:id/move`,
      `GET /battle`, `POST /battle/play` — resposta **sem** `<html>/<head>` e com o mesmo
      contrato htmx (alvo, swap, forms) de antes.

### Estilos externos

- [ ] `public/style.css` (sobre sakura) estiliza as classes atuais dos fragmentos
      (listagem, detalhe, team, batalha); `GET /style.css` responde 200 via pasta pública.

### Garantias (RNF)

- [ ] Testes **sem rede**; suíte completa verde (135 runs/481 asserts) e lint 0;
      commit após cada green.
- [ ] 0 regressão nas rotas/fragmentos atuais (RF-01..RF-13 seguem verdes).
- [ ] `REQUIREMENTS.md` (roadmap item 14 / A2), `SESSIONS.md` (0014) e
      `draft-auto-battler.md` (A2) atualizados no mesmo escopo.

## 4. Decisões de refinamento

- **Layout único via `views/layout.erb`** (padrão Sinatra): `GET /` usa o layout;
  fragmentos com `layout: false` explícito para manter o contrato htmx (resposta
  parcial). `index.erb` deixa de carregar `<html>/<head>` (o layout assume o shell).
- **CSS externo: sakura (CDN) como base + `public/style.css` sobreposto** (decisão do
  usuário em 2026-08-09). Mantém a base visual sakura e adiciona estilos para as classes
  atuais dos fragmentos. O `style.css` atual é órfão → substituído (classes antigas
  `.main`/`.ryu` descartadas, pois não são usadas pelos views).
- **Navegação em header na página única** (decisão do usuário): `<nav>` com título da app
  + links Lista/Time/Batalha; **sem** novas rotas de página (nenhuma mudança de contrato).
  Lista e Time já existem no DOM após `GET /` (âncoras); Batalha mantém
  `hx-get="/battle"` no alvo `#battle` e vira o link do nav.
- Fora do escopo: itens D1–D3 (golpes, XP/evolução, histórico/rank), multipage real,
  tema 100% custom substituindo a sakura, SPA.

## 5. Plano TDD (passos)

| Passo | Teste (red) | Implementação (green) |
| --- | --- | --- |
| 0 | `GET /` contém **exatamente 1** `<html>` + `<title>` e link `/style.css`; fragmentos (`/pokemons`, `/team`, `/pokemon/close`) **não** contêm `<html>/<head>` e mantêm o conteúdo/formas | criar `views/layout.erb`; `index.erb` vira parcial; `layout: false` nos fragmentos e na chamada aninhada `erb :pokemon_list` |
| 1 | `GET /` contém `<nav>` com título e links Lista/Time/Batalha; link Batalha preserva `hx-get="/battle"` + `hx-target="#battle"` | header/nav no layout |
| 2 | `GET /style.css` responde 200 e contém regra para classe usada (ex.: `.battle-pane`); `battle.erb` mantém as classes | reescrever `public/style.css` estilizando as classes dos fragmentos (sobre sakura) |
| 3 | suíte completa `./scripts/test` verde + `./scripts/lint` 0 | checagem |
| 4 | docs: `REQUIREMENTS.md` (roadmap item 14 / A2), `SESSIONS.md` (0014), `draft-auto-battler.md` (A2) | documento |

## 6. Observações e próximo passo

- Ao criar `layout.erb`, **todas** as rotas que respondem fragmento precisam de
  `layout: false` — senão o swap htmx injeta um `<html>` completo dentro do alvo; o
  `/pokemon/close` (vazio) quebraria o teste de body vazio.
- A chamada `erb :pokemon_list` aninhada em `index.erb` também precisa `layout: false`
  (senão gera `<html>` aninhado dentro do layout).
- Sinatra serve estáticos de `public/` na raiz — `/style.css` não exige rota.
- Após a 0014 validada: D1–D3 (golpes, XP/evolução, histórico/rank) seguem no
  `draft-auto-battler.md` como candidatos à próxima sessão.

## 7. Validação (a preencher pelo usuário)

- (aguardando validação do usuário — suíte completa + critérios da seção 3)