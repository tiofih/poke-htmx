- T1: Corrigir flake order-dependente de SeedScriptsTest (team_row sem filtro de user_id)
  accept: `TestDatabase.team_row(name)` filtra por `user_id` (ou usa `team_id`) e `test/seed_scripts_test.rb` passa sob qualquer seed da suíte completa; rodar `./scripts/test` 3x com seeds distintos sem falha do arquivo.
