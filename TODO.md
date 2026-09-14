- T1: 0086: corrigir mensagem falsa sobre htmx no assert de test/battle_strike_routes_test.rb:90
  accept: A mensagem deixa de afirmar "htmx 2.0.3 sem delete" (delete é swap válido do htmx 2.x); `./scripts/test test/battle_strike_routes_test.rb` verde
- T2: 0086: resolver cobertura de review dos Passos 21-28 (lacuna em reviews/) ou registrar decisão de escopo
  accept: Existe arquivo em reviews/ cobrindo 8542a33..5cf6c4a, ou a sessão/review registra explicitamente a decisão de não revisar 21-28 antes do sign-off
- T3: 0086: alinhar §6 (lista só Passos 0-4 e 23-32) com o Status (1-32)
  accept: A tabela do §6 da sessão 0086 cobre os Passos 1–32, ou a lacuna (Passos 5–22 sem linha) fica registrada explicitamente no arquivo
- T4: 0086: triar working tree sujo (cassettes VCR + config e2e + docs untracked) sem commitar lixo
  accept: Cada item pendente (cassettes, e2e/playwright.config.ts, test/pokemon_routes_test.rb, ARCHITECTURE.md/GDD.md/PROJECT.md, reviews/, gotchas/, docs/type-effects-lab.html) está commitado ou explicitamente descartado/ignorado
