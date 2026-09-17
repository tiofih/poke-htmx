- T1: Corrigir flake order-dependente de SeedScriptsTest (team_row sem filtro de user_id)
  accept: `TestDatabase.team_row(name)` filtra por `user_id` (ou usa `team_id`) e `test/seed_scripts_test.rb` passa sob qualquer seed da suíte completa; rodar `./scripts/test` 3x com seeds distintos sem falha do arquivo.
- T2: Registrar/atenuar o db:setup destrutivo (0003/0007 TRUNCATE team_pokemons CASCADE apaga o time no pokedex a cada setup)
  accept: `docs/draft-backlog.md` (ou limitações do REQUIREMENTS) documenta que `rake db:setup` e `TestDatabase.setup!` truncam `team_pokemons`/`team_pokemon_progress` em toda execução; proposta de remediação registrada (ex.: guard/once para migrações destrutivas).
- T3: Reindentar o `<p class="rewards">` (4 espacos a mais) em battle.erb e _strike_result.erb
  accept: o `<p class="rewards">` em `views/battle.erb:126-128` e `views/_strike_result.erb:23-25` fica no nível de indentação do `if` que o envolve; e2e `battle-log.spec.ts` segue 9 passed e `./scripts/lint` 0 offenses.
- T4: Trocar o assert frouxo (OR) de battle_routes_test.rb:793-794 por string exata
  accept: `test/battle_routes_test.rb:793-794` usa `assert_equal`/`assert_includes` da copy exata (trocar vitória por derrota passa a falhar) e a suíte completa segue verde.
- T5: Atualizar o CTA Batalhar (gate + hint) do cabecalho via OOB nas rotas que mexem no time
  accept: Extrair CTA+hint de `views/layout.erb:36-37` para um slot com id estavel (`#cta-slot`) + partial, e anexar o fragmento `hx-swap-oob="outerHTML"` nas respostas de `POST /team` (add/budget-blocked), `DELETE /team`, `POST /team/heal`, `POST /journey/restart` e `/mart/buy|sell`; teste Minitest novo assevera o estado do CTA no corpo do POST (nao so no GET /) e a suite+e2e seguem verdes sem mudanca nos 4 estados da pill/0083.
