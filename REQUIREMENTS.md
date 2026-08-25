# Requisitos — Poke-HTMX

> **Status dos requisitos:** `Draft` (em discussão) · `Approved` (aprovado) · `Done` (implementado)
> **Regra:** toda implementação deve seguir o fluxo TDD (RNF-04), com commit a cada green bem-sucedido.

## Visão Geral

Aplicação web estilo **Pokedex** que busca Pokémon na [PokéAPI](https://pokeapi.co) e permite montar uma equipe, usando **htmx** para interações sem JavaScript customizado. O backend renderiza HTML parcial que o htmx injeta no DOM; cada ação devolve apenas o fragmento necessário.

## Definition of Done (Global)

Para que um requisito seja considerado **completo**, todos os itens abaixo devem ser verdadeiros:

- [ ] Todos os **critérios de aceite** do requisito implementados e verificados.
- [ ] Testes (Minitest) cobrindo o comportamento implementado, todos **verdes**.
- [ ] Nenhuma regressão na suíte existente.
- [ ] `REQUIREMENTS.md` e `SESSIONS.md` **atualizados** no mesmo commit.
- [ ] Commit realizado após cada `green` (TDD).
- [ ] Commit realizado ao concluir e validar cada fase de **refinamento** (critérios de aceite e plano TDD fechados).
- [ ] Um **passo** só é considerado concluído após a **validação** (suíte verde + critérios verificados) — o passo seguinte só é iniciado quando todas as fases do passo anterior estiverem devidamente concluídas e validadas.

## Stack

| Item | Tecnologia |
| --- | --- |
| Linguagem | Ruby 3.3.6 (`/.tool-versions`) |
| Framework web | Sinatra (`server.rb`) |
| HTTP client | Faraday (`lib/gateways/poke_api_http.rb`, gateway via interface `PokeApi`) |
| Modelo | `Dry::Struct` (`lib/pokemon.rb`) |
| Persistência | PostgreSQL (gem `pg`, sem ORM) |
| Testes | Minitest |
| Frontend | htmx 2.0.3 (CDN, `views/index.erb`) |
| Servidor | Puma |
| Infra | Docker / docker-compose (porta 3000) |

## Requisitos Funcionais

### RF-18 — Tratamento de erros (E2) — `Done` (sessão 0018, validado em 2026-08-09)
- Implementar o **tratamento de erros** de ponta a ponta (E2 do `draft-auto-battler.md`,
  levantamento de roadmap 2026-08-09): **nenhuma rota devolve 500** quando a fonte
  (PokéAPI) falha ou recebe input inválido — cada falha devolve um **fragmento
  amigável com status 200** (padrão htmx `@notice`/`@message`) e um **handler global**
  cobre erros não previstos (erro logado, sem stacktrace na resposta ao usuário).

**Critérios de aceite (sessão 0018):**
- [x] `PokeApi.all` → `[]` em status ≠ 200, body não-JSON (HTML) ou erro de rede
      (`Faraday::Error`) — nunca levanta `JSON::ParserError`.
- [x] `fetch_all_names` memoiza **apenas lista não-vazia**; falha transitória →
      `[]` no request corrente e re-tenta no próximo (não trava a lista).
- [x] `find`/`pokemon_data`/`detail` resgatam rede → `nil` (mantêm guard de status);
      **`detail` nunca acessa campos de `nil`** (`pokemon_data` → nil ⇒ `detail` → nil).
- [x] `evolution_chain` → `[]` em status ≠ 200/rede/parse inválido (protege `detail`).
- [x] `move`/`fetch_move_json` resgatam rede → `nil`; `moves_for`/`available_move_names`
      seguem `[]` quando `pokemon_data` é `nil` (já tolerante, 0 regressão).
- [x] `fetch_type_json` → `nil` em status ≠ 200/rede; `type_relations` **pula o tipo
      que falhou** (tabela parcial — `TypeEffectiveness.factor` neutro 1.0).
- [x] `GET /` e `GET /pokemons`: fonte indisponível **e sem filtro** (`q` vazio) →
      fragmento com aviso + select vazio, 200 — sem 500; filtro sem match (q não-vazio)
      sem aviso (0 regressão).
- [x] `GET /pokemon?name=` com `find` → `nil` → fragmento amigável ("Pokémon não
      encontrado."), 200, sem `<html>`.
- [x] `GET /pokemon/:poke_id` com `detail` → `nil` → fragmento amigável, 200, sem `<html>`.
- [x] `POST /team` com nome inválido → re-renderiza `#team` com `@notice`, não insere,
      200 — não chama `add` com `nil`.
- [x] `GET /battle` com membro cujo `detail` → `nil` ou oponente vazio → mensagem
      amigável (200) em vez de batalha quebrada; time vazio mantém "Forme seu time
      para batalhar." (0 regressão).
- [x] `error 500 do` no `server.rb` → `views/error.erb` (fragmento, `layout: false`,
      status 200, sem `<html>`), mensagem amigável, erro original logado
      (`logger.error`/`env["sinatra.error"]`), stacktrace não vaza.
- [x] Em prod/teste o fragmento amigável é servido; em dev `show_exceptions` mantém a
      página de erro padrão do Sinatra.
- [x] Suíte completa verde (222 runs/778 asserts) e lint 0; commit a cada green;
      0 regressão RF-01..RF-17.
- [x] `REQUIREMENTS.md`/`SESSIONS.md`/`draft-auto-battler.md` atualizados no mesmo escopo.
      **Validado pelo usuário em 2026-08-09.**

### RF-17 — Página de gerenciamento de time (A3) — `Done` (sessão 0017, validado em 2026-08-09)
- Página própria para gerenciar o time (A3 do `draft-auto-battler.md`, anotado na
  validação da 0015): o usuário **escolhe a posição (slot) de cada Pokémon** e
  **escolhe os golpes de cada um** — hoje a posição só muda via ▲/▼ no `#team`
  (RF-08) e os golpes são fixos (últimos 4 da PokéAPI, RF-15).
- A escolha de golpes **persiste** entre batalhas/sessões: nova coluna
  `moves TEXT[]` em `team_pokemons`; o seletor oferece a **lista completa** de
  moves do Pokémon (`PokeApi.available_move_names`) e `GET /battle` passa a usar
  os golpes salvos do jogador (fallback para o comportamento da RF-15 quando vazio).

**Critérios de aceite (sessão 0017):**
- [x] Migração idempotente `0017_add_moves.sql` — `team_pokemons.moves TEXT[]
      NOT NULL DEFAULT '{}'` (sem `TRUNCATE`).
- [x] `Pokemon` ganha attribute `moves` (default `[]`); `all` devolve os moves;
      `add` persiste `pokemon.moves`.
- [x] `TeamRepository::MAX_MOVES_PER_POKEMON = 4`; `set_moves(user_id, id, moves)`
      persiste no máximo 4, só do próprio usuário; outro usuário/id inexistente →
      no-op.
- [x] `PokeApi.available_move_names(number)` — todos os nomes de moves do Pokémon
      (sem carregar `/move`), ordenados, memoizado por número.
- [x] `PokeApi.move(name)` → `nil` em status ≠ 200 (robustez, padrão 0014).
- [x] `GET /team/manage` renderiza `team_manage.erb` (checkbox de golpes por
      membro + ▲/▼ de slot reusando `POST /team/:id/move` + Voltar), alvo `#team`,
      sem `<html>`; link "Gerenciar" no `team.erb`.
- [x] `POST /team/:id/moves` salva a seleção via `set_moves` e re-renderiza
      `team_manage.erb`; > 4 selecionados ou nome fora da lista disponível → aviso
      (`@notice`) e não salva.
- [x] `GET /battle` usa os golpes persistidos do jogador (nome → `PokeApi.move`,
      memoizado); lista vazia/inresolvível → fallback `PokeApi.moves_for` (RF-15 sem
      regressão); oponente mantém os 4 defaults.
- [x] Sem JS customizado (RNF-01); testes sem rede (stubs novos
      `with_available_move_names`/`with_move`).
- [x] Suíte completa verde (`./scripts/test` — 199 runs/708 asserts) e lint 0;
      commit a cada green; 0 regressão RF-01..RF-16.
- [x] `REQUIREMENTS.md`/`SESSIONS.md`/`draft-auto-battler.md` atualizados no mesmo
      escopo.
      **Validado pelo usuário em 2026-08-09.**

> **Validação (2026-08-09):** durante a validação, dois ajustes: (1) o link "Gerenciar"
> interno ao `team.erb` sumia ao navegar — o **link "Time" do nav passou a apontar para
> o gerenciador** (`hx-get="/team/manage"` no alvo `#team`) e o botão interno foi
> removido; (2) **500 em `GET /team/manage`** quando a PokéAPI responde falha
> (rate-limit devolve 404/HTML) — `pokemon_data` agora retorna `nil` em status ≠ 200
> (padrão `find`/`fetch_move_json`) e `available_move_names`/`moves_for` viram `[]`.
> Anotado no draft: puxar mais informações dos golpes (nível de aprendizado) e visão de
> XP/evolução por batalha com oponente no mesmo nível do jogador (D2).

### RF-16 — Logs de batalha detalhados (C1) — `Done` (sessão 0016, validado em 2026-08-09)
- Melhorar os **logs de batalha** (C1 do `draft-auto-battler.md`, anotado na validação
  da 0015): hoje o log mostra apenas o **lado** atacante ("Seu Time"/"Oponente"), o
  golpe e o dano — não diz **qual Pokémon** bateu em **qual**. O log passa a indicar
  **quem atacou quem**, com **qual golpe** e o **dano causado** (ex.: "Seu Time:
  pikachu usou thunder-shock em bulbasaur, 12 de dano").
- `BattleEngine` grava **`attacker_name`** e **`target_name`** em **toda** entry do
  log (contrato uniforme, decisão do usuário) e `battle.erb` re-renderiza o log com
  os dois nomes — comportamento da batalha (dano/vencedor/ordem/rounds) intacto.

**Critérios de aceite (sessão 0016):**
- [x] Toda entry do log ganha `attacker_name`/`target_name` (nome do `BattlePokemon`
      atacante e do alvo), em todos os caminhos (legado e com moves) — chaves
      existentes preservadas com os mesmos valores.
- [x] Comportamento da batalha inalterado: dano, vencedor, rounds e ordem de ação
      idênticos — asserts de shape exato atualizados (`battle_engine_test.rb` e
      `move_engine_test.rb`) para o novo contrato (não é regressão: é o deliverable).
- [x] `battle.erb` (log do último round) mostra lado + nome do atacante + "usou" +
      golpe (`entry[:move]` quando presente, senão `entry[:move_type]`) + "em" + nome
      do alvo + dano + KO (`entry[:ko]`); caminho legado também exibe nomes.
- [x] Sem JS customizado (RNF-01); testes de rota sem rede (stubs
      `with_detail`/`with_moves_for`) verificando o novo formato no fragmento de
      `GET /battle` e `POST /battle/play`.
- [x] Suíte completa verde (`./scripts/test`) e lint 0; commit a cada green; sem
      regressão de comportamento em RF-01..RF-15.
- [x] `REQUIREMENTS.md`/`SESSIONS.md`/`draft-auto-battler.md` atualizados no mesmo
      escopo.
      **Validado pelo usuário em 2026-08-09.**

### RF-15 — Golpes (moves) e PP (D1) — `Done` (sessão 0015, validado em 2026-08-09)
- Dar **multi-move** à simulação de batalha (D1 do `draft-auto-battler.md`, roadmap
  item 15): cada `BattlePokemon` passa a ter uma **lista de golpes** (nome, tipo,
  poder, precisão, PP). O `BattleEngine` **escolhe deterministicamente** qual golpe
  usar (maior dano esperado), aplica o **poder do golpe** no dano, **decai o PP** a
  cada uso e, sem golpe utilizável, usa **Struggle** (dano baixo fixo, tipo do
  atacante, sem PP). Sem RNG — escolha determinística e testável.
- `PokeApi.moves_for(number)` busca até **4 golpes** (últimos da lista `moves` de
  `GET /pokemon/:id`, memoizado) e `PokeApi.move(name)` via `GET /move/:name`
  (memoizado). A batalha web (C1/RF-13) carrega os golpes dos dois lados e exibe:
  log mostra o golpe usado e cada painel mostra os golpes com **PP restante**.
- Revisita B3/RF-11 (motor) e toca C1/RF-13 (battle.erb + `GET /battle`) **sem
  regressão**: `BattlePokemon` sem `moves` mantém o caminho legado (ataque por
  melhor tipo, dano `A−D`, mesma shape de log) — suíte 0011 verde sem edição.

**Critérios de aceite:**
- [x] `lib/move.rb`: `Move < Dry::Struct` com `name`, `type`, `power` (Integer ou nil),
      `accuracy` (Integer ou nil) e `pp` (Integer).
- [x] `BattlePokemon` ganha a attribute `moves` (`Array.of(Move)`, default `[]`);
      `from(pokemon, moves:)` aceita a lista — sem `moves` → `[]` (caminho legado).
- [x] `PokeApi.move(name)` → `Move` memoizado; `PokeApi.moves_for(number)` → até 4
      golpes (últimos da lista da API) memoizado; golpes de status (power nil/0)
      carregados mas **inutilizáveis** pelo motor.
- [x] Motor escolhe determinísticamente o golpe de **maior dano esperado**
      (`power × effectiveness × STAB`); desempate maior `power`, depois primeira posição.
- [x] Dano do golpe = `max(1, Attack − Defense) × (power / 50) × multiplicador do tipo
      do golpe` (redondo, min 1); `move_type` no log = tipo do golpe usado.
- [x] **PP decai em 1** a cada uso (funcional); golpe com `pp == 0` deixa de ser escolhido.
- [x] Sem golpe utilizável (todos `pp == 0` ou só status) → **Struggle** (power 10,
      tipo do atacante, sem PP, entra no log com `move: "Struggle"`).
- [x] Pokémon **sem `moves`** (`[]`) → caminho legado de B3 preservado (0 regressão,
      suíte 0011 verde sem editar `battle_engine_test.rb`).
- [x] Log de ação com golpe ganha a chave `move` (nome do golpe); entries legado
      continuam `round/attacker/move_type/damage/ko`.
- [x] `Accuracy` preservada no `Move` mas **não aplicada** (sem RNG neste escopo) — anotado.
- [x] `GET /battle` carrega os golpes dos dois lados (`moves_for`); rota sintetiza
      Struggle quando `moves_for` vazio (nunca expõe `[]`).
- [x] `battle.erb`: cada fighter mostra seus golpes com **PP restante** (`move — PP n`);
      log do round mostra o **nome do golpe** usado (+ Struggle quando for o caso).
- [x] Sem JS customizado (RNF-01); testes de rota sem rede (stubs incluem
      `PokeApiStub.with_moves_for`/`with_move`).
- [x] Suíte completa verde (171 runs/610 asserts) e lint 0; commit a cada green;
      0 regressão RF-01..RF-14; `REQUIREMENTS.md`/`SESSIONS.md`/`draft-auto-battler.md`
      atualizados no mesmo escopo.
      **Validado pelo usuário em 2026-08-09.**

> **Validação (2026-08-09):** comportamento confirmado com o app rodando (batalha abre,
> golpes com PP exibidos, log mostra o golpe usado, play avança rodadas). Durante a
> validação houve um **500 em `GET /battle`** por limitação do Sinatra::Reloader em dev
> (processo Puma com `PokeApi` antigo, sem `moves_for`, apesar de `server.rb` recarregado)
> — resolvido com `docker restart poke-htmx-web-1`; não é bug da implementação. Anotado
> no draft: melhorar logs de batalha (qual pokemon bateu em qual, com qual golpe e dano)
> e **A3 — página própria de gerenciamento de time** (escolher golpes de cada pokemon e
> posição no time).

### RF-14 — Layout e estilos externos (A2) — `Done` (sessão 0014, validado em 2026-08-09)
- Extrair **layout/navbar/estilos compartilhados** (A2 do draft auto-battler, roadmap
  item 14): layout único `views/layout.erb` usado por `GET /`, navegação consistente
  (Lista/Time/Batalha) na **página única** e **CSS externo** estilizando as classes dos
  fragmentos — **sakura (CDN) como base** + `public/style.css` sobreposto.
- Fragmentos htmx permanecem **parciais** (`layout: false`): nenhuma mudança de
  contrato (alvos, swaps, forms).

**Critérios de aceite:**
- [x] `views/layout.erb` = `<html>` único (charset, título, script htmx 2.0.3, sakura
      CDN + link `/style.css`) + `<nav>` com título da app e links Lista/Time/Batalha.
- [x] `GET /` responde o layout único; `index.erb` vira **parcial**; a resposta contém
      **exatamente um** `<html>`, com conteúdo preservado (filtro, `#pokemon-list`,
      `#pokemon`, `#team`, `#battle`).
- [x] Navegação consistente na página única (Lista → `#pokemon-list`, Time → `#team`,
      Batalha → `hx-get="/battle"` no alvo `#battle`), sem JS custom (RNF-01).
- [x] Ao sair da aba Batalha (Lista/Time), o painel `#battle` é limpo via
      `GET /battle/close` (fragmento vazio, padrão `/pokemon/close`) — avisos como
      "Forme seu time para batalhar." deixam de permanecer na tela.
- [x] Fragmentos htmx (`/pokemons`, `/pokemon`, `/pokemon/:poke_id`, `/pokemon/close`,
      `/team`, `POST /team`, `DELETE /team`, `POST /team/:id/move`, `/battle`,
      `POST /battle/play`) continuam **parciais** (`layout: false`) — resposta sem
      `<html>/<head>` e com o mesmo contrato de antes.
- [x] `public/style.css` estiliza as classes atuais dos fragmentos (listagem, detalhe,
      team, batalha) sobre a base sakura; `GET /style.css` responde 200 via pasta pública.
- [x] Suíte completa verde (146 runs/553 asserts) e lint 0; 0 regressão RF-01..RF-13;
      commit a cada green; `REQUIREMENTS.md`/`SESSIONS.md`/`draft-auto-battler.md`
      atualizados no mesmo escopo.
      **Validado pelo usuário em 2026-08-09.**

> **Validação (2026-08-09):** durante a validação, ajustes de robustez no `GET /battle`
> (defeitos encontrados pelo usuário): `GET /battle/close` limpa `#battle` ao sair da
> aba Batalha; `PokeApi.find` retorna `nil` em status ≠ 200 (espécie sem `/pokemon`) e
> `evolution_chain` ignora o estágio; `find`/`detail` mapeiam sprite `front_default`
> nulo para `""` — commits `0cc8d81`, `e5fb57c`, `3abf7f6`.

### RF-13 — Batalha na web (C1) — `Done` (sessão 0013, validado em 2026-08-09)
- Expor o motor de auto-batalha (RF-11/B3) e o oponente automático (RF-12/B4) na UI
  com **100% htmx** (RNF-01): o usuário entra em uma batalha contra um time adversário
  e cada "jogar" avança **uma rodada** do `BattleEngine`, re-renderizando o fragmento
  `#battle` com os dois painéis (time do jogador × oponente), **HP atual** por membro,
  o **log do último round** e, ao fim, o **vencedor** + botão "Novo confronto".
- `BattleEngine` ganha API **incremental** (`play_round`, `finished?`, `winner`,
  `rounds`, `log`, `teams`) mantendo `battle` como loop (0 regressão em B3).
- Estado da batalha entre requests em **memória** (`BattleRegistry` por `user_id`) —
  batalha não é estado persistente (RF-02).

**Critérios de aceite:**
- [x] `BattleEngine#play_round` público: executa **uma rodada**, incrementa `rounds`,
      acumula `@log` e expõe o estado dos times (HP por membro via `teams`).
- [x] `finished?`, `winner`, `rounds`, `log` públicos; `battle` vira loop de
      `play_round!` → mesmo `BattleResult` de antes (B3 sem regressão).
- [x] `play_round` após o fim é **idempotente** (não quebra, não gera log novo).
- [x] `BattleRegistry` guarda por `user_id` a batalha corrente (`fetch`/`set`/`clear`).
- [x] `GET /battle` abre/recria a batalha: monta time do jogador via
      `BattlePokemon.from(PokeApi.detail(member.number))` (por membro), oponente via
      `OpponentGenerator`, cria `BattleEngine` e renderiza `battle.erb` (alvo `#battle`).
- [x] `POST /battle/play` avança **uma rodada** e re-renderiza `battle.erb`; painéis
      mostram nome + sprite + `HP current/max` dos dois lados; log mostra as ações do round.
- [x] Batalha finalizada: fragmento mostra **vencedor** (Seu Time / Oponente) e botão
      "Novo confronto" (`hx-get="/battle"` → recria).
- [x] Time vazio → mensagem amigável ("Forme seu time para batalhar.") sem erro.
- [x] `index.erb` ganha entrada "Batalha" (`hx-get="/battle" hx-target="#battle"`).
- [x] Sem JS custom (RNF-01); testes sem rede (`with_all_names`/`with_detail`/`with_type`).
- [x] Suíte completa verde (135 runs/481 asserts) e lint 0; sem regressão RF-01..RF-12;
      `REQUIREMENTS.md`/`SESSIONS.md`/`draft-auto-battler.md` atualizados no mesmo escopo.
      **Validado pelo usuário em 2026-08-09.**

### RF-12 — Oponente automático (B4) — `Done` (sessão 0012, validado em 2026-08-08)
- Gerar o time adversário para o jogador enfrentar sem montar time próprio — lado
  `team_b` do `BattleEngine` (RF-11) num futuro C1 (batalha na web).
- `OpponentGenerator` sorteia N slugs de uma lista de candidatos (ex: `PokeApi.fetch_all`),
  **sem repetição**, e monta `[BattlePokemon]` na ordem do sorteio (posição = slot).
- **Domínio puro** (sem PG, sem rede): `names:` (lista) e `fetcher:` (name → `Pokemon`)
  são injetados no construtor; `rng` injetável com **seed** (default `Random.new`) →
  determinístico sob mesma seed, variável entre confrontos.
- Sem rota/UI/schema nesta entrega (C1 no roadmap seguinte).

**Critérios de aceite:**
- [x] `OpponentGenerator.new(names:, size: DEFAULT_TEAM_SIZE=6, rng:, fetcher: default
      `PokeApi.method(:detail)`)` — `names` é o array de slugs candidatos; `size` default 6
      (cap RF-07); `rng`/`fetcher` injetáveis.
- [x] `team` devolve `[BattlePokemon]` (via `BattlePokemon.from`) na ordem do sorteio;
      `team_names` devolve os slugs sorteados.
- [x] Sorteio **sem repetição**; `names` menores que `size` → usa o total disponível;
      `names == []` ou `size <= 0` → `[]` (sem erro).
- [x] Determinístico sob seed fixa (`Random.new(42)`) — mesma `team`/ordem; seeds
      diferentes variam.
- [x] Domínio puro: `names`/`fetcher` injetados, testes sem rede (stub `fetcher`);
      suíte completa verde (118 runs/416 asserts) e lint 0; sem regressão RF-01..RF-11.
- [x] `REQUIREMENTS.md`/`SESSIONS.md`/`draft-auto-battler.md` atualizados no mesmo escopo.
      **Validado pelo usuário em 2026-08-08.**

### RF-01 — Listar Pokémon — `Done` (sessão 0006)
- Exibir um `<select>` com os Pokémon da PokéAPI, **paginação (100 por página)**
  e **filtro por nome** (sessão 0006) — substituindo o `limit=100000` único.
- O valor de cada opção é o nome do Pokémon; o `<select>` dispara `hx-get="/pokemon"`.

**Critérios de aceite:**
- [x] Ao acessar `GET /`, a página contém um elemento `<select name="name" id="pokemons" hx-get="/pokemon">`.
- [x] `GET /` renderiza as opções da **primeira página** (máx. 100), sem `limit=100000`.
- [x] `GET /pokemons` (fragmento) re-renderiza o `<select>` com a página solicitada (`offset`)
      + controles "Anterior"/"Próxima" htmx + contador "Página X de Y".
- [x] `GET /pokemons?q=<texto>` filtra por substring sobre a lista cacheada e pagina
      o resultado filtrado; `q` vazio = lista completa.
- [x] Paginação/filtro sem JS customizado (RNF-01); o `<select>` continua disparando
      `hx-get="/pokemon"` ao trocar a opção.

### RF-02 — Visualizar Pokémon — `Draft` (Descartável — superado por RF-03 + RF-06)
> Anotado no levantamento de roadmap (2026-08-09): este requisito está **obsoleto** —
> o comportamento (visualizar sprite/nome + "Add to Team" ao selecionar) já é coberto
> por RF-03 (formulário Add to Team) e RF-06 (página de detalhes com sprite/nome).
> Mantido como `Draft` por convenção (RNF-04), mas **não deve virar sessão**.
- Ao selecionar um Pokémon no `<select>`, disparar `hx-get /pokemon?name=<nome>` em `#change`.
- Renderizar no alvo `#pokemon`: sprite, nome e botão "Add to Team".

**Critérios de aceite:**
- [ ] Buscar por `GET /pokemon?name=pikachu` responde parcial HTML contendo a sprite de Pikachu.
- [ ] O fragmento inclui um botão "Add to Team" (`Add to Team`).
- [ ] O fragmento contém um campo oculto `pokeName` com o valor do nome do Pokémon.

### RF-03 — Formar equipe — `Done` (sessão 0001)
- Formulário envia `hx-post /team` com `pokeName` (nome do Pokémon), renderizando o fragment `#team`.
- Exibir cada membro da equipe com sprite e nome, e um botão "Remove from Team".

**Critérios de aceite:**
- [x] `POST /team` com `pokeName=pikachu` persiste o Pokémon na equipe (Postgres) e responde o fragment atualizado.
- [x] O fragmento `#team` lista, para cada membro, sprite, nome e botão "Remove from Team".

### RF-04 — Remover da equipe — `Done` (sessão 0002)
- Botão dispara `DELETE /team` (via `form hx-delete` htmx) com alvo `#team`.
- Remove o Pokémon pelo `id` persistido e re-renderiza a equipe.

**Critérios de aceite:**
- [x] A ação de remoção é semântica: `DELETE /team` com `id=<id>` (em vez de `GET /team?index=<id>`).
- [x] Após a remoção, o fragmento `#team` não contém mais o Pokémon removido.
- [x] `id` inexistente ou ausente não quebra: re-renderiza a equipe (idempotente).
- [x] Rota `GET /team` deixa de manipular remoção.

### RF-05 — Equipe por usuário — `Done` (sessão 0003)
- Cada navegador (sessão/cookie) tem a **própria equipe**, isolada das demais.
- `POST /team` e `DELETE /team` persistem e buscam apenas os Pokémon do usuário da sessão corrente.
- Ao abrir a aplicação com sessão existente, a equipe do usuário é carregada automaticamente
  (`GET /team` só-leitura + `hx-trigger="load"` no `#team`).

**Critérios de aceite:**
- [x] `team_pokemons` ganha `user_id` (`TEXT NOT NULL`); migração trunca dados antigos.
- [x] `TeamRepository` opera por usuário: `all(user_id)`, `add(user_id, pokemon)`, `remove(user_id, id)`.
- [x] Pokémon de um usuário não aparece na equipe de outro (isolamento).
- [x] `DELETE /team` só remove membro do próprio usuário; id de outro usuário é idempotente (200).
- [x] Sessão Sinatra gera `user_id` no 1º acesso; rotas e `team.erb` usam o usuário da sessão.

### RF-06 — Página de detalhes — `Done` (sessões 0004 + 0005)
- Ao clicar no nome/sprite de um Pokémon (na listagem `#pokemon` ou na equipe),
  renderizar no alvo `#pokemon` os **detalhes**: sprite, nome, tipos, stats base e evoluções.
- Interação 100% htmx (RNF-01); o botão "Add to Team" é preservado no detalhe.
- A rota de detalhe usa o **id único da API** (`GET /pokemon/:poke_id`), mais estável que o nome.
- Botão "Fechar"/"Voltar" limpa o alvo `#pokemon` (apaga status e linha evolutiva).

**Critérios de aceite:**
- [x] `GET /pokemon/:poke_id` responde o fragmento de detalhe (sprite, nome, tipos, stats, evoluções).
- [x] Tipos: exibe todos os tipos do Pokémon (ex.: pikachu → electric; bulbasaur → grass, poison).
- [x] Stats: exibe os 6 base stats com nome e valor (HP, Attack, Defense, Sp.Atk, Sp.Def, Speed).
- [x] Evoluções: exibe a cadeia de evolução (sprite + nome) via species → evolution_chain; sem evolução não quebra.
- [x] Nomes em `pokemon.erb` e `team.erb` clicáveis com `hx-get="/pokemon/:poke_id"` (alvo `#pokemon`).
- [x] Sprites em `pokemon.erb` e `team.erb` clicáveis com `hx-get="/pokemon/:poke_id"`
      (alvo `#pokemon`) — **sem** `<input type="image">` (não submete os forms de equipe) (sessão 0005).
- [x] Detalhe ganha **botão "Fechar"/"Voltar"** (`hx-get="/pokemon/close"` → swap
      innerHTML no alvo `#pokemon`), que apaga status e linda evolutiva da tela (sessão 0005).
- [x] Fragmento de detalhe mantém o form `hx-post /team` (Add to Team, RF-03).
- [x] `GET /pokemon?name=` (fragment add atual) permanece funcional.

### RF-08 — Reordenação manual de slots (A1) — `Done` (sessão 0008)
- Permitir que o usuário **reordene manualmente** os membros do seu time (slots 1..N)
  via botões ▲/▼ — hoje a posição só muda na remoção (sessão 0007).
- A **ordem resultante é o input do futuro game loop**: `all(user_id)` já retorna
  `ORDER BY slot`, e o usuário passa a controlar essa ordem.
- Nenhuma mudança de schema (RF-07 já persistiu `slot` + índices únicos).

**Critérios de aceite:**
- [x] `TeamRepository#move(user_id, id, new_slot)` move para slot `new_slot` (1..N)
      mantendo slots contíguos 1..N (reindexa os demais), para cima e para baixo.
- [x] Idempotente: `new_slot` igual ao atual, fora de `1..N`, ou id inexistente →
      time intacto (sem efeito, sem raise).
- [x] Isolamento (RF-05): id de outro usuário → no-op; time do dono intacto.
- [x] Reordenação não viola `UNIQUE (user_id, slot)` (transação com slot temporário).
- [x] `POST /team/:id/move` com `new_slot` re-renderiza `#team` (200) na ordem nova;
      inválido/igual/outro usuário → 200 com time intacto.
- [x] `team.erb` ganha botões ▲/▼ (forms `hx-post="/team/:id/move"` com hidden
      `new_slot`, alvo `#team`), irmãos do form de remoção; ▲ slot 1 / ▼ último = no-op.
- [x] Sem regressão: RF-01..RF-07 seguem verdes; teste sem rede; commit a cada green.
- [x] Sem regressão: RF-01..RF-07 seguem verdes; teste sem rede; commit a cada green.
- [x] `REQUIREMENTS.md`/`SESSIONS.md` atualizados no mesmo escopo.

### RF-09 — Modelo de batalha (B1) — `Done` (sessão 0009)
- Transformar `Pokemon` (RF-06) em unidade de combate pura: `BattlePokemon`
  (Dry::Struct) com `hp_max` derivado do **base stat HP** e `hp_current`.
- **Domínio puro** (sem PG, sem rede): métodos `take_damage` (funcional/imutável),
  `alive?` e `fainted?` — fundação do motor de auto-batalha (B2/B3).
- Não muda schema, rotas ou `Pokemon`; nenhuma regressão (RF-01..RF-08).

**Critérios de aceite:**
- [x] `BattlePokemon.from(pokemon)` preserva `number`, `name`, `types`, `stats`;
      `hp_max` = HP bruto (Pikachu 45 → 45) e `hp_current` inicial = `hp_max`.
- [x] `Pokemon` sem stat HP → `hp_max = 1` (mínimo para `alive?`).
- [x] `take_damage(dano)` **funcional**: retorna nova instância; original intacta;
      clamp em 0 (nunca negativo); dano `<= 0` → sem efeito.
- [x] `alive?` (`hp > 0`), `fainted?` (`hp == 0`) — coerentes após dano até zerar.
- [x] Domínio puro (sem PG/rede); suíte e lint verdes; commit a cada green; RF-01..RF-08
      sem regressão; `REQUIREMENTS.md`/`SESSIONS.md` atualizados no mesmo escopo.

### RF-10 — Efetividade de tipos (B2) — `Done` (sessão 0010)
- Precisão de dano por tipo para o futuro motor de auto-batalha (B3): fraqueza **×2**,
  resistência **×0.5**, imune **×0**, neutro **×1**; **STAB** ×1.5 quando o atacante tem o
  tipo do golpe; defensor com **dois tipos** multiplica os fatores de cada um.
- Domínio puro (`TypeEffectiveness`) **sem rede**; a fonte é `PokeApi.type_relations`
  (`GET /type/:name` → `damage_relations`), carregada com cache em memória (padrão RF-01).
- Não muda schema, rotas nem `BattlePokemon`; nenhuma regressão (RF-01..RF-09).

**Critérios de aceite:**
- [x] `TypeEffectiveness.from_relations(tabela)` monta o objeto a partir da estrutura
      de `damage_relations` (atacante → `double`/`half`/`no`).
- [x] `factor(attack_type, defender_type)` → **2.0**/**0.5**/**0.0**/**1.0** (ex.: fire→grass=2,
      fire→water=0.5, electric→ground=0, normal→ghost=0; relação inexistente → 1).
- [x] `effectiveness(attack_type, defender_types)` multiplica o fator de cada tipo do
      defensor (ex.: `fire` contra `["water","fire"]` = 0.25); lista vazia → 1.0.
- [x] `stab(attack_types, move_type)` = 1.5 quando o atacante tem o tipo do golpe, senão 1.0.
- [x] `damage_multiplier(attacker_types:, move_type:, defender_types:)` =
      `effectiveness × stab` (ex.: `(["fire"], "fire", ["water"])` = 0.75).
- [x] `PokeApi.extract_type_relations(json)` puro converte `damage_relations`.
- [x] `PokeApi.type_relations` carrega os **18 tipos** (`/type/:name`) com cache
      (memoização) — 2ª chamada sem nova rede; `TypeEffectiveness.load` integra a fonte.
- [x] Domínio puro (sem rede no `TypeEffectiveness`); suíte e lint verdes; commit a cada
      green; RF-01..RF-09 sem regressão; docs atualizadas no mesmo escopo.

### RF-11 — Motor de auto-batalha (B3) — `Done` (sessão 0011, validado em 2026-08-08)
- Simular **combate automático 6v6** entre dois times de `BattlePokemon` — o **game loop**
  do auto-battler. Dados dois times (cada um por slot, ex. `all(user_id)` de RF-07), o
  motor: resolve **turnos por rodada**, calcula **dano** a partir de stats + tipos
  (`TypeEffectiveness`, RF-10), aplica **KO** ao zerar HP, acumula um **log de ações**
  e devolve o **vencedor** (ou empate).
- **Domínio puro** — sem golpes (D1 fora de escopo) e sem rede; determinístico
  (RNG injetável anotado para iteração futura).
- Não muda schema, rotas nem `TypeEffectiveness`; única extensão em B1 é `BattlePokemon#stat`.

**Critérios de aceite:**
- [x] `BattlePokemon#stat(name)` devolve o valor do stat (ex.: `stat("Speed")` → 90) e `1` quando ausente.
- [x] `BattleEngine.new(team_a:, team_b:, effectiveness:)` — times de `BattlePokemon` em
      ordem de slot; `effectiveness` injetado (default `TypeEffectiveness.load`); sem rede no motor.
- [x] Uma **rodada** = cada vivo age uma vez; ação escolhe alvo, aplica dano e marca KO se zerar.
- [x] **Ordem de ação** = Speed decrescente; desempate time 0, depois slot menor.
- [x] **Alvo** = primeiro vivo por slot do adversário (estratégia injetável).
- [x] **Dano** = `max(1, Attack − Defense)` × multiplicador do **melhor tipo** do atacante (inclui STAB); imune (×0) → golpe neutro (×1, sem STAB); dano final ≥ 1.
- [x] **KO**: HP ≤ 0 → `fainted?`; fainted não age nem é alvo.
- [x] **Fim**: lado sem vivos perde; ambos zeram na mesm ação → empate; times vazios → vence o não-vazio (ambos vazios → empate).
- [x] `BattleResult` com `winner` (0/1/nil), `log` (por ação: `round`, `attacker`,
      `move_type`, `damage`, `ko`) e `rounds`.
- [x] Motor 100% domínio puro (sem PG/rede), determinístico; testes sem rede
      (`TypeEffectiveness.from_relations`), suíte completa verde (110 runs/398 asserts),
      lint 0; sem regressão RF-01..RF-10; docs atualizadas no mesmo escopo.
      **Validado pelo usuário em 2026-08-08.**

### RF-07 — Montagem de times (base do auto-battler) — `Done` (sessão 0007)
- Time por usuário limitado a **6 vagas** (`MAX_TEAM_SIZE = 6`), com **`slot` de
  posição (1..N)** persistido e **sem duplicados** (mesmo `number` da PokéAPI).
- `TeamRepository` garante: adicionar respeita o cap e a unicidade, remover
  recompacta os slots (sempre contíguos 1..N) e `all(user_id)` ordena por slot.
- Este requisito é a **estrutura de dados de time** que o futuro game loop
  (auto-battler) vai consumir — não inclui o combate em si (escopo futuro, ver
  Limitações/Roadmap).
- Interação segue 100% htmx (RNF-01): bloqueios (cap/duplicado) são informados via
  fragmento `#team` com aviso (200), sem JS customizado.

**Critérios de aceite:**
- [x] `team_pokemons` ganha `slot INTEGER NOT NULL` (posição) + índices únicos
      `(user_id, number)` e `(user_id, slot)`; migração idempotente.
- [x] `TeamRepository::MAX_TEAM_SIZE = 6`; `add` com time cheio não insere e sinaliza
      `TeamFullError`; com Pokémon duplicado (`number` repetido) sinaliza `DuplicateError`.
- [x] `add` preenche o próximo slot livre (1..6); `remove` recompacta (sem lacunas);
      `all(user_id)` ordena por slot.
- [x] `POST /team` bloqueado devolve 200 com fragmento `#team` + aviso ("Time cheio
      (máx. 6)." / "<nome> já está no time.") e não duplica registro.
- [x] Fragmento `#team` exibe a posição (slot) de cada membro, na ordem de slot.
- [x] Sem regressão: RF-01..RF-06 seguem verdes; teste sem rede; commit a cada green.
- [x] `REQUIREMENTS.md`/`SESSIONS.md` atualizados no mesmo escopo.

## Requisitos Não-Funcionais

### RNF-01 — Arquitetura — `Executado`
- Aplicação server-rendered; **sem JavaScript customizado** — toda interação via htmx.
- Backend consome a PokéAPI externa via Faraday.

### RNF-02 — Estado / Persistência — `Done` (sessão 0001)
- Estado da equipe persistido em **PostgreSQL** (gem `pg`, sem ORM).
- Ligado via `DATABASE_URL` (ex.: `postgres://pokedex:pokedex@db:5432/pokedex`).
- Servidor `db` no `docker-compose.yml`, banco `pokedex`; tabela `team_pokemons` via `rake db:setup`; testes cobrem persistência, add e remoção (sem rede).

### RNF-03 — Ambiente — `Approved`
- Desenvolvimento via `docker compose up` (volume em `/var/www/pokedex`, porta 3000).
- Ruby 3.3.6 com `bundle install`.

### RNF-04 — TDD — `Approved`
- Toda implementação **começa por um teste que falha** (red), depois implementação mínima (green) e depois refatoração.
- Framework: **Minitest**.
- **Commit obrigatório após cada green.**
- **Commit obrigatório após cada fase de refinamento concluída e validada** (documento da sessão com critérios de aceite e plano TDD fechados e verificados).
- `REQUIREMENTS.md` e `SESSIONS.md` sempre atualizados no mesmo escopo.
- Suíte cobre regras de negócio (persistência da equipe, adicionar/remover, consulta à PokéAPI) e rotas do servidor.
- **Sequenciamento:** um passo só é iniciado quando todas as fases do passo anterior estiverem concluídas e validadas (nada de começar novo passo sobre trabalho não validado).
- **Ideias/escopos grandes fora da fase:** ideias, melhorias e escopos grandes identificados
  durante uma sessão são **anotados** no `REQUIREMENTS.md` (limitações/roadmap) ou nas
  observações do arquivo da sessão, mas só seguem o fluxo (refinamento → TDD → validação)
  **após a sessão corrente ser concluída e validada** — nada de abrir novo escopo no meio.
- **SDD robustecido (S1/S2/S3):** critérios de aceite referenciam os **testes que os
  provam** (sem teste automatizado = `manual` explícito); a validação é registrada como
  **tabela por critério** (`critério | evidência automatizada | evidência manual |
  resultado`) e todo **ajuste de validação** é uma **alteração formal de critério**
  (reaberto + reaprovado pelo usuário).
- **Consistência dos docs (S4/S5):** `SESSIONS.md` (tabela de progresso + "Próxima
  sessão") é atualizado **no commit do refinamento** de toda sessão (inclusive fora de
  fila); `./scripts/check_docs` valida sessões ↔ `SESSIONS.md` ↔ "Próxima sessão".

## Limitações Conhecidas / Pontos de Refinamento

- [x] **Estado efêmero e global** — resolvido no escopo de equipe (RF-05, sessão 0003): persistência por usuário; tratamento de erros global segue em backlog.
- [x] **Rota de remoção ambígua** (`GET /team` com `index`) — migrar para `DELETE /team` (RF-04, sessão 0002).
- [x] **Listagem massiva** — resolvido no escopo RF-01 (sessão 0006): paginação (100/página)
      + filtro por nome com cache; busca parcial server-side da PokéAPI segue limitada
      (lista completa cacheada em memória).
- [x] **Sem tratamento de erros** — resolvido no escopo RF-18 (sessão 0018, validado em
      2026-08-09): nenhuma rota devolve 500 quando a PokéAPI falha (fragmento amigável 200)
      e handler global `error 500` cobre erros não previstos.
- [x] **Cache local de detalhes da PokéAPI** — resolvido no escopo E1 (sessões 0021/0022,
      validado em 2026-08-10): gateway `PokeApi` (interface) + adapter real `PokeApiHttp` +
      decorator `PokeApiCache` (TTL 600s / LRU máx 1000 fixos) sobre `PokeApi.instance`;
      `GET /battle`/RF-06 reutilizam detalhes/golpes sem refetch por até 10 min.
- [x] **HTML parcial sem layout único** — resolvido na sessão 0014 (RF-14): layout único
      `views/layout.erb` + navegação (Lista/Time/Batalha) + CSS externo sobre a base sakura.
- [x] **Robustez na batalha (dados da PokéAPI)** — resolvido na validação da sessão 0014:
      espécies sem `/pokemon` (urshifu/dudunsparce) e sprite `front_default` nulo não
      derrubam mais `GET /battle` (`PokeApi.find`/`evolution_chain` tolerantes).
- [ ] **Escritas não atômicas e sem idempotência (anotado 2026-08-20 — fora de
      sessão, RNF-04):** a finalização de batalha (`BattleService#finish_effects`) e a
      compra (`MartService#purchase_result`) fazem **múltiplas escritas sem transação** em
      conexões PG independentes (uma por repositório) — falha no meio deixa recompensa
      parcial/duplicada; `POST /battle/play` e `POST /mart/buy` aceitam re-submit
      (double-submit avança 2 rounds / repete o débito). Candidato a sessão: transação +
      idempotência por round.
- [ ] **Identidade/segurança (anotado 2026-08-20 — fora de sessão, RNF-04):** `?as=` em
      `server.rb` permite assumir qualquer `user_id` (sequestro de conta fora de dev);
      `SESSION_SECRET` usa fallback hardcoded no código (cookie de sessão forjável em prod);
      POSTs sem CSRF (Sinatra modular não habilita `protect_from_csrf` por padrão).
      Restringir `?as` a dev + `fail` no boot quando o secret de prod não existir.
- [ ] **Erros sem status real (anotado 2026-08-20):** handler global de erro devolve
      `status 200` — esconde falhas de monitoria/healthcheck; devolver o status correto +
      fragmento htmx de erro dedicado.
- [ ] **Race no `add` do time (anotado 2026-08-20):** `next_free_slot` é check-then-insert;
      adds concorrentes lançam `PG::UniqueViolation` não tratado (500).
- [ ] **Estado transiente e migrações destrutivas (anotado 2026-08-20):** batalha ativa
      (`BattleRegistry`, memória) e cache PokeAPI (P1) não sobrevivem a `docker compose
      down`; migrações 0003/0007 usam `TRUNCATE` (apagam dados fora de dev).
- [ ] **`pry` carregado no boot de produção (anotado 2026-08-20):** `require "pry"` em
      `server.rb` — mover para o grupo de dev.
- [ ] **Sem CI (anotado 2026-08-20):** teste+lint rodam só local; sem validação
      automatizada no push e sem healthcheck do app/banco.
- [ ] **Performance do `GET /battle` (anotado 2026-08-23, durante validação da 0040):**
      ~2min na 1ª chamada. Causa provável: a **varredura serial da banda** no
      `OpponentGenerator#rated_names` (percorre o pool chamando `detail` + `moves_for`
      por candidato até preencher a banda, sem paralelismo nem cap de varredura) +
      re-fetch de `moves_for` por oponente escolhido, somado ao warm-up da PokéAPI.
      Candidatos: paralelizar a varredura (via `Parallelizer`), cap de varredura,
      pré-computar/cachear o rating, ou pré-cachear a banda offline. Ver
      `draft-auto-battler.md` (anotações de performance). Fora de sessão (RNF-04).
- [ ] **Bug: oponente SEMPRE o mesmo por usuário (anotado 2026-08-25, confirmado no
      playtest 2):** toda batalha de um mesmo usuário repete **o mesmo time oponente
      nível 1** (mesmas espécies), tanto via "Novo confronto" quanto ao re-entrar em
      `/battle`. Causa: `BattleService#build_opponent` (`lib/battle_service.rb:64`) usa
      `Random.new(user_id.sum)` — **seed determinístico por usuário** — então o
      `OpponentGenerator` produz sempre o mesmo oponente para o mesmo usuário, a cada
      `prepare`, independente do time atual/nível (a banda varia, mas a escolha dentro
      dela é determinística). Corrigir = gerar oponente **novo a cada confronto**
      ajustando a dificuldade ao time atual (nova sessão TDD).
- [ ] **Bug: remover Pokémon com itens equipados perde os itens (anotado 2026-08-25,
      durante a preparação do playtest 2 — fora de sessão, RNF-04):** ao **remover um
      Pokémon com itens/seguráveis equipados, todos os itens somem** do estoque.
      `assigned_item`/`held_item` vivem na própria linha do `team_pokemons`;
      `TeamRepository#remove` (`lib/team_repository.rb:188`) faz o `DELETE` sem **repor**
      os itens ao inventário, e o handler `remove_team_member` (`server.rb:263`) não
      restaura. Corrigir = nova sessão (TDD): na remoção, devolver os itens equipados
      (assigned + held) ao estoque antes do delete.
- [ ] **Bug: remover do time às vezes exige clicar 2x (anotado 2026-08-25):** por vezes
      é preciso clicar 2x no botão "Remover do time" para o membro sair. `views/team.erb:40`
      usa `hx-delete="/team"` (alvo `#team-view`, `hx-include=".list-state"`,
      `hx-params="*"`); handler `remove_team_member` (`server.rb:263`) só age se
      `params[:id]`. Hipótese: 1º clique dispara mas o swap/estado não atualiza o painel
      (ou `id` chega vazio/duplicado). Investigar no QA (evento htmx, params, OOB).
- [ ] **Bug: gate da jornada fica aberto após zerar o time (anotado 2026-08-25, no QA):**
      o marcador `user_state` persiste — `JourneyService#started?` =
      `user_state.started? \|\| team >= 6` — então, mesmo com o time zerado/parcial, o
      Poke Center/Mart e o CTA "Batalhar" continuam visíveis. Decidir: o gate deve
      re-fechar quando o time ficar < 6, ou a jornada é irreversível (uma vez iniciada,
      sempre aberta)?
- [ ] **Bug/UX: busca só acha formas base (anotado 2026-08-25, no QA):** "pika" retorna
      vazio (pikachu é não-base da cadeia pichu→pikachu→raichu), "pichu" ok; "char" não
      acha charmander (starter excluído do pool de busca via `reject STARTER_SLUGS`).
      `common_candidates` (`server.rb:132`) filtra `fetch_all_names` por `@q` + rejeita
      starters + `base_form_names`. Pokémon populares/evoluídos ficam inalcançáveis pela
      busca. Decidir: incluir não-base na busca (e na listagem?) ou mostrar um aviso.
- [ ] **Ideias novas (anotado 2026-08-25, fora do fluxo — RNF-04):** (1) **Poke
      Center/Mart como janelas flutuantes** em vez de levar à tela de lista/time;
      (2) **gerenciar golpes no Poke Center e itens no Poke Mart**, reestruturando como
      gerenciamos os golpes dos pokes — esboço: **4 selects** (um por slot, cap 4);
      (3) **itens de evolução no Poke Mart** (pedras e outros) **aleatórios por rodada**;
      (4) **custo de montagem de time** — fortes caros, fracos baratos, com restrição de
      evolução muito baratos/gratuitos; (5) **"batalhar" resolve a batalha inteira**
      (fim das rodadas manuais); (6) **animações nos ataques** (de onde saiu / para onde
      foi). Ver `draft-ui-ux.md` §6 e `draft-auto-battler.md` (anotações 2026-08-25).
- [ ] **Ideias de encerramento 2026-08-25 (fora do fluxo — RNF-04):** (1) **exibir
      ranking/custo dos pokes na lista** após implementar o custo por time (M2) — a
      listagem mostra o custo/ranking (tier) de cada Pokémon para montar o time ciente
      do preço; (2) **filtros além da busca por nome** — tipo, geração, custo, ranking
      (combináveis com busca e paginação); (3) **alinhar a caixa da lista com a caixa do
      time** (colunas da `/` com largura/altura/rolagem coerentes). Ver
      `draft-auto-battler.md` (UX-2).

## Roadmap (executado em `SESSIONS.md`)

| # | Sessão | Status |
| --- | --- | --- |
| 1 | Persistir equipe em PostgreSQL (RNF-02) | Done |
| 2 | Remoção semântica (`DELETE /team`, RF-04) | Done (sessão 0002) |
| 3 | Equipe por usuário (sessão/cookie, RF-05) | Done (sessão 0003) |
| 4 | Página de detalhes (tipos, stats, evoluções) | Done (sessões 0004+0005) |
| 5 | Navegação pela sprite para o detalhe + Fechar/Voltar (RF-06) | Done (sessões 0004+0005) |
| 6 | Paginação/filtro na listagem | Done (sessão 0006) |
| 7 | Montagem de times — cap 6 + slots + sem duplicados (RF-07, base do auto-battler) | Done (sessão 0007) |
| 8 | Reordenação manual de slots (RF-08, A1) | Done (sessão 0008) |
| 9 | Modelo de batalha (BattlePokemon, RF-09, B1) | Done (sessão 0009) |
| 10 | Efetividade de tipos (B2) | Done (sessão 0010) |
| 11 | Motor de auto-batalha (B3) | Done (sessão 0011, validado em 2026-08-08) |
| 12 | Oponente automático (B4) | Done (sessão 0012, validado em 2026-08-08) |
| 13 | Batalha na web (C1) | Done (sessão 0013, validado em 2026-08-09) |
| 14 | UI: layout e estilos externos | Done (sessão 0014, validado em 2026-08-09) |
| 15 | Golpes (moves) e PP (D1) | Done (sessão 0015, validado em 2026-08-09) |
| 16 | Logs de batalha detalhados (C1) | Done (sessão 0016, validado em 2026-08-09) |
| 17 | Página de gerenciamento de time (A3) | Done (sessão 0017, validado em 2026-08-09) |
| 18 | Tratamento de erros (E2) | Done (sessão 0018, validado em 2026-08-09) |
| 19 | Refactor de produção (respiro) — 7 `rubocop:disable` de `lib/**`+`server.rb` | Done (sessão 0020, validado em 2026-08-10) |
| 20 | E1 — Cache de detalhes da PokéAPI (gateway/cache): **E1-A (interface `PokeApi` + adapter real `PokeApiHttp` + adapter fake + injeção via `settings.api`/`PokeApi.instance`)** | Done (sessão 0021, validado em 2026-08-10) |
| 20b | E1-B — decorator de cache TTL/LRU fixos (remove a memoização do `PokeApiHttp`) | Done (sessão 0022, validado em 2026-08-10) |
| 21 | D2 — XP/evolução | **D2-A (sessão 0023)** Done — validado em 2026-08-10 (suíte 292/941, lint 0): `team_pokemon_progress` + `ExperienceCurve` linear + `RewardRule` no `:finished` + `BattleEngine#result` + stats escalam + oponente escala + XP concedido na transição |
| 21b | D2-B — evolução por nível + aprendizado de golpes (species oficial) | Done (sessão 0024, validado em 2026-08-10 — suíte 328/1025, lint 0): `TeamRepository#evolve` + `#learn_move` + `EvolutionRule` puro + `next_evolutions`/`learnable_moves` no gateway + evolução/aprendizado no hook `:finished` da batalha + golpes de nível 1 na montagem |
| 21c | Seeds de validação — SeedTeam parametrizável + 3 cenários prontos (dados hardcoded) | Done (sessão 0025, validado em 2026-08-10: suíte 337/1086, lint 0) |
| 22 | D3 — Histórico/rank de batalhas | **Done (sessão 0026, validado em 2026-08-13 — suíte 367/1172, lint 0)**: `battles` + `BattleRepository` + persistência no `:finished` + `GET /history` (rank local/global) + seed `batalhas_historico` |
| 23 | Fase Eco — moeda (Eco-1), Poke Center (Eco-2), Poke Mart (Eco-3), itens em batalha (Eco-4) | **Eco-1 Done (sessão 0027, validado em 2026-08-14 — suíte 386/1216, lint 0)**: tabela `wallet` + `WalletRepository` (balance/grant upsert) + `RewardRule#money_for` (win 100/draw 50/lose 40) concedido no hook `:finished` + aviso no `battle.erb`. **Eco-2 Done (sessão 0028, validado em 2026-08-14 — suíte 428/1333, lint 0)**: HP persistente por membro (`team_pokemon_progress.hp_max/hp_current`) + carryover p/ a próxima batalha + `HealCostPolicy` (custo proporcional ao HP faltante, 0.5/Hp) + `WalletRepository#spend` + `HealService` + `POST /team/heal` + bloco Poke Center no `team.erb`. **Eco-3 Done (sessão 0029, validado em 2026-08-14 — suíte 459/1432, lint 0)**: `Item` (Dry::Struct) + catálogo estático (`ItemCatalog`, potion 20 / super-potion 50 / hyper-potion 100) + tabela `inventory` + `InventoryRepository` (add upsert) + `MartService` (compra via `WalletRepository#spend`) + `POST /mart/buy` + bloco Poke Mart no `team.erb` (catálogo/inventário/saldo) + seed `saldo_inicial`. **Eco-4-A (itens em batalha — sessão 0030, validado em 2026-08-17 — suíte 493/1525, lint 0)**: `Item#heal_amount` (potion 20 / super-potion 50 / hyper-potion 100) + `BattlePokemon#heal` (clamp no `hp_max`) + `ItemUsePolicy` automática determinística (decisão 12 — 1ª parte) + `BattleEngine` ação `:item` no half-FSM + `InventoryRepository#use` (débito min 0) + `POST /battle/play` debitando o inventário a cada round + `battle.erb` (branch `:item` + estoque `Itens:`). **Eco-4-B (item atribuído por membro — sessão 0031, validado em 2026-08-18 — suíte 524/1599, lint 0)**: coluna `assigned_item` (migração 0031, nullable) + `TeamRepository#assign_item` (limpa com vazio/nil, isolado por usuário) + `BattlePokemon#assigned_item` (from) + `ItemUsePolicy#decide` prefere o item atribuído (estoque + catálogo, decisão 12 — 2ª parte), fallback ao pool comum + motor usa o atribuído + `POST /team/:id/item` + select "Nenhum"/inventário (`×qty`) no `team_manage.erb` + `battle.erb` (`carrega: <display>`). **Eco-4-C (seguráveis — sessão 0032, validado em 2026-08-18 — suíte 559/1696, lint 0)**: `Item` ganha `stat`/`multiplier` + `ItemCatalog.can_hold` (choice-band Attack ×1.5 / choice-scarf Speed ×1.5, category `held`, price 80, decisão 13 escopo simples) + coluna `held_item` (migração 0032, nullable) + `TeamRepository#assign_held_item` (posse exigida na rota, não consome) + `BattlePokemon#held_item` + modulação de stat via decorator no `stat` (motor sem mudança) + `POST /team/:id/held-item` + select "Segurável:" no `team_manage.erb` + `battle.erb` (`segura:`) + seed `team_duelo` (forte x fraco com saldo p/ comprar). **Fase Eco concluída (Eco-1..4 — sessões 0027..0032).** |
| 24 | Candidatos futuros — D4 (draft temático), D1 (nível de aprendizado), J2 (personalização); ~~J3 (ranking S–F)~~ executado — sessão 0040, ver item 25; ~~J1 (seleção inicial)~~ movido para execução — sessão 0036, ver item 25; ~~JN-3 (itens de uso único)~~ executado — sessão 0045, ver item 25; ~~JN-3-B (equipamento por quantidade do estoque)~~ executado — sessão 0046, ver item 25; ~~JN-4 (componentes de Mart/Center)~~ executado — sessão 0047, ver item 25; ~~JN-5 (gameloop)~~ executado — sessão 0048, ver item 25 | Backlog |
| 25 | **Próximas sessões (ordem fechada em 2026-08-18)** — 1. **Respiro 2** (extrair `BattleService`/`TeamService` + split `server_test.rb`); 2. **D1 parcial** (nível de aprendizado de golpes); 3. **J1** (seleção inicial); 4. **JN-2** (golpes em lista); 5. **J3** (ranking S–F); 6. **JN-1** (telas próprias, fim do empilhamento) — depois organizar o resto (JN-3, JN-4, JN-5, J2, J4, D4) | **Respiro 2 Done (sessão 0033, validado em 2026-08-19 — suíte 559/1696, lint 0, grep `rubocop:` em `server.rb` → 0)**: `BattleService` (`prepare`/`advance`, módulos Preparation/Finalization) + `TeamService` (`manage_data`/`save_moves`/`assign_item`/`assign_held_item`) — services usam providers lambda p/ a gateway (testes trocam instância em runtime) e compartilham as mesmas instâncias de repositórios; handlers de batalha/time/itens ficam **thin**; `test/server_test.rb` (1925 linhas) fatiado em 7 arquivos por área + `battle_test_helpers.rb`. **D1 parcial executado (sessão 0034, **concluída e validada em 2026-08-19 — suíte 566/1734, lint 0** — status `Done`)**: gating do manage por nível (`TeamService` com `progression` + `manage_data` via `learnable_moves` filtrado por `level <= nível` do membro), validação gated (golpe acima do nível → aviso, não salva), nível na UI (`"<nome> — Nível N"`), união com moves salvos (legados visíveis/removíveis, sem nível quando fora do `learnable_moves`), troca manual preservada (cap 4, sem substituição automática), `BattleService#learn_moves_for_member` (`:finished`) inalterado, `available_move_names` órfão na UI (mantido no gateway), stubs migrados para `with_learnable_moves`. Depois da 0034, **0035 (P1 — performance do gateway)** foi aberta **no lugar de J1** (decisão do usuário em 2026-08-19) e **concluída e validada em 2026-08-19 — suíte 586/1787, lint 0 — status `Done`**: `Parallelizer` puro (pool threads, ordem de entrada, exceção propagada) + `PokeApiCache` thread-safe (lock por chave, dedup in-flight) + `PersistentJsonStore` em `tmp/` (TTL 7d, write-through) + choke point `http_get` (boot com `POKEAPI_CACHE_PATH`) + fonte paralela (`type_relations` 18 tipos, `OpponentGenerator` com `parallelizer:`, `BattleService` prepare/finalize com prefetch; progresso DB pré-carregado/mutações seriais). **Resultados de validação: `GET /battle` ~38s (era ~93s), 2º play ~4s.** **J1 concluído e validado pelo usuário (sessão 0036 — implementação em 2026-08-21, validação com ajustes S3 e aprovação final em 2026-08-22, status `Done`)**: fim do dropdown (`pokemon_list.erb` vira lista clicável — sprite+nome linkam `GET /pokemon/:number`, botão Add por item faz `POST /team`; sem `<select>`), pool total paginado **20/página** (`PAGE_SIZE`, enriquecimento sprite/número na rota via `find` + `Parallelizer`, contrato `paginate` intacto) **e apenas formas base** (ajuste S3 de validação em 2026-08-22: predicado `base_form?(name)` — espécie raiz da própria cadeia evolutiva — em `PokeApiParsing`/`PokeApiCache`/fake; rota filtra antes de renderizar, fail-closed), destaques **"Iniciais"** (**27** slugs de **gen 1–9** no topo quando a busca está vazia — ajuste S3 de 2026-08-22; iniciais excluídos da listagem do pool para não duplicar), tela de entrada da jornada (gate em `GET /battle`, `POST /team/heal` e `POST /mart/buy` até o time de 6 — fragmento amigável sem ação; marcador persistido em `user_state` (migração 0036) **+ regra derivada** `team.size >= 6` via `JourneyService`; `POST /team` marca ao completar o 6º; `team.erb` esconde Poke Center/Mart antes da jornada). Suíte 611/1936, lint 0. **JN-2 Done (sessão 0037, implementada e validada pelo usuário em 2026-08-22 — suíte 614/1952, lint 0)**: fim dos checkboxes de golpes no manage — `team_manage.erb` renderiza **lista clicável com marcação via htmx** (linha por golpe com `data-move`, classe `marked` nos selecionados; rótulo "— Nível N" e legados fora do learnable preservados); clique alterna via round-trip na própria rota `POST /team/:id/moves` (`draft=1` + `toggle` + hidden `moves[]` carregando o rascunho) re-renderizando sem persistir; cap de 4 aplicado no preview com aviso (`TeamService#preview_move`); rascunho inicial = golpes salvos; save/validação intactos (`save_moves`). Testes de manage/golpes fatiados em `test/team_manage_test.rb`. Suíte 614/1952, lint 0. **Onda 0 UX Done (sessão 0038, implementada e validada pelo usuário em 2026-08-22 — suíte 624/2006, lint 0; decisão do usuário de priorizar UX antes da fila)**: `alt` nos sprites e `aria-label` nos botões ▲▼, `loading="lazy"` nas listagens, evoluções do detalhe viram links (`hx-get="/pokemon/:number"` → `#pokemon`), copy pt-BR ("Adicionar ao time", "Remover do time", "Filtrar por nome"), hierarquia de notices (`notice--info/success/error`; `kind:` nos resultados de HealService/MartService e `@notice_kind` nos handlers) e indicador global de carregamento (barra fixa acionada pelos eventos htmx). Suíte 624/2006, lint 0. **JN-1 Done (sessão 0039, implementada e validada pelo usuário em 2026-08-22 — suíte 626/2017, lint 0)**: cada área virou **página própria com layout** — Lista (`GET /`), Time (`GET /team`), Batalha (`GET /battle`), Histórico (`GET /history`) — com modo fragmento quando a requisição é htmx (`HX-Request`); nav com **links reais + estado ativo** por rota (hack de limpeza do SPA único removido); htmx restrito ao intra-tela (`#team-view`, `#battle-view`, `#pokemon-detail`, `#add-status`); `POST /team` na lista retorna **mini-status local** ("Adicionado ao time."/erro) em vez do fragmento do time; membros do time sem link cruzado de detalhe; rotas `GET /battle/close` e `GET /history/close` removidas (404) e `HX-Trigger: teamRefresh` eliminado. Suíte 626/2017, lint 0. Próxima: **J3 (ranking S–F) Done (sessão 0040, concluída e validada em 2026-08-23 — suíte 649/2063, lint 0)**: `PokemonRating` (domínio puro) classifica Pokémon em S–F por stats ponderados + bônus dos moves (top-4, STAB-aware) — `rate(pokemon, moves:) → {score:, tier:}` com thresholds S≥600/A≥500/B≥420/C≥350/D≥280/F<280 — + `band_for_level(level)` (≤2→F–D; 3–5→D–C; 6–9→C–B; 10–14→B–A; ≥15→A–S); `OpponentGenerator` ganhou `rater`/`moves_fetcher`/`band` (agrupados em `options:`) filtrando nomes pela banda com **fallback puro** quando a banda esvazia; `BattleService#build_opponent` deriva a banda do nível médio do jogador (fim do sorteio puro). Retorno `score` + `tier`, sem UI. **Perf anotada (limitações):** `GET /battle` ~2min na 1ª chamada — varredura serial da banda (RNF-04, fora de sessão). Próximo: **Onda 2 UX (leitura da batalha) — sessão 0041, concluída e validada em 2026-08-23 — suíte 680/2132, lint 0**: `Move#pp_max` (default = pp, preservado no `use_move`) + `FighterPresenter` (linha do lutador: HP/PP percent+tier, itens) + `BattleLogPresenter` (últimas 3 rodadas, mais recente no topo) + partial único `_fighter_panel.erb` (Seu Time/Oponente sem duplicação) com barras `hp-bar`/`pp-bar` (tokens do design system) + log com rótulo por rodada + `hx-indicator` local no botão Jogar; ajuste S3 de validação — layout em 3 colunas em tela cheia (Seu Time esq, controles centralizados + log centro, Oponente dir). **Onda 1 UX (jornada visível) — sessão 0042, concluída e validada em 2026-08-24 — suíte 689/2184, lint 0 (Caminho B: Lista+Time unificados)**: `GET /` virou **página única de 2 colunas em largura cheia** (busca + lista à esquerda, painel do time com contador "Time n/6" + membros à direita); **página `/team` removida** — `GET /team` sem `HX-Request` → 404, fragmento htmx interno preservado (alvo `#team-view`); **nav sem link "Time"**; `team_page.erb` removido; **estados do botão Add** (default / "No time ✓" desabilitado / cheio desabilitado) via `@team_names`/`@team_full` expostos na rota da listagem; add `POST /team` devolve mini-status **+ `#team-view` com `hx-swap-oob`**; **ajustes S3 de validação** — add/remove também re-renderizam `#pokemon-list` via OOB (`oob_pokemon_list`, offset/q via `hx-include=".list-state"`: remover de time cheio reativa os botões, adicionar o 6º desabilita) e link "Gerenciar time" em `<p class="team-tools">`; `body.page-list` com `max-width: none` + grid `list-team-grid`/`team-column`. Anotado (fora de sessão): flakiness `too many clients` na suíte com o container `web` ativo — workaround `docker compose stop web`. Depois: **Onda 3 UX (estrutura) — sessão 0044, refinada em 2026-08-24, implementada em 2026-08-24 e VALIDADA pelo usuário em 2026-08-24 (suíte 694/2200, lint 0)**: grade **uniforme de 6 colunas com páginas cheias e paginação on-demand** — `PAGE_SIZE` 36 = grid 6×6, página 1 = 27 iniciais + 9 comuns (sem título), páginas 2+ = 36 comuns, cada página carrega só o próprio lote (scan `base_form?` em batchs, "Página X" sem total) + largura cheia do Histórico (`body.page-history`). **Estabilidade:** conexão PG por thread (fim do "message type while idle" sob Puma), timeout 15s na gateway, banco de teste separado `pokedex_test` (suíte verde com `web` ativo). Depois: **JN-3 (itens de uso único) — sessão 0045, concluída e VALIDADA pelo usuário em 2026-08-24 (suíte 701/2222, lint 0)**: regra de **1 uso de item curativo por Pokémon por batalha** (`@items_used_by_member` no `BattleEngine`, bloqueio de novo uso do mesmo membro — pool comum e item atribuído) + badge "já usou item" por membro no painel do lutador (`FighterPresenter#item_used?`). **Anotado (JN-3-B, fora da fila):** equipamento não respeita a quantidade do estoque — regra: equipar debita, itens consumidos na batalha (poke fica sem), seguráveis permanecem até desequipar, option desabilitado + qtd livre. Depois: **JN-3-B (equipamento por quantidade) — sessão 0046, concluída e VALIDADA pelo usuário em 2026-08-24 (suíte 718/2294, lint 0)**: itens/seguráveis por poke (1 de cada), **equipar debita do estoque**, desequipar repõe, trocar repõe o antigo e debita o novo, re-equipar o mesmo item não debita; item atribuído consumido em batalha **não debita de novo** e **limpa o `assigned_item`** (`TeamItemOperations`, `battle_items` + `debit_used_items` por `attacker_index`); UI com quantidade livre + option `disabled` ×0. **Correções de UI na validação:** `reload_manage_state` no POST + fix de scroll. Depois: **JN-4 (componentes de Mart/Center) — sessão 0047, concluída e VALIDADA pelo usuário em 2026-08-24 (suíte 724/2329, lint 0)**: blocos de `views/team.erb` viram partials reutilizáveis `_mart.erb`/`_center.erb` no painel do time (`#team-view`), sem rotas/páginas novas — **cura completada** (HP atual/máx por membro + **custo total antecipado** via `HealService#preview_cost`; botão Curar `disabled` quando já curado ou saldo insuficiente) e **compra completada** (**preço × quantidade comprável = saldo/preço**, ex. "×5"; botão `disabled` quando saldo < preço). `team_hp.erb` absorvido pelo `_center.erb` (removido). Depois: **JN-5 (gameloop — circuito por CTAs) — sessão 0048, refinada em 2026-08-25, implementada em 2026-08-25 e VALIDADA pelo usuário em 2026-08-25 (passos 1–2, suíte 727/2344, lint 0; C1–C5 ok; decisão do usuário: **fluxo guiado por CTAs**, sem páginas/rotas novas)**: o circuito montagem → batalha → Poke Center/Poke Mart → repete vira explícito — fim de batalha mostra CTAs Poke Center/Poke Mart (levam à Lista `/`, onde `#team-view` mostra os partials) + botão "Novo confronto" mantido; painel do time pós-jornada ganha CTA **Batalhar** (`/battle`); `nav` permanece `Lista/Batalha/Histórico` (sem reordenação). **Anotações 2026-08-25 (RNF-04):** Center/Mart como janelas flutuantes + gerência de golpes/itens (4 selects); itens de evolução no Mart aleatórios por rodada; custo de montagem de time; "batalhar" resolve a batalha inteira; animações nos ataques; bug "novo confronto" repete oponente (seed determinístico por user). Depois: organizar o resto (J2, J4, D4, P2 e as novas anotações) |

## Ideias de auto-battler (anotadas — ainda NÃO refinadas)

> Regra RNF-04: escopos grandes são anotados aqui e só viram sessão **após** a sessão
> corrente ser concluída e validada. A 0007 (montagem de times) é `Done` (2026-08-08)
> — os itens abaixo passam a poder virar sessões. **A1 (reordenação de slots) virou
> RF-08/sessão 0008; B1 (modelo de batalha) virou RF-09/sessão 0009; D1 (golpes/PP)
> virou RF-15/sessão 0015; melhores logs de batalha virou RF-16/sessão 0016.**
> Refinamento de UI/layout volta ao roadmap como 0009+.

- **Melhores logs de batalha (C1):** mostrar **qual Pokémon bateu em qual**, com qual
  golpe e dano causado (hoje o log só mostra o lado atacante). Anotado em 2026-08-09
  durante a validação da sessão 0015. **Virou RF-16/sessão 0016, `Done` (validado em
  2026-08-09).**
- **A3 — Página própria de gerenciamento de time:** escolher os **golpes de cada
  Pokémon** e a **posição no time** em página dedicada (cruza com A1 — slots — e D1 —
  golpes). Anotado em 2026-08-09 durante a validação da sessão 0015. **Virou
  RF-17/sessão 0017, `Done` (validado em 2026-08-09).**

- **Game loop (auto-battler):** combate automático por turnos usando os 6 slots do time
  como ordem de combate; stats (RF-06) e tipos como base de dano/efetividade; estado de
  HP/status persistido ou em memória a definir em refinamento próprio.
  **B1 (modelo de batalha) e B2 (efetividade de tipos) `Done` (sessões 0009/0010);
  B3 (motor de auto-batalha) `Done` (sessão 0011, validado em 2026-08-08;
  ver draft-auto-battler.md).**
- **Layout/estilos externos:** extrair layout, navbar e estilos compartilhados
  (a antiga sessão 0007-UI volta ao backlog como 0009+).

### Candidatas do draft para a próxima sessão (levantamento de roadmap, 2026-08-09)

> **E2 (tratamento de erros) virou RF-18/sessão 0018, `Done` (validado em 2026-08-09).**
> **Refatoração de testes (respiro) virou sessão 0019, `Done` (validado em 2026-08-10)** —
> `rubocop:disable` removidos dos 6 arquivos de teste via `TestSupport`/`TestDatabase`/
> `PokeApiStub` genérico + orçamentos em `test/.rubocop.yml` (métricas do root mantidas).
> **Refactor de produção (respiro) virou sessão 0020, `Done` (validado em 2026-08-10)** —
> os 7 `rubocop:disable` de `lib/**` + `server.rb` removidos via módulos por área
> (suíte 222/778 + lint 0 preservados, sem mudança de comportamento).
> **E1 (gateway/cache) virou sessão 0021 — E1-A, `Done` (validado em 2026-08-10):** interface
> `PokeApi` (`lib/gateways/poke_api.rb`) + adapter real `PokeApiHttp` + adapter fake nos testes
> (`PokeApiFake`) + injeção (`set :api, PokeApi.instance` em `server.rb`, domínio por default
> `PokeApi.instance`); static `lib/poke_api.rb` e `PokeApiStub.stub_singleton` removidos
> (suíte 239/821 + lint 0; `grep 'PokeApi\.[a-z]' lib server.rb` → só `PokeApi.instance`).
> **E1-B (decorator de cache TTL/LRU fixos sobre o gateway) fica para a sessão 0022.**
> **Roadmap fechado em 2026-08-10 (decisão do usuário):** o respiro de produção
> (sessão 0020) foi executado e validado em 2026-08-10 com suíte 222/778 + lint 0
> preservados, sem mudança de comportamento. Em sequência depois: **E1 (cache de
> detalhes da PokéAPI)** → **D2
> (XP/evolução)** → **D3 (histórico/rank)** → **Fase Eco (Eco-1..4)** → candidatos futuros
> (D4, D1, J1/J2/J3). Visão fechada de D2: pokémon sempre 1ª evolução nível 1 na montagem,
> ganham XP a cada batalha, aprendem movimentos e evoluem; oponente no mesmo nível do
> jogador. Ver `draft-arquitetura-design-patterns.md` (seções 2 e 8) e a tabela do
> Roadmap acima.