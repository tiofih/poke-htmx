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
| 21b | D2-B — evolução por nível + aprendizado de golpes (species oficial) | Implementado (sessão 0024, aguardando validação do usuário — suíte 327/1018, lint 0): `TeamRepository#evolve` + `#learn_move` + `EvolutionRule` puro + `next_evolutions`/`learnable_moves` no gateway + evolução/aprendizado no hook `:finished` da batalha |
| 22 | D3 — Histórico/rank de batalhas | Planejada (após D2) |
| 23 | Fase Eco — moeda (Eco-1), Poke Center (Eco-2), Poke Mart (Eco-3), itens em batalha (Eco-4) | Planejada (após D3) |
| 24 | Candidatos futuros — D4 (draft temático), D1 (nível de aprendizado), J1 (seleção inicial), J2 (personalização), J3 (ranking S–F) | Backlog |

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