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
- [ ] **Sem tratamento de erros** — nome inválido, rate-limit da PokéAPI, time sem membros, duplicados.
- [ ] **HTML parcial sem layout único** — extrair layout/navbar/estilos.

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
| 8 | UI: layout e estilos externo | Backlog |

## Ideias de auto-battler (anotadas — ainda NÃO refinadas)

> Regra RNF-04: escopos grandes são anotados aqui e só viram sessão **após** a sessão
> corrente ser concluída e validada. A 0007 (montagem de times) é `Done` (2026-08-08)
> — os itens abaixo passam a poder virar sessões. Refinamento de UI/layout volta ao
> roadmap como 0008+.

- **Game loop (auto-battler):** combate automático por turnos usando os 6 slots do time
  como ordem de ação; stats (RF-06) e tipos como base de dano/efetividade; estado de
  HP/status persistido ou em memória a definir em refinamento próprio.
- **Reordenação de slots:** mover Pokémon manualmente entre slots (a 0007 só reindexa
  na remoção; "manter lacunas" e "mover para slot arbitrário" são variantes futuras).
- **Layout/estilos externos:** extrair layout, navbar e estilos compartilhados
  (a antiga sessão 0007-UI volta ao backlog como 0008+).