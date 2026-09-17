-- 0037: sessao 0089 (D2/D3) - remove o estado morto `user_state`.
-- A criacao (0036) saiu do historico: a tabela era escrita a cada add e nunca lida
-- (o gate da jornada e derivado de team >= 6). Idempotente: 2a execucao e no-op.
-- Nao toca em nenhuma outra tabela.

DROP TABLE IF EXISTS user_state;
