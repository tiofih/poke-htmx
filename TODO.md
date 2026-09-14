- T1: 0086: regras legadas de HP/dano `.arena[data-jx-hp|hit|dmg|ko="on"]` (`public/style.css:968,975,980,992`) sao mortas — os atributos sao estaticos no `.arena` e o gate vivo e `:has(> #jx-gates[...])` (o teste ainda as exige)
  accept: as regras sao removidas com o teste que as exige ajustado, ou religadas ao carrier vivo `#jx-gates`; `./scripts/test` + `./scripts/lint` verdes
- T2: 0086: alinhar os nomes de teste citados no §7 da sessao — `test_log_tiered_pacing_delays`, `test_effect_sync_step_delay` e `test_aggregates_off_aspect_timed` nao existem (divergencia pre-existente)
  accept: o §7 cita os nomes reais dos testes que provam cada criterio, ou marca explicitamente as divergencias como so-doc
