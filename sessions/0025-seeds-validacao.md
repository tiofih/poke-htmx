# Sessão 0025 — Seeds de validação (parametrizável + cenários prontos)

## Status

| Fase | Status |
| --- | --- |
| Refinamento | Concluído — decisões do usuário em 2026-08-10 (SeedTeam parametrizável + 3 cenários prontos + rake db:seed, dados hardcoded sem PokéAPI) |
| Implementação | Concluída — passos 1–3, suíte 336/1078, lint 0 (2026-08-10) |
| Validação | Concluída — validado pelo usuário em 2026-08-10 (suíte 337/1086, lint 0; sprites corrigidos para front_default; oponente fixo nível 1 determinístico por user_id; helper ?as= funcional) |

---

## 1. Objetivo

Criar **seeds de banco** para acelerar a validação manual de cenários: times
persistidos no Postgres com níveis/XP/moves pré-definidos, sem dependência da
PokéAPI (dados hardcoded). A base é uma classe parametrizável (`SeedTeam`) +
scripts prontos que a invocam com times específicos, disparados via `rake db:seed`.

**Regra do draft (2026-08-10):** todo refinamento deve incluir seeds nos cenários de
validação para acelerar a verificação manual.

**Fora de escopo:** alterar `db:setup`, migrações de schema, PokéAPI, UI ou
comportamento de batalha.

## 2. Contexto (estado atual — pós-0024)

- Suíte base **328 runs/1025 asserts**, lint 0 (D2-B, 2026-08-10).
- Tabelas: `team_pokemons` (`id, user_id, name, sprite, number, slot, moves TEXT[]`) +
  `team_pokemon_progress` (`team_pokemon_id PK FK, level, xp`).
- `TeamRepository` (`lib/team_repository.rb`): `add` insere em `team_pokemons` e
  automaticamente cria a linha em `team_pokemon_progress` (nível 1, XP 0) — a seed
  precisa **sobrescrever** nível/XP após o insert (ou usar SQL direto), pois `add`
  sempre inicia no nível 1.
- `ProgressionRepository#grant` recalcula nível via `ExperienceCurve`
  (`level * 100` por nível; `level_for_xp` usa `cumulative_xp_for(level)`).
- `EvolutionRule.next_stage` usa `evolutions: [{number:, name:, min_level:}]` para
  decidir se o Pokémon evolui (nível atual >= `min_level` do próximo estágio).
- Nenhuma seed ou `db:seed` existe atualmente; o `Rakefile` tem apenas `db:setup`.
- O app roda em Docker (porta 3000); o banco acessível via `DATABASE_URL`.
- Para validação manual, hoje é necessário: abrir o app, buscar Pokémon um por um,
  adicionar ao time, batalhar repetidamente para subir nível — as seeds eliminam
  esse grind.

**Curva de XP (`ExperienceCurve`):**
| Nível | XP acumulado para atingi-lo | XP para estar "quase lá" |
| --- | --- | --- |
| 1 | 0 (início) | — |
| 16 | `cumulative_xp_for(15)` = 12000 | 11999 (nível 15) |
| 17 | `cumulative_xp_for(16)` = 13600 | 13599 (nível 16) |
| 36 | `cumulative_xp_for(35)` = 63000 | 62999 (nível 35) |

**Cadeias evolutivas (PokéAPI, dados oficiais — nível mínimo `level-up`):**
| Estágio | Número | Evolui para | Número | Nível mín. |
| --- | --- | --- | --- | --- |
| charmander | 4 | charmeleon | 5 | 16 |
| charmeleon | 5 | charizard | 6 | 36 |
| squirtle | 7 | wartortle | 8 | 16 |
| wartortle | 8 | blastoise | 9 | 36 |
| bulbasaur | 1 | ivysaur | 2 | 16 |
| ivysaur | 2 | venusaur | 3 | 32 |

## 3. Arquitetura

```
db/
  seeds/
    team_basico.rb        # Time inicial: 6 starters nível 1
    team_evolucao.rb      # Time para validar evolução: níveis próximos
                           #   dos thresholds + cadeias curtas
    team_niveis_mistos.rb # Time em níveis variados (1, 5, 10, 20, 35, 50)
lib/
  seed_team.rb            # Classe parametrizável (user_id, db_url, members[])
scripts/
  seed                    # Script de conveniência: docker compose exec web rake db:seed
Rakefile                  # + task db:seed (chama os scripts de db/seeds/)
```

### SeedTeam (classe parametrizável)

```ruby
seed = SeedTeam.new(user_id: "seed-validation", db_url: ENV["DATABASE_URL"])
seed.add_member(
  name: "charmander", sprite: "...", number: 4, slot: 1,
  moves: ["ember", "scratch", "growl", "smokescreen"],
  level: 15, experience: 11999
)
```

- Insere direto via SQL no `team_pokemons` + `team_pokemon_progress` (nível/XP
  customizados — não usa `TeamRepository#add` que força nível 1).
- `#add_member` faz INSERT em transação: uma linha em `team_pokemons` + uma em
  `team_pokemon_progress` com o team_pokemon_id retornado.
- `#clear!` faz TRUNCATE CASCADE das duas tabelas antes de popular.
- Dados **hardcoded** por membro (name, sprite, number, moves) — sem PokéAPI.

### Scripts prontos (`db/seeds/`)

Cada script é um método/classe que chama `SeedTeam` com um cenário específico:

| Script | Cenário |
| --- | --- |
| `team_basico.rb` | 6 iniciantes nível 1 (charmander, squirtle, bulbasaur, pikachu, eevee, dratini) — time pronto para começar |
| `team_evolucao.rb` | 6 Pokémon com níveis próximos das evoluções: charmander 15 (→16), charmeleon 35 (→36), squirtle 15 (→16), bulbasaur 15 (→16), ivysaur 31 (→32), pikachu 30 (→ raichu pedra — não evolui) |
| `team_niveis_mistos.rb` | 6 Pokémon em níveis variados: 1, 5, 10, 20, 35, 50 — para validar escalonamento de stats |

### `rake db:seed`

- Por padrão, roda **todos** os scripts em `db/seeds/` em ordem (cada um para um
  `user_id` diferente: `seed-basic`, `seed-evol`, `seed-mixed`).
- Aceita `USER_ID=xxx` para popular um único usuário; aceita `SEED=team_basico` para
  rodar um script específico.

### Script `./scripts/seed`

Atalho de conveniência: `docker compose exec web rake db:seed`.

## 4. Critérios de aceite

### SeedTeam (classe)

- [ ] `SeedTeam.new(user_id:, db_url:)` — aceita user_id e URL do banco (default
      `ENV["DATABASE_URL"]`).
- [ ] `#add_member(name:, sprite:, number:, slot:, moves:, level:, xp:)` — insere
      uma linha em `team_pokemons` + uma em `team_pokemon_progress` com
      `team_pokemon_id` vinculado, em transação; `moves` default `[]`, `level`
      default 1, `xp` default 0.
- [ ] `#clear!` — TRUNCATE CASCADE de `team_pokemons` e `team_pokemon_progress`
      **apenas** para o `user_id` da seed (não limpa outros usuários).
- [ ] Insert não viola constraints do schema (slot 1..6, UNIQUE user_id+number,
      UNIQUE user_id+slot, FK team_pokemon_id); dados inválidos levantam erro do PG
      (não faz validação própria).
- [ ] Suíte verde + lint 0; commit a cada green.

### Scripts prontos (`db/seeds/`)

- [ ] `team_basico.rb` — 6 Pokémon nível 1 (charmander #4, squirtle #7, bulbasaur #1,
      pikachu #25, eevee #133, dratini #147), cada um com sprite hardcoded e 1–2
      moves de nível 1 típicos.
- [ ] `team_evolucao.rb` — 6 Pokémon com níveis próximos de evolução (nível/XP da
      tabela da seção 2), moves de nível baixo.
- [ ] `team_niveis_mistos.rb` — 6 Pokémon em níveis 1/5/10/20/35/50.
- [ ] Cada script aceita `user_id:` e `db_url:` como parâmetros e chama `SeedTeam`.

### `rake db:seed`

- [ ] `rake db:seed` sem args roda todos os scripts de `db/seeds/` (3 usuários).
- [ ] `rake db:seed USER_ID=meu-id` popula um único usuário com o time básico (default).
- [ ] `rake db:seed SEED=team_evolucao USER_ID=meu-id` roda um script específico.
- [ ] Task não quebra se a tabela não existir (avisa e pula — não faz `db:setup`).
- [ ] `./scripts/seed` executa o rake no container.

### Garantias (RNF)

- [ ] Suíte completa verde (baseline 328/1025 preservado) + novos testes; lint 0 em
      todo green; commit por passo; 0 regressão RF-01..RF-18/D2-A/D2-B.
- [ ] Sem novas gems; sem dependência da PokéAPI (dados hardcoded, sem rede nos
      testes); sem `rubocop:disable`.
- [ ] `clear!` não afeta dados de outros `user_id` (isolamento RF-05).
- [ ] `REQUIREMENTS.md` (seeds → seção própria ou novo RF), `SESSIONS.md` (tabela
      0025 em fase 2), `draft-arquitetura-design-patterns.md` (regra de seeds
      atendida para esta sessão) atualizados no mesmo escopo.

## 5. Decisões de refinamento

- **Dados hardcoded:** sprites, nomes e números fixos — sem dependência da PokéAPI.
  Seeds rodam offline e são determinísticas.
- **SQL direto:** `SeedTeam` insere direto no banco (não usa `TeamRepository#add`)
  porque `add` sempre inicia progresso no nível 1.
- **`clear!` por `user_id`:** TRUNCATE só do próprio user_id da seed — não afeta
  outros usuários.
- **3 cenários, 3 user_ids:** cada script gera um time diferente → 3 times
  simultâneos no banco, cada um acessível por um user_id fixo
  (`seed-basic`, `seed-evol`, `seed-mixed`).
- **Não usa `TeamRepository`:** a seed é inserção pura de dados de validação — não
  passa pelas regras de negócio (cap, duplicado), pois o script garante dados válidos.
- **Moves hardcoded:** nomes de golpes que existem nos dados oficiais (ex: "ember",
  "scratch", "tackle", "water-gun") — o app os resolve via `PokeApi.move` quando a
  batalha começa (cache cobre).
- **Sprites hardcoded:** URLs de placeholder ou caminho vazio — o detalhe do Pokémon
  puxa da PokéAPI no app.

## 6. Plano TDD (passos)

> Cada passo = `red` → `green` (lint 0 + suíte completa verde) → commit.

| Passo | Escopo (red → green) | Verificação |
| --- | --- | --- |
| 0 | **Refinamento** — este arquivo com critérios e plano fechados | commit `Sessao 0025: refinamento concluido — seeds de validacao (SeedTeam parametrizavel + 3 cenarios prontos + rake db:seed), dados hardcoded sem PokeAPI` |
| 1 | **`SeedTeam`:** `red` — `seed_team_test.rb` novo falha (classe inexistente): insere membro com nível/XP/moves customizados; 6 membros com slots 1..6; `clear!` limpa só o user_id próprio; transação garante FK progress → team. `green` — implementar | suíte verde + lint 0, commit `Passo 1:` |
| 2 | **Scripts prontos + `rake db:seed`:** `red` — teste de integração falha (task ausente): `rake db:seed` roda todos os scripts; `USER_ID`/`SEED` filtra; `./scripts/seed` executa no container; cada script popula o time esperado. `green` — scripts + task + atalho | suíte verde + lint 0, commit `Passo 2:` |
| 3 | **Docs:** `REQUIREMENTS.md` (seeds documentadas), `SESSIONS.md` (0025 em fase 2), `draft-arquitetura-design-patterns.md` (regra atendida — nota de seeds resolvida) | suíte verde + lint 0, commit `Passo 3:` |
| — | **Fase 2 concluída** → **PARAR** e aguardar validação do usuário (fase 3). | |

## 7. Validação (executada pelo usuário)

**Concluída em 2026-08-10.** O usuário validou:
- `./scripts/seed` popula 3 times com sprites corretos (front_default)
- `?as=seed-evol` carrega time de evolução; batalha → evolução visível nos painéis e no `#team`
- Oponente fixo (determinístico por user_id) e nível 1
- Sprites carregam corretamente após `./scripts/seed`

**Ajustes pós-validação:**
- Sprites migrados de `official-artwork` para `front_default` (endpoint padrão da PokéAPI)
- Oponente com `rng: Random.new(current_user.sum)` + `level: 1` fixo
- `HX-Trigger: teamRefresh` para atualizar `#team` após evolução
- `rebuild_display_team` no engine para painéis refletirem pokémon evoluído
- Helper `?as=` no `before` filter para trocar de usuário seed

## 8. Observações

- **Próxima sessão:** D3 — histórico/rank de batalhas (item 22 do roadmap).
- Os dados hardcoded (sprites) são placeholders — o app os atualiza ao carregar o
  detalhe do Pokémon (`GET /pokemon/:poke_id`).
- Se a PokéAPI estiver offline, o time aparece mas pode falhar ao abrir detalhe
  ou batalha (comportamento existente — RF-18 cobre com mensagens amigáveis).
- Sprites vazias não quebram o `team.erb` (já tratado desde RF-14/validação 0014).
