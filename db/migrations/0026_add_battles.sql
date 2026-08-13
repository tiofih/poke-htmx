-- 0026: historico/rank de batalhas (D3). Idempotente; sem truncate.
-- Oponente serializado como JSONB (array de {number, name}); created_at pelo banco.

CREATE TABLE IF NOT EXISTS battles (
  id SERIAL PRIMARY KEY,
  user_id TEXT NOT NULL,
  result TEXT NOT NULL,
  opponent_team JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS battles_user_created_idx
  ON battles (user_id, created_at DESC);