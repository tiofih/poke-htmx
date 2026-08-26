# Draft — Changelog de playtest (experiência e melhorias)

> **Fora do fluxo (RNF-04).** Registro cumulativo de sessões de playtest: cada
> sessão anota o que foi testado, a experiência real jogando e as melhorias que
> saíram dela. Não gera critérios de aceite nem plano TDD na hora; revisar ao
> fechar as fases correntes. Jogo é **auto-battler** (decisão do usuário):
> a estratégia vive no pré-combate (moveset, itens, seguráveis), a batalha
> resolve sozinha.

---

## Sessão 1 — 2026-08-25 (playtest via browser-harness)

> Execução: agente navegou o app real em Chrome (CDP) e jogou ~15+ batalhas.
> Time subiu até nível 5; comprou itens no Mart, curou no Center, montou moveset
> (draft + salvar) e equipou itens/seguráveis.

### 1.1 O que foi testado

- Conectividade: `GET /`, `/battle`, `/history` respondendo; `/team` é 404 em
  navegação direta (virou fragmento htmx interno — esperado pós-0042).
- Lista: filtro por nome (htmx), paginação "Próxima", modal de detalhe.
- Loop do time: adicionar Pokémon, gerenciar golpes (draft/marcar/salvar),
  equipar item, equipar segurável, mover slots (▲/▼), remover.
- Mart: compra de poções/seguráveis debita saldo e adiciona ao inventário.
- Center: cura cobra custo proporcional ao HP faltante e debita saldo.
- Batalha: rodadas automáticas, uso automático de item equipado, resultado
  com XP/dinheiro, "Novo confronto".

### 1.2 Experiência (o que o jogador sente)

- **O loop base funciona e é legível**: batalhar → XP + dinheiro → curar/comprar
  → batalhar de novo. Feedback imediato no fim ("ganhou 50 XP e 100 de dinheiro").
- **A batalha é 100% automática** (auto-battler confirmado): o jogador só clica
  "Jogar". A estratégia real está em montar o moveset e equipar itens/seguráveis
  antes. Isso **não é comunicado ao jogador** — a UI parece que vai pedir uma
  decisão a cada turno, e nunca pede.
- **Dificuldade não escala**: oponentes sempre nível 1; só o pool de espécies
  varia (bunnelby → delibird → meditite…). Com time nível 5 + cura, o jogo
  vira rotina; não há incentivo a continuar além do lvl ~4–5.
- **Perder ainda recompensa** (20 XP / 40 dinheiro) — bom para não frustrar,
  mas achatado: vitória e derrota são sempre a mesma recompensa fixa, sem bônus
  por rodadas/KOs.
- **Progressão de golpes por nível é o coração do jogo** e funciona
  (vine-whip N3, ember N4, smokescreen N4…). É a única decisão com peso real.

### 1.3 Melhorias anotadas (playtest)

| # | Achado | Impacto | Área |
| --- | --- | --- | --- |
| P1 | **CRÍTICO — vazamento de conexões PG**: cliques rápidos em sequência derrubam o app com `PG::ConnectionBad — too many clients already` (ConnectionRegistry cacheia por `[owner, thread_id]` sem limite/reciclagem) | Impede uso real contínuo | Infra/back |
| P2 | Batalha automática não é comunicada — sem onboarding/ajuda do modelo auto-battler | Expectativa errada do jogador | UX/conteúdo |
| P3 | Oponentes não escalam (sempre lvl 1); falta curva por nível/time | Gameplay estagna | Game design |
| P4 | Recompensa fixa (100/50); sem bônus por performance | Auto-battler sem camada de skill | Game design |
| P5 | Painel do time tem dois modos (home: Center/Mart+cards / "Gerenciar": edição) e **some** saldo/Mart/Center no modo edição; sem caminho de volta claro | Navegação confusa | UX |
| P6 | Status de item/segurável invisível no gerenciar (select mostra "Nenhum" mesmo equipado); info só no battle screen ("carrega:/segura:") | Falta de visibilidade do estado | UX |
| P7 | Sem estado vazio: batalha inicia com time HP 0 (Pokémon lutam "mortos"); sem aviso "cure seu time" | Confuso | UX |
| P8 | Ranking global com seeds competindo no topo ("seed-shop 21 vitórias") | Desmotiva (bot invencível) | Game design |

### 1.4 Acelerar o ciclo de playtest (propostas)

Ideias para reduzir o custo de cada sessão de playtest futura:

- **TP-1 — Playbook reutilizável**: script `browser-harness` com helpers prontos
  (add_team, heal, buy, equip, fight_x_rounds, assert_state) salvos em
  `agent_helpers.py` do harness; cada playtest vira um roteiro curto que
  reaproveita os mesmos passos.
- **TP-2 — Estado determinístico por sessão**: seed/endpoint dev para resetar o
  estado do jogador (saldo, time, inventário) e sortear oponentes fixos — playtest
  sempre começa igual e é reprodutível.
- **TP-3 — Log estruturado da batalha**: além do log textual, expor JSON por
  rodada (ações, dano, PP, itens usados) para análise automatizada (ex.: balanço
  de dificuldade) sem ler tela.
- **TP-4 — Sandbox de balanceamento**: parametrizar XP/dinheiro/dificuldade por
  env (ex.: `PLAYTEST_XP_MULT`, `OPPONENT_LEVEL_FLOOR`) para testar curvas sem
  tocar código.
- **TP-5 — Checagem de robustez antes do playtest**: rodar o jogo com rajadas de
  cliques rápidos (rate de htmx) para pegar vazamentos/500 cedo — evitaria o
  crash da sessão 1 (P1).

---

## 1.5 Drafts para virarem sessão (esboço de critérios + plano TDD)

> Cada item abaixo segue o formato dos drafts existentes (`draft-auto-battler.md`):
> decisões, critérios de aceite esboçados e plano TDD. **Fora do fluxo** — viram
> sessão quando o usuário decidir encaixá-las (regra RNF-04). Prioridade sugerida
> na tabela §1.3 (P1 é bloqueante).

### P1. Pool de conexões PostgreSQL com limite/reciclagem (bloqueante)

- **Status:** pendente (achado da sessão 1). **Objetivo:** o app não pode cair com
  `PG::ConnectionBad — too many clients already` sob uso real (rajadas de htmx).
- **Decisões (esboço):** `ConnectionRegistry` hoje cacheia `@entries[[owner, thread_id]]`
  e abre `PG.connect` sem teto nem reciclagem. Alternativas: (a) pool fixo por
  processo com `connection_pool` + `statement_timeout`; (b) reutilizar a mesma
  conexão por thread com `CHECK` de `PG::ConnectionBad` → reconnect com backoff;
  (c) `max_connections` do Postgres alinhado ao pool. Validar com teste de rajada
  (N requests concorrentes) no ambiente docker.
- **Critérios (esboço):**
  - `[ ]` Rajada de ~50 requests htmx em sequência/concorrentes **não** derruba o
    app (sem `too many clients already`).
  - `[ ]` Pool tem teto documentado; conexões excedentes aguardam ou falham com 5xx
    limpo (não crash do processo).
  - `[ ]` Conexões ociosas são recicladas/liberadas; contador de conexões no PG
    estabiliza após o pico.
  - `[ ]` Sem rede nos testes (substituir `PG.connect` por pool injetável/mock).
- **Plano TDD [esboço]:** **[0]** teste de rajada reproduzindo o crash (red);
  **[1]** pool com teto + reciclagem (green); **[2]** robustez/falha limpa;
  **[3]** regressão da suíte + lint.
- **Observação:** este é o único com risco de infra; pode exigir mexer em
  `docker-compose.yml` (max_connections) e no Rakefile de setup.

### P2. Comunicar o modelo auto-battler (onboarding/ajuda)

- **Objetivo:** o jogador entende que a estratégia é pré-combate (moveset, itens,
  seguráveis) e a batalha resolve sozinha.
- **Decisões (esboço):** copy curta na home/primeiro acesso ("Este é um auto-battler:
  monte seu time e seus golpes — a batalha acontece sozinha"); tooltip/hint na tela
  de batalha ("O time luta sozinho; o que decide é o que você equipou"); talvez um
  primeiro confronto tutorial com oponente nível 1 fraco. Sem mudança de mecânica.
- **Critérios (esboço):** `[ ]` primeira visita exibe a explicação; `[ ]` hint na
  batalha visível sem poluir; `[ ]` acessível (aria-label/texto alternativo);
  `[ ]` não quebra rotas/fragmentos atuais.
- **Plano TDD [esboço]:** **[0]** copy/estrutura (partial); **[1]** gating primeira
  visita; **[2]** teste de regressão.

### P3. Curva de oponentes por nível do time

- **Objetivo:** oponentes acompanham o jogador (auto-battler precisa de desafio
  crescente). Hoje: sempre nível 1, só varia o pool.
- **Decisões (esboço):** nível do time = média (ou mediana) dos níveis dos membros
  (ou `max`); oponente sorteado com nível `floor(clamp(time_nivel - delta, 1, cap))`;
  `delta` controla o desafio (ex.: 0 = espelho, -1 = mais fraco, +1 = mais forte);
  stats/HP do oponente escalam por nível (fórmula igual à do jogador). Cuidar para
  não virar snowball (cap por progresso da jornada — ver JN gate).
- **Critérios (esboço):**
  - `[ ]` Oponente com time nível 5 tem nível ≥ 2 (ex.: espelho-1), não mais 1.
  - `[ ]` Determinístico por seed (mesmo estado → mesmo oponente).
  - `[ ]` Não quebra o gate da jornada (time de 6 continua sendo pré-requisito).
  - `[ ]` Testes sem rede; regressão da suíte.
- **Plano TDD [esboço]:** **[0]** fórmula de nível do time; **[1]** sorteio com
  nível derivado; **[2]** integração rota/UI; **[3]** regressão + lint.

### P4. Recompensa variável por performance

- **Objetivo:** vitórias rápidas/limpas rendem mais (camada de skill no
  auto-battler). Hoje: fixo 100/50 (vitória/derrota) e 50/20 XP.
- **Decisões (esboço):** base + bônus: `dinheiro = base + bônus_rodadas +
  bônus_KO + bônus_time` (ex.: vencer em ≤N rodadas, sem KOs no time, time menor);
  derrota mantém consolação. Manter valores no domínio puro e parametrizáveis
  (cruza com TP-4). Evitar inflação — calibrar na mesma sessão.
- **Critérios (esboço):** `[ ]` fórmula pura testável (sem PG/rede); `[ ]` bônus
  zeram/positivos conforme regra; `[ ]` histórico mostra o total detalhado (ou
  preserva só o total); `[ ]` regressão das rotas de fim de batalha.
- **Plano TDD [esboço]:** **[0]** fórmula de recompensa; **[1]** integração no
  resultado da batalha; **[2]** UI/histórico; **[3]** calibração + regressão.

### P5. Painel do time em modo único (Center/Mart + edição inline)

- **Objetivo:** matar a troca de modos (home mostra Center/Mart+cards; "Gerenciar"
  substitui tudo e esconde saldo/Mart/Center; sem caminho de volta claro).
- **Decisões (esboço):** um único painel `#team-view` com Center/Mart sempre
  visíveis e edição inline por card (golpes/itens/segurável sem trocar de tela);
  ou manter dois modos mas com breadcrumb/tab visível e saldo persistente. Decisão
  de design a fechar na sessão. Cruzar com draft-ui-ux (JN-1/telas próprias).
- **Critérios (esboço):** `[ ]` saldo/Mart/Center visíveis em qualquer modo;
  `[ ]` edição de um membro não esconde os demais; `[ ]` caminho de retorno óbvio;
  `[ ]` sem JS customizado (só htmx); `[ ]` regressão da suíte.
- **Plano TDD [esboço]:** **[0]** unificar layout/fragmento; **[1]** saldo
  persistente; **[2]** edição inline; **[3]** regressão + lint.

### P6. Visibilidade do estado de item/segurável no gerenciar

- **Objetivo:** o select mostra "Nenhum" mesmo com item equipado; o estado real só
  aparece no battle screen ("carrega:/segura:").
- **Decisões (esboço):** no select, o rótulo reflete o equipado (ex.: "Pocao (1)"
  selecionado em vez de "Nenhum"); e/ou badge no card do membro mostrando
  item/segurável; consistente entre gerenciar e batalha. Só view/label, sem mecânica.
- **Critérios (esboço):** `[ ]` select mostra o item/segurável equipado como
  selecionado; `[ ]` badge/indicador no card; `[ ]` acessível; `[ ]` regressão.
- **Plano TDD [esboço]:** **[0]** label do select reflete estado; **[1]** badge;
  **[2]** regressão + lint.

### P7. Estado vazio / aviso de cura antes da batalha

- **Objetivo:** batalha não deve iniciar com time HP 0 (Pokémon "mortos" lutando);
  jogador deve ser avisado para curar.
- **Decisões (esboço):** `GET /battle` com time todo HP 0 → aviso no lugar do botão
  "Jogar" (ex.: "Seu time está desmaiado — cure no Poke Center") com link/até
  auto-cura; ou permitir iniciar mas sinalizar. Decidir na sessão.
- **Critérios (esboço):** `[ ]` time todo HP 0 não inicia batalha normal (aviso +
  CTA); `[ ]` com pelo menos 1 vivo, funciona como hoje; `[ ]` regressão.
- **Plano TDD [esboço]:** **[0]** condição de time morto na rota; **[1]** aviso/CTA;
  **[2]** regressão + lint.

### P8. Ranking global sem seeds no topo

- **Objetivo:** seeds ("seed-shop 21 vitórias") não devem competir com o jogador
  no ranking — desmotiva.
- **Decisões (esboço):** separar jogadores reais de seeds (flag `is_seed` na tabela
  de usuários/batalhas); ranking global só com jogadores reais; seeds viram dados
  de treino/histórico separado (ou somem). Decidir com o usuário.
- **Critérios (esboço):** `[ ]` ranking ignora seeds; `[ ]` seeds não poluem
  "Últimas batalhas"; `[ ]` migração idempotente; `[ ]` regressão.
- **Plano TDD [esboço]:** **[0]** flag/semente no modelo; **[1]** queries do ranking
  filtram; **[2]** migração + regressão + lint.

### TP-1. Playbook de playtest reutilizável

- **Objetivo:** cada sessão de playtest vira roteiro curto em vez de navegação ad hoc.
- **Decisões (esboço):** helpers prontos no `agent_helpers.py` do browser-harness
  (fora do repo do app, ou em `scripts/playtest/` no repo para versionar):
  `add_team(names)`, `heal()`, `buy(item, qty)`, `equip(slot, item)`, `equip_held`,
  `fight_x_rounds(n)`, `assert_state(...)`. Roteiro por sessão em markdown com
  passos → assertivas.
- **Critérios (esboço):** `[ ]` helpers cobertos por uso em ≥1 playtest;
  `[ ]` roteiro de exemplo (sessão 2) documentado; `[ ]` não depende de rede
  externa (PokéAPI não acessada — stubs existentes no app).
- **Plano TDD [esboço]:** não é TDD de app; é script. Validar por playtest real.

### TP-2. Estado determinístico por sessão (seed dev)

- **Objetivo:** playtest sempre começa igual e é reprodutível (saldo, time,
  inventário, oponentes fixos).
- **Decisões (esboço):** rota dev `POST /dev/seed` (ou `?playtest=1` em env de
  dev) que reseta o jogador corrente: saldo inicial, time vazio/pré-montado,
  inventário, nível; sorteio de oponentes com seed fixa (reusa B3/D1 determinismo).
  **Fora de prod** (gate por env `RACK_ENV=development` / `PLAYTEST=1`).
- **Critérios (esboço):** `[ ]` reset completo do estado do jogador; `[ ]` mesma
  seed → mesmos oponentes; `[ ]]` indisponível fora de dev; `[ ]` sem rede.
- **Plano TDD [esboço]:** **[0]** rota dev + repo de reset; **[1]** seed de
  oponentes; **[2]** gate env; **[3]** regressão.

### TP-3. Log estruturado da batalha (JSON)

- **Objetivo:** análise automatizada de balanço (dificuldade, uso de itens, PP,
  dano) sem ler tela.
- **Decisões (esboço):** junto ao log textual atual, expor por batalha um JSON
  (ou CSV) com as ações por rodada (autor, golpe, alvo, dano, PP antes/depois,
  item usado, HP restante). Rota dev (`GET /battle/:id/log.json`) ou campo no
  histórico. Reaproveita o motor determinístico (D1).
- **Critérios (esboço):** `[ ]` JSON com 1 registro por ação; `[ ]` idempotente/
  consistente com o log textual; `[ ]` rota dev (gate env); `[ ]` testes sem rede.
- **Plano TDD [esboço]:** **[0]** serializer das ações; **[1]** rota; **[2]** gate +
  regressão.

### TP-4. Balanceamento parametrizável por env

- **Objetivo:** testar curvas de XP/dinheiro/dificuldade sem tocar código.
- **Decisões (esboço):** ler de env (defaults = atuais): `XP_WIN`, `XP_LOSS`,
  `MONEY_WIN`, `MONEY_LOSS`, `OPPONENT_LEVEL_FLOOR` (cruza com P3), `OPPONENT_DELTA`.
  Valores em domínio puro com injeção de config; teste com envs variados.
- **Critérios (esboço):** `[ ]` defaults preservam comportamento atual;
  `[ ]` envs alteram recompensa/nível sem quebrar suíte (teste com override);
  `[ ]]` documentado no README/Rakefile.
- **Plano TDD [esboço]:** **[0]** config + injeção; **[1]** testes com override;
  **[2]** README.

### TP-5. Checagem de robustez pré-playtest (teste de rajada)

- **Objetivo:** pegar vazamentos/500 antes de cada playtest (teria evitado o P1).
- **Decisões (esboço):** script (no repo, `scripts/stress_smoke`) que dispara N
  requests htmx em rajada (páginas + ações POST) contra o app docker e falha se
  aparecer 5xx/`too many clients`; rodar antes de iniciar playtest. Reusa o padrão
  de conexão do P1 (pode virar teste de integração permanente).
- **Critérios (esboço):** `[ ]` detecta o crash do P1 (regressão real);
  `[ ]` roda rápido (< 30s); `[ ]` exit code claro (0 ok / 1 falhou).
- **Plano TDD [esboço]:** não é TDD de app; é script de operação. Validar rodando.

---

## Sessão 2 — 2026-08-25 (playtest via browser-harness)

> Execução: agente navegou o app real em Chrome (CDP) e jogou o **gameloop novo
> (0048)** de ponta a ponta: jornada inicial (montar time de 6) → Batalhar →
> batalha completa → fim com CTAs do circuito → curar no Center → comprar no Mart →
> nova batalha. Foco: **UX e game design** (o loop mudou com a 0048).

### 2.1 O que foi testado

- **Início de jornada**: adicionar 6 Pokémon pela lista de iniciais (gate abre).
- **Gameloop (0048)**: CTA **"Batalhar"** no painel do time (`/`); batalha; fim de
  batalha com **Poke Center / Poke Mart / Novo confronto**; curar (Center) e comprar
  (Mart) a partir da Lista.
- **Centro**: cura completa (HP por membro + custo antecipado + debita saldo).
- **Mart**: compra de poção (debita saldo, adiciona inventário).
- **Repetição de confronto**: "Novo confronto" e re-entrada em `/battle`.

### 2.2 Experiência (o que o jogador sente)

- **O circuito do gameloop funciona e fecha (0048 ok)**: Batalhar → batalha →
  fim com CTAs → curar/comprar → Batalhar de novo. A jornada inicial (montar 6) abre
  o gate e o loop flui.
- **O oponente é SEMPRE o mesmo** para o mesmo usuário: não importa se é "Novo
  confronto" ou re-entrar em `/battle` — vem **o mesmo time nível 1** (bunnelby,
  weedle, toxel, nidoran-m, tympole, goomy). O jogo perde variedade e escalonamento;
  vira rotina na 1ª batalha.
- **Oponentes têm 4 golpes, o jogador tem 2** (nível 1): o time do jogador começa com
  growl/tackle/scratch etc. enquanto o oponente vem com wild-charge/tera-blast/etc.
  Sensação de desvantagem no moveset sem explicação.
- **A batalha pede vários cliques "Jogar"** (uma por rodada até o fim) — com o loop
  fechado, o jogador sente atrito: esperaria "batalhar" resolver.
- **O ranking segue com o bot "seed-shop" no topo** (P8 sessão 1 não resolvido) —
  desmotiva olhar o histórico.

### 2.3 Melhorias anotadas (playtest 2)

| # | Achado | Impacto | Área |
| --- | --- | --- | --- |
| U1 | Notice "Time cheio (máx. 6)." **duplicado** na Lista (2× no DOM do `#team-view`/`#add-status`) | Poluição visual / redundância | UX |
| U2 | **Mart ambíguo**: catálogo mostra "Pocao — 20 ×N" (qtd comprável) e logo abaixo inventário com "potion — 0×"; dois blocos de itens confusos | Entendimento errado do estoque | UX |
| U3 | CTAs do fim de batalha (Center/Mart/Novo confronto) **próximos em linha** — fácil clicar errado (aconteceu no playtest: clique em Center virou novo confronto) | Erro de navegação | UX |
| U4 | **Sem destaque do time danificado** antes da batalha: HP carrega reduzido (bulbasaur 0/45) e a batalha inicia com Pokémon "mortos" sem aviso "cure seu time" (reforça P7 sessão 1) | Confuso | UX |
| G1 | **Oponente SEMPRE o mesmo por usuário** (seed `Random.new(user_id.sum)`): repete em "Novo confronto" E em nova entrada em `/battle` — sem variedade nem escala | Gameplay estagna | Game design |
| G2 | Oponentes nível 1 fixos com **4 golpes vs 2 do jogador** — sem curva de dificuldade (reforça P3 sessão 1) | Desvantagem injusta | Game design |
| G3 | **Ranking com bot "seed-shop" no topo** (P8 sessão 1 não resolvido) | Desmotiva | Game design |
| G4 | **Batalha exige N cliques "Jogar"** (uma por rodada) — atrito no loop fechado (reforça a ideia B5 de resolver a batalha inteira num clique) | Atrito de interação | Game design |

### 2.4 Observações do bug do oponente (G1)

- Confirmado e **mais grave que o anotado**: não é só "Novo confronto" — **toda batalha
  do mesmo usuário repete o mesmo time oponente nível 1**, pois `build_opponent` usa
  `Random.new(user_id.sum)` (seed determinístico por usuário). O histórico mostrou
  repetições idênticas ("Vitória contra delibird, skiploom, meditite, bunnelby, abra,
  solosis" várias vezes). Ver bug atualizado em `REQUIREMENTS.md` (limitações) e
  `draft-auto-battler.md` (BUG-1).

---

## Sessão 3 — 2026-08-25 (QA — caça e catálogo de bugs)

> Execução: agente navegou o app real em Chrome (CDP) e percorreu **sistematicamente**
> o fluxo procurando bugs: montagem do time, gerenciar (golpes/itens/seguráveis),
> Centro, Mart, busca/paginação, detalhe, batalha. Foco: **encontrar e catalogar bugs**.

### 3.1 Bugs confirmados / catalogados

| # | Bug | Reprodução | Área | Status |
| --- | --- | --- | --- | --- |
| Q1 | **Oponente SEMPRE o mesmo por usuário** — toda batalha repete o mesmo time nível 1 (via "Novo confronto" e ao re-entrar em `/battle`); histórico mostra repetições idênticas | `Random.new(user_id.sum)` em `build_opponent` (`lib/battle_service.rb:64`) | Game design | = BUG-1 (confirmado) |
| Q2 | **Item perdido ao remover Pokémon com item/segurável equipado** — equipa poção em um membro, remove o membro, a poção não volta ao estoque ("potion — 0×") | `TeamRepository#remove` faz `DELETE` sem repor itens (`lib/team_repository.rb:188`; `server.rb:263`) | Persistência | = BUG-2 (confirmado) |
| Q3 | **Gate da jornada fica aberto após zerar o time** — o marcador `user_state` persiste; com time parcial (ou vazio), Poke Center/Mart e CTA "Batalhar" continuam visíveis | `JourneyService#started?` = `user_state.started? \|\| team >= 6` — o marcador nunca re-fecha | UX/fluxo | novo |
| Q4 | **Busca só acha formas base** — "pika" retorna vazio (pikachu é não-base), "pichu" ok; "char" não acha charmander (starter excluído do pool de busca); Pokémon populares/evoluídos inalcançáveis pela busca | `common_candidates` filtra por `@q` + `reject STARTER_SLUGS` + `base_form_names` (`server.rb:132`) | UX/game design | novo |
| Q5 | **Remover do time às vezes exige clicar 2x** — relatado pelo usuário; não reproduzido deterministicamente no QA (intermitente; hipótese: race com o swap/OOB do `#team-view`) | `hx-delete="/team"` + `hx-include=".list-state"` (`views/team.erb:40`) | UX (intermitente) | = BUG-3 (a investigar) |

### 3.2 Verificado funcionando (não é bug)

- Detail modal abre (tipos, stats, cadeia evolutiva, Adicionar/Fechar).
- Links de evolução no detalhe navegam (`hx-get="/pokemon/N"` → `#pokemon-detail`).
- Paginação "Próxima" avança (página 1 = iniciais+comuns → página 2 = comuns).
- Busca filtra formas base corretamente (comportamento do design, mas vira Q4).
- Estado do botão Add ("No time ✓" = Pokémon já no time; "Adicionar ao time" = livre; cheio desabilita).
- Equipar item debita do estoque (JN-3-B ok); Center cura + debita; Mart compra + debita.

### 3.3 Priorização sugerida

1. **Q1 (oponente repetido)** — bloqueante de gameplay (sem variedade/escala).
2. **Q2 (item perdido no remove)** — perda de progresso/recursos.
3. **Q3 (gate aberto após zerar)** — fluxo de jornada.
4. **Q4 (busca base-form)** — UX de descoberta.
5. **Q5 (remover 2x)** — intermitente, investigar com dados/evento htmx.

---

## Sessão 4 — 2026-08-26 (playtest focado em game design / UI / UX)

> Execução: agente navegou o app real em Chrome (CDP) com gravação
> `poke-playtest-s4` (61 frames em
> `~/.config/browser-harness/agent-workspace/recordings/poke-playtest-s4`).
> Foco explícito do usuário: **game design, UI e UX** (não caça de bugs — embora
> bugs críticos tenham aparecido). Jogou a partir de uma conta seed
> (`seed-shop`, posição 1 do ranking, saldo 200, time vazio).

### 4.1 O que foi testado

- Tela inicial `/` (Lista): 36 Pokémon (24 starters + 10 comuns + 2 extras),
  paginação "Próxima", botão "Adicionar ao time" por card, mensagem
  "Monte seu time inicial de 6 Pokémon para iniciar a jornada", painel
  `#team-view` com contador "Time: 0/6".
- Montagem do time: 6 cliques para adicionar (bulbasaur, charmander, squirtle,
  chikorita, cyndaquil, totodile). Confirmação "Adicionado ao time." + slot
  `#1..#6` com ▲/▼/Remover.
- Painel de jornada (após 6/6): "Batalhar", "Poke Center" (Custo total, Curar),
  "Poke Mart" (Pocao 20, Super Pocao 50, Hiper Pocao 100, Choice Band 80,
  Choice Scarf 80 — todos com `×N` de estoque do Mart), "Gerenciar time".
- Batalha `/battle`: 26+ rodadas clicando "Jogar", log textual cumulativo,
  HP/PP por Pokémon, painel "Itens:", oponente nível 1 fixo.
- Tela "Gerenciar time" (`hx-get="/team/manage"`): 3 forms por membro (golpes,
  item, segurável), cada um com select + "Salvar …". Itens aparecem como
  `Nenhum / Hiper Pocao ×0 / Pocao ×0 / Super Pocao ×0` (reflete estoque).
- Poke Mart: comprou 1 Poção (saldo 200→180, estoque Mart ×10→×9, apareceu
  `potion — 1×` + "Vender" no estoque do jogador).
- Equipar item: selecionou "Pocao ×1" no #1 + "Salvar item" (estoque voltou
  a ×0, sem mensagem de confirmação).
- Poke Center: clicou "Curar" antes e depois da batalha — em ambos Custo total
  = 0, sem feedback de ação.
- Histórico `/history`: ranking global (2 entradas), "Sua posição: Posição 1
  — Vitórias: 40 — Derrotas: 15", lista textual de últimas batalhas.

### 4.2 Experiência (foco game design / UI / UX)

- **Onboarding raso**: a tela inicial mostra uma lista de 36 Pokémon e um
  contador "0/6" sem explicar *por que* 6, *o que* é jornada, *como* escolher
  (por tipo? por stats?). Um novato sem contexto de Pokémon não tem critério
  para escolher. O único guia é o nome do Pokémon.
- **O momento "completei o time" é mudo**: ao adicionar o 6º, o contador
  "Time: N/6" **desaparece** e o painel de jornada (Batalhar/Center/Mart)
  aparece no lugar, sem transição nem "6/6 ✓ — jornada iniciada". Fui direto
  para a batalha sem saber que o painel novo era o "próximo passo".
- **A batalha é o ponto fraco do loop**: 26 cliques em "Jogar" para uma
  batalha que **não terminou**. Não há botão "Jogar até o fim" / auto-resolver,
  não há indicador de progresso ("3/6 oponentes restantes"), não há velocidade.
  O auto-battler pede input manual a cada rodada — contradição com o gênero.
- **O log de batalha mente**: o log diz "wattrel usou dual-wingbeat em bulbasaur,
  2 de dano", mas o HP do bulbasaur cai de 45 para 3 em uma rodada onde o log
  soma 5 de dano. O jogador **não pode confiar** no log para entender o que
  aconteceu — e em um auto-battler onde a estratégia é pré-combate, o log é a
  única forma de aprender com a derrota. Sem fidelity, não há aprendizado.
- **Itens são uma camada invisível**: equipei uma Poção no bulbasaur via
  Gerenciar — ela **sumiu do estoque da home** e **não apareceu em "Itens:" da
  batalha**. Não sei se está equipada, se será usada, se perdi o item. A camada
  de itens/seguráveis (que o conceito do jogo diz ser o coração da estratégia
  pré-combate) é **opaca em todas as telas**.
- **Estado do time é inconsistente entre telas**: a home/Center trata meu time
  como **cheio** (Custo total 0) enquanto a batalha mostra o mesmo time
  **massacrado** (5 KOs, totodile 22/50). O jogador não sabe qual estado é
  "real" — e o Center gratuito (por ler estado cheio) vira exploit implícito.
- **Economia sem tensão**: saldo inicial 200, Poção 20, Center "Custo total 0"
  (quando lê estado cheio). Sem cura custosa, sem decisão de gastar vs.
  economizar, sem razão para comprar Poção se Center é grátis. A camada
  econômica não gera choices interessante.
- **Ranking desmotivador desde o início**: "Sua posição: Posição 1 — Vitórias:
  40" herdado do seed. O jogador começa no topo sem ter jogado — zera o senso
  de progressão e o incentive de subir.
- **Gerenciar time é repetitivo**: 3 forms salvar por membro (golpes, item,
  segurável) = 18 botões para 6 membros. Cada mudança exige um clique de
  salvar isolado; sem "Salvar tudo" ou auto-save no change.

### 4.3 Achados de game design / UI / UX

| # | Achado | Impacto | Área |
| --- | --- | --- | --- |
| P1 | **Transição muda ao completar 6/6** — contador "Time: N/6" desaparece e o painel de jornada aparece sem "6/6 ✓ — jornada iniciada"; parece que a UI quebrou | Confusão de onboarding | UX |
| P2 | **Log de batalha não reflete dano real** — bulbasaur cai 45→3 HP em 1 rodada mas log soma só 5 dano; log é cosmético/fictional, não informa o jogador | Impossibilita aprendizado em auto-battler | Game design / UX |
| P3 | **Batalha em impasse infinito** — 26+ rodadas em loop totodile (scratch 1) vs nincada (struggle-bug 2) sem cap de rodadas / condição de empate | Bloqueia o loop de jogo | Game design (crítico) |
| P4 | **HP não decrementa conforme dano logado** — totodile mantém 22/50 há 15+ rodadas tomando "2/rodada"; PP decrementa certo, HP não | Corrompe o feedback da batalha | Game design / back (crítico) |
| P5 | **Sem indicador de progresso da batalha** — não há "X/6 oponentes restantes", barra de progresso, nem contador de KO | Jogador perdido no estado da batalha | UX |
| P6 | **Home não mostra HP/PP do time** — após batalha massacrada, a home lista só nomes; estado de saúde invisível fora da batalha | Jogador não sabe se precisa curar | UX |
| P7 | **Adicionar Pokémon em rajada falha** — 6 cliques rápidos em "Adicionar ao time" só registram 1 (necessário esperar swap htmx entre cada clique) | Confunde na primeira ação do jogo | UX / robustez htmx |
| P8 | **Gerenciar time: 3 "Salvar" por membro** — golpes, item, segurável como forms isolados (18 botões para 6 membros); sem "Salvar tudo" nem auto-save | Edição penosa e repetitiva | UX |
| P9 | **Inconsistência de nomenclatura de item** — "Pocao" no Mart vs "potion" no estoque; tradução parcial de nomes | Falta de polish, confunde busca | UX |
| P10 | **Item equipado SOME da home** — equipar Poção no #1 via Gerenciar a debita do estoque mas não aparece como "equipado" nem no estoque da home; item "desaparece" da perspectiva do jogador | Perda aparente de recurso, erode confiança | Persistência / UX (crítico) |
| P11 | **Item equipado não aparece em "Itens:" da batalha** — a Poção equipada não é exibida nem usada no painel de batalha; camada de itens invisível em combate | Itens/seguráveis (núcleo do auto-battler) sem efeito visível | Game design / UX (crítico) |
| P12 | **Estado divergente home vs batalha** — home/Center veem time com HP cheio (Custo 0); batalha mostra o mesmo time massacrado (5 KO); dois states of truth | Center gratuito vira exploit; jogador não sabe qual estado é real | Back / persistência (crítico) |
| P13 | **Poke Center "Curar" sem feedback** — clicar com HP cheio (ou lendo estado cheio) é no-op silencioso, sem mensagem "nada a curar" | Jogador acha que o botão quebrou | UX |
| P14 | **Jogador herda 40 vitórias do seed** — "Posição 1 — Vitórias: 40" antes de jogar; senso de progressão zerado | Desmotiva desde a primeira tela | Game design |
| P15 | **Histórico de batalhas raso** — só "Resultado + 6 nomes de oponentes"; sem rounds, HP final, golpes usados, link para detalhe | Jogador não pode refletir sobre batalhas passadas | UX / game design |
| P16 | **Sem "Jogar tudo" / auto-resolver** — auto-battler exige 26+ cliques em "Jogar" para resolver uma batalha; sem velocidade 2× ou resolver-instant | Tédio, contradição com o gênero | UX / game design |
| P17 | **Targeting automático fixo** — time sempre foca o mesmo oponente até KO, sem prioridade por tipo/efetividade visível; estratégia pré-combate limitada a moveset/itens | Reduz a profundidade do auto-battler | Game design |
| P18 | **Economia sem tensão** — Center lê estado cheio (cura grátis) + saldo inicial 200 cobre 10 Poções; sem escolha gastar vs. economizar | Camada econômica não gera choices | Game design |
| P19 | **Onboarding sem critério de escolha** — lista de 36 Pokémon por slug sem tipo/stats visíveis no card; novato escolhe "por nome" | Primeira decisão é arbitrária | UX / game design |
| P20 | **Painel "Itens:" vazio na batalha** — mesmo com item equipado, o painel de itens do time na batalha está sempre vazio | Itens não têm presença visual em combate | UX |

### 4.4 Propostas de melhoria (TP)

- **TP-1 — Feedback "6/6 ✓ — jornada iniciada"** (ref: P1): ao atingir 6
  membros, mostrar toast/badge de confirmação antes de trocar o painel;
  manter um indicador "Time: 6/6" persistente no painel de jornada.
- **TP-2 — Log de batalha fiel + estruturado** (ref: P2, P4): o log textual
  deve somar o dano real aplicado ao HP; complementar com um JSON por rodada
  (ações, dano, PP, item usado) para análise/depuração. Aumentar fidelity é
  pré-requisito para balancear o auto-battler.
- **TP-3 — Cap de rodadas + condição de empate** (ref: P3): limite máximo de
  rodadas (ex.: 30) com desempate por HP total restante, ou empate explícito
  com recompensa parcial. Evita batalha infinita e dá fim ao loop.
- **TP-4 — Indicador de progresso da batalha** (ref: P5): "Oponentes: X/6"
  + marcador KO em cada card. Barra de progresso opcional.
- **TP-5 — HP/PP do time na home** (ref: P6): cada card de membro no painel
  `#team-view` mostra `HP a/b` e PP total; state badge (ferido/KO/saudável).
- **TP-6 — Add em rajada robusto** (ref: P7): `hx-post="/team"` com
  `hx-disabled-elt` + fila de requests (ou debounce no botão) para cliques
  rápidos não se perderem; idealmente adicionar sem esperar swap.
- **TP-7 — Gerenciar com auto-save ou "Salvar tudo"** (ref: P8): um único
  botão "Salvar time" por sessão de edição, ou persistir mudança no `change`
  do select (htmx `hx-post` por field, sem botão).
- **TP-8 — Nomenclatura consistente de item** (ref: P9): usar o mesmo nome
  traduzido em Mart/estoque/batalha; ou o mesmo slug em inglês em todos.
- **TP-9 — Item equipado visível em todas as telas** (ref: P10, P11, P20):
  mostrar "Equipado: Poção ×1" no card do membro na home e na batalha;
  painel "Itens:" da batalha lista itens equipados do time com uso automático
  visível no log ("bulbasaur usou Poção, +20 HP").
- **TP-10 — Estado único do time** (ref: P12, P13): uma só fonte de verdade
  para HP/PP/itens; home, Center, batalha e histórico leem o mesmo estado.
  Center cobra proporcional ao HP faltante real; mensagem "nada a curar"
  quando aplicável.
- **TP-11 — Reset de progressão para jogadores novos** (ref: P14): não
  herdar vitórias/derrotas do seed; jogador novo começa com 0/0/0 fora do
  ranking até a primeira batalha.
- **TP-12 — Detalhe de batalha no histórico** (ref: P15): cada batalha em
  `/history` clicável → tela/sub-rotta com rodadas, HP final, golpes usados,
  itens, XP/dinheiro ganho.
- **TP-13 — "Jogar tudo" + velocidade** (ref: P16): botão "Resolver batalha"
  (executa até fim) + velocidade 1×/2×/4×; reduz tédio do auto-battler.
- **TP-14 — Card de Pokémon com tipo/stats na Lista** (ref: P19): cada card
  na `/` mostra tipos (badges coloridos) + HP/Ataque/Defesa base; dá critério
  de escolha ao novato já no onboarding.
- **TP-15 — Targeting configurável ou documentado** (ref: P17): mostrar no
  pré-combate qual a regra de targeting (ex.: "sempre o líder inimigo" /
  "primeiro vivo") ou permitir marcar um alvo优先 por Pokémon do time.

### 4.5 Priorização sugerida (impacto no jogador)

1. **P3 + P4 (impasse + HP não decrementa)** — bloqueiam o loop de jogo; a
   batalha nunca termina e o feedback é falso. **Crítico de game design/back.**
2. **P12 + P10 + P11 (estado divergente + item some + item não aparece em
   batalha)** — corrompem a confiança no estado; camada de itens (núcleo do
   auto-battler) invisível. **Crítico de persistência/UX.**
3. **P2 (log não reflete dano)** — sem fidelity, não há aprendizado; pré-requisito para balanceamento.
4. **P16 + P5 (sem auto-resolver + sem progresso)** — tédio + desorientação na batalha.
5. **P1 + P19 (onboarding)** — primeira impressão confusa.
6. **P14 (herdar vitórias)** — desmotiva desde a primeira tela.
7. **P8 + P6 (gerenciar repetitivo + HP invisível na home)** — polish de UX.
8. **P9 + P13 + P15 + P18 + P17** — refinamentos de polish/economia/depth.

### 4.6 Mapeamento para bugs já catalogados (Sessão 3)

- **P16 (oponente sempre nível 1)** = **Q1** (confirmado novamente;同一
  oponente por usuário nesta sessão: wattrel, panpour, jigglypuff, paras,
  tympole, nincada — todos nível 1).
- **P10/P11 (item some / não aparece em batalha)** é **variante de Q2**
  (item perdido) — aqui o item some ao *equipar* (não ao remover), e não
  aparece na batalha; mesmo sintoma de "item debitado do estoque e perdido".
- **P7 (add em rajada)** é **novo** — não é Q5 (remover 2x); é falha de
  clique rápido no `hx-post` de adicionar.
- **P12 (estado divergente)** é **novo** — não catalogado antes; o Center
  lê state diferente da batalha.

### 4.7 Evidências

- Gravação: `~/.config/browser-harness/agent-workspace/recordings/poke-playtest-s4`
  (61 frames; sequência: lista → add 6 → battle r0..r26 → history → home →
  mart buy → equip → center → manage).
- Gravação continuação:
  `~/.config/browser-harness/agent-workspace/recordings/poke-playtest-s4b`
  (37 frames; sequência: battle travada → remove 6 via requestSubmit →
  remontar time comum → battle 2 derrota → center curar → novo confronto →
  battle 3 vitória).
- Screenshots pontuais em `/tmp/poke-s4-01..17-*.png` e
  `/tmp/poke-s4b-01..17-*.png` (34 capturas no total).
- Batalha travada em rodada 26 reprodutível ao reabrir `/battle` (estado
  persiste): totodile 22/50 vs nincada, log em loop `scratch 1 / struggle-bug 2`.

### 4.8 Continuação do playtest (time remontado — refutações e refinamentos)

Após a Sessão 4 inicial, remontei o time (6 Pokémon comuns: rattata, pidgey,
ekans, sandshrew, nidoran-f, nidoran-m) e joguei mais 2 batalhas completas
(derrota em 7 rodadas, vitória em 7 rodadas). Resultados que **refutam ou
refinam** achados anteriores — importante para não trabalhar em cima de
hipóteses erradas:

#### Refutações (bug não reproduzido nesta sessão)

- **Q1 ("oponente sempre o mesmo por usuário") — NÃO reproduzido**: 3 batalhas,
  3 oponentes diferentes:
  1. wattrel, panpour, jigglypuff, paras, tympole, nincada
  2. spewpa, cosmog, darumaka-galar, cutiefly, pidove, gulpin
  3. silcoon, kirlia, nymble, pichu, skitty, (e mais um)

  Ou Q1 foi corrigido desde a Sessão 3, ou a hipótese `Random.new(user_id.sum)`
  só se aplica a "Novo confronto" vs re-GET `/battle`, ou depende de o time ter
  mudado. **Re-teste necessário antes de abrir sessão para corrigir Q1.**
- **Q2 ("item perdido ao remover Pokémon com item equipado") — NÃO reproduzido**:
  equipei Poção no bulbasaur (#1), removi o bulbasaur — a Poção **voltou ao
  estoque** (`potion — 1×` reapareceu com botão "Vender"). Q2 pode ter sido
  corrigido, ou só se manifesta com seguráveis (Choice Band/Scarf) vs.
  consumíveis (Poção). **Re-teste com segurável recomendado.**
- **Q3 ("gate da jornada fica aberto após zerar o time") — NÃO reproduzido ao
  zerar (0/6)**: removi todos os 6 membros → o painel de jornada (Batalhar/
  Center/Mart) **sumiu** e voltou a mensagem "Monte seu time inicial de 6
  Pokémon". Q3 pode se manifestar só com time **parcial** (1-5), não com 0.
  **Re-teste com time parcial recomendado.**
- **P12 ("estado divergente home vs batalha") — REFUTADO**: após "Fim de
  batalha" (derrota com time todo KO), a home/Center **leram corretamente** o
  estado KO (`Custo total: 128`, lista com `rattata — HP 0/30` etc.). A
  divergência observada antes era porque **sair de batalha em andamento
  (não-finalizada) não persiste o dano** — só ao "Fim de batalha" o estado
  pós-combate é salvo. **Isso confirma P10 como exploit real**: sair de uma
  batalha ruim em andamento reverte o dano do time sem penalidade.

#### Refinamentos (achado anterior ajustado)

- **P9/P30 — "×N" do Mart é affordability, não estoque**: confirmei que o `×N`
  ao lado de cada item no Mart é `floor(saldo/preço)`, não estoque físico.
  Mapeamento perfeito: saldo 200 → Pocao ×10 (200/20), Super ×4 (200/50),
  Hiper ×2 (200/100), Choice Band ×2 (200/80); saldo 92 → Pocao ×4 (92/20),
  Super ×1 (92/50), Hiper ×0 (92/100), Choice Band ×1 (92/80). **Rótulo
  confuso** — parece estoque, é affordability. Refinamento de P9.
- **P28 — "clique no botão não dispara htmx" — RECLASSIFICADO como artefato de
  automação**: o `click_at_xy` (CDP) e `.click()` (JS sintético) não disparam
  handlers htmx em botões com `hx-*` fora de form; `form.requestSubmit()` e
  `htmx.trigger(b, 'click')` funcionam. Um **humano real** clicando no botão
  dispara o evento nativo corretamente. **Não é bug do app** — é limitação do
  CDP/automação. P22 (remover via clique) tem a mesma causa. **Quem permanece
  é Q5** ("remover 2×" relatado pelo humano) — possivelmente race com
  `hx-disabled-elt` durante o swap htmx.
- **P11 — "Itens:" da batalha mostra estoque livre, não equipados**: o painel
  "Itens:" da batalha lista itens do **estoque do jogador** disponíveis para
  uso automático (ex.: `Pocao ×1` quando há 1 no estoque). Itens **equipados
  em Pokémon** (consumíveis ou seguráveis) **não aparecem em nenhuma tela da
  batalha**. Achado mantém relevância: equipados são invisíveis em combate.

#### Novos achados da continuação (P21-P34)

| # | Achado | Impacto | Área |
| --- | --- | --- | --- |
| P21 | **Sem botão "Desistir"/"Render" na batalha** — só "Jogar" + navs; jogador preso no impasse sem saída limpa (P3) | Sem saída para batalha travada | UX / game design |
| P22 | **Remover via clique é frágil** (artefato CDP + Q5 humano) — `click_at_xy`/`.click()` não disparam o `hx-delete` do form; só `requestSubmit()` funciona. Usuário humano relatou "2× cliques" (Q5) | Remover inconsistente | UX (confirma Q5) |
| P23 | **Dano desbalanceado em nível 1** — golpes causam 1 a 210 de dano em Pokémon nível 1 com HP 20-70 (ex.: darumaka-galar freeze-dry 80-105, "210 de dano — KO!"); fórmula de dano provavelmente buggy | Combate caótico, sem previsibilidade | Game design / back (crítico) |
| P24 | **cosmog usa Struggle com PP disponível** — cosmog só tinha teleport (PP 20) e splash (PP 40), mas usou "Struggle" (golpe de "sem PP"); AI do oponente não lida bem com Pokémon sem golpes ofensivos | AI duvidosa | Game design |
| P25 | **Itens do estoque usados automaticamente na batalha sem escolha** — rattata "já usou item"; a Poção ×1 do estoque foi gasta automaticamente; jogador não decide quando/em quem curar | Auto-battler tira decisão de cura | Game design |
| P26 | **Painel pós-batalha traz Center/Mart/Novo confronto** — após "Fim de batalha", a tela de batalha mostra ações de próximo passo no contexto | UX positiva | UX (positivo) |
| P27 | **"Vencedor: Oponente" / "Vencedor: Seu" impessoal** — resultado da batalha announced em 3ª pessoa genérica; melhor "Você venceu!" / "Você perdeu" | Falta de imersão | UX |
| P28 | ~~"Novo confronto" não funciona via clique~~ — **artefato de automação CDP** (htmx não dispara com `.click()` sintético); humano real funciona. Reclassificado | (não é bug do app) | — |
| P29 | **Gate "batalhar requer time curado" existe** — "Novo confronto" disabled com title "Recupere seus pokémons no Poke Center" | Game design positivo | UX (positivo) |
| P30 | **Mart "×N" = affordability** — refinado em P9 acima; não é estoque físico | (ver P9) | — |
| P31 | **GET /battle mostra a última batalha finalizada, não inicia nova** — clicar em "Batalhar" (href=/battle) leva à tela de resultado anterior (Rodada 7, "Vencedor: ..."); só "Novo confronto" inicia nova | "Batalhar" da home é enganoso | UX (crítico) |
| P32 | **Vitória recompensa 2,5× a derrota** — 50 XP + 100 dinheiro vs 20 XP + 40 dinheiro; incentivo real a vencer | Game design positivo | Game design (positivo) |
| P33 | **Resultado impessoal** — mesma raiz de P27; "Vencedor: Seu" ao vencer | (ver P27) | UX |
| P34 | **"Novo confronto" habilitado com time ferido** — após vitória com 3 KO + 1 ferido, o botão está habilitado; jogador entra na próxima batalha com time enfraquecido sem warning | Armadilha sem feedback | UX / game design |

#### Propostas adicionais (TP-16 a TP-20)

- **TP-16 — Botão "Desistir"/"Render" na batalha** (ref: P21, P3): permitir
  abandonar uma batalha em andamento com penalidade explícita (ex.: perde XP,
  mantém dano) — fecha o exploit de P10 (sair reverte dano) e dá saída ao
  impasse de P3.
- **TP-17 — Revisar fórmula de dano** (ref: P23, P2, P4): o dano precisa ser
  previsível e consistente com o log; investigar por que nível 1 gera dano
  1-210 e por que HP não decrementa conforme log. Pré-requisito para
  balanceamento.
- **TP-18 — AI do oponente com golpes não-ofensivos** (ref: P24): cosmog/splash
  não deveria usar Struggle enquanto tem PP; definir política (usar golpe de
  status ou Struggle só sem PP).
- **TP-19 — GET /battle inicia nova batalha se a anterior está finalizada**
  (ref: P31): `/battle` deve iniciar nova batalha quando não há batalha em
  andamento; manter a tela de resultado só imediatamente após o fim, com CTA
  "Novo confronto" / "Voltar".
- **TP-20 — Warning de time ferido ao iniciar nova batalha** (ref: P34):
  mostrar "Seu time está ferido (3/6 KO). Curar antes?" com CTA para Center,
  ou bloquear "Novo confronto" se time tem KO.

<!-- registros futuros adicionados abaixo -->