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

### RF-03 — Formar equipe — `Draft`
- Formulário envia `hx-post /team` com `pokeName` (nome do Pokémon), renderizando o fragment `#team`.
- Exibir cada membro da equipe com sprite e nome, e um botão "Remove from Team".

**Critérios de aceite:**
- [ ] `POST /team` com `pokeName=pikachu` persiste o Pokémon na equipe (Postgres) e responde o fragment atualizado.
- [ ] O fragmento `#team` lista, para cada membro, sprite, nome e botão "Remove from Team".

### RF-04 — Remover da equipe — `Completo` na implementação atual / em refino
- Botão dispara `hx-get /team?index=<idx>` com alvo `#team`.
- Remover o Pokémon na posição indexada e re-renderizar a equipe.

**Critérios de aceite:**
- [ ] A ação de remoção é verbosa e explícita (refinar: `DELETE /team/:key` em sessão futura).
- [ ] Após a remoção, o fragmento `#team` não contém mais o Pokémon removido.

## Requisitos Não-Funcionais

### RNF-01 — Arquitetura — `Executado`
- Aplicação server-rendered; **sem JavaScript customizado** — toda interação via htmx.
- Backend consome a PokéAPI externa via Faraday.

### RNF-02 — Estado / Persistência — `Approved`
- A sprint pretende trocar o estado em memória por **PostgreSQL** (gem `pg`, sem ORM).
- Ligar via `DATABASE_URL` (ex.: `postgres://pokedex:pokedex@db:5432/pokedex`).
- Servidor `db` no `docker-compose.yml`, banco `pokedex`.

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

## Limitações Conhecidas / Pontos de Refinamento

- [x] **Estado efêmero e global** — fase atual do roadmap: substituir memória por Postgres (RNF-02).
- [ ] **Rota de remoção ambígua** (`GET /team` com `index`) — migrar para `DELETE /team/:key` (RF-04).
- [ ] **Listagem massiva** — `limit=100000` lento e sem paginação/filtro (RF-01).
- [ ] **Sem tratamento de erros** — nome inválido, rate-limit da PokéAPI, time sem membros, duplicados.
- [ ] **HTML parcial sem layout único** — extrair layout/navbar/estilos.

## Roadmap (executado em `SESSIONS.md`)

| # | Sessão | Status |
| --- | --- | --- |
| 1 | Persistir equipe em PostgreSQL (RNF-02) | Prevista |
| 2 | Remoção semântico (`DELETE /team/:key`) | Prevista |
| 3 | Equipe por usuário (sessão/cookie) | Backlog |
| 4 | Página de detalhes (tipos, stats, evoluções) | Backlog |
| 5 | Paginação/filtro na listagem | Backlog |
| 6 | UI: layout e estilos externo | Backlog |