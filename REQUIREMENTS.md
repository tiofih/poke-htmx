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
| HTTP client | Faraday (`lib/poke_api.rb`) |
| Modelo | `Dry::Struct` (`lib/pokemon.rb`) |
| Persistência | PostgreSQL (gem `pg`, sem ORM) |
| Testes | Minitest |
| Frontend | htmx 2.0.3 (CDN, `views/index.erb`) |
| Servidor | Puma |
| Infra | Docker / docker-compose (porta 3000) |

## Requisitos Funcionais

### RF-01 — Listar Pokémon — `Approved`
- Exibir um `<select>` com todos os Pokémon disponíveis na PokéAPI (versão `limite=100000` atual, já pontuado em RNF-05).
- O valor de cada opção é o nome do Pokémon.

**Critérios de aceite:**
- [ ] Ao acessar `GET /`, a página contém um elemento `<select name="name" id="pokemons" hx-get="/pokemon">`.
- [ ] O `<select>` contém uma opção para cada Pokémon retornado pela PokéAPI, com `value` = nome do Pokémon.

### RF-02 — Visualizar Pokémon — `Draft`
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

### RF-06 — Página de detalhes — `Em refinamento` (sessão 0004, refinamento validado)
- Ao clicar no nome/sprite de um Pokémon (na listagem `#pokemon` ou na equipe),
  renderizar no alvo `#pokemon` os **detalhes**: sprite, nome, tipos, stats base e evoluções.
- Interação 100% htmx (RNF-01); o botão "Add to Team" é preservado no detalhe.
- A rota de detalhe usa o **id único da API** (`GET /pokemon/:poke_id`), mais estável que o nome.

**Critérios de aceite:**
- [ ] `GET /pokemon/:poke_id` responde o fragmento de detalhe (sprite, nome, tipos, stats, evoluções).
- [ ] Tipos: exibe todos os tipos do Pokémon (ex.: pikachu → electric; bulbasaur → grass, poison).
- [ ] Stats: exibe os 6 base stats com nome e valor (HP, Attack, Defense, Sp.Atk, Sp.Def, Speed).
- [ ] Evoluções: exibe a cadeia de evolução (sprite + nome) via species → evolution_chain; sem evolução não quebra.
- [ ] Nomes em `pokemon.erb` e `team.erb` clicáveis com `hx-get="/pokemon/:poke_id"` (alvo `#pokemon`).
- [ ] Sprites em `pokemon.erb` e `team.erb` clicáveis com `hx-get="/pokemon/:poke_id"`
      (alvo `#pokemon`) — **sem** `<input type="image">` (não submete os forms de equipe) (sessão 0005).
- [ ] Fragmento de detalhe mantém o form `hx-post /team` (Add to Team, RF-03).
- [ ] `GET /pokemon?name=` (fragment add atual) permanece funcional.

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

## Limitações Conhecidas / Pontos de Refinamento

- [x] **Estado efêmero e global** — resolvido no escopo de equipe (RF-05, sessão 0003): persistência por usuário; tratamento de erros global segue em backlog.
- [x] **Rota de remoção ambígua** (`GET /team` com `index`) — migrar para `DELETE /team` (RF-04, sessão 0002).
- [ ] **Listagem massiva** — `limit=100000` lento e sem paginação/filtro (RF-01).
- [ ] **Sem tratamento de erros** — nome inválido, rate-limit da PokéAPI, time sem membros, duplicados.
- [ ] **HTML parcial sem layout único** — extrair layout/navbar/estilos.

## Roadmap (executado em `SESSIONS.md`)

| # | Sessão | Status |
| --- | --- | --- |
| 1 | Persistir equipe em PostgreSQL (RNF-02) | Done |
| 2 | Remoção semântica (`DELETE /team`, RF-04) | Done (sessão 0002) |
| 3 | Equipe por usuário (sessão/cookie, RF-05) | Done (sessão 0003) |
| 4 | Página de detalhes (tipos, stats, evoluções) | Em refinamento (sessão 0004) |
| 5 | Navegação pelo sprite para o detalhe (RF-06) | Em refinamento (sessão 0005) |
| 6 | Paginação/filtro na listagem | Backlog |
| 7 | UI: layout e estilos externo | Backlog |