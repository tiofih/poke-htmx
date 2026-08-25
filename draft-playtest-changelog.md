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

<!-- registros futuros adicionados abaixo -->